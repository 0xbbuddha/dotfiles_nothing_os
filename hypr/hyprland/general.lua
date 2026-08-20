hl.config({
    general = {
        -- Values from your configuration: larger gaps made windows
        -- look noticeably smaller.
        gaps_in    = 4,
        gaps_out   = 5,
        gaps_workspaces = 50,

        border_size = 1,

        col = {
            -- Nothing red on the active window, deep black otherwise
            active_border   = RED,
            inactive_border = INACTIVE,
        },

        resize_on_border = true,
        allow_tearing    = false,
        layout           = "dwindle",

        snap = {
            enabled = true,
            window_gap = 4,
            monitor_gap = 5,
            respect_gaps = true,
        },

        no_focus_fallback = true,
    },

    decoration = {
        rounding       = 18,
        rounding_power = 2.6,

        active_opacity   = 1.0,
        inactive_opacity = 0.94,

        shadow = {
            enabled      = true,
            range        = 28,
            render_power = 3,
            color        = 0x66000000,
            offset       = "0 6",
        },

        -- Nothing is matte: no frosted glass. A light blur only,
        -- just enough to lift panels off the background.
        blur = {
            enabled           = true,
            size              = 4,
            passes            = 2,
            noise             = 0.035,
            contrast          = 0.9,
            brightness        = 0.75,
            vibrancy          = 0.0,
            vibrancy_darkness = 0.0,
            special           = false,
            popups            = true,
            popups_ignorealpha = 0.4,
        },

        -- The red halo on the active window: a nod to the Glyph.
        glow = {
            enabled        = true,
            color          = 0x40d71921,
            color_inactive = 0x00000000,
            range          = 12,
            render_power   = 2,
        },
    },

    animations = {
        enabled = true,
    },

    dwindle = {
        preserve_split = true,
        smart_split    = false,
        smart_resizing = true,
    },

    master = {
        new_status = "master",
    },

    misc = {
        disable_hyprland_logo    = true,
        disable_splash_rendering = true,
        force_default_wallpaper  = 0,
        focus_on_activate        = true,
        -- Safety net: if a layer is missing, we see black,
        -- not a light gray that clashes with everything else.
        background_color         = "rgba(0b0b0bff)",
        vrr                      = 1,
    },

    input = {
        kb_layout    = "fr",
        follow_mouse = 1,
        sensitivity  = 0,

        touchpad = {
            natural_scroll       = true,
            disable_while_typing = true,
            scroll_factor        = 0.5,
        },
    },

    cursor = {
        inactive_timeout  = 4,
        hide_on_key_press = false,
    },
})

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
