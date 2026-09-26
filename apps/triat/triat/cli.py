"""CLI compagnon : pilote le moteur sans interface graphique.

Sert de banc d'essai du core et de contrôle en ligne de commande.

    python -m triat.cli play "daft punk instant crush"
    python -m triat.cli search "aphex twin"
    python -m triat.cli cookies browser firefox
    python -m triat.cli stats
"""

from __future__ import annotations

import argparse
import logging
import signal
import sys

import gi

gi.require_version("Gtk", "4.0")

from gi.repository import GLib

from .core.auth import CookieError, CookieManager
from .core.engine import Engine
from .core.settings import Settings


def format_time(seconds: float) -> str:
    total = int(max(0, seconds))
    minutes, secs = divmod(total, 60)
    hours, minutes = divmod(minutes, 60)
    return f"{hours}:{minutes:02d}:{secs:02d}" if hours else f"{minutes}:{secs:02d}"


# ---- Commandes ---------------------------------------------------------

def cmd_search(args) -> int:
    engine = Engine()
    refs = engine.recommender.search(args.query, limit=args.limit)
    if not refs:
        print("Aucun résultat.")
        return 1
    for i, ref in enumerate(refs, 1):
        print(f"{i:2}. {ref.label}  [{format_time(ref.duration)}]  {ref.video_id}")
    engine.library.close()
    return 0


def cmd_play(args) -> int:
    engine = Engine()
    loop = GLib.MainLoop()
    state = {"skipped": 0.0, "last_line": ""}

    def on_track(_e, ref) -> None:
        if ref is None:
            return
        print(f"\n▶  {ref.label}  [{format_time(ref.duration)}]")

    def on_state(_e, value) -> None:
        if value == "idle":
            print()

    def on_position(_e, position) -> None:
        duration = engine.player.duration
        line = f"   {format_time(position)} / {format_time(duration)}"
        if line != state["last_line"]:
            state["last_line"] = line
            sys.stdout.write("\r" + line + "   ")
            sys.stdout.flush()

    def on_skip(_e, segment, gained) -> None:
        state["skipped"] += gained
        print(f"\n   ⏭  {segment.category} sauté ({gained:.0f} s, "
              f"total {state['skipped']:.0f} s)")

    def on_pending(_e, segment) -> None:
        print(f"\n   ?  segment {segment.category} à "
              f"{format_time(segment.start)} (politique « demander »)")

    def on_error(_e, message) -> None:
        print(f"\n   ✗  {message}", file=sys.stderr)

    engine.connect("track-changed", on_track)
    engine.connect("state-changed", on_state)
    engine.connect("position-changed", on_position)
    engine.connect("segment-skipped", on_skip)
    engine.connect("segment-pending", on_pending)
    engine.connect("error", on_error)

    mpris = None
    if not args.no_mpris:
        from .services.mpris import MprisService

        mpris = MprisService(engine)
        if mpris.publish():
            print("MPRIS publié sur le bus de session.")

    def stop(*_args) -> bool:
        loop.quit()
        return False

    try:
        gi.require_version("GLibUnix", "2.0")
        from gi.repository import GLibUnix

        GLibUnix.signal_add(GLib.PRIORITY_DEFAULT, signal.SIGINT, stop)
    except (ValueError, ImportError):
        GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, signal.SIGINT, stop)
    if args.seconds:
        GLib.timeout_add_seconds(args.seconds, stop)

    # « playlist:12 » lit une playlist locale au lieu de chercher.
    if args.query.startswith("playlist:"):
        try:
            playlist_id = int(args.query.split(":", 1)[1])
        except ValueError:
            print("Identifiant de playlist invalide.", file=sys.stderr)
            return 1
        refs = engine.library.playlist_items(playlist_id)
        if not refs:
            print("Playlist vide ou inconnue.", file=sys.stderr)
            return 1
        print(f"Lecture de {len(refs)} pistes.")
        engine.play_refs(refs)
    else:
        engine.play_query(args.query)
    loop.run()

    print(f"\nTemps économisé par SponsorBlock : {state['skipped']:.0f} s")
    if mpris is not None:
        mpris.unpublish()
    engine.shutdown()
    return 0


def cmd_cookies(args) -> int:
    settings = Settings()
    manager = CookieManager(settings)
    try:
        if args.action == "status":
            pass
        elif args.action == "import":
            manager.import_file(args.value)
        elif args.action == "browser":
            manager.import_from_browser(args.value)
        elif args.action == "clear":
            manager.clear()
            print("Cookies effacés.")
            return 0
    except CookieError as exc:
        print(f"Erreur : {exc}", file=sys.stderr)
        return 1

    status = manager.status()
    if not status.present:
        print("Aucun cookie enregistré.")
        return 0
    days = status.days_left
    print(f"Cookies : {status.count} entrées"
          f" | source : {status.source or 'inconnue'}"
          f" | session authentifiée : {'oui' if status.authenticated else 'non'}"
          + (f" | expire dans {days:.1f} j" if days is not None else ""))
    if status.expired:
        print("⚠  Session expirée : réimportez les cookies.")
    return 0


