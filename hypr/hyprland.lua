-- ═══════════════════════════════════════════════════════════════════════
--  NOTHING - Hyprland config (Lua API, Hyprland ≥ 0.56)
--  Lives at hypr/hyprland.lua (clone) and ~/.config/hypr/hyprland.lua
--  (install). Split files are hypr/hyprland/*.lua, loaded with require.
--  API reference: /usr/share/hypr/stubs/hl.meta.lua
-- ═══════════════════════════════════════════════════════════════════════

local src = debug.getinfo(1, "S").source:sub(2)
if not src:match("^/") then
    src = (os.getenv("PWD") or ".") .. "/" .. src
end
HYPR_DIR = src:match("^(.*)/[^/]+$")
assert(HYPR_DIR, "could not locate hypr/")

local function fileExists(path)
    local fh = io.open(path)
    if not fh then return false end
    fh:close()
    return true
end

-- Clone: parent of hypr/ has quickshell/. Installed: parent is ~/.config.
local parent = HYPR_DIR:match("^(.*)/[^/]+$")
if fileExists(parent .. "/quickshell/nothing/shell.qml") then
    ROOT = parent
else
    ROOT = os.getenv("NOTHING_ROOT") or parent
end
assert(ROOT, "could not locate the rice root; set NOTHING_ROOT")
shellDir = ROOT .. "/quickshell/nothing"

require("hyprland.variables")
require("hyprland.env")
require("hyprland.monitors")
require("hyprland.execs")
require("hyprland.general")
require("hyprland.animations")
require("hyprland.keybinds")
require("hyprland.rules")

local function loadLua(path)
    if not fileExists(path) then return false end
    dofile(path)
    return true
end

local hyprConf = (os.getenv("HOME") or "") .. "/.config/hypr"
if not loadLua(hyprConf .. "/custom.lua") then
    loadLua(HYPR_DIR .. "/custom.lua")
end
if not loadLua(hyprConf .. "/local.lua") then
    loadLua(HYPR_DIR .. "/local.lua")
end
