-- Taken from your illogical-impulse configuration so it stays familiar,
-- with targets pointed at this shell's panels.

--## Applications
hl.bind(mainMod .. " + Return",     hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + T",          hl.dsp.exec_cmd(terminal))
hl.bind("CTRL + ALT + T",           hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + E",          hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + W",          hl.dsp.exec_cmd(browser))
hl.bind(mainMod .. " + C",          hl.dsp.exec_cmd(codeEditor))
hl.bind(mainMod .. " + X",          hl.dsp.exec_cmd(textEditor))
hl.bind("CTRL + " .. mainMod .. " + V", hl.dsp.exec_cmd(volumeMixer))

hl.bind(mainMod .. " + R",          ipc("launcher", "toggle"))
hl.bind(mainMod .. " + Tab",        ipc("launcher", "toggle"))
hl.bind(mainMod .. " + V",          ipc("clipboard", "toggle"))
hl.bind(mainMod .. " + Period",     ipc("emoji", "toggle"))
hl.bind(mainMod .. " + N",          ipc("bar", "toggle"))
hl.bind(mainMod .. " + B",          ipc("notifications", "toggle"))
hl.bind(mainMod .. " + I",          ipc("settings", "toggle"))
hl.bind(mainMod .. " + A",          ipc("essential", "toggle"))
hl.bind(mainMod .. " + G",          ipc("game", "toggle"))
hl.bind(mainMod .. " + Slash",      ipc("cheatsheet", "toggle"))
hl.bind(mainMod .. " + ALT + G",    ipc("game", "mode"))
hl.bind(mainMod .. " + ALT + X",    ipc("game", "crosshair"))
hl.bind("CTRL + ALT + Delete",      ipc("session", "toggle"))
hl.bind(mainMod .. " + Escape",     ipc("session", "toggle"))
-- The shell reloads itself. A "pkill -f 'qs -p <dir>'" followed by a
-- restart cannot work: the pattern also matches the sh that holds the
-- command, which is killed before it can relaunch anything.
hl.bind("CTRL + " .. mainMod .. " + R", ipc("shell", "reload"))

--## Session
hl.bind(mainMod .. " + L",          hl.dsp.exec_cmd(
    "hyprlock -c " .. ROOT .. "/hypr/hyprlock.conf"))
hl.bind(mainMod .. " + SHIFT + L",  hl.dsp.exec_cmd("systemctl suspend || loginctl suspend"),
    { locked = true })
hl.bind("CTRL + SHIFT + ALT + " .. mainMod .. " + Delete",
    hl.dsp.exec_cmd("systemctl poweroff || loginctl poweroff"))

--## Windows
hl.bind(mainMod .. " + Q",          hl.dsp.window.close())
hl.bind(mainMod .. " + SHIFT + ALT + Q", hl.dsp.exec_cmd("hyprctl kill"))
hl.bind(mainMod .. " + D",          hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))
hl.bind(mainMod .. " + SHIFT + F",  hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))
hl.bind(mainMod .. " + F",          hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
hl.bind(mainMod .. " + ALT + F",    hl.dsp.window.fullscreen_state({ internal = 0, client = 3, action = "toggle" }))
hl.bind(mainMod .. " + ALT + Space", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + P",          hl.dsp.window.pin())
hl.bind(mainMod .. " + J",          hl.dsp.layout("togglesplit"))

hl.bind(mainMod .. " + Semicolon",  hl.dsp.layout("splitratio -0.1"), { repeating = true })
hl.bind(mainMod .. " + Apostrophe", hl.dsp.layout("splitratio +0.1"), { repeating = true })

hl.bind(mainMod .. " + mouse:272",  hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:274",  hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273",  hl.dsp.window.resize(), { mouse = true })

-- Alt+F4: reminder rather than a surprise close
hl.bind("ALT + F4", hl.dsp.exec_cmd(
    "notify-send 'Wrong shortcut' 'Use SUPER+Q to close' -a Hyprland"),
    { non_consuming = true })

--# Directional focus and move
local arrows = { Left = "l", Right = "r", Up = "u", Down = "d" }
for key, dir in pairs(arrows) do
    hl.bind(mainMod .. " + " .. key,         hl.dsp.focus({ direction = dir }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ direction = dir }))
end
hl.bind(mainMod .. " + BracketLeft",  hl.dsp.focus({ direction = "l" }))
hl.bind(mainMod .. " + BracketRight", hl.dsp.focus({ direction = "r" }))

--## Workspaces
-- Raw keycodes: on an AZERTY keyboard the top row does not produce
-- digits, so key names like "1" would never fire.
--# Switching workspace from the special workspace
-- A special workspace stays displayed over the normal one: switching
-- without closing it does change the workspace underneath, but you see nothing.
-- Close it first.
local function closeSpecial()
    local sp = hl.get_active_special_workspace()
    if sp then
        hl.dispatch(hl.dsp.workspace.toggle_special(sp.name:gsub("^special:", "")))
    end
end

-- Exposed as a global: the shell calls it via
-- Hyprland.dispatch("gotoWorkspaceSafe(3)"). A dispatch expects an
-- expression that yields a dispatcher, hence the trailing no_op.
function gotoWorkspaceSafe(target)
    closeSpecial()
    hl.dispatch(hl.dsp.focus({ workspace = target }))
    return hl.dsp.no_op()
end

local function goWorkspace(target)
    return function()
        closeSpecial()
        hl.dispatch(hl.dsp.focus({ workspace = target }))
    end
end

-- To move, send the window first: the special workspace empties and
-- Hyprland closes it on its own.
local function sendToWorkspace(target)
    return function()
        hl.dispatch(hl.dsp.window.move({ workspace = target, follow = false }))
    end
end

for i = 1, 10 do
    local code = 9 + i          -- code:10 = key "1" ... code:19 = "0"
    hl.bind(mainMod .. " + code:" .. code,       goWorkspace(i))
    hl.bind(mainMod .. " + ALT + code:" .. code, sendToWorkspace(i))
end

local numpad = { 87, 88, 89, 83, 84, 85, 79, 80, 81, 90 }
for i = 1, 10 do
    hl.bind(mainMod .. " + code:" .. numpad[i],       goWorkspace(i))
    hl.bind(mainMod .. " + ALT + code:" .. numpad[i], sendToWorkspace(i))
end

--# Relative navigation
hl.bind("CTRL + " .. mainMod .. " + Left",  goWorkspace("r-1"))
hl.bind("CTRL + " .. mainMod .. " + Right", goWorkspace("r+1"))
hl.bind(mainMod .. " + Page_Up",            goWorkspace("r-1"))
hl.bind(mainMod .. " + Page_Down",          goWorkspace("r+1"))
hl.bind(mainMod .. " + mouse_up",           goWorkspace("-1"))
hl.bind(mainMod .. " + mouse_down",         goWorkspace("+1"))
hl.bind(mainMod .. " + SHIFT + Page_Up",    sendToWorkspace("r-1"))
hl.bind(mainMod .. " + SHIFT + Page_Down",  sendToWorkspace("r+1"))

--# Scratchpad
hl.bind(mainMod .. " + S",       hl.dsp.workspace.toggle_special("special"))
hl.bind(mainMod .. " + ALT + S", hl.dsp.window.move({ workspace = "special:special", follow = false }))

--## Utilities
hl.bind(mainMod .. " + SHIFT + S", ipc("screenshot", "region"))
hl.bind("CTRL + SHIFT + S",        ipc("screenshot", "region"))
hl.bind(mainMod .. " + SHIFT + X", ipc("screenshot", "ocr"))
hl.bind(mainMod .. " + SHIFT + C", hl.dsp.exec_cmd("hyprpicker -a"))
hl.bind(mainMod .. " + SHIFT + A", ipc("lens", "search"))
hl.bind(mainMod .. " + ALT + N",   ipc("song", "toggle"))
hl.bind(mainMod .. " + SHIFT + R", ipc("record", "region"))
hl.bind("CTRL + ALT + R",          ipc("record", "toggle"))
hl.bind(mainMod .. " + SHIFT + ALT + R", ipc("record", "sound"))
hl.bind("Print",                   ipc("screenshot", "screen"))
hl.bind("CTRL + Print",            ipc("screenshot", "save"))

--# Zoom
local function zoom(delta)
    local v = hl.get_config("cursor:zoom_factor") + delta
    hl.config({ cursor = { zoom_factor = math.max(1.0, math.min(3.0, v)) } })
end
hl.bind(mainMod .. " + Minus",   function() zoom(-0.3) end, { repeating = true })
hl.bind(mainMod .. " + Equal",   function() zoom(0.3) end,  { repeating = true })
hl.bind(mainMod .. " + code:82", function() zoom(-0.3) end, { repeating = true })
hl.bind(mainMod .. " + code:86", function() zoom(0.3) end,  { repeating = true })

--## Media
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 2%+"),
    { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 2%-"),
    { locked = true, repeating = true })
hl.bind("XF86AudioMute",    hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),   { locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })
hl.bind(mainMod .. " + SHIFT + M", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),   { locked = true })
hl.bind(mainMod .. " + ALT + M",   hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })

hl.bind("XF86MonBrightnessUp",   hl.dsp.global("quickshell:brightnessUp"),
    { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.global("quickshell:brightnessDown"),
    { locked = true, repeating = true })

hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind(mainMod .. " + SHIFT + N", hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind(mainMod .. " + SHIFT + B", hl.dsp.exec_cmd("playerctl previous"),   { locked = true })

-- SUPER press-release alone: opens the launcher. Hyprland only emits the
-- release if no other key was pressed in between.
hl.bind(mainMod .. " + SUPER_L", hl.dsp.global("quickshell:launcherToggle"))
hl.bind(mainMod .. " + SUPER_R", hl.dsp.global("quickshell:launcherToggle"))