def cmd_import(args) -> int:
    from .core.importer import ImportError_, import_playlist

    engine = Engine()
    state = {"last": -1}

    def progress(done: int, total: int) -> None:
        percent = done * 100 // total
        if percent != state["last"]:
            state["last"] = percent
            sys.stdout.write(f"\r   {done}/{total} ({percent} %)   ")
            sys.stdout.flush()

    try:
        _pid, name, refs = import_playlist(
            args.file, engine.library, name=args.name, progress=progress)
    except ImportError_ as exc:
        print(f"\nErreur : {exc}", file=sys.stderr)
        engine.library.close()
        return 1
    print(f"\n« {name} » : {len(refs)} pistes importées.")
    resolus = sum(1 for r in refs if r.artist)
    if resolus < len(refs):
        print(f"   {len(refs) - resolus} sans métadonnées (elles restent jouables).")
    for ref in refs[:5]:
        print(f"   {(ref.artist or '—')[:24]:26} | {ref.title[:44]}")
    if len(refs) > 5:
        print(f"   … et {len(refs) - 5} autres")
    engine.library.close()
    return 0


def cmd_playlists(args) -> int:
    engine = Engine()
    playlists = engine.library.list_playlists()
    if not playlists:
        print("Aucune playlist. Importez-en une : triat import <fichier>")
        engine.library.close()
        return 0
    for item in playlists:
        print(f"{item['id']:>3}. {item['name'][:40]:42} {item['item_count']:>4} pistes")
    if args.show is not None:
        refs = engine.library.playlist_items(args.show)
        print()
        for i, ref in enumerate(refs, 1):
            print(f"  {i:>3}. {(ref.artist or '—')[:22]:24} | {ref.title[:44]}")
    engine.library.close()
    return 0


def cmd_export(args) -> int:
    from .core.importer import export_playlist

    engine = Engine()
    refs = engine.library.playlist_items(args.playlist)
    if not refs:
        print("Playlist vide ou inconnue.", file=sys.stderr)
        engine.library.close()
        return 1
    try:
        path = export_playlist(refs, args.file, args.format)
    except Exception as exc:
        print(f"Erreur : {exc}", file=sys.stderr)
        engine.library.close()
        return 1
    print(f"{len(refs)} pistes exportées vers {path}")
    engine.library.close()
    return 0


def cmd_stats(args) -> int:
    engine = Engine()
    stats = engine.library.stats()
    print(f"Pistes connues   : {stats['tracks']}")
    print(f"Favoris          : {stats['favorites']}")
    print(f"Playlists        : {stats['playlists']}")
    print(f"Écoutes          : {stats['plays']}")
    print(f"Temps d'écoute   : {format_time(stats['seconds'])}")
    top = engine.library.top_tracks(limit=args.limit)
    if top:
        print("\nLes plus écoutées :")
        for i, ref in enumerate(top, 1):
            print(f"{i:2}. {ref.label}")
    engine.library.close()
    return 0


