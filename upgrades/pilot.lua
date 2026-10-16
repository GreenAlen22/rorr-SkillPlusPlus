-- Улучшения навыков Пилота. Числа - в таблице T.

SPP = SPP or {}

local S = SPP.State
local U = SPP.Upgrades
local H = SPP.Hooks

local OP = gm.constants.oP
local FPS = 60

local function constant(name)
    local value = gm.constants[name]
    if value == nil then error("vanilla constant "..name.." not found") end
    return value
end

local T = {
    pilotZ  = { range = 0.15, clusterEvery = 2,
                text = { { "range", "pct" }, { "clusterEvery", "every" } } },
    pilotX  = { shotWidth = 0.20, lockOnAngle = 0.20,
                text = { { "shotWidth", "pct" }, { "lockOnAngle", "pct" } } },
    pilotC  = { chuteArmor = 15, stock_every = 2,
                text = { { "chuteArmor", "count" } } },
    pilotV  = { bombEvery = 2, radius = 0.20,
                text = { { "bombEvery", "every" }, { "radius", "pct" } } },
    pilotZ2 = { critChance = 0.10, damage = 0.10,
                text = { { "critChance", "pct" } } },
    pilotC2 = { dashInvuln = 0.2, dashInvulnMax = 1.0, clingArmor = 15,
                text = { { "dashInvuln", "sec", "dashInvulnMax" }, { "clingArmor", "count" } } },
    pilotV2 = { strikes = 2, radius = 0.20,
                text = { { "strikes", "count" }, { "radius", "pct" } } },
}

U.register({ "pilotZ" }, T.pilotZ)
U.register({ "pilotX" }, T.pilotX)
U.register({ "pilotC" }, T.pilotC)
U.register({ "pilotV", "pilotVBoosted" }, T.pilotV)
U.register({ "pilotZ2" }, T.pilotZ2)
U.register({ "pilotC2" }, T.pilotC2)
U.register({ "pilotV2", "pilotV2Boosted" }, T.pilotV2)

local Z  = U.ids("pilotZ")
local X  = U.ids("pilotX")
local C  = U.ids("pilotC")
local V  = U.ids("pilotV", "pilotVBoosted")
local Z2 = U.ids("pilotZ2")
local C2 = U.ids("pilotC2")
local V2 = U.ids("pilotV2", "pilotV2Boosted")

local STATE_ZA = H.state("pilotZA")
local STATE_ZB = H.state("pilotZB")
local STATE_ZC = H.state("pilotZC")
local STATE_X  = H.state("pilotX")
local STATE_Z2 = H.state("pilotZ2")

local MINE = constant("oPilotMine")
local RAID = constant("oPilotRaidDamager")
local WALL = constant("pBlock")

local shadow_clone = Buff.find("shadowClone", "ror")
if not shadow_clone then error("vanilla buff ror-shadowClone not found") end

local Z_RANGE, Z2_RANGE = 400, 1400

local TRACER_STRONG = 6
local TRACER_COLOUR = 5324799
local CLIMB_STEP = 8 * 1.35

local firing_extra = false

local strong_shot = nil

H.on_bullet(function(actor, args)
    strong_shot = nil
    if args[6].value ~= Z_RANGE then return end
    local strong = H.in_state(actor, STATE_ZC)
    if not (strong or H.in_state(actor, STATE_ZA) or H.in_state(actor, STATE_ZB)) then return end
    local rank = U.rank_for(actor, Z)
    if rank < 1 then return end
    args[6].value = Z_RANGE * (1 + T.pilotZ.range * rank)
    if strong and not firing_extra then strong_shot = actor.id end
end)

local FAN_DEGREES = 4
local fan_climb = {}

Callback.add(ActorState.find("pilotZC", "ror").on_enter, function(actor, data)
    fan_climb[actor.id] = 0
end)

H.after_bullet(function(actor, attack, args, vanilla)
    if strong_shot ~= actor.id then return end
    strong_shot = nil
    local extra = math.floor(U.rank_for(actor, Z) / T.pilotZ.clusterEvery)
    if extra < 1 then return end

    local values = {}
    for i = 1, #vanilla do values[i] = vanilla[i] end
    local dir = values[8]
    local xs = actor.image_xscale
    local colour = GM.skin_get_colour_override(actor.skin_current, "pilotZ", TRACER_COLOUR)
    local steps = actor:buff_count(shadow_clone) + 1

    for k = 1, extra do
        values[8] = dir + FAN_DEGREES * math.ceil(k / 2) * (k % 2 == 1 and 1 or -1)
        firing_extra = true
        local ok, bullet = pcall(GM.SO.fire_bullet, actor, actor, table.unpack(values))
        firing_extra = false
        if not ok then error(bullet, 0) end

        fan_climb[actor.id] = (fan_climb[actor.id] or 0) + 1
        bullet.damage_degrade = 0.5
        bullet.climb = (steps + fan_climb[actor.id] - 1) * CLIMB_STEP
        bullet.knockback_direction = xs
        bullet.tracer_kind = TRACER_STRONG
        bullet.tracer_col = colour
    end
end)

