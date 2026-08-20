-- Back-compat if something still points at hypr/nothing.lua.
-- The real entry is hypr/hyprland.lua (Hyprland's expected name).
dofile((debug.getinfo(1, "S").source:sub(2):match("^(.*)/") or ".") .. "/hyprland.lua")
