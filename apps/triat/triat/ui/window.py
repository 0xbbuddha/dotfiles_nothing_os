"""Fenêtre principale de Triat — squelette visuel (M0).

Structure conforme à design/GTK.md §1 : sidebar 248 px + contenu, barre de
lecture persistante de 96 px, accueil en état vide. Aucune donnée réelle :
le branchement sur l'Engine viendra avec M1.
"""

from __future__ import annotations

import datetime

from gi.repository import Adw, GLib, Gtk

from .artist_page import ArtistPage
from .downloads_page import DownloadsPage
from .library_page import LibraryPage
from .now_playing import NowPlayingView
from .onboarding import OnboardingView
from .immersion import ImmersionView
from .search_page import SearchPage
from .settings_dialog import SettingsDialog
from .track_actions import TrackActions
from ..core.models import TrackRef
from .track_grid import TrackGrid
from .track_list import TrackList, format_time
from .widgets.common import EmptyState, SectionTitle, accent_dot, label
from .widgets.cover import Cover
from .widgets.glyph import GlyphArt
from ..core.mixes import build_mixes
from .widgets.dot_progress import DotProgressBar
from .widgets.dot_volume import DotVolume


# Triat affiche ses dates en français sans dépendre de la locale du système.
JOURS = ("lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi",
         "dimanche")
MOIS = ("janvier", "février", "mars", "avril", "mai", "juin", "juillet",
        "août", "septembre", "octobre", "novembre", "décembre")

# « Radio » n'est plus une page : c'est une action (tuile de l'accueil).
NAV_ITEMS = (
    ("home", "Accueil", "triat-home-symbolic"),
    ("search", "Recherche", "triat-search-symbolic"),
    ("library", "Bibliothèque", "triat-library-symbolic"),
    ("downloads", "Hors-ligne", "triat-downloads-symbolic"),
)


def overline(text: str) -> Gtk.Label:
    """Sur-titre espacé (DESIGN.md §3).

    L'espacement vient du CSS (`.spaced`, letter-spacing .5em) et non
    d'espaces insérés dans la chaîne : un lecteur d'écran épellerait
    « L E C T E U R » lettre par lettre.
    """
    return label(text, "triat-label", "triat-dim")


def greeting(now: datetime.datetime | None = None) -> str:
    hour = (now or datetime.datetime.now()).hour
    if hour < 12:
        return "Bonjour"
    if hour < 18:
        return "Bon après-midi"
    return "Bonsoir"


def date_line(now: datetime.datetime | None = None) -> str:
    today = now or datetime.datetime.now()
    day = JOURS[today.weekday()]
    return f"{day.capitalize()} {today.day} {MOIS[today.month - 1]}"


