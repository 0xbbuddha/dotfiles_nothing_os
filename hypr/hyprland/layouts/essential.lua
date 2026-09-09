-- Essential: one window, and a shelf of the rest.
--
-- The phone puts what you are doing in front of you and everything you
-- put aside in Essential Space. This is that, applied to windows: a big
-- pane for the thing you are working on, and every other window as a
-- sliver down one side. You do not tile, you pick something off the
-- shelf.
--
-- The main pane does not follow focus, deliberately. This config has
-- follow_mouse = 1, so a pane that followed focus would swap itself out
-- every time the pointer crossed a sliver. You promote a window on
-- purpose instead, with the key that turns the split in the other
-- layouts.
--
-- The shelf sits on the side the rest of the shell puts its shelf on:
-- Config.essentialSide in the settings panel, mirrored here by
-- hypr/hyprland/layouts.lua when the shell writes it out.
--
-- Written against /usr/share/hypr/stubs/hl.meta.lua and the example at
-- example/layouts/manual.lua in the Hyprland repo.

if not (hl.layout and hl.layout.register) then
    return
end

-- Set by ~/.config/hypr/layout.lua, which the shell writes.
--
-- Read on every recalculate rather than captured here, and that is not a
-- style choice: layout.lua is loaded at the end of general.lua, which is
-- after this file has already been required. Read once at load time, the
-- globals would always still be nil and the settings would never arrive.
local function side()
    return ESSENTIAL_SIDE == "left" and "left" or "right"
end

local function configured_ratio()
    return tonumber(ESSENTIAL_RATIO) or 0.62
end

local state = {
    order = {},   -- shelf order, main first
    ratio = nil,  -- set by splitratio, otherwise the config value
}

local function target_id(target)
    local window = target.window
    return window and tostring(window.stable_id) or tostring(target.index)
end

local function index_of(tbl, value)
    for i, v in ipairs(tbl) do
        if v == value then return i end
    end
end

local function active_id(ctx)
    for _, target in ipairs(ctx.targets) do
        local window = target.window
        if window and window.active then
            return target_id(target)
        end
    end
    return state.order[1]
end

-- A new window goes to the front, not the back: you opened it because you
-- want it now. Everything else slides one place down the shelf.
local function sync_order(ctx)
    local present, targets = {}, {}
    for _, target in ipairs(ctx.targets) do
        local id = target_id(target)
        present[id] = true
        targets[id] = target
    end

    local old = state.order
    state.order = {}
    for _, id in ipairs(old) do
        if present[id] then
            table.insert(state.order, id)
        end
    end

    for _, target in ipairs(ctx.targets) do
        local id = target_id(target)
        if not index_of(state.order, id) then
            table.insert(state.order, 1, id)
        end
    end

    return targets
end

local function main_ratio()
    local r = state.ratio or configured_ratio()
    if r < 0.25 then r = 0.25 end
    if r > 0.9 then r = 0.9 end
    return r
end

hl.layout.register("essential", {
    recalculate = function(ctx)
        local n = #ctx.targets
        if n == 0 then return end

        local targets = sync_order(ctx)
        local ids = state.order

        -- Alone on the workspace, there is no shelf to draw.
        if n == 1 then
            local only = targets[ids[1]]
            if only then only:place(ctx.area) end
            return
        end

        local ratio = main_ratio()
        local shelfSide = side()
        local mainSide  = shelfSide == "left" and "right" or "left"

        local main = targets[ids[1]]
        if main then
            main:place(ctx:split(ctx.area, mainSide, ratio))
        end

        -- The shelf is cut one row at a time off what is left, because
        -- ctx:row divides the whole work area and not an arbitrary box.
        -- Taking 1/k of the remainder each time gives k equal rows without
        -- ever having to know where the shelf starts.
        local shelf = ctx:split(ctx.area, shelfSide, 1 - ratio)
        local left = n - 1
        for i = 2, #ids do
            local target = targets[ids[i]]
            if target then
                if left == 1 then
                    target:place(shelf)
                else
                    target:place(ctx:split(shelf, "top", 1 / left))
                    shelf = ctx:split(shelf, "bottom", (left - 1) / left)
                end
                left = left - 1
            end
        end
    end,

    -- togglesplit is here because that is what SUPER + J already sends in
    -- the tiling layout. In a layout with one pane there is no split to
    -- turn, and "put this in front" is the thing you want that key for.
    layout_msg = function(ctx, msg)
        local id = active_id(ctx)
        local command, arg = msg:match("^(%S+)%s*(.*)$")

        if command == "promote" or command == "togglesplit" then
            local i = id and index_of(state.order, id)
            if i and i > 1 then
                table.remove(state.order, i)
                table.insert(state.order, 1, id)
            end
        elseif command == "splitratio" then
            local delta = tonumber(arg)
            if not delta then
                return "essential: splitratio wants a number"
            end
            state.ratio = main_ratio() + delta
        elseif command == "cycle" then
            -- Next thing off the shelf, without reaching for the mouse.
            if #state.order > 1 then
                local first = table.remove(state.order, 1)
                table.insert(state.order, first)
            end
        elseif command == "swapnext" then
            local i = id and index_of(state.order, id)
            if i and i < #state.order then
                state.order[i], state.order[i + 1] = state.order[i + 1], state.order[i]
            end
        elseif command == "swapprev" then
            local i = id and index_of(state.order, id)
            if i and i > 1 then
                state.order[i], state.order[i - 1] = state.order[i - 1], state.order[i]
            end
        elseif command == "reset" then
            state.ratio = nil
        else
            -- Not ours. The scrolling binds are bound in every layout, so
            -- their messages arrive here on every press; answering with an
            -- error would turn a dead key into a complaining one.
            return false
        end

        return true
    end,
})
