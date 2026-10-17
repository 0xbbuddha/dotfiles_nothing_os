# Polices de Triat

Trois familles, toutes sous **SIL Open Font License 1.1** — redistribution
autorisée, y compris dans un paquet Flatpak, à condition de conserver les
fichiers de licence présents dans ce dossier.

| Fichier | Famille | Rôle (DESIGN.md §3) | Source |
|---|---|---|---|
| `Doto[ROND,wght].ttf` | Doto | Display — titres, chiffres, logo | [google/fonts · ofl/doto](https://github.com/google/fonts/tree/main/ofl/doto) |
| `Geist[wght].ttf` | Geist | Texte courant | [google/fonts · ofl/geist](https://github.com/google/fonts/tree/main/ofl/geist) |
| `GeistMono[wght].ttf` | Geist Mono | Étiquettes capitales, durées, données | [google/fonts · ofl/geistmono](https://github.com/google/fonts/tree/main/ofl/geistmono) |

Ce sont des polices **variables** : une seule fabrique couvre toutes les
graisses demandées par la feuille de style (400 à 900).

`app.py` les charge au démarrage via `PangoCairo.FontMap.add_font_file()` —
aucune installation système n'est nécessaire. Si le dossier est vide, les
replis du CSS s'appliquent (`monospace`, Inter, Cantarell) et l'application
reste utilisable, mais ne ressemble plus aux maquettes.

**Ndot** : si cette police des dotfiles Nothing est installée sur le système,
`GTK.md` §2 prévoit de l'utiliser à la place de Doto. Non implémenté.
