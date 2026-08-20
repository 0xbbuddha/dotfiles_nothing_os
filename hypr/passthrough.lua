-- Keyboard passthrough for testing the nested session.
--
-- Add this to your CURRENT Hyprland config (not the theme's), for example
-- at the end of ~/.config/hypr/custom/keybinds.lua:
--
--     dofile(os.getenv("HOME") .. "/hypr_nothing/hypr/passthrough.lua")
--
-- SUPER+ALT+P switches to a mode where the host no longer captures any
-- shortcut: everything goes to the foreground window, i.e. nested Hyprland.
-- Same combination to return.

hl.define_submap("passthrough", "reset", function()
    hl.bind("SUPER + ALT + P", hl.dsp.submap("reset"))
end)

hl.bind("SUPER + ALT + P", hl.dsp.submap("passthrough"))
