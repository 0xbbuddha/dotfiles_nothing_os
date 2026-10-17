"""Liste de pistes virtualisée.

`Gtk.ListView` + `Gio.ListStore` + factory, comme l'impose GTK.md §5 : une
playlist ou un historique peut compter des milliers d'entrées, un `Gtk.Box`
rempli en boucle ne tiendrait pas.
"""

from __future__ import annotations

from gi.repository import Gdk, Gio, GObject, Gtk

from ..core.models import TrackRef, display_title
from .widgets.cover import Cover


def format_time(seconds: float) -> str:
    total = int(max(0, seconds or 0))
    minutes, secs = divmod(total, 60)
    hours, minutes = divmod(minutes, 60)
    return f"{hours}:{minutes:02d}:{secs:02d}" if hours else f"{minutes}:{secs:02d}"


# Hauteur d'une ligne : pochette 40 px et marges.
ROW_HEIGHT = 50


class TrackItem(GObject.Object):
    """Enveloppe GObject autour d'un TrackRef, pour le Gio.ListStore."""

    __gtype_name__ = "TriatTrackItem"

    def __init__(self, ref: TrackRef, index: int) -> None:
        super().__init__()
        self.ref = ref
        self.index = index


class TrackList(Gtk.ListView):
    """Liste de pistes. Émet `track-activated` avec l'index dans le modèle."""

    __gtype_name__ = "TriatTrackList"

    __gsignals__ = {
        "track-activated": (GObject.SignalFlags.RUN_FIRST, None, (int,)),
        # Action demandée sur une piste : (nom de l'action, index)
        "track-action": (GObject.SignalFlags.RUN_FIRST, None, (str, int)),
    }

    def __init__(self) -> None:
        self._store = Gio.ListStore(item_type=TrackItem)
        selection = Gtk.SingleSelection(model=self._store, autoselect=False)
        selection.set_can_unselect(True)

        factory = Gtk.SignalListItemFactory()
        factory.connect("setup", self._on_setup)
        factory.connect("bind", self._on_bind)

        super().__init__(model=selection, factory=factory)
        self.add_css_class("triat-track-list")
        self.set_vexpand(True)
        self.connect("activate", self._on_activate)
        self._current_id: str | None = None
        self._menu_index = -1
        self._build_menu()

    # ---- Menu contextuel -------------------------------------------------

    def _build_menu(self) -> None:
        """Menu au clic droit (screens.md §4)."""
        menu = Gio.Menu()
        lecture = Gio.Menu()
        lecture.append("Lire ensuite", "piste.next")
        lecture.append("Ajouter à la file", "piste.queue")
        menu.append_section(None, lecture)

        organiser = Gio.Menu()
        organiser.append("Ajouter aux favoris", "piste.favorite")
        organiser.append("Ajouter à une playlist…", "piste.playlist")
        organiser.append("Télécharger", "piste.download")
        menu.append_section(None, organiser)

        divers = Gio.Menu()
        divers.append("Aller à l'artiste", "piste.artist")
        divers.append("Copier le lien", "piste.copy")
        menu.append_section(None, divers)

        self._popover = Gtk.PopoverMenu.new_from_model(menu)
        self._popover.set_parent(self)
        self._popover.set_has_arrow(False)
        self._popover.set_halign(Gtk.Align.START)

        group = Gio.SimpleActionGroup()
        for name in ("next", "queue", "favorite", "playlist", "copy",
                     "download", "artist"):
            action = Gio.SimpleAction.new(name, None)
            action.connect("activate", self._on_menu_action, name)
            group.add_action(action)
        self.insert_action_group("piste", group)

        gesture = Gtk.GestureClick(button=Gdk.BUTTON_SECONDARY)
        gesture.connect("pressed", self._on_right_click)
        self.add_controller(gesture)

    def _on_right_click(self, _gesture, _n: int, x: float, y: float) -> None:
        index = self._index_at(y)
        if index < 0:
            return
        self._menu_index = index
        rect = Gdk.Rectangle()
        rect.x, rect.y, rect.width, rect.height = int(x), int(y), 1, 1
        self._popover.set_pointing_to(rect)
        self._popover.popup()

    def _index_at(self, y: float) -> int:
        """Index de la ligne sous le pointeur.

        `Gtk.ListView` n'expose pas la position : on part de la hauteur de
        ligne, uniforme ici.
        """
        count = self._store.get_n_items()
        if count == 0:
            return -1
        height = max(self.get_height(), 1)
        row_height = height / count if count * ROW_HEIGHT <= height else ROW_HEIGHT
        index = int(y // max(row_height, 1))
        return index if 0 <= index < count else -1

    def _on_menu_action(self, _action, _param, name: str) -> None:
        if 0 <= self._menu_index < self._store.get_n_items():
            self.emit("track-action", name, self._menu_index)

    # ---- Modèle ----------------------------------------------------------

    def set_tracks(self, refs) -> None:
        # Un seul splice : un append par piste émettait un signal par ligne
        # (100 ms pour 217 pistes, une saccade à chaque ouverture).
        items = [TrackItem(ref, index) for index, ref in enumerate(refs)]
        self._store.splice(0, self._store.get_n_items(), items)

    def set_current(self, video_id: str | None) -> None:
        """Marque la piste en cours (point accent à la place du numéro)."""
        if video_id == self._current_id:
            return
        previous, self._current_id = self._current_id, video_id
        # Seules les deux lignes concernées sont réaffichées : tout relier
        # rechargeait chaque pochette visible.
        for index in range(self._store.get_n_items()):
            if self._store.get_item(index).ref.video_id in (previous, video_id):
                self._store.items_changed(index, 1, 1)

    @property
    def tracks(self) -> list[TrackRef]:
        return [self._store.get_item(i).ref for i in range(self._store.get_n_items())]

    # ---- Factory ---------------------------------------------------------

    def _on_setup(self, _factory, list_item: Gtk.ListItem) -> None:
        row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        row.add_css_class("triat-track-row")
        row.set_size_request(-1, ROW_HEIGHT)

        number = Gtk.Label(xalign=0.5, width_chars=3)
        number.add_css_class("triat-mono")
        number.add_css_class("triat-dim")
        row.append(number)

        cover = Cover(size=36, radius=4.0)
        cover.add_css_class("small")
        cover.set_valign(Gtk.Align.CENTER)
        row.append(cover)

        texts = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=1,
                        valign=Gtk.Align.CENTER, hexpand=True)
        title = Gtk.Label(xalign=0, ellipsize=3)       # PANGO_ELLIPSIZE_END
        title.add_css_class("triat-body")
        title.add_css_class("title")
        artist = Gtk.Label(xalign=0, ellipsize=3)
        artist.add_css_class("triat-dim")
        texts.append(title)
        texts.append(artist)
        row.append(texts)

        duration = Gtk.Label(xalign=1)
        duration.add_css_class("triat-mono")
        duration.add_css_class("triat-dim")
        row.append(duration)

        list_item.set_child(row)
        list_item._widgets = (number, cover, title, artist, duration)

    def _on_bind(self, _factory, list_item: Gtk.ListItem) -> None:
        item = list_item.get_item()
        number, cover, title, artist, duration = list_item._widgets
        playing = item.ref.video_id == self._current_id
        # La piste en cours remplace son numéro par un point accent (screens.md §4).
        number.set_text("●" if playing else f"{item.index + 1:02d}")
        row = number.get_parent()
        if playing:
            number.add_css_class("triat-accent-text")
            row.add_css_class("playing")
        else:
            number.remove_css_class("triat-accent-text")
            row.remove_css_class("playing")
        title.set_text(display_title(item.ref.title, item.ref.artist))
        title.set_tooltip_text(item.ref.title)
        cover.set_track(item.ref)
        artist.set_text(item.ref.artist or "—")
        duration.set_text(format_time(item.ref.duration) if item.ref.duration else "—")

    def _on_activate(self, _view, position: int) -> None:
        self.emit("track-activated", position)
