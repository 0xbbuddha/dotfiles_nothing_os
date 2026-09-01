pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import ".."
import "../components"

// Weather via wttr.in (can be disabled in Config.qml).
Singleton {
    id: root

    property int    temp: 0
    property int    hi: 0
    property int    lo: 0
    property string desc: "-"
    property string city: "-"
    // The sky, named. The font glyph is one rendering of it and Nothing's
    // dot icon is another, so the name is what the service publishes and
    // each widget picks its own way of drawing it.
    property string kind: "cloud"
    readonly property string glyph: root.icons[root.kind] ?? "󰖐"

    // Their dot set has a night pair for a clear and a clouded sky. wttr
    // does not say which side of dusk you are on, so the clock does.
    readonly property bool night: {
        const h = Time.now.getHours();
        return h < 7 || h >= 20;
    }
    readonly property string dotKind: DotIcons.nightly(root.kind, root.night)
    property bool   ready: false

    readonly property var icons: ({
        "sun": "󰖙", "cloud": "󰖐", "partly": "󰖕", "rain": "󰖗",
        "storm": "󰙾", "snow": "󰖘", "fog": "󰖑"
    })

    readonly property string endpoint: {
        const c = (Config.weatherCity || "").trim();
        const path = encodeURIComponent(c).replace(/%20/g, "+");
        // English, because every other string in this shell is. wttr
        // was answering in French, so the widgets read "PLUIE EPARSE A
        // PROXIMITE" beside labels that said HIGH and LOW.
        return "https://wttr.in/" + path + "?format=j1&lang=en";
    }

    function refresh(): void {
        if (!Config.weatherEnabled) return;
        const typed = (Config.weatherCity || "").trim();
        if (typed.length > 0)
            root.city = typed;
        fetch.running = false;
        Qt.callLater(() => {
            if (Config.weatherEnabled)
                fetch.running = true;
        });
    }

    NProcess {
        id: fetch
        running: Config.weatherEnabled
        command: ["curl", "-sf", "--max-time", "8",
                  "-H", "Accept-Language: fr", root.endpoint]

        stdout: StdioCollector {
            onStreamFinished: {
                if (!text.trim()) return;
                try {
                    const j = JSON.parse(text);
                    const cur = j.current_condition[0];
                    const day = j.weather[0];
                    root.temp = parseInt(cur.temp_C);
                    root.hi = parseInt(day.maxtempC);
                    root.lo = parseInt(day.mintempC);
                    root.desc = cur.weatherDesc?.[0]?.value ?? "";
                    const typed = (Config.weatherCity || "").trim();
                    root.city = typed.length > 0
                        ? typed
                        : (j.nearest_area?.[0]?.areaName?.[0]?.value ?? "");
                    root.kind = root.pick(parseInt(cur.weatherCode));
                    root.ready = true;
                } catch (e) {
                    console.warn("weather: unreadable response", e);
                }
            }
        }
    }

    Connections {
        target: Config
        function onWeatherCityChanged() { root.refresh(); }
        function onWeatherEnabledChanged() {
            if (Config.weatherEnabled) root.refresh();
            else root.ready = false;
        }
    }

    Timer {
        interval: 15 * 60 * 1000
        running: Config.weatherEnabled
        repeat: true
        onTriggered: root.refresh()
    }

    function pick(code: int): string {
        if (code === 113) return "sun";
        if ([116, 119].includes(code)) return "partly";
        if ([122, 143, 248, 260].includes(code)) return "fog";
        if (code >= 200 && code < 400) return "storm";
        if ([386, 389, 392, 395].includes(code)) return "storm";
        if ([227, 230, 320, 323, 326, 329, 332, 335, 338, 368, 371].includes(code)) return "snow";
        if (code >= 176) return "rain";
        return "cloud";
    }
}
