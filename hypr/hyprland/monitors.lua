-- scale = 1 rather than "auto": on the laptop screen, "auto" makes Hyprland
-- pick 1.5 and everything looks twice as large as with your configuration.
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = 1,
})

-- External display
hl.monitor({
   output   = "HDMI-A-1",
    mode     = "preferred",
    position = "auto",
    scale    = "auto",
})

-- A layout arranged in the shell's display manager (SUPER+P) and kept is
-- written here as the same calls. It comes last so it wins over the
-- defaults above, and the file simply does not exist until you press Keep.
local kept = (os.getenv("HOME") or "") .. "/.config/hypr/displays.lua"
local fh = io.open(kept)
if fh then
    fh:close()
    dofile(kept)
end