class Sidebar(Gtk.Box):
    """Navigation : rail d'icônes sous 1 100 px, libellés au-dessus.

    La fenêtre est tuilée par Hyprland (950 px sur la moitié d'un
    ultrawide) : replier la navigation par-dessus le contenu, comme le
    faisait Adw.NavigationSplitView, masquait tout l'écran. Le rail reste.
    """

    WIDE = 208
    COMPACT = 60

    def __init__(self, on_navigate, on_settings=None) -> None:
        super().__init__(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.add_css_class("triat-sidebar")
        self._on_settings = on_settings or (lambda: None)
        self._on_navigate = on_navigate
        self._buttons: dict[str, Gtk.Button] = {}
        self._labels: list[Gtk.Widget] = []
        self.compact = False
        self.set_size_request(self.WIDE, -1)

        # Logo : Doto, comme le Ndot de la barre, et le point « en lecture ».
        self.wordmark = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        self.wordmark.set_margin_start(12)
        self.wordmark.set_margin_top(4)
        self.wordmark.set_margin_bottom(22)
        self._logo = label("triat", "triat-display", "nav")
        self.wordmark.append(self._logo)
        # En rail, le mot ne tient pas : le triangle en points de l'icône.
        self._mark = Gtk.Image.new_from_icon_name("triat-logo-symbolic")
        self._mark.set_pixel_size(20)
        self._mark.set_visible(False)
        self.wordmark.append(self._mark)
        self.live = accent_dot(6)
        self.live.set_valign(Gtk.Align.END)
        self.live.set_margin_bottom(6)
        self.wordmark.append(self.live)
        self.append(self.wordmark)

        nav = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        for key, text, icon in NAV_ITEMS:
            button = self._nav_button(key, text, icon,
                                      lambda _b, k=key: self._on_navigate(k))
            self._buttons[key] = button
            nav.append(button)
        self.append(nav)

        self._playlists = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=1)
        self._playlists.set_margin_top(22)
        heading = label("Playlists", "triat-side-heading")
        heading.set_margin_start(12)
        heading.set_margin_bottom(6)
        self._playlists.append(heading)
        self._playlist_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL,
                                     spacing=1)
        self._playlists.append(self._playlist_box)
        self.append(self._playlists)
        self.set_playlists([], None)

        spacer = Gtk.Box(vexpand=True)
        self.append(spacer)
        self.settings_button = self._nav_button(
            "settings", "Réglages", "triat-settings-symbolic",
            lambda *_: self._on_settings())
        self.append(self.settings_button)
        self._data_path = ""

        self.select("home")

    def set_compact(self, compact: bool) -> None:
        """Rail d'icônes (fenêtre étroite) ou navigation avec libellés."""
        self.compact = compact
        if compact:
            self.add_css_class("compact")
        else:
            self.remove_css_class("compact")
        self.set_size_request(self.COMPACT if compact else self.WIDE, -1)
        for widget in self._labels:
            widget.set_visible(not compact)
        self._logo.set_visible(not compact)
        self._mark.set_visible(compact)
        self.wordmark.set_halign(Gtk.Align.CENTER if compact else Gtk.Align.FILL)
        self.wordmark.set_margin_start(0 if compact else 12)
        self.wordmark.set_margin_top(10 if compact else 4)
        self._playlists.set_visible(not compact)
        for button in (*self._buttons.values(), self.settings_button):
            button.set_halign(Gtk.Align.CENTER if compact else Gtk.Align.FILL)

    def set_data_path(self, path: str) -> None:
        """Le dossier de données, en infobulle de Réglages : utile au
        diagnostic, bruit au quotidien."""
        home = GLib.get_home_dir()
        shown = "~" + path[len(home):] if path.startswith(home) else path
        self._data_path = shown
        self.settings_button.set_tooltip_text(f"Réglages\nDonnées : {shown}")

    def set_live(self, playing: bool) -> None:
        self.live.set_opacity(1.0 if playing else 0.0)

    def set_playlists(self, items: list[dict], on_open) -> None:
        """Raccourcis vers les playlists, sous la navigation."""
        while (child := self._playlist_box.get_first_child()) is not None:
            self._playlist_box.remove(child)
        self._playlists.set_visible(bool(items) and not self.compact)
        for item in items[:8]:
            button = Gtk.Button(halign=Gtk.Align.FILL)
            button.add_css_class("triat-side-playlist")
            row = Gtk.Box(spacing=8)
            row.append(label(item["name"], hexpand=True, ellipsize=3))
            row.append(label(str(item["item_count"]), "triat-mono"))
            button.set_child(row)
            button.set_tooltip_text(item["name"])
            button.connect("clicked", lambda _b, pid=item["id"]: on_open(pid))
            self._playlist_box.append(button)

    def _nav_button(self, key: str, text: str, icon: str,
                    callback) -> Gtk.Button:
        content = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        image = Gtk.Image.new_from_icon_name(icon)
        image.set_pixel_size(18)
        content.append(image)
        name = label(text)
        content.append(name)
        self._labels.append(name)

        button = Gtk.Button(child=content)
        button.add_css_class("triat-nav-item")
        button.set_tooltip_text(text)
        button.update_property([Gtk.AccessibleProperty.LABEL], [text])
        button.connect("clicked", callback)
        return button

    def select(self, key: str) -> None:
        for name, button in self._buttons.items():
            if name == key:
                button.add_css_class("active")
            else:
                button.remove_css_class("active")


class ResumeCard(Gtk.Box):
    """Tête de l'accueil : la piste en cours ou la dernière écoutée, en
    grande trame. C'est l'élément fort de l'écran ; le reste se tait."""

    def __init__(self) -> None:
        super().__init__(orientation=Gtk.Orientation.HORIZONTAL, spacing=22)
        self.add_css_class("triat-resume")
        self.art = GlyphArt(grid=19, size=148, radius=6.0)
        self.art.set_size_request(148, 148)
        self.art.set_valign(Gtk.Align.CENTER)
        self.append(self.art)

        words = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4,
                        valign=Gtk.Align.CENTER, hexpand=True)
        self.kicker = label("", "triat-dim")
        words.append(self.kicker)
        self.title = label("", "triat-display", "md", ellipsize=3,
                           max_width_chars=34)
        words.append(self.title)
        self.artist = label("", "triat-body", "triat-dim", ellipsize=3)
        words.append(self.artist)
        # Les boutons passent à la ligne dans une fenêtre étroite.
        self.actions = Gtk.FlowBox(selection_mode=Gtk.SelectionMode.NONE,
                                   column_spacing=8, row_spacing=8,
                                   max_children_per_line=3)
        self.actions.set_halign(Gtk.Align.START)
        self.actions.set_margin_top(12)
        self.primary = Gtk.Button(label="Reprendre")
        self.primary.add_css_class("suggested-action")
        self.radio = Gtk.Button(label="Ma radio")
        self.radio.add_css_class("pill")
        self.radio.set_tooltip_text("Enchaîne sur ce que tu écoutes")
        self.fullscreen = Gtk.Button(label="Plein écran")
        self.fullscreen.add_css_class("pill")
        self.fullscreen.set_tooltip_text("Le clip, ou la matrice de points (Ctrl+I)")
        for button in (self.primary, self.radio, self.fullscreen):
            self.actions.append(button)
        words.append(self.actions)
        self.append(words)
        self.ref = None

    def show(self, ref, playing: bool, is_current: bool) -> None:
        self.ref = ref
        if ref is None:
            self.art.set_seed(7)
            self.kicker.set_text("Rien n'a encore été écouté")
            self.title.set_text("Cherche un titre pour commencer")
            self.artist.set_text("Ou importe une playlist depuis la Bibliothèque.")
            self.primary.set_label("Rechercher")
            self.radio.set_visible(False)
            self.fullscreen.set_visible(False)
            return
        self.art.set_track(ref)
        self.kicker.set_text("En lecture" if playing and is_current
                             else "Reprendre")
        self.title.set_text(ref.title)
        self.artist.set_text(ref.artist or "")
        self.primary.set_label("Pause" if playing and is_current
                               else "Reprendre")
        self.radio.set_visible(True)
        self.fullscreen.set_visible(True)


