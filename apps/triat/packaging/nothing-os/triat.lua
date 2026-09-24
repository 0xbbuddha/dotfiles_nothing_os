-- Triat — intégration à la session Nothing OS
-- Déposé dans ~/.config/hypr/triat.lua, chargé depuis custom.lua par :
--     require("triat")
--
-- Syntaxe alignée sur hypr/hyprland/rules.lua et keybinds.lua des dotfiles.
-- Les touches média passent déjà par playerctl : Triat expose MPRIS2, elles
-- fonctionnent donc sans rien ajouter ici.

-- Hyprland filtre en regex RE2, pas en motif Lua : l'échappement est
-- « \. » et non « %. ». Un motif Lua ici ne matcherait aucune fenêtre.
local APP = "org\\.triat\\.Triat"

-- Fenêtre principale : gérée en tuilage comme les autres applications.
-- On se contente de lui laisser une taille de départ confortable.
hl.window_rule({
    name  = "triat-main",
    match = { class = "^(" .. APP .. ")$", title = "^(Triat)$" },
})

-- Mini-lecteur : petite fenêtre flottante, épinglée sur tous les bureaux.
-- Wayland interdit à une application de se placer « toujours au-dessus » :
-- c'est au compositeur de le faire, d'où cette règle (GTK.md §7).
hl.window_rule({
    name  = "triat-mini",
    -- Le titre porte un tiret cadratin : on matche « mini » plutôt que la
    -- chaîne exacte, moins fragile côté motifs Lua.
    match = { class = "^(" .. APP .. ")$", title = ".*mini.*" },
    float = true,
    pin   = true,
    size  = { 440, 200 },   -- hauteur réelle imposée par GTK
})

-- Opacité. La session pose `inactive_opacity = 0.94` : joli sur du texte,
-- gênant sur des pochettes, qui se mélangent alors au fond d'écran. Triat
-- reste donc opaque, focalisé ou non. Commentez ce bloc pour revenir au
-- comportement global de la session.
-- `opacity` attend une chaîne, au format « actif inactif ».
hl.window_rule({
    name    = "triat-opaque",
    match   = { class = "^(" .. APP .. ")$" },
    opacity = "1.0 1.0",
})

-- Dialogues (import de fichier, réglages) : flottants et centrés.
hl.window_rule({
    name  = "triat-dialogs",
    match = { class = "^(" .. APP .. ")$", float = true },
    center = true,
})

-- Raccourcis, choisis libres dans keybinds.lua des dotfiles (SUPER+N y
-- affiche la barre, SUPER+SHIFT+N passe au titre suivant, SUPER+ALT+Espace
-- rend une fenêtre flottante). `locked = true` : les contrôles répondent
-- aussi écran verrouillé, comme les autres binds média des dotfiles.
hl.bind("SUPER + M",        hl.dsp.exec_cmd("triat"))
hl.bind("SUPER + CTRL + M", hl.dsp.exec_cmd("triat --mini"))

-- Pilotage direct de Triat, sans passer par le lecteur actif du système.
local function triat_ctl(action)
    return hl.dsp.exec_cmd(
        "playerctl --player=triat " .. action .. " || playerctl " .. action)
end

hl.bind("SUPER + ALT + Down",  triat_ctl("play-pause"), { locked = true })
hl.bind("SUPER + ALT + Right", triat_ctl("next"),       { locked = true })
hl.bind("SUPER + ALT + Left",  triat_ctl("previous"),   { locked = true })
