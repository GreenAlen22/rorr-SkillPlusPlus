-- Покупка уровня: зажатая клавиша + клавиша навыка или Tab + клик по иконке.

SPP = SPP or {}

local C = SPP.Config
local S = SPP.State

local UPGRADE_VERB = C.namespace..".upgrade"
local SKILL_VERBS  = { [0] = "skill1", "skill2", "skill3", "skill4" }

local MOUSE_LEFT, MOUSE_RIGHT = 1, 2

local I = {}

local hold = {}

local blocked = {}

local function control(player, verb, kind)
    return S.bool(player:control(verb, kind))
end

local function can_buy(player, slot)
    local free = S.free(player)
    return free ~= nil and free > 0 and S.rankable(player, slot)
end

local function buy(player, h, slot)
    S.buy(player, slot)
    h.bought = S.frame
end

local function keyboard_and_mouse(player)
    return gm.input_profile_get(player.input_player_index) == "keyboard_and_mouse"
end

local function force_cursor()
    local init = Instance.find(gm.constants.oInit)
    if Instance.exists(init) then init.last_mouse_timer = 0 end
    Global.mouse_on = true
end

local function block_all(player)
    local b = blocked[player.id] or {}
    for slot = 0, 3 do b[SKILL_VERBS[slot]] = true end
    blocked[player.id] = b
end

local function block_slot(player, slot)
    local b = blocked[player.id] or {}
    b[SKILL_VERBS[slot]] = true
    blocked[player.id] = b
end

local function can_undo(h)
    return h.bought ~= nil and S.frame - h.bought <= C.undo_frames
end

local function step_hold(player, h, keys)
    local down = control(player, UPGRADE_VERB, 0) and S.bool(gm.window_has_focus())
    if not down then
        h.armed = false
    elseif control(player, UPGRADE_VERB, 1) then
        h.armed = true
    end

    if h.locked ~= nil and not keys[h.locked] then h.locked = nil end

    if not h.armed then
        h.slot, h.frames = nil, 0
        for slot = 0, 3 do
            if not keys[slot] then h.held[slot] = nil end
            if h.held[slot] then block_slot(player, slot) end
        end
        return
    end

    block_all(player)
    for slot = 0, 3 do
        if keys[slot] then h.held[slot] = true end
    end

    local pressed = nil
    if h.slot ~= nil and keys[h.slot] then
        pressed = h.slot
    else
        for slot = 0, 3 do
            if keys[slot] and slot ~= h.locked then pressed = slot break end
        end
    end

    if pressed == nil or not can_buy(player, pressed) then
        h.slot, h.frames = nil, 0
    elseif pressed == h.slot then
        h.frames = h.frames + 1
        if h.frames >= C.hold_frames then
            buy(player, h, pressed)
            h.locked, h.slot, h.frames = pressed, nil, 0
        end
    else
        h.slot, h.frames = pressed, 1
    end
end

local function step_mouse(player, h)
    force_cursor()

    local slot = SPP.Tooltip.hovered(player)
    local undo = can_undo(h)

    if slot ~= nil or undo then block_all(player) end

    if slot ~= nil and S.bool(gm.mouse_check_button_pressed(MOUSE_LEFT)) and can_buy(player, slot) then
        buy(player, h, slot)
    elseif undo and S.bool(gm.mouse_check_button_pressed(MOUSE_RIGHT)) then
        S.refund(player)
        h.bought = nil
    end
end

local control_hook = Hook.add_post(gm.constants.control, function(self, other, result, args)
    local b = blocked[self.id]
    if b and b[args[1].value] then result.value = false end
end)
control_hook:toggle(false)
local control_hook_on = false

Callback.add(Callback.PRE_STEP, function()
    blocked = {}

    if S.level() then
        for _, player in ipairs(S.players()) do
            if S.bool(player.is_local) and not S.bool(player.dead) then
                local id = player.id
                hold[id] = hold[id] or { frames = 0, held = {} }

                local keys = {}
                for slot = 0, 3 do
                    keys[slot] = control(player, SKILL_VERBS[slot], 0)
                end

                step_hold(player, hold[id], keys)

                if control(player, "tab", 0) and keyboard_and_mouse(player) then
                    step_mouse(player, hold[id])
                end
            end
        end
    else
        hold = {}
    end

    local want = next(blocked) ~= nil
    if want ~= control_hook_on then
        control_hook:toggle(want)
        control_hook_on = want
    end
end)

function I.progress(player)
    local h = hold[player.id]
    if not h or h.slot == nil then return nil end
    return h.slot, math.min(1, h.frames / C.hold_frames)
end

SPP.Input = I