class MixCard(Gtk.Button):
    """Vignette de mix : matrice de points propre au mix, nom, artistes."""

    def __init__(self, mix, size: int = 148) -> None:
        super().__init__()
        self.add_css_class("triat-mix")
        self.mix = mix
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        self.art = GlyphArt(grid=13, size=size, radius=6.0)
        self.art.set_size_request(size, size)
        self.art.set_halign(Gtk.Align.START)
        box.set_size_request(size, -1)
        self.set_halign(Gtk.Align.START)
        self.art.set_seed(mix.seed)
        box.append(self.art)
        name = label(mix.title, "mix-name", ellipsize=3, max_width_chars=18)
        name.set_margin_top(8)
        box.append(name)
        box.append(label(mix.subtitle, "mix-detail", wrap=True, lines=2,
                         ellipsize=3, max_width_chars=20))
        self.set_child(box)
        self.set_tooltip_text(mix.subtitle)
        self.update_property([Gtk.AccessibleProperty.LABEL],
                             [f"{mix.title}, {mix.subtitle}"])


class HomePage(Gtk.Box):
    """Accueil : reprendre, mixes, réécoute, playlists (screens.md §1)."""

    def __init__(self, engine=None, on_play=None, on_immersion=None,
                 on_search=None) -> None:
        super().__init__(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.add_css_class("triat-content")
        self._engine = engine
        self._on_play = on_play
        self._on_immersion = on_immersion
        self._on_search = on_search
        self.mixes = []

        scroller = Gtk.ScrolledWindow(hexpand=True, vexpand=True)
        scroller.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        column = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=14)
        column.set_margin_bottom(28)

        self.resume = ResumeCard()
        self.resume.set_margin_top(6)
        self.resume.set_margin_bottom(18)
        column.append(self.resume)
        self.resume.primary.connect("clicked", self._on_primary)
        self.start_button = self.resume.radio
        if engine is not None:
            self.resume.radio.connect("clicked", lambda *_: engine.start_radio())
            self.resume.fullscreen.connect("clicked", self._start_immersion)
            engine.connect("track-changed", lambda *_: self._show_resume())
            engine.connect("state-changed", lambda *_: self._show_resume())

        # --- Mixes ---
        self.mixes_section = SectionTitle("Mixes pour toi")
        column.append(self.mixes_section)
        self.mix_box = Gtk.FlowBox(selection_mode=Gtk.SelectionMode.NONE,
                                   homogeneous=True, column_spacing=4,
                                   row_spacing=10, min_children_per_line=2,
                                   max_children_per_line=8)
        self.mix_box.set_valign(Gtk.Align.START)
        self.mix_box.set_margin_bottom(18)
        column.append(self.mix_box)

        # --- Écouter à nouveau ---
        self.recent_title = SectionTitle("Écouter à nouveau")
        column.append(self.recent_title)
        self.recent_grid = TrackGrid(cover_size=120)
        self.recent_grid.connect("item-activated", self._play_recent)
        self.recent_grid.set_margin_bottom(18)
        self.recent_empty = EmptyState(
            "Rien pour l'instant",
            "Ton historique d'écoute apparaîtra ici. Il reste sur cet "
            "ordinateur.")
        column.append(self.recent_grid)
        column.append(self.recent_empty)

        # --- Playlists ---
        self.mixes_title = SectionTitle("Tes playlists")
        column.append(self.mixes_title)
        self.mixes_grid = TrackGrid(cover_size=120)
        self.mixes_grid.connect("item-activated", self._play_mix)
        self.mixes_empty = EmptyState(
            "Aucune playlist",
            "Importe un fichier de liens YouTube depuis la Bibliothèque "
            "pour créer ta première playlist.")
        column.append(self.mixes_grid)
        column.append(self.mixes_empty)

        scroller.set_child(column)
        self.append(scroller)

        self._playlist_ids: list[int] = []
        self.refresh()

    def set_narrow(self, narrow: bool) -> None:
        self.resume.art.set_size_request(112 if narrow else 148,
                                         112 if narrow else 148)

    # ---- Contenu ---------------------------------------------------------

    def _show_resume(self) -> None:
        if self._engine is None:
            self.resume.show(None, False, False)
            return
        current = self._engine.current
        ref = current
        if ref is None:
            recent = self._engine.library.recent(limit=1)
            ref = recent[0] if recent else None
        playing = self._engine.state == "playing"
        is_current = (ref is not None and current is not None
                      and ref.video_id == current.video_id)
        self.resume.show(ref, playing, is_current)

    def refresh(self) -> None:
        """Recharge toutes les sections depuis la bibliothèque."""
        self._show_resume()
        if self._engine is None:
            self.recent_grid.set_visible(False)
            self.mixes_grid.set_visible(False)
            self.mixes_section.set_visible(False)
            return
        library = self._engine.library

        self.mixes = build_mixes(library)
        child = self.mix_box.get_first_child()
        while child is not None:
            following = child.get_next_sibling()
            self.mix_box.remove(child)
            child = following
        for mix in self.mixes:
            card = MixCard(mix)
            card.connect("clicked", self._play_generated, mix)
            self.mix_box.append(card)
        self.mixes_section.set_visible(bool(self.mixes))
        self.mix_box.set_visible(bool(self.mixes))

        recent = library.recent(limit=18)
        self.recent_grid.set_items(recent)
        self.recent_grid.set_visible(bool(recent))
        # Sans historique mais avec des mixes, la section vide n'apprend rien.
        self.recent_title.set_visible(bool(recent) or not self.mixes)
        self.recent_empty.set_visible(not recent and not self.mixes)

        # Chaque playlist est représentée par la pochette de sa première
        # piste : c'est ce que l'utilisateur reconnaît.
        playlists = library.list_playlists()
        covers, badges, self._playlist_ids = [], {}, []
        for item in playlists:
            tracks = library.playlist_items(item["id"])
            if not tracks:
                continue
            cover = TrackRef(video_id=tracks[0].video_id, title=item["name"],
                             artist="", thumbnail=tracks[0].thumbnail)
            covers.append(cover)
            badges[cover.video_id] = f"{item['item_count']} titres"
            self._playlist_ids.append(item["id"])

        self.mixes_grid.set_items(covers, badges)
        self.mixes_grid.set_visible(bool(covers))
        self.mixes_empty.set_visible(not covers)

    # ---- Lecture ---------------------------------------------------------

    def _on_primary(self, _button) -> None:
        engine, ref = self._engine, self.resume.ref
        if engine is None or ref is None:
            if self._on_search:
                self._on_search()
            return
        if engine.current is not None and engine.current.video_id == ref.video_id:
            engine.toggle_pause()
        elif self._on_play:
            self._on_play([ref], 0)

    def _play_generated(self, _button, mix) -> None:
        if self._on_play and mix.refs:
            self._on_play(mix.refs, 0)

    def _start_immersion(self, _button) -> None:
        """Plein écran tout de suite ; sans lecture, lance le mix du jour."""
        if self._engine.current is None and self.mixes and self._on_play:
            self._on_play(self.mixes[0].refs, 0)
        if self._on_immersion is not None:
            self._on_immersion()

    def _play_recent(self, _grid, position: int) -> None:
        refs = self.recent_grid.items
        if self._on_play and 0 <= position < len(refs):
            self._on_play(refs, position)

    def _play_mix(self, _grid, position: int) -> None:
        if not (self._on_play and 0 <= position < len(self._playlist_ids)):
            return
        refs = self._engine.library.playlist_items(self._playlist_ids[position])
        if refs:
            self._on_play(refs, 0)


