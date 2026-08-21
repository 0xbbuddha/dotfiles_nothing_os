hl.window_rule({
    name  = "suppress-maximize",
    match = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    -- fix XWayland drag-and-drop
    name  = "fix-xwayland-drags",
    match = {
        class = "^$",
        title = "^$",
        xwayland = true,
        float = true,
        fullscreen = false,
        pin = false,
    },
    no_focus = true,
})

hl.window_rule({
    name  = "float-settings-dialogs",
    match = { class = "^(pavucontrol|nm-connection-editor|blueman-manager)$" },
})

-- KDE's pairing wizard, opened from the Bluetooth panel for devices the
-- built-in NoInputNoOutput agent cannot answer.
hl.window_rule({
    match = { class = ".*bluedevilwizard" },
    float  = true,
    size   = "480 620",
    center = true,
})

hl.window_rule({
    name  = "float-file-chooser",
    match = {
        class = "^(org\\.freedesktop\\.impl\\.portal\\.desktop\\.(kde|gtk)|xdg-desktop-portal-gtk)$"
    },
    float  = true,
    center = true,
})

hl.window_rule({
    name  = "pip",
    match = { title = "^(Picture-in-Picture)$" },
    float             = true,
    pin               = true,
    keep_aspect_ratio = true,
})

-- Namespaces are set on the Quickshell side (WlrLayershell.namespace).

hl.layer_rule({
    name  = "nothing-no-anim",
    match = {
        namespace = "^nothing-(wallpaper|widgets|glyph-osd|essential|essential-fly)$"
    },
    no_anim = true,
})

hl.layer_rule({
    name  = "nothing-panels",
    match = {
        namespace = "^nothing-(bar|dock|overlay|settings|launcher|session|notifications|osd|crosshair)$"
    },
    blur         = true,
    ignore_alpha = 0.6,
})
