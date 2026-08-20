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
