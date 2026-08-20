-- Nothing never bounces: everything starts fast and stops dead.

hl.curve("nothing",     { type = "bezier", points = { {0.16, 1.0}, {0.30, 1.0} } })
hl.curve("nothingSnap", { type = "bezier", points = { {0.22, 1.0}, {0.36, 1.0} } })
hl.curve("nothingIn",   { type = "bezier", points = { {0.55, 0.0}, {0.30, 1.0} } })
hl.curve("linear",      { type = "bezier", points = { {0.0,  0.0}, {1.00, 1.0} } })

hl.animation({ leaf = "global",        enabled = true, speed = 3.5, bezier = "nothing" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 3.5, bezier = "nothing",     style = "popin 96%" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 2.6, bezier = "nothingIn",   style = "popin 94%" })
hl.animation({ leaf = "windowsMove",   enabled = true, speed = 3.5, bezier = "nothing" })
hl.animation({ leaf = "border",        enabled = true, speed = 6.0, bezier = "linear" })
hl.animation({ leaf = "fade",          enabled = true, speed = 2.8, bezier = "nothing" })
hl.animation({ leaf = "layersIn",      enabled = true, speed = 3.0, bezier = "nothing",     style = "popin 92%" })
hl.animation({ leaf = "layersOut",    enabled = true, speed = 2.2, bezier = "nothingIn",   style = "fade" })
hl.animation({ leaf = "workspaces",    enabled = true, speed = 4.0, bezier = "nothingSnap", style = "slidefade 12%" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 4.0, bezier = "nothingSnap", style = "slidevert" })
