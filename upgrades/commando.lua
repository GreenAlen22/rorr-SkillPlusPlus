-- Улучшения навыков Коммандо. Числа - в таблице T.

SPP = SPP or {}

local S = SPP.State
local U = SPP.Upgrades
local H = SPP.Hooks

local OP = gm.constants.oP
local FPS = 60

local T = {
    commandoZ  = { skillAttackSpeed = 0.08, doubleChance = 0.10,
                   text = { { "skillAttackSpeed", "pct" }, { "doubleChance", "pct" } } },
    commandoX  = { damage = 0.15, bulletEvery = 2,
                   text = { { "bulletEvery", "every" } } },
    commandoC  = { invulnAfter = 0.2, invulnAfterMax = 1.0, hasteAfter = 0.10, hasteSeconds = 2,
                   text = { { "invulnAfter", "sec", "invulnAfterMax" },
                            { "hasteAfter", "pct", "hasteSeconds", "sec" } } },
    commandoV  = { shots = 2, damage = 0.10,
                   text = { { "shots", "count" } } },
    commandoX2 = { knifeSize = 0.20, bleeds = 2,
                   text = { { "knifeSize", "pct" }, { "bleeds", "count" } } },
    commandoC2 = { slideAttackSpeed = 0.15, stock_every = 2,
                   text = { { "slideAttackSpeed", "pct" } } },
    commandoV2 = { pellets = 1, pelletRange = 0.15,
                   text = { { "pellets", "count" }, { "pelletRange", "pct" } } },
}

U.register({ "commandoZ" }, T.commandoZ)
U.register({ "commandoX" }, T.commandoX)
U.register({ "commandoC" }, T.commandoC)
U.register({ "commandoV", "commandoVBoosted" }, T.commandoV)
U.register({ "commandoX2" }, T.commandoX2)
U.register({ "commandoC2" }, T.commandoC2)
U.register({ "commandoV2", "commandoV2Boosted" }, T.commandoV2)

local Z  = U.ids("commandoZ")
local X  = U.ids("commandoX")
local C  = U.ids("commandoC")
local V  = U.ids("commandoV", "commandoVBoosted")
local X2 = U.ids("commandoX2")
local C2 = U.ids("commandoC2")
local V2 = U.ids("commandoV2", "commandoV2Boosted")

local STATE_Z     = H.state("commandoZ")
local STATE_X     = H.state("commandoX")
local STATE_X2    = H.state("commandoX2")
local STATE_V2    = H.state("commandoV2")
local STATE_V2B   = H.state("commandoV2Boosted")

local TRACER_Z, TRACER_X, TRACER_V2, TRACER_V2B = 8, 9, 10, 11

local firing_extra = false

local function fire_copy(actor, vanilla)
    firing_extra = true
    local ok, attack = pcall(GM.SO.fire_bullet, actor, actor, table.unpack(vanilla))
    firing_extra = false
    if not ok then error(attack, 0) end
    return attack
end

H.after_bullet(function(actor, attack, args, vanilla)
    if firing_extra or not H.in_state(actor, STATE_Z) or args[4].value ~= 0 then return end
    local rank = U.rank_for(actor, Z)
    if rank < 1 or math.random() >= T.commandoZ.doubleChance * rank then return end

    local extra = fire_copy(actor, vanilla)
    extra.climb = 8 * 1.35
    extra.tracer_kind = TRACER_Z
end)

local DOUBLE_TAP_RATE = 0.22

Callback.add(ActorState.find("commandoZ", "ror").on_step, function(actor, data)
    local rank = U.rank_for(actor, Z)
    if rank < 1 then return end
    local rate = DOUBLE_TAP_RATE * actor.attack_speed
    local faster = math.min(rate * (1 + T.commandoZ.skillAttackSpeed * rank), 1)
    if S.bool(actor.state_strafe_half) then
        actor.image_index2 = actor.image_index2 + faster - math.min(rate, 1)
    else
        actor.image_speed = faster
    end
end)

H.after_bullet(function(actor, attack, args, vanilla)
    if firing_extra or not H.in_state(actor, STATE_X) then return end
    local extra_count = math.floor(U.rank_for(actor, X) / T.commandoX.bulletEvery)
    for k = 1, extra_count do
        local extra = fire_copy(actor, vanilla)
        extra.knockback = extra.knockback + 6
        extra.climb = k * 8 * 1.35
        extra.tracer_kind = TRACER_X
    end
end)

local ROLL = 3

local haste = SPP.Stats.timer()

H.on_activity(function(actor, prev)
    if prev.activity ~= ROLL or tonumber(actor.activity) == ROLL then return end
    local rank = U.rank_for(actor, C)
    if rank < 1 then return end

    local seconds = math.min(T.commandoC.invulnAfter * rank, T.commandoC.invulnAfterMax)
    actor.invincible = math.max(tonumber(actor.invincible) or 0, math.floor(seconds * FPS))

    haste.start(actor, T.commandoC.hasteSeconds * FPS)
end)