H.on_explosion(function(actor, args, source)
    if source or not H.in_state(actor, STATE_X) then return end
    if args[8].value ~= 12.9 or args[9].value ~= 0.25 then return end
    local rank = U.rank_for(actor, X)
    if rank > 0 then args[9].value = args[9].value * (1 + T.pilotX.shotWidth * rank) end
end)

Hook.add_pre(constant("_survivor_pilot_find_target"), function(self, other, result, args)
    if self.object_index ~= OP then return end
    local rank = U.rank_for(self, X)
    if rank > 0 then args[2].value = args[2].value * (1 + T.pilotX.lockOnAngle * rank) end
end)

local function has_chute(actor)
    return S.bool(gm.variable_struct_exists(actor.component_data.value, "pilot_para"))
end

local function is_clinging(actor)
    return S.bool(GM.SO._survivor_pilot_is_clinging(actor, actor))
end

local was_clinging = {}

H.on_activity(function(actor, prev)
    if U.rank_for(actor, C2) < 1 then return end
    local clinging = is_clinging(actor)
    if clinging ~= (was_clinging[actor.id] or false) then
        was_clinging[actor.id] = clinging
        actor:queue_recalculate_stats()
    end
end)

RecalculateStats.add(function(actor, api)
    if actor.object_index ~= OP then return end

    local rank = U.rank_for(actor, C)
    if rank > 0 and has_chute(actor) then api.armor_add(T.pilotC.chuteArmor * rank) end

    rank = U.rank_for(actor, C2)
    if rank > 0 and is_clinging(actor) then api.armor_add(T.pilotC2.clingArmor * rank) end
end)

Callback.add(ActorState.find("pilotC2", "ror").on_exit, function(actor, data)
    if actor.object_index ~= OP then return end
    local rank = U.rank_for(actor, C2)
    if rank < 1 then return end
    local seconds = math.min(T.pilotC2.dashInvuln * rank, T.pilotC2.dashInvulnMax)
    actor.invincible = math.max(tonumber(actor.invincible) or 0, math.floor(seconds * FPS))
end)

local BOMB_SPACING = 14
local dropped = {}

for _, spec in ipairs({ { "pilotV", false }, { "pilotVBoosted", true } }) do
    local state, scepter = ActorState.find(spec[1], "ror"), spec[2]

    Callback.add(state.on_enter, function(actor, data)
        dropped[actor.id] = false
    end)

    Callback.add(state.on_step, function(actor, data)
        if dropped[actor.id] or not S.bool(data.fired) then return end
        dropped[actor.id] = true
        if not Net.host or actor.object_index ~= OP then return end

        local extra = math.floor(U.rank_for(actor, V) / T.pilotV.bombEvery)
        if extra < 1 then return end

        local steps = actor:buff_count(shadow_clone) + 1
        for k = 1, extra * steps do
            local offset = BOMB_SPACING * math.ceil(k / 2) * (k % 2 == 1 and 1 or -1)
            if actor:is_colliding(WALL, actor.x + offset, actor.y) then offset = 0 end
            local bomb = GM.instance_create(actor.x + offset, actor.y, MINE)
            bomb.parent = actor
            bomb.scepter = scepter
        end
    end)
end

H.after_bullet(function(actor, attack, args)
    if firing_extra or args[6].value ~= Z2_RANGE or not H.in_state(actor, STATE_Z2) then return end
    local rank = U.rank_for(actor, Z2)
    if rank > 0 and math.random() < T.pilotZ2.critChance * rank then
        AttackInfo.wrap(attack):set_critical(true)
    end
end)

H.watch_event("oPilotMine", "Step_2")
H.watch_event("oPilotRaidDamager", "Step_2")

H.on_explosion(function(actor, args, source)
    if not source then return end
    local object = source.object_index
    local ids, def
    if object == MINE then
        ids, def = V, T.pilotV
    elseif object == RAID then
        ids, def = V2, T.pilotV2
    else
        return
    end
    local rank = U.rank_for(actor, ids)
    if rank > 0 then H.scale_blast(args, 1 + def.radius * rank) end
end)

H.on_first_step("oPilotRaidDamager", function(raid)
    local parent = raid.parent
    if not Instance.exists(parent) or parent.object_index ~= OP then return end
    local extra = T.pilotV2.strikes * U.rank_for(parent, V2)
    if extra > 0 then raid.loops = raid.loops + extra end
end)

Callback.add(Callback.ON_GAME_START, function()
    fan_climb = {}
    was_clinging = {}
    dropped = {}
    strong_shot = nil
end)

SPP.Pilot = T