class PlayerBar(Gtk.Box):
    """Bandeau de lecture : à plat, collé au bas de la fenêtre.

    La progression court sur toute la largeur, au-dessus. Dessous : la
    piste à gauche (cliquable, ouvre Lecture en cours), le transport au
    centre, le temps, le volume et le plein écran à droite.
    """

    def __init__(self, engine=None) -> None:
        super().__init__(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.add_css_class("triat-player-bar")
        self._engine = engine

        self.progress = DotProgressBar(step=5.0, radius=1.3, height=10,
                                       show_head=True)
        self.progress.set_hexpand(True)
        self.progress.set_margin_top(6)
        self.append(self.progress)

        row = Gtk.CenterBox()
        row.set_size_request(-1, 58)
        self.append(row)

        # --- gauche : pochette + titres ---
        self.cover = Cover(size=40, radius=4.0)
        self.cover.set_valign(Gtk.Align.CENTER)
        titles = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=1,
                         valign=Gtk.Align.CENTER)
        self._title = label("Rien en lecture", "now-title", ellipsize=3,
                            max_width_chars=30)
        self._artist = label("Choisissez une piste", "now-artist", ellipsize=3,
                             max_width_chars=30)
        titles.append(self._title)
        titles.append(self._artist)
        left = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10,
                       valign=Gtk.Align.CENTER)
        left.add_css_class("triat-expand")
        left.append(self.cover)
        left.append(titles)
        left.set_tooltip_text("Lecture en cours (Ctrl+L)")
        self.expand_gesture = Gtk.GestureClick()
        left.add_controller(self.expand_gesture)
        row.set_start_widget(left)

        # --- centre : transport ---
        transport = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=4,
                            halign=Gtk.Align.CENTER, valign=Gtk.Align.CENTER)
        self.prev_button = self._icon_button("triat-previous-symbolic", "Précédent")
        self.play_button = self._icon_button("triat-play-symbolic", "Lecture",
                                             primary=True)
        self.next_button = self._icon_button("triat-next-symbolic", "Suivant")
        for button in (self.prev_button, self.play_button, self.next_button):
            transport.append(button)
        self.centre = transport
        row.set_center_widget(transport)

        # --- droite : temps, volume, plein écran ---
        right = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10,
                        valign=Gtk.Align.CENTER)
        self._elapsed = label("0:00", "triat-mono")
        self._total = label("0:00", "triat-mono")
        times = Gtk.Box(spacing=4)
        times.append(self._elapsed)
        times.append(label("/", "triat-mono"))
        times.append(self._total)
        right.append(times)
        self.volume_box = Gtk.Box(spacing=6, valign=Gtk.Align.CENTER)
        volume_icon = Gtk.Image.new_from_icon_name("triat-volume-symbolic")
        volume_icon.add_css_class("triat-dim")
        self.volume_box.append(volume_icon)
        self.volume = DotVolume()
        self.volume_box.append(self.volume)
        right.append(self.volume_box)
        self.fullscreen_button = Gtk.Button(icon_name="triat-fullscreen-symbolic")
        self.fullscreen_button.add_css_class("flat")
        self.fullscreen_button.add_css_class("circular")
        self.fullscreen_button.set_tooltip_text("Plein écran (Ctrl+I)")
        self.fullscreen_button.update_property(
            [Gtk.AccessibleProperty.LABEL], ["Plein écran"])
        right.append(self.fullscreen_button)
        row.set_end_widget(right)
        self.right = right
        self._times = times

        if engine is not None:
            self._connect(engine)
        else:
            for button in (self.prev_button, self.play_button, self.next_button):
                button.set_sensitive(False)

    # ---- Câblage ---------------------------------------------------------

    def _connect(self, engine) -> None:
        self.play_button.connect("clicked", lambda *_: engine.toggle_pause())
        self.next_button.connect("clicked", lambda *_: engine.next())
        self.prev_button.connect("clicked", lambda *_: engine.previous())
        self.progress.connect("seek-requested",
                              lambda _w, value: engine.seek(value))
        self.volume.connect("volume-changed",
                            lambda _w, value: engine.set_volume(value))
        self.volume.props.volume = float(engine.settings.get("volume"))

        engine.connect("track-changed", self._on_track)
        engine.connect("state-changed", self._on_state)
        engine.connect("position-changed", self._on_position)
        engine.connect("duration-changed", self._on_duration)
        engine.connect("queue-changed", lambda *_: self._refresh_buttons())
        self._refresh_buttons()

    def _icon_button(self, icon: str, name: str,
                     primary: bool = False) -> Gtk.Button:
        button = Gtk.Button(icon_name=icon)
        button.add_css_class("circular")
        button.add_css_class("suggested-action" if primary else "flat")
        button.set_tooltip_text(name)
        button.update_property([Gtk.AccessibleProperty.LABEL], [name])
        size = 40 if primary else 34
        button.set_size_request(size, size)
        button.set_valign(Gtk.Align.CENTER)
        return button

    # ---- Réactions -------------------------------------------------------

    def _on_track(self, _engine, ref) -> None:
        if ref is None:
            self._title.set_text("Rien en lecture")
            self._artist.set_text("Choisissez une piste")
            self.cover.clear()
            self.progress.clear()
            self._elapsed.set_text("0:00")
            self._total.set_text("0:00")
            return
        self._title.set_text(ref.title)
        self._artist.set_text(ref.artist or "—")
        self.cover.set_track(ref)
        self.progress.props.position = 0.0
        self.progress.props.duration = ref.duration or 0.0
        self._total.set_text(format_time(ref.duration))
        self._refresh_buttons()

    def _on_state(self, _engine, state: str) -> None:
        playing = state == "playing"
        self.play_button.set_icon_name(
            "triat-pause-symbolic" if playing
            else "triat-play-symbolic")
        self.play_button.set_sensitive(state != "idle")
        self.play_button.set_tooltip_text("Pause" if playing else "Lecture")

    def _on_position(self, _engine, value: float) -> None:
        self.progress.props.position = value
        self._elapsed.set_text(format_time(value))

    def _on_duration(self, _engine, value: float) -> None:
        if value > 0:
            self.progress.props.duration = value
            self._total.set_text(format_time(value))

    def _refresh_buttons(self) -> None:
        if self._engine is None:
            return
        self.next_button.set_sensitive(self._engine.queue.has_next)
        self.prev_button.set_sensitive(self._engine.queue.has_previous
                                       or self._engine.current is not None)

    def set_segments(self, segments) -> None:
        self.progress.set_segments(
            [(s.start, s.end, 1.0) for s in segments])

    def set_compact(self, compact: bool) -> None:
        """Sous 760 px : piste, transport et plein écran seulement."""
        self.volume_box.set_visible(not compact)
        self._times.set_visible(not compact)


