local function allow(binary, kind)
    if not pcall(hl.permission, { binary = binary, type = kind, mode = "allow" }) then
        if not pcall(hl.permission, binary, kind, "allow") then
            print("permissions.lua: could not grant " .. kind .. " to " .. binary
                .. " - hl.permission's signature may have changed")
        end
    end
end

hl.config({ ecosystem = { enforce_permissions = true } })

allow("/usr/(bin|local/bin)/grim", "screencopy")
allow("/usr/(bin|local/bin)/wf-recorder", "screencopy")
allow("/usr/(bin|local/bin)/hyprpicker", "screencopy")
allow("/usr/(lib|libexec|lib64)/xdg-desktop-portal-hyprland", "screencopy")
allow("/usr/(bin|local/bin)/(qs|quickshell)", "screencopy")

allow("/usr/(bin|local/bin)/hyprpicker", "cursorpos")
allow("/usr/(bin|local/bin)/(qs|quickshell)", "cursorpos")

allow("/usr/(bin|local/bin)/(qs|quickshell)", "keyboard")
