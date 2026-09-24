"""Point d'entrée de Triat."""

from __future__ import annotations

import logging
import os
import sys
from pathlib import Path

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")

from gi.repository import Adw, Gdk, Gio, GLib, Gtk

from .core import logs
from .core.engine import Engine
from .core import desktop
from .core.paths import data_dir, state_dir
from .ui.mini_player import MiniPlayer
from .ui.window import TriatWindow

APP_ID = "org.triat.Triat"
DATA_DIR = Path(__file__).parent.parent / "data"

log = logging.getLogger(__name__)


class TriatApp(Adw.Application):
    def __init__(self) -> None:
        super().__init__(application_id=APP_ID,
                         flags=Gio.ApplicationFlags.DEFAULT_FLAGS)
        self._window: TriatWindow | None = None
        self._mini: MiniPlayer | None = None
        self._engine: Engine | None = None
        self._mpris = None
        self._start_mini = False
        self._start_action: str | None = None
        self._quitting = False

    # ---- Cycle de vie ----------------------------------------------------

    def do_startup(self) -> None:
        Adw.Application.do_startup(self)
        # Triat est monochrome sombre ; le thème clair est prévu pour M2.
        Adw.StyleManager.get_default().set_color_scheme(Adw.ColorScheme.FORCE_DARK)
        self._load_icons()
        Gtk.Window.set_default_icon_name(APP_ID)
        self._load_fonts()
        self._load_css()

        self._fatal: str | None = None
        try:
            self._engine = Engine()
        except Exception as exc:  # noqa: BLE001 - montré à l'utilisateur
            log.critical("Le moteur ne démarre pas", exc_info=True)
            self._engine = None
            self._fatal = str(exc) or exc.__class__.__name__
            return
        self._apply_desktop_accent()

        for name, accels, callback in (
            ("quit", ["<Primary>q"], lambda *_: self.quit_for_real()),
            ("next", [], lambda *_: self._engine.next()),
            ("previous", [], lambda *_: self._engine.previous()),
            # Appelables depuis une autre instance (lanceur, barre, .desktop).
            ("show", [], lambda *_: self._show_page(None)),
            ("search", [], lambda *_: self._show_page("search")),
            ("mini", [], lambda *_: self._remote_mini()),
            ("play-pause", [], lambda *_: self._engine.toggle_pause()),
        ):
            action = Gio.SimpleAction.new(name, None)
            action.connect("activate", callback)
            self.add_action(action)
            if accels:
                self.set_accels_for_action(f"app.{name}", accels)

    def _show_page(self, page: str | None) -> None:
        """Fenêtre principale au premier plan, sur une page donnée."""
        self.activate()
        if page and self._window is not None:
            self._window._on_navigate(page)

    def _remote_mini(self) -> None:
        if self._window is None:
            self._start_mini = True
            self.activate()
        else:
            self.open_mini()

    def open_mini(self) -> None:
        """Ouvre le mini-lecteur, ou le ramène au premier plan."""
        if self._mini is None:
            self._mini = MiniPlayer(self, self._engine, self._show_main)
            self._mini.connect("close-request", self._on_mini_closed)
        self._mini.present()

    def _on_mini_closed(self, *_args) -> bool:
        self._mini = None
        # Fermer le mini sans fenêtre principale ouverte quitte l'application,
        # sauf si une piste joue : elle continue en arrière-plan.
        playing = self._engine is not None and self._engine.state == "playing"
        if (self._window is None or not self._window.get_visible()) and not playing:
            self.quit_for_real()
        return False

    def _show_fatal(self) -> None:
        """Le moteur n'a pas démarré : on le dit, avec de quoi agir."""
        journal = state_dir() / "triat.log"
        page = Adw.StatusPage(
            icon_name="triat-play-symbolic",
            title="Triat ne peut pas démarrer",
            description=(f"{self._fatal}\n\nDétails dans {journal}.\n"
                         "« triat doctor » dans un terminal vérifie "
                         "l'installation (libmpv, yt-dlp, cookies)."))
        close = Gtk.Button(label="Quitter", halign=Gtk.Align.CENTER)
        close.add_css_class("suggested-action")
        close.connect("clicked", lambda *_: self.quit())
        page.set_child(close)
        window = Adw.ApplicationWindow(application=self, title="Triat",
                                       content=page)
        window.set_default_size(560, 420)
        window.present()

    def _show_main(self) -> None:
        self.do_activate()

    def do_activate(self) -> None:
        if self._engine is None:
            self._show_fatal()
            return
        if self._start_mini:
            self._start_mini = False
            if self._window is None:
                # Le moteur et l'état doivent exister avant le mini-lecteur.
                self._window = TriatWindow(self, self._engine,
                                           data_path=str(data_dir()))
                self._window.connect("close-request", self._on_close)
                self._publish_mpris()
                self._engine.restore_state()
                self._schedule_backfill()
            self.open_mini()
            return
        if self._window is None:
            self._window = TriatWindow(self, self._engine, data_path=str(data_dir()))
            self._window.connect("close-request", self._on_close)
            self._publish_mpris()
            # La restauration émet « track-changed » : elle doit venir après
            # la fenêtre, sinon personne n'écoute et la barre reste vide.
            self._engine.restore_state()
            self._schedule_backfill()
        reactivated = self._window.get_mapped()
        self._window.present()
        if reactivated:
            GLib.idle_add(lambda: (desktop.focus_under_hyprland(APP_ID), False)[1])
        action, self._start_action = self._start_action, None
        if action == "search":
            self._window._on_navigate("search")
        elif action == "play-pause" and self._engine is not None:
            self._engine.toggle_pause()

    def _schedule_backfill(self) -> None:
        """Durées manquantes complétées après le démarrage, pas pendant."""
        engine = self._engine
        GLib.timeout_add_seconds(
            8, lambda: (engine.backfill_durations_async(), False)[1])

    def do_shutdown(self) -> None:
        self._teardown()
        Adw.Application.do_shutdown(self)

    def _on_close(self, window, *_args) -> bool:
        """Fermer la fenêtre ne coupe pas la musique.

        Une piste est chargée : la fenêtre se cache, la lecture continue en
        arrière-plan (MPRIS, barre Quickshell, raccourcis). Triat se rouvre
        par la barre, SUPER+M ou le lanceur ; Ctrl+Q le quitte vraiment.
        Rien de chargé : on quitte, comme avant."""
        engine = self._engine
        if engine is not None and engine.current is not None and not self._quitting:
            if self._window is not None:
                self._window.close_immersion()
            engine.save_state()
            window.set_visible(False)
            return True     # garder la fenêtre (cachée) et l'application
        self._teardown()
        return False        # laisser la fenêtre se fermer

    def quit_for_real(self) -> None:
        """Ctrl+Q, « Quitter » de la barre : arrêt complet, lecture comprise."""
        self._quitting = True
        if self._mini is not None:
            self._mini.destroy()
        self._teardown()
        self.quit()

    def _teardown(self) -> None:
        if self._mpris is not None:
            self._mpris.unpublish()
            self._mpris = None
        if self._engine is not None:
            # Enregistre l'historique, la file, puis efface le fichier de
            # cookies déchiffré (voir docs/security/).
            self._engine.shutdown()
            self._engine = None

    # ---- Intégration bureau ----------------------------------------------

    def _publish_mpris(self) -> None:
        try:
            from .services.mpris import MprisService

            service = MprisService(self._engine, self)
            if service.publish():
                self._mpris = service
            else:
                log.info("MPRIS non publié (bus de session indisponible)")
        except Exception as exc:
            log.info("MPRIS indisponible : %s", exc)

    # ---- Habillage -------------------------------------------------------

    @staticmethod
    def _load_icons() -> None:
        """Ajoute nos icônes au thème.

        Sans cela, Triat hérite du thème d'icônes du système — qui peut être
        coloré (Sardi, Papirus…) et casse le monochrome de DESIGN.md §1.
        Nos icônes sont préfixées « triat- » : aucun risque de collision.
        """
        folder = DATA_DIR / "icons"
        if not folder.is_dir():
            return
        display = Gdk.Display.get_default()
        if display is None:
            return
        theme = Gtk.IconTheme.get_for_display(display)
        theme.add_search_path(str(folder))
        # Les icônes standard (fermer, loupe, effacer) venaient elles aussi du
        # thème système : un bouton fermer rouge sous Sardi. Adwaita est
        # installé avec libadwaita et entièrement symbolique.
        # Réglé sur GtkSettings, propre au processus : poser le nom sur le
        # thème ne suffit pas, GtkSettings le réimpose aussitôt.
        settings = Gtk.Settings.get_default()
        if settings is not None and Path("/usr/share/icons/Adwaita").is_dir():
            settings.set_property("gtk-icon-theme-name", "Adwaita")

    @staticmethod
    def _neutralise_user_decorations(display) -> None:
        """Le gtk.css de l'utilisateur (priorité USER, au-dessus de la nôtre)
        peut dessiner des boutons de titre colorés en image de fond : un
        fermer rouge dans nos dialogues. On ne retire que cette image."""
        provider = Gtk.CssProvider()
        provider.load_from_string(
            "button.titlebutton, button.titlebutton:hover,"
            " button.titlebutton:active, button.titlebutton:backdrop"
            " { background-image: none; }")
        Gtk.StyleContext.add_provider_for_display(
            display, provider, Gtk.STYLE_PROVIDER_PRIORITY_USER + 1)

    def _load_css(self) -> None:
        path = DATA_DIR / "style.css"
        if not path.exists():
            log.warning("Feuille de style absente : %s", path)
            return
        provider = Gtk.CssProvider()
        provider.load_from_path(str(path))
        display = Gdk.Display.get_default()
        if display is not None:
            Gtk.StyleContext.add_provider_for_display(
                display, provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
            self._neutralise_user_decorations(display)

    def _apply_desktop_accent(self) -> None:
        """Accorde l'accent de Triat à celui du bureau Nothing OS.

        Chargé dans un second fournisseur, de priorité supérieure : la
        feuille principale reste intacte (GTK.md §2). Le réglage
        `follow_desktop_accent` permet de garder le rouge de DESIGN.md.
        """
        if not self._engine.settings.get("follow_desktop_accent", True):
            return
        accent = desktop.desktop_accent()
        if not accent:
            return
        display = Gdk.Display.get_default()
        if display is None:
            return
        provider = Gtk.CssProvider()
        try:
            provider.load_from_string(desktop.accent_css(accent))
        except AttributeError:      # GTK < 4.12
            provider.load_from_data(desktop.accent_css(accent).encode())
        Gtk.StyleContext.add_provider_for_display(
            display, provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION + 1)
        log.info("Accent accordé au bureau : %s", accent)

    @staticmethod
    def _load_fonts() -> None:
        """Charge Doto / Geist si elles sont fournies dans data/fonts.

        Absentes, les replis du CSS s'appliquent (monospace et Inter) :
        l'app reste utilisable, seule la personnalité typographique manque.
        """
        folder = DATA_DIR / "fonts"
        if not folder.is_dir():
            return
        try:
            gi.require_version("PangoCairo", "1.0")
            from gi.repository import PangoCairo

            font_map = PangoCairo.FontMap.get_default()
            if not hasattr(font_map, "add_font_file"):
                log.info("Pango trop ancien pour charger des polices à chaud")
                return
            chargées = 0
            for font in sorted(folder.glob("*.tt[fc]")) + sorted(folder.glob("*.otf")):
                font_map.add_font_file(str(font))
                chargées += 1
            if chargées:
                log.info("%d police(s) chargée(s) depuis data/fonts", chargées)
        except Exception as exc:
            log.info("Polices non chargées : %s", exc)


def run(argv: list[str] | None = None, mini: bool = False,
        action: str | None = None) -> int:
    """Lance Triat, ou transmet `action` à l'instance déjà ouverte.

    `action` : "search", "mini" ou "play-pause". Sans instance ouverte,
    Triat démarre puis l'exécute."""
    logs.setup()
    app = TriatApp()
    if mini:
        action = "mini"
    if action:
        try:
            app.register(None)
        except GLib.Error as exc:
            log.warning("Enregistrement impossible : %s", exc)
        if app.get_is_remote():
            app.activate_action(action, None)
            # Sans `run()`, GApplication proteste à la destruction qu'on ne
            # s'est pas désinscrit du bus. On vide la file D-Bus et on sort
            # sans finaliser : l'instance ouverte a déjà reçu l'action.
            connection = app.get_dbus_connection()
            if connection is not None:
                connection.flush_sync(None)
            os._exit(0)
        app._start_action = action
    app._start_mini = action == "mini"
    return app.run(argv if argv is not None else sys.argv)


def main(argv: list[str] | None = None) -> int:
    logs.setup()
    return TriatApp().run(argv if argv is not None else sys.argv)
