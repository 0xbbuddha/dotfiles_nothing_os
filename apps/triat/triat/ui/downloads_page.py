"""Écran Hors-ligne (screens.md §9)."""

from __future__ import annotations

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")

from gi.repository import Adw, GLib, Gtk

from ..core.downloads import DONE, FAILED, PENDING, RUNNING
from ..core.paths import downloads_dir

STATE_LABELS = {
    PENDING: "en attente",
    RUNNING: "en cours",
    DONE: "terminé",
    FAILED: "échec",
}
FORMATS = (("opus", "Opus"), ("m4a", "M4A"), ("mp3", "MP3"))


def _label(text: str, *css: str, **kwargs) -> Gtk.Label:
    widget = Gtk.Label(label=text, xalign=0, **kwargs)
    for name in css:
        widget.add_css_class(name)
    return widget


class DownloadsPage(Gtk.Box):
    def __init__(self, engine) -> None:
        super().__init__(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.add_css_class("triat-content")
        self._engine = engine
        self._rows: dict[str, Gtk.Widget] = {}

        column = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=20)
        column.set_margin_bottom(24)

        header = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        title = _label("Hors-ligne", "triat-display", "lg")
        title.set_hexpand(True)
        header.append(title)

        self.pause_button = Gtk.Button(label="Tout suspendre",
                                       valign=Gtk.Align.CENTER)
        self.pause_button.add_css_class("pill")
        self.pause_button.connect("clicked", self._toggle_pause)
        header.append(self.pause_button)
        column.append(header)

        self.summary = _label("", "triat-label", "triat-dim")
        column.append(self.summary)

        options = Adw.PreferencesGroup(title="Options")
        fmt = Adw.ComboRow(title="Format",
                           subtitle="Opus offre le meilleur rapport qualité/poids")
        model = Gtk.StringList()
        for _value, name in FORMATS:
            model.append(name)
        fmt.set_model(model)
        current = engine.settings.get("download_format")
        fmt.set_selected(next((i for i, (v, _) in enumerate(FORMATS)
                               if v == current), 0))
        fmt.connect("notify::selected", lambda r, _p: self._set(
            "download_format", FORMATS[r.get_selected()][0]))
        options.add(fmt)

        cut = Adw.SwitchRow(
            title="Couper les segments SponsorBlock",
            subtitle="Le fichier produit ne contient plus les passages non musicaux")
        cut.set_active(bool(engine.settings.get("download_cut_sponsorblock")))
        cut.connect("notify::active", lambda r, _p: self._set(
            "download_cut_sponsorblock", r.get_active()))
        options.add(cut)

        folder = Adw.ActionRow(title="Dossier", subtitle=str(downloads_dir()))
        options.add(folder)
        column.append(options)

        self.list_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        column.append(self.list_box)

        self.empty = _label(
            "Aucun téléchargement. Clic droit sur une piste pour l'ajouter.",
            "triat-body", "triat-dim", wrap=True, max_width_chars=54)
        column.append(self.empty)

        scroller = Gtk.ScrolledWindow(hexpand=True, vexpand=True)
        scroller.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scroller.set_child(column)
        self.append(scroller)

        self._refresh_pending = False
        engine.downloads.on_change = self._on_change
        self.refresh()

    # ---- Réglages --------------------------------------------------------

    def _set(self, key: str, value) -> None:
        self._engine.settings.set(key, value)
        self._engine.settings.save()

    def _toggle_pause(self, _button) -> None:
        manager = self._engine.downloads
        if manager.paused:
            manager.resume()
        else:
            manager.pause()
        self.refresh()

    # ---- Affichage -------------------------------------------------------

    def _on_change(self, _task) -> None:
        # Appelé depuis le thread de téléchargement, à chaque tranche de
        # progression : on regroupe en un rafraîchissement au plus toutes
        # les 250 ms au lieu de reconstruire la page des dizaines de fois
        # par seconde.
        if not self._refresh_pending:
            self._refresh_pending = True
            GLib.timeout_add(250, self._deferred_refresh)

    def _deferred_refresh(self) -> bool:
        self._refresh_pending = False
        self.refresh()
        return GLib.SOURCE_REMOVE

    def refresh(self) -> bool:
        manager = self._engine.downloads
        tasks = manager.tasks

        while (child := self.list_box.get_first_child()) is not None:
            self.list_box.remove(child)

        self.empty.set_visible(not tasks)
        self.pause_button.set_label(
            "Reprendre" if manager.paused else "Tout suspendre")

        done = sum(1 for t in tasks if t.state == DONE)
        self.summary.set_text(
            f"{done} terminés, {len(tasks) - done} en file"
            if tasks else "")

        for task in tasks:
            self.list_box.append(self._row(task))
        return GLib.SOURCE_REMOVE

    def _row(self, task) -> Gtk.Widget:
        row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        row.add_css_class("triat-track-row")
        row.set_size_request(-1, 56)

        texts = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2,
                        hexpand=True, valign=Gtk.Align.CENTER)
        title = _label(task.ref.title, "triat-body")
        title.set_ellipsize(3)
        title.set_max_width_chars(40)
        texts.append(title)

        state = STATE_LABELS.get(task.state, task.state)
        detail = f"{task.ref.artist or '—'} · {state}"
        if task.state == RUNNING:
            detail += f" · {task.progress * 100:.0f} %"
        elif task.state == FAILED and task.error:
            detail += f" · {task.error[:40]}"
        texts.append(_label(detail, "triat-body", "triat-dim"))
        row.append(texts)

        if task.state in (PENDING, RUNNING):
            cancel = Gtk.Button(icon_name="triat-chevron-down-symbolic")
            cancel.add_css_class("flat")
            cancel.add_css_class("circular")
            cancel.set_valign(Gtk.Align.CENTER)
            cancel.set_size_request(36, 36)
            cancel.set_tooltip_text("Annuler")
            cancel.update_property([Gtk.AccessibleProperty.LABEL], ["Annuler"])
            cancel.connect("clicked", lambda *_: (
                self._engine.downloads.cancel(task.ref.video_id),
                self.refresh()))
            row.append(cancel)
        return row
