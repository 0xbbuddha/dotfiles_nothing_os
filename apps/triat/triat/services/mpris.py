"""Intégration MPRIS2 : contrôle depuis GNOME/KDE et les touches média.

Implémenté directement sur Gio.DBusConnection pour ne pas ajouter de
dépendance D-Bus supplémentaire.
"""

from __future__ import annotations

import os

import logging
import re

from gi.repository import Gio, GLib

from ..core.net import is_safe_url

log = logging.getLogger(__name__)

BUS_NAME = "org.mpris.MediaPlayer2.triat"
OBJECT_PATH = "/org/mpris/MediaPlayer2"
ROOT_IFACE = "org.mpris.MediaPlayer2"
PLAYER_IFACE = "org.mpris.MediaPlayer2.Player"
PROPS_IFACE = "org.freedesktop.DBus.Properties"
TRACK_PATH_PREFIX = "/org/triat/Triat/track/"

INTROSPECTION = """
<node>
  <interface name="org.mpris.MediaPlayer2">
    <method name="Raise"/>
    <method name="Quit"/>
    <property name="CanQuit" type="b" access="read"/>
    <property name="CanRaise" type="b" access="read"/>
    <property name="HasTrackList" type="b" access="read"/>
    <property name="Identity" type="s" access="read"/>
    <property name="DesktopEntry" type="s" access="read"/>
    <property name="SupportedUriSchemes" type="as" access="read"/>
    <property name="SupportedMimeTypes" type="as" access="read"/>
  </interface>
  <interface name="org.mpris.MediaPlayer2.Player">
    <method name="Next"/>
    <method name="Previous"/>
    <method name="Pause"/>
    <method name="PlayPause"/>
    <method name="Stop"/>
    <method name="Play"/>
    <method name="Seek">
      <arg direction="in" name="Offset" type="x"/>
    </method>
    <method name="SetPosition">
      <arg direction="in" name="TrackId" type="o"/>
      <arg direction="in" name="Position" type="x"/>
    </method>
    <method name="OpenUri">
      <arg direction="in" name="Uri" type="s"/>
    </method>
    <signal name="Seeked">
      <arg name="Position" type="x"/>
    </signal>
    <property name="PlaybackStatus" type="s" access="read"/>
    <property name="LoopStatus" type="s" access="readwrite"/>
    <property name="Rate" type="d" access="readwrite"/>
    <property name="Shuffle" type="b" access="readwrite"/>
    <property name="Metadata" type="a{sv}" access="read"/>
    <property name="Volume" type="d" access="readwrite"/>
    <property name="Position" type="x" access="read"/>
    <property name="MinimumRate" type="d" access="read"/>
    <property name="MaximumRate" type="d" access="read"/>
    <property name="CanGoNext" type="b" access="read"/>
    <property name="CanGoPrevious" type="b" access="read"/>
    <property name="CanPlay" type="b" access="read"/>
    <property name="CanPause" type="b" access="read"/>
    <property name="CanSeek" type="b" access="read"/>
    <property name="CanControl" type="b" access="read"/>
  </interface>
</node>
"""

LOOP_TO_REPEAT = {"None": "off", "Track": "one", "Playlist": "all"}
REPEAT_TO_LOOP = {v: k for k, v in LOOP_TO_REPEAT.items()}


def track_object_path(video_id: str) -> str:
    """Un identifiant MPRIS doit être un chemin d'objet D-Bus valide."""
    if not video_id:
        return TRACK_PATH_PREFIX + "none"
    return TRACK_PATH_PREFIX + re.sub(r"[^A-Za-z0-9_]", "_", video_id)


