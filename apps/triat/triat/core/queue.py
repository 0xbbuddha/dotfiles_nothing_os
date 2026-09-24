"""File d'attente : ordre de lecture, aléatoire, répétition.

La file ne contient que des `TrackRef` (pas d'URL de flux) : la résolution
réseau est faite au dernier moment par le moteur.
"""

from __future__ import annotations

import random
from collections.abc import Sequence

from gi.repository import GObject

from .models import TrackRef

REPEAT_OFF = "off"
REPEAT_ALL = "all"
REPEAT_ONE = "one"
REPEAT_MODES = (REPEAT_OFF, REPEAT_ALL, REPEAT_ONE)


class Queue(GObject.Object):
    """Liste de pistes + curseur de lecture.

    `items` garde l'ordre d'insertion (ce que voit l'utilisateur).
    `_order` est l'ordre de lecture : identité en mode normal, permutation
    en mode aléatoire. Le curseur `_pos` pointe dans `_order`.
    """

    __gsignals__ = {
        "changed": (GObject.SignalFlags.RUN_FIRST, None, ()),
        "current-changed": (GObject.SignalFlags.RUN_FIRST, None, (object,)),
    }

    def __init__(self) -> None:
        super().__init__()
        self._items: list[TrackRef] = []
        self._order: list[int] = []
        self._pos: int = -1
        self._shuffle = False
        self._repeat = REPEAT_OFF
        self._rng = random.Random()

    # ---- Lecture seule -------------------------------------------------

    @property
    def items(self) -> list[TrackRef]:
        return list(self._items)

    def __len__(self) -> int:
        return len(self._items)

    @property
    def current_index(self) -> int:
        """Index dans `items`, ou -1 si rien n'est sélectionné."""
        if 0 <= self._pos < len(self._order):
            return self._order[self._pos]
        return -1

    @property
    def current(self) -> TrackRef | None:
        idx = self.current_index
        return self._items[idx] if idx >= 0 else None

    @property
    def upcoming(self) -> list[TrackRef]:
        """Pistes restantes dans l'ordre de lecture réel."""
        return [self._items[i] for i in self._order[self._pos + 1:]]

    @property
    def has_next(self) -> bool:
        if not self._items:
            return False
        if self._repeat in (REPEAT_ALL, REPEAT_ONE):
            return True
        return self._pos + 1 < len(self._order)

    @property
    def has_previous(self) -> bool:
        return bool(self._items) and (self._pos > 0 or self._repeat == REPEAT_ALL)

    # ---- Modes ---------------------------------------------------------

    @property
    def shuffle(self) -> bool:
        return self._shuffle

    @shuffle.setter
    def shuffle(self, value: bool) -> None:
        if value == self._shuffle:
            return
        self._shuffle = value
        self._rebuild_order(keep_current=True)
        self.emit("changed")

    @property
    def repeat(self) -> str:
        return self._repeat

    @repeat.setter
    def repeat(self, mode: str) -> None:
        if mode not in REPEAT_MODES:
            raise ValueError(f"Mode de répétition inconnu: {mode}")
        self._repeat = mode

    # ---- Mutations -----------------------------------------------------

    def set_items(self, refs: Sequence[TrackRef], start: int = 0) -> None:
        """Remplace toute la file et positionne le curseur sur `start`."""
        self._items = list(refs)
        if not self._items:
            self._order, self._pos = [], -1
        else:
            start = max(0, min(start, len(self._items) - 1))
            self._build_order_from(start)
        self.emit("changed")
        self.emit("current-changed", self.current)

    def append(self, refs: Sequence[TrackRef]) -> None:
        """Ajoute à la fin de la file."""
        if not refs:
            return
        first_new = len(self._items)
        self._items.extend(refs)
        new_indices = list(range(first_new, len(self._items)))
        if self._shuffle:
            self._rng.shuffle(new_indices)
        self._order.extend(new_indices)
        if self._pos < 0:
            self._pos = 0
            self.emit("changed")
            self.emit("current-changed", self.current)
            return
        self.emit("changed")

    def insert_next(self, refs: Sequence[TrackRef]) -> None:
        """« Lire ensuite » : insère juste après la piste courante."""
        if not refs:
            return
        first_new = len(self._items)
        self._items.extend(refs)
        new_indices = list(range(first_new, len(self._items)))
        insert_at = self._pos + 1 if self._pos >= 0 else 0
        self._order[insert_at:insert_at] = new_indices
        if self._pos < 0:
            self._pos = 0
            self.emit("changed")
            self.emit("current-changed", self.current)
            return
        self.emit("changed")

    def remove_at(self, index: int) -> None:
        """Retire une piste par son index dans `items`."""
        if not (0 <= index < len(self._items)):
            return
        removing_current = index == self.current_index
        order_pos = self._order.index(index)

        self._items.pop(index)
        self._order = [i - 1 if i > index else i
                       for i in self._order if i != index]
        # Seul un retrait situé AVANT le curseur le décale. Retirer la piste
        # courante laisse le curseur en place : la suivante glisse dessus.
        if order_pos < self._pos:
            self._pos -= 1
        if not self._items:
            self._pos = -1
        elif self._pos >= len(self._order):
            self._pos = len(self._order) - 1
        elif self._pos < 0:
            self._pos = 0

        self.emit("changed")
        if removing_current:
            self.emit("current-changed", self.current)

    def move(self, from_index: int, to_index: int) -> None:
        """Déplace une piste dans la vue utilisateur (drag & drop)."""
        n = len(self._items)
        if not (0 <= from_index < n) or not (0 <= to_index < n) or from_index == to_index:
            return
        current = self.current_index
        item = self._items.pop(from_index)
        self._items.insert(to_index, item)

        def remap(old: int) -> int:
            if old == from_index:
                return to_index
            if from_index < old <= to_index:
                return old - 1
            if to_index <= old < from_index:
                return old + 1
            return old

        self._order = [remap(i) for i in self._order]
        if current >= 0:
            self._pos = self._order.index(remap(current))
        self.emit("changed")

    def clear(self) -> None:
        self._items, self._order, self._pos = [], [], -1
        self.emit("changed")
        self.emit("current-changed", None)

    # ---- Navigation ----------------------------------------------------

    def jump_to(self, index: int) -> TrackRef | None:
        if not (0 <= index < len(self._items)):
            return None
        self._pos = self._order.index(index)
        self.emit("current-changed", self.current)
        return self.current

    def next(self, manual: bool = False) -> TrackRef | None:
        """Avance. `manual=True` ignore la répétition d'une seule piste."""
        if not self._items:
            return None
        if self._repeat == REPEAT_ONE and not manual:
            self.emit("current-changed", self.current)
            return self.current
        if self._pos + 1 < len(self._order):
            self._pos += 1
        elif self._repeat == REPEAT_ALL:
            # Nouveau tirage à chaque tour, sinon l'aléatoire se répète.
            if self._shuffle:
                self._rebuild_order(keep_current=False)
            self._pos = 0
        else:
            return None
        self.emit("current-changed", self.current)
        return self.current

    def previous(self) -> TrackRef | None:
        if not self._items:
            return None
        if self._pos > 0:
            self._pos -= 1
        elif self._repeat == REPEAT_ALL:
            self._pos = len(self._order) - 1
        else:
            return None
        self.emit("current-changed", self.current)
        return self.current

    # ---- Persistance ---------------------------------------------------

    def snapshot(self) -> dict:
        return {
            "items": [r.as_dict() for r in self._items],
            "index": self.current_index,
            "shuffle": self._shuffle,
            "repeat": self._repeat,
        }

    def restore(self, data: dict) -> None:
        refs = []
        for item in data.get("items") or []:
            if isinstance(item, dict):
                try:
                    refs.append(TrackRef.from_dict(item))
                except (ValueError, TypeError):
                    continue
        self._shuffle = bool(data.get("shuffle", False))
        repeat = data.get("repeat", REPEAT_OFF)
        self._repeat = repeat if repeat in REPEAT_MODES else REPEAT_OFF
        index = data.get("index", 0)
        self.set_items(refs, start=index if isinstance(index, int) and index >= 0 else 0)

    # ---- Interne -------------------------------------------------------

    def _build_order_from(self, start: int) -> None:
        """Construit l'ordre de lecture avec `start` en tête."""
        indices = list(range(len(self._items)))
        if self._shuffle:
            rest = [i for i in indices if i != start]
            self._rng.shuffle(rest)
            self._order = [start] + rest
            self._pos = 0
        else:
            self._order = indices
            self._pos = start

    def _rebuild_order(self, keep_current: bool) -> None:
        if not self._items:
            self._order, self._pos = [], -1
            return
        current = self.current_index if keep_current else -1
        if current < 0:
            indices = list(range(len(self._items)))
            if self._shuffle:
                self._rng.shuffle(indices)
            self._order = indices
            self._pos = 0
        else:
            self._build_order_from(current)