class TriatWindow(Adw.ApplicationWindow):
    def __init__(self, app: Adw.Application, engine=None,
                 data_path: str = "") -> None:
        super().__init__(application=app, title="Triat")
        self.set_default_size(1440, 900)
        self.set_size_request(360, 480)
        self.engine = engine

        self.add_css_class("triat-window")
        self.sidebar = Sidebar(self._on_navigate, self.open_settings)
        # Sans défilement, « Réglages » se fait rogner dès que la fenêtre
        # manque de hauteur.
        sidebar_scroll = Gtk.ScrolledWindow()
        sidebar_scroll.add_css_class("triat-sidebar-scroll")
        sidebar_scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        sidebar_scroll.set_child(self.sidebar)
        sidebar_scroll.set_propagate_natural_width(True)
        # Un libellé extensible dans une ligne de playlist propagerait son
        # hexpand jusqu'ici : la navigation mangeait la moitié de la fenêtre.
        sidebar_scroll.set_hexpand(False)
        self.sidebar.set_vexpand(True)
        if data_path:
            self.sidebar.set_data_path(data_path)

        self.home = HomePage(engine, self._play_from_list,
                             on_immersion=self.open_immersion,
                             on_search=lambda: self._on_navigate("search"))
        self.actions = TrackActions(engine, self._toast, self) if engine else None
        self.search = SearchPage(engine, self._play_from_list,
                                 self._on_track_action,
                                 on_artist=self.show_artist,
                                 on_playlist=self.show_playlist) if engine else None
        self.library = (LibraryPage(engine, self._play_from_list, self._toast,
                                    self._on_track_action,
                                    on_artist=self.show_artist)
                        if engine else None)

        # Pas de fondu : les pages sont translucides, un fondu les
        # superposerait. Changement sec, comme le shell (« dry, fast »).
        self.pages = Gtk.Stack(hexpand=True, vexpand=True)
        self.pages.set_transition_type(Gtk.StackTransitionType.NONE)
        self.pages.add_named(self.home, "home")
        if self.search is not None:
            self.pages.add_named(self.search, "search")
        if self.library is not None:
            self.pages.add_named(self.library, "library")
        self.downloads = DownloadsPage(engine) if engine else None
        if self.downloads is not None:
            self.pages.add_named(self.downloads, "downloads")
        self.artist = (ArtistPage(engine, self._play_from_list,
                                  self._on_track_action) if engine else None)
        if self.artist is not None:
            self.pages.add_named(self.artist, "artist")

        body = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        body.append(sidebar_scroll)
        body.append(self.pages)
        self.body = body

        self.player_bar = PlayerBar(engine)

        # Coquille : navigation + pages, bandeau de lecture dessous.
        shell = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        shell.append(self.body)
        shell.append(self.player_bar)
        self.shell = shell
        if engine is not None:
            self.now_playing = NowPlayingView(engine, on_close=self.close_sheet,
                                           on_artist=self.show_artist,
                                           on_immersion=self.open_immersion)
        else:
            self.now_playing = None

        self.stack = Gtk.Stack()
        self.stack.set_transition_type(Gtk.StackTransitionType.CROSSFADE)
        self.stack.set_transition_duration(320)
        self.stack.add_named(self.shell, "main")
        # « Lecture en cours » occupe toute la fenêtre et glisse depuis le
        # bandeau : Adw.BottomSheet la plafonnait à mi-hauteur.
        if self.now_playing is not None:
            self.stack.add_named(self.now_playing, "nowplaying")

        # Immersion : construite une fois, sa surface GL n'existe que pendant
        # l'affichage (voir ImmersionView.activate).
        self.immersion = None
        self._fullscreen_by_immersion = False
        if engine is not None:
            self.immersion = ImmersionView(engine, self.close_immersion,
                                           self._toggle_fullscreen)
            self.stack.add_named(self.immersion, "immersion")
            # Le rendu mpv doit être libéré avant l'arrêt du moteur, avec le
            # contexte GL encore vivant : on quitte l'écran avant la fermeture.
            self.connect("close-request", lambda *_: (self.close_immersion(),
                                                      False)[1])

        # Premier lancement : on guide plutôt que d'ouvrir sur une
        # bibliothèque vide (screens.md §11).
        self.onboarding = None
        if engine is not None and not engine.settings.get("onboarding_done"):
            self.onboarding = OnboardingView(engine, self._finish_onboarding)
            self.stack.add_named(self.onboarding, "onboarding")
            self.stack.set_visible_child_name("onboarding")

        self.toasts = Adw.ToastOverlay(child=self.stack)
        self.toasts.add_css_class("triat-root")
        self.stack.add_css_class("triat-root")
        self.set_content(self.toasts)

        self._install_breakpoints()
        self._install_shortcuts()
        self.refresh_sidebar()
        if engine is not None:
            self._connect_engine(engine)
            self.player_bar.expand_gesture.connect(
                "released", lambda *_: self.open_sheet())
            self.player_bar.fullscreen_button.connect(
                "clicked", lambda *_: self.home._start_immersion(None))

    def refresh_sidebar(self) -> None:
        if self.engine is None:
            return
        self.sidebar.set_playlists(self.engine.library.list_playlists(),
                                   self.show_playlist)

    def _finish_onboarding(self) -> None:
        self.stack.set_visible_child_name("main")
        self.home.refresh()
        if self.library is not None:
            self.library.refresh()

    # ---- Réglages --------------------------------------------------------

    def open_settings(self) -> None:
        if self.engine is None:
            return
        SettingsDialog(self.engine, self._on_setting_changed).present(self)

    def _on_setting_changed(self, key: str, _value) -> None:
        """Répercute un réglage sans attendre un redémarrage."""
        if key == "immersion_mode" and self.immersion is not None:
            self.immersion.set_mode(_value, remember=False)
            return
        if key in ("cookie_source", "wiped"):
            self.home.refresh()
            if self.library is not None:
                self.library.refresh()
            self._toast("Réglages appliqués")

    # ---- Vue plein écran -------------------------------------------------

    @property
    def sheet_open(self) -> bool:
        return self.stack.get_visible_child_name() == "nowplaying"

    def open_sheet(self) -> None:
        if self.now_playing is not None and not self.sheet_open:
            self.stack.set_transition_type(Gtk.StackTransitionType.SLIDE_UP)
            self.stack.set_transition_duration(240)
            self.stack.set_visible_child_name("nowplaying")

    # ---- Immersion ---------------------------------------------------------

    def open_immersion(self) -> None:
        if self.immersion is None or self.immersion.active:
            return
        if self.engine.current is None:
            self._toast("Rien en lecture")
            return
        self.stack.set_transition_type(Gtk.StackTransitionType.CROSSFADE)
        self.stack.set_transition_duration(320)
        self.stack.set_visible_child_name("immersion")
        self._fullscreen_by_immersion = not self.is_fullscreen()
        if self._fullscreen_by_immersion:
            self.fullscreen()
        self.immersion.activate()

    def close_immersion(self) -> None:
        if self.immersion is None or not self.immersion.active:
            return
        self.immersion.deactivate()
        self.stack.set_transition_type(Gtk.StackTransitionType.CROSSFADE)
        self.stack.set_visible_child_name("main")
        if self._fullscreen_by_immersion:
            self.unfullscreen()
        self._fullscreen_by_immersion = False

    def _toggle_fullscreen(self) -> None:
        if self.is_fullscreen():
            self.unfullscreen()
        else:
            self.fullscreen()

    def close_sheet(self) -> None:
        if self.sheet_open:
            self.stack.set_transition_type(Gtk.StackTransitionType.SLIDE_DOWN)
            self.stack.set_transition_duration(200)
            self.stack.set_visible_child_name("main")

    def toggle_sheet(self) -> None:
        if self.sheet_open:
            self.close_sheet()
        else:
            self.open_sheet()

    # ---- Moteur ----------------------------------------------------------

    def _connect_engine(self, engine) -> None:
        engine.connect("state-changed",
                       lambda _e, state: self.sidebar.set_live(state == "playing"))
        self.sidebar.set_live(False)
        engine.connect("error", self._on_error)
        engine.connect("track-changed", self._on_track_segments)
        engine.connect("track-changed", self._on_track_marks)
        engine.connect("segment-skipped", self._on_segment_skipped)
        engine.connect("segment-pending", self._on_segment_pending)

    def _on_track_marks(self, _engine, _ref) -> None:
        if self.library is not None:
            self.library._mark_current()

    def _on_track_segments(self, engine, _ref) -> None:
        """Reporte les segments connus sur les deux barres de progression."""
        planner = getattr(engine, "_planner", None)
        segments = planner.segments if planner is not None else []
        self.player_bar.set_segments(segments)
        if self.now_playing is not None:
            self.now_playing.set_segments(segments)

    def _toast(self, message: str, timeout: int = 5) -> None:
        self.toasts.add_toast(Adw.Toast(title=message, timeout=timeout))

    def _on_error(self, _engine, message: str) -> None:
        self._toast(message, timeout=6)

    def _on_segment_skipped(self, _engine, segment, gained: float) -> None:
        # Toast SponsorBlock avec possibilité d'annuler (DESIGN.md §6).
        libelle = {
            "music_offtopic": "Passage non musical",
            "sponsor": "Sponsor",
            "selfpromo": "Auto-promotion",
            "intro": "Intro",
            "outro": "Outro",
            "interaction": "Rappel d'abonnement",
        }.get(segment.category, segment.category)
        toast = Adw.Toast(
            title=f"{libelle} sauté · {format_time(gained)}", timeout=5)
        toast.set_button_label("Annuler")
        toast.connect("button-clicked",
                      lambda *_: self.engine.cancel_segment(segment))
        self.toasts.add_toast(toast)

    def _on_segment_pending(self, _engine, segment) -> None:
        toast = Adw.Toast(title=f"Segment {segment.category} détecté", timeout=6)
        toast.set_button_label("Sauter")
        toast.connect("button-clicked",
                      lambda *_: self.engine.skip_segment(segment))
        self.toasts.add_toast(toast)

    def _on_track_action(self, action: str, ref) -> None:
        if action == "artist":
            self.show_artist(ref.artist if ref else "")
            return
        if self.actions is not None:
            self.actions.handle(action, ref)

    def show_playlist(self, playlist_id: int) -> None:
        """Ouvre une playlist dans la Bibliothèque."""
        if self.library is None:
            return
        self._on_navigate("library")
        self.library.show_playlist(playlist_id)

    def show_artist(self, artist: str) -> None:
        """Ouvre la page d'un artiste."""
        if self.artist is None or not (artist or "").strip():
            self._toast("Artiste inconnu pour cette piste")
            return
        self.artist.show_artist(artist)
        self.sidebar.select("library")
        self.pages.set_visible_child_name("artist")
        self.close_sheet()

    def _play_from_list(self, refs, position: int) -> None:
        if self.engine is not None:
            self.engine.play_refs(refs, start=position)

    # ---- Raccourcis ------------------------------------------------------

    def _install_shortcuts(self) -> None:
        controller = Gtk.ShortcutController()
        controller.set_scope(Gtk.ShortcutScope.GLOBAL)

        def add(accel: str, callback) -> None:
            controller.add_shortcut(Gtk.Shortcut(
                trigger=Gtk.ShortcutTrigger.parse_string(accel),
                action=Gtk.CallbackAction.new(callback)))

        def toggle(*_args) -> bool:
            if self.engine is not None:
                self.engine.toggle_pause()
            return True

        def focus_search(*_args) -> bool:
            self._on_navigate("search")
            return True

        def open_now_playing(*_args) -> bool:
            self.toggle_sheet()
            return True

        def open_prefs(*_args) -> bool:
            self.open_settings()
            return True

        def toggle_immersion(*_args) -> bool:
            if self.immersion is not None and self.immersion.active:
                self.close_immersion()
            else:
                self.open_immersion()
            return True

        add("space", toggle)
        add("<Primary>f", focus_search)
        add("<Primary>l", open_now_playing)
        add("<Primary>comma", open_prefs)
        add("<Primary>i", toggle_immersion)
        self.add_controller(controller)

    # ---- Navigation ------------------------------------------------------

    def _install_breakpoints(self) -> None:
        # Hyprland tuile Triat à ~950 px sur la moitié d'un ultrawide :
        # rail d'icônes en dessous de 1 100 px, libellés au-dessus.
        wide = Adw.Breakpoint.new(
            Adw.BreakpointCondition.parse("max-width: 1100px"))
        wide.connect("apply", lambda *_: self._set_narrow(True))
        wide.connect("unapply", lambda *_: self._set_narrow(False))
        self.add_breakpoint(wide)

        narrow = Adw.Breakpoint.new(
            Adw.BreakpointCondition.parse("max-width: 760px"))
        narrow.connect("apply", lambda *_: self.player_bar.set_compact(True))
        narrow.connect("unapply", lambda *_: self.player_bar.set_compact(False))
        self.add_breakpoint(narrow)

    def _set_narrow(self, narrow: bool) -> None:
        self.sidebar.set_compact(narrow)
        for page in (self.home, self.search, self.library, self.downloads,
                     self.artist):
            if page is None:
                continue
            if narrow:
                page.add_css_class("narrow")
            else:
                page.remove_css_class("narrow")
        self.home.set_narrow(narrow)
        if self.now_playing is not None:
            self.now_playing.set_narrow(narrow)

    def _on_navigate(self, key: str) -> None:
        self.sidebar.select(key)
        if key == "home":
            self.home.refresh()
            self.refresh_sidebar()
            self.pages.set_visible_child_name("home")
        elif key == "search" and self.search is not None:
            self.pages.set_visible_child_name("search")
            GLib.idle_add(self.search.focus_entry)
        elif key == "library" and self.library is not None:
            self.pages.set_visible_child_name("library")
            self.library.refresh()
            self.refresh_sidebar()
        elif key == "downloads" and self.downloads is not None:
            self.pages.set_visible_child_name("downloads")
            self.downloads.refresh()
        else:
            self.toasts.add_toast(Adw.Toast(title="Écran à venir", timeout=2))
