hl.window_rule({
    name  = "suppress-maximize",
    match = { class = ".*" },
    suppress_event = "maximize",
})

-- Chromium/Electron apps paint one frame of their toolkit's white default
-- background before their own (usually dark) CSS takes over - a flash
-- against this rice's black theme. The gap is also the one moment the
-- window has no title yet, so hiding on that condition clears itself the
-- instant the app sets its real title, no timer needed. Scoped to the
-- apps this rice already special-cases (Vesktop, Spotify) plus the
-- common Electron/Chromium shells, not every window: an app that never
-- sets a title would otherwise stay invisible forever.
hl.window_rule({
    name  = "no-flashbang",
    match = {
        class = "^(vesktop|discord|spotify|chromium.*|code|[Ee]lectron.*|[Ss]lack|obsidian)$",
        title = "^$",
    },
    opacity = "0.0 override",
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
        -- The glyph bar swaps between a desktop-layer surface and an
        -- above-windows one to rise for its event. Both sit on the same
        -- pixels, so the swap should be invisible; with layersIn set to
        -- popin it read as the bar jumping out at you every time.
        namespace = "^nothing-(wallpaper|widgets|glyph|glyph-top|glyphbar|glyphbar-over|glyph-osd|essential|essential-fly)$"
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