class MprisService:
    """Publie le lecteur sur le bus de session. Silencieux si D-Bus manque."""

    def __init__(self, engine, application=None) -> None:
        self._engine = engine
        self._app = application
        self._connection: Gio.DBusConnection | None = None
        self._owner_id = 0
        self._registration = 0
        self._player_registration = 0
        self._node = Gio.DBusNodeInfo.new_for_xml(INTROSPECTION)

    # ---- Cycle de vie ---------------------------------------------------

    def publish(self) -> bool:
        try:
            self._connection = Gio.bus_get_sync(Gio.BusType.SESSION, None)
        except GLib.Error as exc:
            log.warning("Bus de session indisponible, MPRIS désactivé: %s", exc)
            return False

        try:
            self._registration = self._connection.register_object(
                OBJECT_PATH,
                self._node.interfaces[0],
                self._on_method_call,
                self._on_get_property,
                self._on_set_property,
            )
            # register_object n'accepte qu'une interface : la seconde est
            # enregistrée sur le même chemin par un second appel.
            self._player_registration = self._connection.register_object(
                OBJECT_PATH,
                self._node.interfaces[1],
                self._on_method_call,
                self._on_get_property,
                self._on_set_property,
            )
        except GLib.Error as exc:
            log.warning("Enregistrement MPRIS impossible: %s", exc)
            return False

        # Suffixe « instance<pid> », la convention MPRIS : unique par
        # processus, sans rien révéler de l'utilisateur.
        self._owner_id = Gio.bus_own_name(
            Gio.BusType.SESSION,
            f"{BUS_NAME}.instance{os.getpid()}",
            Gio.BusNameOwnerFlags.NONE,
            None, None, None,
        )
        self._connect_engine()
        return True

    def unpublish(self) -> None:
        if self._connection is not None:
            for registration in (self._registration, self._player_registration):
                if registration:
                    self._connection.unregister_object(registration)
            self._registration = self._player_registration = 0
        if self._owner_id:
            Gio.bus_unown_name(self._owner_id)
            self._owner_id = 0

    def _connect_engine(self) -> None:
        e = self._engine
        e.connect("track-changed", lambda *_: self._changed(
            ["Metadata", "CanGoNext", "CanGoPrevious"]))
        e.connect("state-changed", lambda *_: self._changed(
            ["PlaybackStatus", "CanPause", "CanPlay", "CanSeek"]))
        e.connect("duration-changed", lambda *_: self._changed(["Metadata"]))
        e.connect("queue-changed", lambda *_: self._changed(
            ["CanGoNext", "CanGoPrevious"]))

    # ---- Émission -------------------------------------------------------

    def _changed(self, names: list[str]) -> None:
        if self._connection is None:
            return
        changed = {}
        for name in names:
            try:
                changed[name] = self._player_property(name)
            except Exception as exc:
                log.debug("Propriété MPRIS %s indisponible: %s", name, exc)
        if not changed:
            return
        payload = GLib.Variant("(sa{sv}as)", (PLAYER_IFACE, changed, []))
        try:
            self._connection.emit_signal(None, OBJECT_PATH, PROPS_IFACE,
                                         "PropertiesChanged", payload)
        except GLib.Error as exc:
            log.debug("Émission PropertiesChanged échouée: %s", exc)

    def emit_seeked(self, position: float) -> None:
        if self._connection is None:
            return
        try:
            self._connection.emit_signal(
                None, OBJECT_PATH, PLAYER_IFACE, "Seeked",
                GLib.Variant("(x)", (int(position * 1e6),)))
        except GLib.Error as exc:
            log.debug("Émission Seeked échouée: %s", exc)

    # ---- Méthodes D-Bus --------------------------------------------------

    def _on_method_call(self, _conn, _sender, _path, interface, method,
                        params, invocation) -> None:
        engine = self._engine
        try:
            if interface == ROOT_IFACE:
                if method == "Raise" and self._app is not None:
                    window = self._app.get_active_window()
                    if window is not None:
                        window.present()
                elif method == "Quit" and self._app is not None:
                    self._app.quit()
            elif interface == PLAYER_IFACE:
                if method == "Next":
                    engine.next()
                elif method == "Previous":
                    engine.previous()
                elif method == "PlayPause":
                    engine.toggle_pause()
                elif method == "Play":
                    if engine.player.state in ("paused", "idle"):
                        engine.toggle_pause()
                elif method == "Pause":
                    if engine.player.state == "playing":
                        engine.toggle_pause()
                elif method == "Stop":
                    engine.stop()
                elif method == "Seek":
                    offset = params.unpack()[0] / 1e6
                    engine.seek(max(0.0, engine.player.position_hint + offset))
                elif method == "SetPosition":
                    _track_id, position = params.unpack()
                    engine.seek(position / 1e6)
                elif method == "OpenUri":
                    # N'importe quelle application du bus de session peut
                    # appeler OpenUri : on n'accepte que les schémas déclarés
                    # dans SupportedUriSchemes, jamais file:// ni autre.
                    uri = params.unpack()[0]
                    if is_safe_url(uri):
                        engine.play_query(uri)
                    else:
                        log.warning("OpenUri refusé : schéma non autorisé")
            invocation.return_value(None)
        except Exception as exc:
            log.warning("Appel MPRIS %s.%s échoué: %s", interface, method, exc)
            invocation.return_value(None)

    # ---- Propriétés ------------------------------------------------------

    def _on_get_property(self, _conn, _sender, _path, interface, name):
        try:
            if interface == ROOT_IFACE:
                return self._root_property(name)
            return self._player_property(name)
        except Exception as exc:
            log.debug("Lecture propriété %s échouée: %s", name, exc)
            return None

    def _on_set_property(self, _conn, _sender, _path, _interface, name, value) -> bool:
        engine = self._engine
        try:
            if name == "Volume":
                engine.set_volume(max(0.0, min(1.0, value.get_double())) * 100)
                self._changed(["Volume"])
            elif name == "Shuffle":
                engine.shuffle = value.get_boolean()
                self._changed(["Shuffle"])
            elif name == "LoopStatus":
                engine.repeat = LOOP_TO_REPEAT.get(value.get_string(), "off")
                self._changed(["LoopStatus"])
            else:
                return False
        except Exception as exc:
            log.warning("Écriture propriété MPRIS %s échouée: %s", name, exc)
            return False
        return True

    @staticmethod
    def _root_property(name: str):
        values = {
            "CanQuit": GLib.Variant("b", True),
            "CanRaise": GLib.Variant("b", True),
            "HasTrackList": GLib.Variant("b", False),
            "Identity": GLib.Variant("s", "Triat"),
            "DesktopEntry": GLib.Variant("s", "org.triat.Triat"),
            "SupportedUriSchemes": GLib.Variant("as", ["http", "https"]),
            "SupportedMimeTypes": GLib.Variant("as", []),
        }
        return values.get(name)

    def _player_property(self, name: str):
        engine = self._engine
        state = engine.player.state
        if name == "PlaybackStatus":
            status = {"playing": "Playing", "paused": "Paused",
                      "loading": "Playing"}.get(state, "Stopped")
            return GLib.Variant("s", status)
        if name == "LoopStatus":
            return GLib.Variant("s", REPEAT_TO_LOOP.get(engine.repeat, "None"))
        if name == "Shuffle":
            return GLib.Variant("b", engine.shuffle)
        if name == "Rate":
            return GLib.Variant("d", 1.0)
        if name == "MinimumRate":
            return GLib.Variant("d", 1.0)
        if name == "MaximumRate":
            return GLib.Variant("d", 1.0)
        if name == "Volume":
            return GLib.Variant("d", float(engine.settings.get("volume")) / 100.0)
        if name == "Position":
            return GLib.Variant("x", int(engine.player.position_hint * 1e6))
        if name == "Metadata":
            return GLib.Variant("a{sv}", self._metadata())
        if name == "CanGoNext":
            return GLib.Variant("b", engine.queue.has_next)
        if name == "CanGoPrevious":
            return GLib.Variant("b", engine.queue.has_previous)
        if name == "CanPlay":
            return GLib.Variant("b", engine.current is not None)
        if name == "CanPause":
            return GLib.Variant("b", state in ("playing", "paused"))
        if name == "CanSeek":
            return GLib.Variant("b", state in ("playing", "paused"))
        if name == "CanControl":
            return GLib.Variant("b", True)
        return None

    def _metadata(self) -> dict:
        ref = self._engine.current
        if ref is None:
            return {"mpris:trackid": GLib.Variant("o", track_object_path(""))}
        duration = self._engine.player.duration or ref.duration
        data = {
            "mpris:trackid": GLib.Variant("o", track_object_path(ref.video_id)),
            "mpris:length": GLib.Variant("x", int(max(0.0, duration) * 1e6)),
            "xesam:title": GLib.Variant("s", ref.title or ""),
            "xesam:artist": GLib.Variant("as", [ref.artist] if ref.artist else []),
            "xesam:url": GLib.Variant("s", ref.url),
        }
        if ref.album:
            data["xesam:album"] = GLib.Variant("s", ref.album)
        if ref.thumbnail:
            data["mpris:artUrl"] = GLib.Variant("s", ref.thumbnail)
        return data
