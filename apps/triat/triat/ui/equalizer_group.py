"""Groupe « Égaliseur » des réglages : interrupteur, préréglage, 10 curseurs."""

from __future__ import annotations

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")

from gi.repository import Adw, GLib, Gtk

from ..core.equalizer import (BANDS, CUSTOM, FLAT, GAIN_MAX, GAIN_MIN,
                              PRESETS, match_preset, preset_gains)

# Le filtre mpv est reconstruit à chaque application, ce qui provoque un
# micro-silence : on attend que le curseur se stabilise.
APPLY_DELAY_MS = 180


def band_label(freq: int) -> str:
    return f"{freq // 1000}k" if freq >= 1000 else str(freq)


class EqualizerGroup(Adw.PreferencesGroup):
    def __init__(self, engine) -> None:
        super().__init__(title="Égaliseur",
                         description="Dix bandes d'une octave, de 31 Hz à 16 kHz")
        self._engine = engine
        self._pending = 0
        self._syncing = False
        enabled, gains = engine.equalizer

        self.switch = Adw.SwitchRow(title="Activer l'égaliseur")
        self.switch.set_active(enabled)
        self.switch.connect("notify::active", self._on_toggled)
        self.add(self.switch)

        # « Personnalisé » n'est proposé qu'en dernier, et seulement affiché
        # quand les curseurs ne correspondent à aucun préréglage.
        self._preset_ids = [pid for pid, _l, _g in PRESETS] + [CUSTOM]
        model = Gtk.StringList()
        for _pid, label, _gains in PRESETS:
            model.append(label)
        model.append("Personnalisé")
        self.preset = Adw.ComboRow(title="Préréglage", model=model)
        self.preset.set_selected(self._preset_ids.index(match_preset(gains)))
        self.preset.connect("notify::selected", self._on_preset)
        self.add(self.preset)

        self.scales: list[Gtk.Scale] = []
        bands = Gtk.Box(spacing=4, homogeneous=True,
                        margin_top=12, margin_bottom=12,
                        margin_start=8, margin_end=8)
        bands.add_css_class("triat-eq")
        for freq, gain in zip(BANDS, gains, strict=True):
            bands.append(self._band(freq, gain))
        row = Adw.PreferencesRow(activatable=False, focusable=False)
        row.set_child(bands)
        self.add(row)

        reset = Gtk.Button(label="Remettre à plat", valign=Gtk.Align.CENTER)
        reset.add_css_class("flat")
        reset.connect("clicked", lambda _b: self._set_scales(FLAT, apply=True))
        self.set_header_suffix(reset)

        self._update_sensitivity()

    # ---- Construction ----------------------------------------------------

    def _band(self, freq: int, gain: float) -> Gtk.Box:
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        scale = Gtk.Scale(orientation=Gtk.Orientation.VERTICAL,
                          inverted=True, vexpand=True,
                          halign=Gtk.Align.CENTER)
        scale.set_range(GAIN_MIN, GAIN_MAX)
        scale.set_increments(1.0, 3.0)
        scale.set_round_digits(0)
        scale.set_size_request(-1, 140)
        scale.add_mark(0.0, Gtk.PositionType.LEFT, None)
        scale.set_value(gain)
        scale.set_tooltip_text(f"{band_label(freq)} Hz")
        scale.update_property([Gtk.AccessibleProperty.LABEL],
                              [f"{band_label(freq)} hertz"])
        scale.connect("value-changed", self._on_scale)
        self.scales.append(scale)

        value = Gtk.Label(label=_fmt(gain))
        value.add_css_class("triat-mono")
        scale.connect("value-changed",
                      lambda s: value.set_label(_fmt(s.get_value())))
        name = Gtk.Label(label=band_label(freq))
        name.add_css_class("triat-mono")
        box.append(value)
        box.append(scale)
        box.append(name)
        return box

    # ---- Événements ------------------------------------------------------

    def gains(self) -> tuple[float, ...]:
        return tuple(round(s.get_value()) * 1.0 for s in self.scales)

    def _on_toggled(self, row, _pspec) -> None:
        self._update_sensitivity()
        self._engine.set_equalizer(enabled=row.get_active())

    def _update_sensitivity(self) -> None:
        on = self.switch.get_active()
        self.preset.set_sensitive(on)
        for scale in self.scales:
            scale.get_parent().set_sensitive(on)

    def _on_preset(self, row, _pspec) -> None:
        if self._syncing:
            return
        gains = preset_gains(self._preset_ids[row.get_selected()])
        if gains is not None:          # « Personnalisé » ne change rien
            self._set_scales(gains, apply=True)

    def _set_scales(self, gains, apply: bool) -> None:
        self._syncing = True
        try:
            for scale, gain in zip(self.scales, gains, strict=True):
                scale.set_value(gain)
        finally:
            self._syncing = False
        self._sync_preset()
        if apply:
            self._apply_now()

    def _on_scale(self, _scale) -> None:
        if self._syncing:
            return
        self._sync_preset()
        if self._pending:
            GLib.source_remove(self._pending)
        self._pending = GLib.timeout_add(APPLY_DELAY_MS, self._on_delay)

    def _sync_preset(self) -> None:
        index = self._preset_ids.index(match_preset(self.gains()))
        if self.preset.get_selected() != index:
            self._syncing = True
            try:
                self.preset.set_selected(index)
            finally:
                self._syncing = False

    def _on_delay(self) -> bool:
        self._pending = 0
        self._engine.set_equalizer(gains=self.gains())
        return GLib.SOURCE_REMOVE

    def _apply_now(self) -> None:
        if self._pending:
            GLib.source_remove(self._pending)
            self._pending = 0
        self._engine.set_equalizer(gains=self.gains())


def _fmt(gain: float) -> str:
    gain = round(gain)
    return f"+{gain}" if gain > 0 else str(gain)
