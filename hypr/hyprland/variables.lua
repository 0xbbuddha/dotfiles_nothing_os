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

-- The keyboard, taken from the system rather than from whoever wrote this
-- file. It said "fr" for a long time, because I am French and forgot that
-- everyone else is not; on a QWERTY keyboard that swaps A with Q and Z
-- with W, so SUPER + A closed the window. Reported and fixed by
-- parthpatyl in #2, extended here to the variant.
--
-- Three sources, in order of how much they mean it:
--
--   XKB_DEFAULT_LAYOUT   set for this session on purpose, so it wins
--   00-keyboard.conf     what localectl set-x11-keymap writes, read
--                        directly: it carries the variant too, and it
--                        costs a file open rather than a process
--   localectl            the fallback, for a system where that file is
--                        absent but localed answers
--
-- A layout with no variant is normal and not a failure: "fr" alone is
-- AZERTY already. The variant only matters for the likes of us+intl or
-- de+nodeadkeys, which is the same wrong-characters bug one level down.
local function xkbFile()
    local fh = io.open("/etc/X11/xorg.conf.d/00-keyboard.conf")
    if not fh then return nil, nil end
    local text = fh:read("*a")
    fh:close()
    return text:match('Option%s+"XkbLayout"%s+"([^"]*)"'),
           text:match('Option%s+"XkbVariant"%s+"([^"]*)"')
end

local function xkbLocalectl()
    -- Spawns a process, so it runs only when the file above is missing.
    -- Hyprland re-reads this config on every reload, and localectl talks
    -- to systemd-localed over dbus, which is not free on a cold bus.
    local f = io.popen("localectl status 2>/dev/null")
    if not f then return nil, nil end
    local layout, variant
    for line in f:lines() do
        layout  = layout  or line:match("X11 Layout:%s*(.-)%s*$")
        variant = variant or line:match("X11 Variant:%s*(.-)%s*$")
    end
    f:close()
    return layout, variant
end

local function detectKeyboard()
    local env = os.getenv("XKB_DEFAULT_LAYOUT")
    if env and env ~= "" then
        local v = os.getenv("XKB_DEFAULT_VARIANT")
        return env, (v ~= "" and v or nil)
    end

    local layout, variant = xkbFile()
    if not layout or layout == "" then
        layout, variant = xkbLocalectl()
    end
    if not layout or layout == "" then
        -- Hyprland's own default anyway, said out loud so the next reader
        -- does not go looking for where it was decided.
        return "us", nil
    end
    -- "fr,us" is a legitimate answer: two layouts you switch between.
    return (layout:gsub("%s+", "")), (variant and variant ~= "" and variant:gsub("%s+", "") or nil)
end

kbLayout, kbVariant = detectKeyboard()

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
