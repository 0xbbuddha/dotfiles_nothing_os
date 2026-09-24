"""Point d'entrée du module.

`triat` sans argument ouvre la fenêtre ; `triat <commande>` passe la main à
la ligne de commande. Les options propres à l'interface (--mini) restent du
côté graphique.
"""

import sys

# Sous-commandes de triat.cli. Tout le reste va à l'interface graphique.
COMMANDS = {"search", "play", "import", "export", "playlists",
            "cookies", "stats", "doctor"}


def main() -> int:
    argv = sys.argv[1:]
    first = next((a for a in argv if not a.startswith("-")), None)
    if first in COMMANDS:
        from .cli import main as cli_main

        return cli_main(argv)
    if argv and argv[0] in ("-h", "--help"):
        print("Usage :\n"
              "  triat                    ouvrir la fenêtre\n"
              "  triat --mini             ouvrir le mini-lecteur\n"
              "  triat --search           ouvrir la recherche\n"
              "  triat --play-pause       lecture / pause (instance ouverte)\n"
              f"  triat <commande>         {', '.join(sorted(COMMANDS))}\n"
              "  triat <commande> --help  aide d'une commande")
        return 0

    from .app import run as app_run

    action = next((a[2:] for a in argv
                   if a in ("--mini", "--search", "--play-pause")), None)
    return app_run([sys.argv[0]], action=action)


if __name__ == "__main__":
    sys.exit(main())
