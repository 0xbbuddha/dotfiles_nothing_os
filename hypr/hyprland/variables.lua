-- Apps, palette, and helpers. Shared as globals so hypr/custom.lua
-- and the other hypr/hyprland/*.lua modules can use ipc / mainMod.

function exists(bin)
    -- os.execute() does not work here (Hyprland reaps its own children,
    -- system() returns ECHILD), so we use io.popen instead.
    local f = io.popen("command -v " .. bin .. " 2>/dev/null")
    if not f then return false end
    local out = f:read("*l")
    f:close()
    return out ~= nil and out ~= ""
end

function firstAvailable(candidates, fallback)
    for _, c in ipairs(candidates) do
        if exists(c:match("^(%S+)")) then return c end
    end
    return fallback
end

terminal    = firstAvailable({ "kitty", "foot", "alacritty", "ghostty", "wezterm" }, "xterm")
fileManager = firstAvailable({ "dolphin", "nautilus", "thunar", "nemo", "pcmanfm" },
                             terminal .. " -e ranger")
browser     = firstAvailable({ "helium-browser", "zen-browser", "google-chrome-stable",
                               "firefox", "chromium", "brave" },
                             "xdg-open https://start.duckduckgo.com")
codeEditor  = firstAvailable({ "code", "codium", "cursor", "zed" },
                             terminal .. " -e " .. firstAvailable({ "helix", "nvim", "vim" }, "nano"))
textEditor  = firstAvailable({ "kate", "gnome-text-editor", "gedit", "mousepad" },
                             terminal .. " -e " .. firstAvailable({ "helix", "nvim", "vim" }, "nano"))
volumeMixer = firstAvailable({ "pavucontrol-qt", "pavucontrol" },
                             terminal .. " -e wpctl status")

local function detectLayout()
    local env = os.getenv("XKB_DEFAULT_LAYOUT")
    if env and env ~= "" then return env end
    local f = io.popen("localectl status 2>/dev/null")
    if f then
        for line in f:lines() do
            local layout = line:match("X11 Layout:%s*(.-)%s*$")
            if layout and layout ~= "" then
                f:close()
                return layout
            end
        end
        f:close()
    end
    return "us"
end

kbLayout    = detectLayout()

function ipc(target, fn)
    return hl.dsp.exec_cmd("qs -p " .. shellDir .. " ipc call " .. target .. " " .. fn)
end

mainMod = "SUPER"

-- Nothing palette, shared with the shell (see quickshell/nothing/Theme.qml)
RED      = "rgba(d71921ff)"
INACTIVE = "rgba(1a1a1aff)"
BG       = "rgba(c4c4c4ff)"

cursorTheme = "Bibata-Modern-Classic"
cursorSize  = "24"
