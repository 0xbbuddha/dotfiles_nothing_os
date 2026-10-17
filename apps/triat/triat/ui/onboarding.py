"""Écran Bienvenue (screens.md §11).

Affiché au premier lancement. Trois étapes, toutes facultatives : Triat doit
rester utilisable sans compte.
"""

from __future__ import annotations

import logging
import threading

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")

from gi.repository import Adw, GLib, Gtk

from ..core.auth import CookieError
from ..core.downloads import FORMATS

log = logging.getLogger(__name__)

BROWSERS = ("firefox", "chromium", "brave", "vivaldi", "librewolf")
STEPS = 3


def _label(text: str, *css: str, **kwargs) -> Gtk.Label:
    widget = Gtk.Label(label=text, xalign=0, **kwargs)
    for name in css:
        widget.add_css_class(name)
    return widget


class OnboardingView(Gtk.Box):
    """Accueil du premier lancement. Émet `finished` quand on peut entrer."""

    def __init__(self, engine, on_finish) -> None:
        super().__init__(orientation=Gtk.Orientation.HORIZONTAL, spacing=0)
        self.add_css_class("triat-onboarding")
        self._engine = engine
        self._on_finish = on_finish
        self._step = 0

        self.append(self._build_left())
        self.append(self._build_right())
        self._show_step(0)

    # ---- Colonne gauche : identité ---------------------------------------

    def _build_left(self) -> Gtk.Widget:
        column = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=16,
                         valign=Gtk.Align.CENTER, hexpand=True)
        column.set_margin_start(56)
        column.set_margin_end(40)

        wordmark = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        name = _label("triat", "triat-display", "nav")
        name.add_css_class("hero")
        wordmark.append(name)
        dot = Gtk.Box(valign=Gtk.Align.CENTER)
        dot.add_css_class("triat-accent-dot")
        dot.set_size_request(10, 10)
        wordmark.append(dot)
        column.append(wordmark)

        column.append(_label(
            "Toute la musique de YouTube. Sans publicité, sans intro parlée.",
            "triat-body", wrap=True, max_width_chars=34))

        engagements = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        engagements.set_margin_top(20)
        for titre, detail in (
            ("Local d'abord",
             "Bibliothèque, playlists et historique restent sur votre machine."),
            ("Aucune télémétrie",
             "Rien n'est envoyé ailleurs que vers YouTube et SponsorBlock."),
            ("SponsorBlock intégré",
             "Les passages non musicaux sont sautés automatiquement."),
        ):
            ligne = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
            marqueur = Gtk.Box(valign=Gtk.Align.START)
            marqueur.add_css_class("triat-chip-dot")
            marqueur.set_size_request(5, 5)
            marqueur.set_margin_top(7)
            ligne.append(marqueur)
            textes = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
            textes.append(_label(titre, "triat-body"))
            textes.append(_label(detail, "triat-body", "triat-dim", wrap=True,
                                 max_width_chars=38))
            ligne.append(textes)
            engagements.append(ligne)
        column.append(engagements)

        field = Gtk.Box()
        field.add_css_class("triat-dotfield")
        field.set_size_request(260, 200)
        field.set_can_target(False)
        field.set_halign(Gtk.Align.START)

        overlay = Gtk.Overlay()
        overlay.set_child(column)
        overlay.add_overlay(field)
        return overlay

    # ---- Colonne droite : étapes -----------------------------------------

    def _build_right(self) -> Gtk.Widget:
        card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=18)
        card.add_css_class("triat-card")
        card.set_size_request(520, -1)
        card.set_valign(Gtk.Align.CENTER)
        card.set_margin_end(56)
        card.set_margin_top(40)
        card.set_margin_bottom(40)

        self._step_label = _label("", "triat-label", "triat-dim")
        card.append(self._step_label)

        self._dots = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        self._step_dots = []
        for _ in range(STEPS):
            dot = Gtk.Box()
            dot.add_css_class("triat-chip-dot")
            dot.set_size_request(8, 8)
            self._step_dots.append(dot)
            self._dots.append(dot)
        card.append(self._dots)

        self._stack = Gtk.Stack()
        self._stack.set_transition_type(Gtk.StackTransitionType.CROSSFADE)
        self._stack.add_named(self._step_account(), "account")
        self._stack.add_named(self._step_sponsorblock(), "sponsorblock")
        self._stack.add_named(self._step_quality(), "quality")
        card.append(self._stack)

        buttons = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        buttons.set_margin_top(8)
        self._skip = Gtk.Button(label="Continuer sans compte")
        self._skip.add_css_class("pill")
        self._skip.set_size_request(-1, 44)
        self._skip.connect("clicked", lambda *_: self._next())
        buttons.append(self._skip)
        buttons.append(Gtk.Box(hexpand=True))
        self._next_button = Gtk.Button(label="Suivant")
        self._next_button.add_css_class("suggested-action")
        self._next_button.add_css_class("pill")
        self._next_button.set_size_request(-1, 44)
        self._next_button.connect("clicked", lambda *_: self._next())
        buttons.append(self._next_button)
        card.append(buttons)
        return card

    def _step_account(self) -> Gtk.Widget:
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        box.append(_label("Importer vos cookies", "triat-display", "sm"))
        box.append(_label(
            "Sans compte, la recherche, la lecture et SponsorBlock "
            "fonctionnent. Les recommandations personnalisées, elles, "
            "demandent une session YouTube.",
            "triat-body", "triat-dim", wrap=True, max_width_chars=52))

        detected = self._detect_browsers()
        self._browser = Gtk.DropDown.new_from_strings(
            [b.capitalize() for b in detected] or ["Aucun navigateur détecté"])
        self._browser.set_sensitive(bool(detected))
        self._detected = detected
        box.append(self._browser)

        self._import = Gtk.Button(label="Importer depuis ce navigateur")
        self._import.add_css_class("suggested-action")
        self._import.add_css_class("pill")
        self._import.set_size_request(-1, 44)
        self._import.set_sensitive(bool(detected))
        self._import.connect("clicked", self._do_import)
        box.append(self._import)

        self._account_status = _label(
            "Les cookies sont chiffrés dans le trousseau du système, "
            "jamais écrits en clair.",
            "triat-body", "triat-dim", wrap=True, max_width_chars=52)
        box.append(self._account_status)
        return box

    def _step_sponsorblock(self) -> Gtk.Widget:
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        box.append(_label("Sauter le hors-sujet", "triat-display", "sm"))
        box.append(_label(
            "Triat saute les passages non musicaux : intros parlées, "
            "sponsors, rappels d'abonnement. Réglable catégorie par "
            "catégorie dans les réglages.",
            "triat-body", "triat-dim", wrap=True, max_width_chars=52))

        row = Adw.SwitchRow(title="Sauter les segments",
                            subtitle="Recommandé")
        row.set_active(bool(self._engine.settings.get("sponsorblock_enabled")))
        row.connect("notify::active", lambda r, _p: self._set(
            "sponsorblock_enabled", r.get_active()))
        group = Adw.PreferencesGroup()
        group.add(row)
        box.append(group)
        return box

    def _step_quality(self) -> Gtk.Widget:
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        box.append(_label("Qualité audio", "triat-display", "sm"))
        box.append(_label(
            "Opus offre le meilleur rapport qualité-débit. Ce réglage vaut "
            "pour la lecture comme pour les téléchargements.",
            "triat-body", "triat-dim", wrap=True, max_width_chars=52))

        group = Adw.PreferencesGroup()
        combo = Adw.ComboRow(title="Format téléchargé")
        model = Gtk.StringList()
        values = list(FORMATS)
        for name in values:
            model.append({"opus": "Opus", "m4a": "M4A (AAC)", "mp3": "MP3"}.get(name, name))
        combo.set_model(model)
        current = self._engine.settings.get("download_format")
        combo.set_selected(values.index(current) if current in values else 0)
        combo.connect("notify::selected", lambda r, _p: self._set(
            "download_format", values[r.get_selected()]))
        group.add(combo)
        box.append(group)
        return box

    # ---- Logique ---------------------------------------------------------

    def _set(self, key: str, value) -> None:
        self._engine.settings.set(key, value)
        self._engine.settings.save()

    @staticmethod
    def _detect_browsers() -> list[str]:
        """Navigateurs dont un profil existe réellement."""
        from pathlib import Path

        home = Path.home()
        chemins = {
            "firefox": home / ".mozilla" / "firefox",
            "librewolf": home / ".librewolf",
            "chromium": home / ".config" / "chromium",
            "brave": home / ".config" / "BraveSoftware",
            "vivaldi": home / ".config" / "vivaldi",
        }
        return [name for name in BROWSERS
                if name in chemins and chemins[name].is_dir()]

    def _do_import(self, button: Gtk.Button) -> None:
        if not self._detected:
            return
        name = self._detected[self._browser.get_selected()]
        button.set_sensitive(False)
        self._account_status.set_text(f"Lecture du profil {name}…")

        def worker() -> None:
            try:
                status = self._engine.cookies.import_from_browser(name)
            except CookieError as exc:
                GLib.idle_add(self._import_done, button, None, str(exc))
                return
            except Exception as exc:
                log.exception("Import impossible")
                GLib.idle_add(self._import_done, button, None, str(exc))
                return
            GLib.idle_add(self._import_done, button, status, None)

        threading.Thread(target=worker, daemon=True).start()

    def _import_done(self, button: Gtk.Button, status, error) -> bool:
        button.set_sensitive(True)
        if error:
            self._account_status.set_text(error.split("\n")[0][:110])
            return GLib.SOURCE_REMOVE
        self._engine.ytmusic.invalidate()
        self._engine.innertube.invalidate()
        if status is not None and status.authenticated:
            self._account_status.set_text(
                f"Session trouvée : {status.count} cookies. "
                "Les recommandations sont actives.")
            self._skip.set_label("Passer")
        else:
            self._account_status.set_text(
                "Cookies importés, mais sans session connectée. "
                "Connectez-vous à YouTube dans le navigateur, puis réessayez.")
        return GLib.SOURCE_REMOVE

    def _show_step(self, index: int) -> None:
        self._step = index
        names = ("account", "sponsorblock", "quality")
        titres = ("compte, facultatif", "SponsorBlock", "qualité")
        self._stack.set_visible_child_name(names[index])
        self._step_label.set_text(f"Étape {index + 1} sur {STEPS} : {titres[index]}")
        for position, dot in enumerate(self._step_dots):
            if position == index:
                dot.add_css_class("triat-accent-dot")
                dot.remove_css_class("triat-chip-dot")
            else:
                dot.remove_css_class("triat-accent-dot")
                dot.add_css_class("triat-chip-dot")
        self._skip.set_visible(index == 0)
        self._next_button.set_label(
            "Commencer" if index == STEPS - 1 else "Suivant")

    def _next(self) -> None:
        if self._step + 1 < STEPS:
            self._show_step(self._step + 1)
            return
        self._set("onboarding_done", True)
        self._on_finish()
