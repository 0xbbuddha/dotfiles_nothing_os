pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import ".."

// Weather via wttr.in (can be disabled in Config.qml).
Singleton {
    id: root

    property int    temp: 0
    property int    hi: 0
    property int    lo: 0
    property string desc: "-"
    property string city: "-"
    property string glyph: "󰖐"
    property bool   ready: false

    readonly property var icons: ({
        "sun": "󰖙", "cloud": "󰖐", "partly": "󰖕", "rain": "󰖗",
        "storm": "󰙾", "snow": "󰖘", "fog": "󰖑"
    })

    readonly property string endpoint: {
        const c = (Config.weatherCity || "").trim();
        const path = encodeURIComponent(c).replace(/%20/g, "+");
        return "https://wttr.in/" + path + "?format=j1&lang=fr";
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

    Process {
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
                    root.desc = cur.lang_fr?.[0]?.value ?? cur.weatherDesc?.[0]?.value ?? "";
                    const typed = (Config.weatherCity || "").trim();
                    root.city = typed.length > 0
                        ? typed
                        : (j.nearest_area?.[0]?.areaName?.[0]?.value ?? "");
                    root.glyph = root.pick(parseInt(cur.weatherCode));
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
        if (code === 113) return icons.sun;
        if ([116, 119].includes(code)) return icons.partly;
        if ([122, 143, 248, 260].includes(code)) return icons.fog;
        if (code >= 200 && code < 400) return icons.storm;
        if ([386, 389, 392, 395].includes(code)) return icons.storm;
        if ([227, 230, 320, 323, 326, 329, 332, 335, 338, 368, 371].includes(code)) return icons.snow;
        if (code >= 176) return icons.rain;
        return icons.cloud;
    }
}
