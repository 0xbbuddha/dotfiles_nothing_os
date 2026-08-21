local function pidof(name)
    local f = io.popen("pidof -s " .. name .. " 2>/dev/null")
    if not f then return false end
    local out = f:read("*l")
    f:close()
    return out ~= nil and out ~= ""
end

-- start-hyprland can emit hyprland.start before Lua is loaded, so we
-- run this both on the event and immediately. The guard is process-based.
local function startup()
    hl.exec_cmd("dbus-update-activation-environment --systemd --all")
    hl.exec_cmd("systemctl --user import-environment "
        .. "WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE HYPRLAND_INSTANCE_SIGNATURE")
    hl.exec_cmd(ROOT .. "/scripts/setup-portals.sh")

    if not pidof("quickshell") then
        hl.exec_cmd("qs -p " .. shellDir)
    end

    -- BlueZ will not finish a pairing without an agent registered, and
    -- nothing else here provides one. The script holds its own lock, so
    -- running it twice is harmless.
    hl.exec_cmd(ROOT .. "/scripts/bt-agent.sh")

    hl.exec_cmd("hyprctl setcursor " .. cursorTheme .. " " .. cursorSize)

    if exists("hypridle") and not pidof("hypridle") then
        hl.exec_cmd("hypridle -c " .. ROOT .. "/hypr/hypridle.conf")
    end

    if exists("gnome-keyring-daemon") then
        hl.exec_cmd("gnome-keyring-daemon --start --components=secrets")
    end

    if exists("cliphist") and exists("wl-paste") then
        hl.exec_cmd(ROOT .. "/scripts/ensure-cliphist.sh")
    end

    hl.exec_cmd("sleep 2 && " .. ROOT .. "/scripts/setup-portals.sh")
end

hl.on("hyprland.start", startup)
startup()
