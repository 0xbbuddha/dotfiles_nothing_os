"""Surface vidéo : mpv dessine le clip dans un `Gtk.GLArea` (GTK.md §6).

L'API de rendu de libmpv écrit dans le framebuffer que GTK nous prête à
chaque image ; les contrôles Triat restent des widgets GTK posés par-dessus.
mpv n'ouvre donc jamais sa propre fenêtre, et tout fonctionne sous Wayland.

Le contexte de rendu vit exactement le temps de la réalisation du widget :
créé à `realize`, libéré à `unrealize`, toujours avec le contexte GL courant.
"""

from __future__ import annotations

import ctypes
import logging

import gi

gi.require_version("Gtk", "4.0")

import mpv
from gi.repository import GLib, Gtk

log = logging.getLogger(__name__)

GL_DRAW_FRAMEBUFFER_BINDING = 0x8CA6


def _load_proc_loader():
    """`eglGetProcAddress`, ou `glXGetProcAddressARB` pour une session X11
    sans EGL. GTK 4 passe par EGL presque partout."""
    for lib, symbol in (("libEGL.so.1", "eglGetProcAddress"),
                        ("libGL.so.1", "glXGetProcAddressARB")):
        try:
            fn = getattr(ctypes.CDLL(lib), symbol)
        except (OSError, AttributeError):
            continue
        fn.restype = ctypes.c_void_p
        fn.argtypes = [ctypes.c_char_p]
        return fn
    return None


_PROC_LOADER = _load_proc_loader()
_GetIntegerv = ctypes.CFUNCTYPE(None, ctypes.c_uint,
                                ctypes.POINTER(ctypes.c_int))
_ClearColor = ctypes.CFUNCTYPE(None, ctypes.c_float, ctypes.c_float,
                               ctypes.c_float, ctypes.c_float)
_Clear = ctypes.CFUNCTYPE(None, ctypes.c_uint)
GL_COLOR_BUFFER_BIT = 0x4000


def _proc_address(_ctx, name: bytes) -> int | None:
    return _PROC_LOADER(name) if _PROC_LOADER is not None else None


class VideoArea(Gtk.GLArea):
    """Affiche la vidéo de l'instance mpv du `Player`."""

    def __init__(self, player) -> None:
        super().__init__()
        self._player = player
        self._ctx = None
        self._get_integerv = None
        # Garder une référence : mpv appelle ce pointeur de fonction C.
        self._proc_cb = mpv.MpvGlGetProcAddressFn(_proc_address)
        self._redraw_pending = False
        self._tick = 0
        self.set_auto_render(False)
        self.set_hexpand(True)
        self.set_vexpand(True)
        self.add_css_class("triat-video")
        self.connect("realize", self._on_realize)
        self.connect("unrealize", self._on_unrealize)
        self.connect("render", self._on_render)
        self.connect("map", lambda *_: self._schedule_redraw())

    @property
    def ready(self) -> bool:
        return self._ctx is not None

    def _on_realize(self, _area) -> None:
        self.make_current()
        if self.get_error() is not None or _PROC_LOADER is None:
            log.warning("OpenGL indisponible : %s", self.get_error())
            return
        address = _PROC_LOADER(b"glGetIntegerv")
        if not address:
            log.warning("glGetIntegerv introuvable")
            return
        self._get_integerv = _GetIntegerv(address)
        self._clear_color = _ClearColor(_PROC_LOADER(b"glClearColor"))
        self._clear = _Clear(_PROC_LOADER(b"glClear"))
        try:
            self._ctx = self._player.create_render_context(self._proc_cb)
        except Exception as exc:
            log.warning("Contexte de rendu mpv refusé : %s", exc)
            self._ctx = None
            return
        # Appelé depuis un thread de mpv : on repasse par la boucle GLib.
        self._ctx.update_cb = self._schedule_redraw
        # Filet de sécurité : sonder mpv à chaque image de l'horloge GTK,
        # au cas où un rappel se perdrait. Ne dessine que si mpv a une
        # nouvelle image : le coût reste négligeable.
        self._tick = self.add_tick_callback(self._on_tick)

    def _on_tick(self, _widget, _clock) -> bool:
        if self._ctx is not None and self._ctx.update():
            self.queue_render()
        return GLib.SOURCE_CONTINUE

    def _on_unrealize(self, _area) -> None:
        if self._tick:
            self.remove_tick_callback(self._tick)
            self._tick = 0
        if self._ctx is None:
            return
        self.make_current()
        self._ctx = None
        self._player.free_render_context()

    def _schedule_redraw(self) -> None:
        if not self._redraw_pending:
            self._redraw_pending = True
            GLib.idle_add(self._redraw)

    def _redraw(self) -> bool:
        self._redraw_pending = False
        if self._ctx is not None:
            # L'API de rendu exige cet appel après chaque rappel : sans lui,
            # mpv cesse de signaler les images suivantes si l'une d'elles
            # n'a pas été dessinée (surface masquée au moment du rappel).
            self._ctx.update()
            self.queue_render()
        return GLib.SOURCE_REMOVE

    def _on_render(self, _area, _gl_context) -> bool:
        if self._ctx is None:
            return False
        fbo = ctypes.c_int(0)
        self._get_integerv(GL_DRAW_FRAMEBUFFER_BINDING, ctypes.byref(fbo))
        # Fond noir tant qu'aucune image n'est décodée : sans cela, le
        # framebuffer prêté par GTK garde des restes d'une image précédente.
        self._clear_color(0.0, 0.0, 0.0, 1.0)
        self._clear(GL_COLOR_BUFFER_BIT)
        scale = self.get_scale_factor()
        self._ctx.render(flip_y=True, opengl_fbo={
            "fbo": fbo.value,
            "w": self.get_width() * scale,
            "h": self.get_height() * scale,
        })
        return True