def cmd_doctor(args) -> int:
    """Vérifie que toutes les briques externes répondent."""
    engine = Engine()
    # état : "ok" (vert), "warn" (fonctionne en mode dégradé), "fail" (cassé)
    checks: list[tuple[str, str, str]] = []

    import yt_dlp
    checks.append(("yt-dlp", "ok", yt_dlp.version.__version__))

    try:
        import mpv
        checks.append(("libmpv", "ok", str(mpv.MPV(video=False).mpv_version)))
    except Exception as exc:
        checks.append(("libmpv", "fail", str(exc)))

    status = engine.cookies.status()
    if status.authenticated and not status.expired:
        checks.append(("cookies", "ok", "session authentifiée"))
    elif status.present:
        checks.append(("cookies", "warn", "présents mais sans session valide"))
    else:
        checks.append(("cookies", "warn",
                       "aucun — lecture anonyme, pas de recommandations Google"))

    if not engine.ytmusic.available:
        checks.append(("youtube music", "fail", "injoignable"))
    elif engine.ytmusic.authenticated:
        checks.append(("youtube music", "ok", "authentifié"))
    else:
        checks.append(("youtube music", "warn",
                       "anonyme — recherche et radio dégradées, repli sur yt-dlp"))

    try:
        segments = engine.sponsorblock.fetch("kJQP7kiw5Fk", ["music_offtopic"])
        checks.append(("sponsorblock", "ok", f"{len(segments)} segment(s) de test"))
    except Exception as exc:
        checks.append(("sponsorblock", "fail", str(exc)))

    checks.append(("bibliothèque", "ok", f"{engine.library.stats()['tracks']} pistes"))

    # Quels clients YouTube répondent encore : c'est le point de rupture
    # numéro un de ce type d'application.
    from .core.extractor import CLIENT_FALLBACKS, _QuietLogger

    import yt_dlp

    vivants = []
    for client in CLIENT_FALLBACKS:
        options = {"quiet": True, "no_warnings": True, "skip_download": True,
                   "format": "bestaudio/best", "noprogress": True,
                   "logger": _QuietLogger()}
        options.update(engine.cookies.ytdlp_opts())
        if client is not None:
            options["extractor_args"] = {"youtube": {"player_client": [client]}}
        try:
            with yt_dlp.YoutubeDL(options) as ydl:
                info = ydl.extract_info(
                    "https://www.youtube.com/watch?v=jNQXAC9IVRw", download=False)
            if info and info.get("url"):
                vivants.append(client or "défaut")
        except Exception:
            continue
    if vivants:
        checks.append(("clients youtube", "ok",
                       f"{len(vivants)}/{len(CLIENT_FALLBACKS)} répondent : "
                       + ", ".join(vivants)))
    else:
        checks.append(("clients youtube", "fail",
                       "aucun client ne répond — voir docs/po-token.md"))

    from .core import desktop

    info = desktop.describe()
    if info["dotfiles"]:
        detail = f"accent {info['accent'] or 'non lu'} · police {info['display_font']}"
        checks.append(("bureau nothing", "ok", detail))
    else:
        checks.append(("bureau nothing", "warn",
                       "dotfiles absents — thème de Triat par défaut"))

    marks = {"ok": "✓", "warn": "~", "fail": "✗"}
    width = max(len(name) for name, _, _ in checks)
    for name, level, detail in checks:
        print(f"{marks[level]} {name.ljust(width)}  {detail}")
    engine.library.close()
    # Seule une brique cassée fait échouer : le mode dégradé reste utilisable.
    return 1 if any(level == "fail" for _, level, _ in checks) else 0


# ---- Point d'entrée ----------------------------------------------------

def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="triat", description=__doc__)
    parser.add_argument("-v", "--verbose", action="store_true")
    sub = parser.add_subparsers(dest="command", required=True)

    p_search = sub.add_parser("search", help="rechercher des pistes")
    p_search.add_argument("query")
    p_search.add_argument("-n", "--limit", type=int, default=15)
    p_search.set_defaults(func=cmd_search)

    p_play = sub.add_parser("play", help="lire une recherche ou une URL")
    p_play.add_argument("query", help="recherche, URL, ou « playlist:<id> »")
    p_play.add_argument("-s", "--seconds", type=int, default=0,
                        help="arrêt automatique après N secondes")
    p_play.add_argument("--no-mpris", action="store_true")
    p_play.set_defaults(func=cmd_play)

    p_cookies = sub.add_parser("cookies", help="gérer les cookies YouTube")
    p_cookies.add_argument("action",
                           choices=("status", "import", "browser", "clear"))
    p_cookies.add_argument("value", nargs="?")
    p_cookies.set_defaults(func=cmd_cookies)

    p_import = sub.add_parser("import", help="importer une playlist (.txt, .m3u)")
    p_import.add_argument("file")
    p_import.add_argument("-n", "--name", help="nom de la playlist")
    p_import.set_defaults(func=cmd_import)

    p_pl = sub.add_parser("playlists", help="lister les playlists")
    p_pl.add_argument("--show", type=int, metavar="ID",
                      help="afficher le contenu d'une playlist")
    p_pl.set_defaults(func=cmd_playlists)

    p_export = sub.add_parser("export", help="exporter une playlist")
    p_export.add_argument("playlist", type=int, metavar="ID")
    p_export.add_argument("file")
    p_export.add_argument("-f", "--format",
                          choices=("m3u8", "txt", "json", "csv"))
    p_export.set_defaults(func=cmd_export)

    p_stats = sub.add_parser("stats", help="statistiques d'écoute")
    p_stats.add_argument("-n", "--limit", type=int, default=10)
    p_stats.set_defaults(func=cmd_stats)

    p_doctor = sub.add_parser("doctor", help="vérifier les dépendances externes")
    p_doctor.set_defaults(func=cmd_doctor)
    return parser


def main(argv=None) -> int:
    args = build_parser().parse_args(argv)
    logging.basicConfig(
        level=logging.DEBUG if args.verbose else logging.WARNING,
        format="%(levelname)-7s %(name)s: %(message)s",
    )
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