local function is_sliding(actor)
    return S.bool(GM.SO._survivor_commando_is_sliding(actor, actor))
end

local was_sliding = {}

H.on_activity(function(actor, prev)
    if U.rank_for(actor, C2) < 1 then return end
    local sliding = is_sliding(actor)
    if sliding ~= (was_sliding[actor.id] or false) then
        was_sliding[actor.id] = sliding
        actor:queue_recalculate_stats()
    end
end)

Callback.add(Callback.ON_GAME_START, function()
    was_sliding = {}
end)

RecalculateStats.add(function(actor, api)
    if actor.object_index ~= OP then return end

    if haste.active(actor) then
        api.pHmax_mult(1 + T.commandoC.hasteAfter * U.rank_for(actor, C))
    end

    local rank = U.rank_for(actor, C2)
    if rank > 0 and is_sliding(actor) then
        api.attack_speed_add(T.commandoC2.slideAttackSpeed * rank)
    end
end)

H.on_explosion(function(actor, args, source)
    if source or not H.in_state(actor, STATE_X2) then return end
    local rank = U.rank_for(actor, X2)
    if rank > 0 then H.scale_blast(args, 1 + T.commandoX2.knifeSize * rank) end
end)

local WOUND = 16384
local BLEED_SHARE, BLEED_TICKS = 0.35, 4

Callback.add(Callback.ON_HIT_PROC, function(attacker, target, hit_info)
    if not Net.host then return end
    local flags = math.floor(tonumber(hit_info.attack_info.attack_flags) or 0)
    if flags & WOUND == 0 or not Instance.exists(attacker) or attacker.object_index ~= OP then return end
    local rank = U.rank_for(attacker, X2)
    if rank < 1 or not Instance.exists(target) then return end

    local damage = math.ceil(hit_info.damage_true * BLEED_SHARE)
    for _ = 1, T.commandoX2.bleeds * rank do
        local dot = GM.instance_create(target.x, target.y, gm.constants.oDot)
        dot.team = attacker.team
        dot.target = target
        dot.parent = attacker
        dot.damage = damage
        dot.ticks = BLEED_TICKS
    end
end)

for _, name in ipairs({ "commandoV", "commandoVAlternating", "commandoVBoosted", "commandoVBoostedAlternating" }) do
    Callback.add(ActorState.find(name, "ror").on_enter, function(actor, data)
        local rank = U.rank_for(actor, V)
        if rank > 0 then data.loop = data.loop + T.commandoV.shots * rank end
    end)
end

H.on_bullet(function(actor, args)
    if not (H.in_state(actor, STATE_V2) or H.in_state(actor, STATE_V2B)) then return end
    local rank = U.rank_for(actor, V2)
    if rank > 0 then args[6].value = args[6].value * (1 + T.commandoV2.pelletRange * rank) end
end)

local V2_BASE = Skill.find("commandoV2", "ror").value
local shadow_clone = Buff.find("shadowClone", "ror")
if not shadow_clone then error("vanilla buff ror-shadowClone not found") end

local pellets_done = {}

for _, spec in ipairs({
    { "commandoV2",        6, gm.constants.sSparks23,  TRACER_V2 },
    { "commandoV2Boosted", 8, gm.constants.sSparks23r, TRACER_V2B },
}) do
    local state, per_step, sparks, tracer = ActorState.find(spec[1], "ror"), spec[2], spec[3], spec[4]

    Callback.add(state.on_enter, function(actor, data)
        pellets_done[actor.id] = false
    end)

    Callback.add(state.on_step, function(actor, data)
        if pellets_done[actor.id] or not S.bool(data.fired) then return end
        pellets_done[actor.id] = true
        if not S.bool(actor.local_client_is_authority) then return end

        local rank = U.rank_for(actor, V2)
        if rank < 1 then return end

        local steps = actor:buff_count(shadow_clone) + 1
        local count = T.commandoV2.pellets * rank * steps
        local first_climb = per_step * steps

        local sliding = is_sliding(actor)
        local dir = GM.SO.skill_util_facing_direction(actor, actor) + (S.bool(data.reverse) and 180 or 0)
        local damage = GM.SO.skill_get_damage(actor, actor, V2_BASE)
        for k = 0, count - 1 do
            local attack = GM.SO.fire_bullet(actor, actor, 0, actor.x, actor.y + (sliding and 4 or 0), 1, damage,
                128 + math.random() * 30, sparks, dir + math.random() * 16 - 8)
            attack.knockback = attack.knockback + 4
            attack.climb = (first_climb + k) * 8 * 1.35
            attack.tracer_kind = tracer
            attack.damage_degrade = 0.35
            attack.stun = 1
        end
    end)
end

SPP.Commando = T
