-- Улучшения навыков Наёмника. Числа - в таблице T.

SPP = SPP or {}

local S = SPP.State
local U = SPP.Upgrades
local H = SPP.Hooks

local OP = gm.constants.oP
local FPS = 60

local STUN_FRAMES = 90

local T = {
    mercenaryZ  = { size = 0.15, stunChance = 0.10, stunSeconds = 0.75,
                    text = { { "size", "pct" }, { "stunChance", "pct", "stunSeconds", "sec" } } },
    mercenaryX  = { size = 0.20, slashEvery = 2,
                    text = { { "size", "pct" }, { "slashEvery", "every" } } },
    mercenaryC  = { redashEvery = 2, dashInvuln = 0.1, dashInvulnMax = 0.5,
                    text = { { "redashEvery", "every" }, { "dashInvuln", "sec", "dashInvulnMax" } } },
    mercenaryV  = { slashes = 1, damage = 0.10,
                    text = { { "slashes", "count" } } },
    mercenaryX2 = { parryChance = 0.10, size = 0.20,
                    text = { { "parryChance", "pct" }, { "size", "pct" } } },
    mercenaryC2 = { slamAttackSpeed = 0.15, slamSeconds = 2, stock_every = 2,
                    text = { { "slamAttackSpeed", "pct", "slamSeconds", "sec" } } },
    mercenaryV2 = { echoEvery = 2, afterimageSeconds = 0.5,
                    text = { { "echoEvery", "every" }, { "afterimageSeconds", "sec" } } },
}

U.register({ "mercenaryZ" }, T.mercenaryZ)
U.register({ "mercenaryX" }, T.mercenaryX)
U.register({ "mercenaryC" }, T.mercenaryC)
U.register({ "mercenaryV", "mercenaryVBoosted" }, T.mercenaryV)
U.register({ "mercenaryX2" }, T.mercenaryX2)
U.register({ "mercenaryC2" }, T.mercenaryC2)
U.register({ "mercenaryV2", "mercenaryV2Boosted" }, T.mercenaryV2)

local Z  = U.ids("mercenaryZ")
local X  = U.ids("mercenaryX")
local C  = U.ids("mercenaryC")
local V  = U.ids("mercenaryV", "mercenaryVBoosted")
local X2 = U.ids("mercenaryX2")
local C2 = U.ids("mercenaryC2")
local V2 = U.ids("mercenaryV2", "mercenaryV2Boosted")

local X_ID = Skill.find("mercenaryX", "ror").value

local STATE_ZA     = H.state("mercenaryZA")
local STATE_ZB     = H.state("mercenaryZB")
local STATE_ZC     = H.state("mercenaryZC")
local STATE_X      = H.state("mercenaryX")
local STATE_WEAK   = H.state("mercenaryX2SwingWeak")
local STATE_STRONG = H.state("mercenaryX2SwingStrong")

local shadow_clone = Buff.find("shadowClone", "ror")
if not shadow_clone then error("vanilla buff ror-shadowClone not found") end
local afterimage = Buff.find("mercAfterimage", "ror")
if not afterimage then error("vanilla buff ror-mercAfterimage not found") end

local function player_of(object)
    local parent = object.parent
    if Instance.exists(parent) and parent.object_index == OP then return parent end
    return nil
end

local function box_is(args, xs, ys)
    return args[8].value == xs and args[9].value == ys
end

local function laser_swing(actor, args)
    if not (H.in_state(actor, STATE_ZA) or H.in_state(actor, STATE_ZB) or H.in_state(actor, STATE_ZC)) then
        return false
    end
    return box_is(args, 1, 4)
end

local function whirlwind_slash(actor, args)
    return H.in_state(actor, STATE_X) and (box_is(args, 1.8, 5) or box_is(args, 1.9, 4))
end

local function focused_swing(actor, args)
    return (H.in_state(actor, STATE_WEAK) and box_is(args, 1.5, 3))
        or (H.in_state(actor, STATE_STRONG) and box_is(args, 4, 6))
end

H.on_explosion(function(actor, args, source)
    if source then return end

    if laser_swing(actor, args) then
        local rank = U.rank_for(actor, Z)
        if rank < 1 then return end
        H.scale_blast(args, 1 + T.mercenaryZ.size * rank)
        return "laserSword"
    end

    if whirlwind_slash(actor, args) then
        local rank = U.rank_for(actor, X)
        if rank > 0 then H.scale_blast(args, 1 + T.mercenaryX.size * rank) end
        return
    end

    if focused_swing(actor, args) then
        local rank = U.rank_for(actor, X2)
        if rank > 0 then H.scale_blast(args, 1 + T.mercenaryX2.size * rank) end
    end
end)

local LASER_STUN = T.mercenaryZ.stunSeconds * FPS / STUN_FRAMES

H.after_explosion(function(actor, attack, args, source, tag)
    if tag ~= "laserSword" then return end
    local rank = U.rank_for(actor, Z)
    if math.random() < T.mercenaryZ.stunChance * rank then
        attack.stun = math.max(tonumber(attack.stun) or 0, LASER_STUN)
    end
end)

local WHIRL_FRAME = 2
local whirl_done = {}

local whirlwind = ActorState.find("mercenaryX", "ror")

Callback.add(whirlwind.on_enter, function(actor, data)
    whirl_done[actor.id] = false
end)

Callback.add(whirlwind.on_step, function(actor, data)
    if whirl_done[actor.id] or math.floor(actor.image_index) < WHIRL_FRAME then return end
    whirl_done[actor.id] = true
    if actor.object_index ~= OP or not S.bool(actor.local_client_is_authority) then return end

    local extra = math.floor(U.rank_for(actor, X) / T.mercenaryX.slashEvery)
    if extra < 1 then return end

    local damage = GM.SO.skill_get_damage(actor, actor, X_ID)
    local steps = actor:buff_count(shadow_clone) + 1
    for k = 1, extra do
        for i = 0, steps - 1 do
            local attack = GM.SO.fire_explosion(actor, actor, 0, actor.x, actor.y, damage,
                gm.constants.sSparks9, 2, -1, 1.8, 5)
            attack.climb = 14.85 * (k + 1) + i * 8 * 1.35
        end
    end
end)

H.on_first_step("oMercRestockController", function(counter)
    local player = player_of(counter)
    if not player then return end
    local extra = math.floor(U.rank_for(player, C) / T.mercenaryC.redashEvery)
    if extra > 0 then counter.remaining = counter.remaining + extra end
end)

local POOL_TAIL = 4

Callback.add(ActorState.find("mercenaryC", "ror").on_exit, function(actor, data)
    if actor.object_index ~= OP then return end
    local rank = U.rank_for(actor, C)
    if rank < 1 then return end
    local seconds = math.min(T.mercenaryC.dashInvuln * rank, T.mercenaryC.dashInvulnMax)
    local frames = math.max(0, math.floor(seconds * FPS) - POOL_TAIL)
    actor.merc_bonus_iframes = math.max(tonumber(actor.merc_bonus_iframes) or 0, frames)
end)

local EVISCERATE = 4
local REWIND_AT = 13
local slashes_left = {}

H.on_activity(function(actor, prev)
    if tonumber(actor.activity) ~= EVISCERATE then return end
    local rank = U.rank_for(actor, V)
    if rank < 1 then return end

    local id = actor.id
    if prev.activity ~= EVISCERATE then slashes_left[id] = T.mercenaryV.slashes * rank end
    if (slashes_left[id] or 0) < 1 or math.floor(actor.image_index) ~= REWIND_AT then return end

    slashes_left[id] = slashes_left[id] - 1
    actor.image_index = actor.image_index - 2
    actor.activity_var1 = 0
end)

Callback.add(ActorState.find("mercenaryX2Release", "ror").on_enter, function(actor, data)
    if not Net.host or actor.object_index ~= OP then return end
    local rank = U.rank_for(actor, X2)
    if rank > 0 and math.random() < T.mercenaryX2.parryChance * rank then actor.deflect = 2 end
end)

local slam_haste = SPP.Stats.timer()
local slam_landed = {}

local slam = ActorState.find("mercenaryC2Slam", "ror")

Callback.add(slam.on_enter, function(actor, data)
    slam_landed[actor.id] = false
end)

Callback.add(slam.on_step, function(actor, data)
    if slam_landed[actor.id] or not S.bool(data.fired) then return end
    slam_landed[actor.id] = true
    if U.rank_for(actor, C2) > 0 then slam_haste.start(actor, T.mercenaryC2.slamSeconds * FPS) end
end)

RecalculateStats.add(function(actor, api)
    if actor.object_index ~= OP or not slam_haste.active(actor) then return end
    local rank = U.rank_for(actor, C2)
    if rank > 0 then api.attack_speed_add(T.mercenaryC2.slamAttackSpeed * rank) end
end)

H.on_first_step("oMercAfterimageDamager", function(echo)
    local player = player_of(echo)
    if not player then return end
    local extra = math.floor(U.rank_for(player, V2) / T.mercenaryV2.echoEvery)
    if extra > 0 then echo.loops = echo.loops + extra end
end)

for _, spec in ipairs({ { "mercenaryV2", 180 }, { "mercenaryV2Boosted", 300 } }) do
    local base = spec[2]
    Callback.add(Skill.find(spec[1], "ror").on_activate, function(actor, skill, slot)
        if not Net.host then return end
        local rank = U.rank_for(actor, V2)
        if rank < 1 then return end
        local want = base + math.floor(T.mercenaryV2.afterimageSeconds * FPS * rank)
        if actor:buff_get_time(afterimage) < want then actor:buff_set_time(afterimage, want) end
    end)
end

Callback.add(Callback.ON_GAME_START, function()
    whirl_done = {}
    slashes_left = {}
    slam_landed = {}
end)

SPP.Mercenary = T
