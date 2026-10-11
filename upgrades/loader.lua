-- Улучшения навыков Погрузчицы. Числа - в таблице T.

SPP = SPP or {}

local S = SPP.State
local U = SPP.Upgrades
local H = SPP.Hooks

local OP = gm.constants.oP
local FPS = 60

local T = {
    loaderZ  = { size = 0.15, knockChance = 0.10,
                 text = { { "size", "pct" }, { "knockChance", "pct" } } },
    loaderX  = { shieldSeconds = 0.25, shieldSecondsMax = 1.0, shieldSpeed = 0.10,
                 text = { { "shieldSeconds", "sec", "shieldSecondsMax" }, { "shieldSpeed", "pct" } } },
    loaderC  = { pullArmor = 15, pullArmorSeconds = 2, stock_every = 2,
                 text = { { "pullArmor", "count", "pullArmorSeconds", "sec" } } },
    loaderV  = { boltSeconds = 1, boltThickness = 0.20,
                 text = { { "boltSeconds", "sec" }, { "boltThickness", "pct" } } },
    loaderZ2 = { punchChargeSpeed = 0.15, size = 0.20,
                 text = { { "punchChargeSpeed", "pct" }, { "size", "pct" } } },
    loaderX2 = { size = 0.20, aftershockEvery = 2,
                 text = { { "size", "pct" }, { "aftershockEvery", "every" } } },
    loaderV2 = { beaconRadius = 0.20, beaconAttackSpeed = 0.10,
                 text = { { "beaconRadius", "pct" }, { "beaconAttackSpeed", "pct" } } },
}

U.register({ "loaderZ" }, T.loaderZ)
U.register({ "loaderX" }, T.loaderX)
U.register({ "loaderC" }, T.loaderC)
U.register({ "loaderV", "loaderVBoosted" }, T.loaderV)
U.register({ "loaderZ2" }, T.loaderZ2)
U.register({ "loaderX2" }, T.loaderX2)
U.register({ "loaderV2", "loaderV2Boosted" }, T.loaderV2)

local Z  = U.ids("loaderZ")
local X  = U.ids("loaderX")
local C  = U.ids("loaderC")
local V  = U.ids("loaderV", "loaderVBoosted")
local Z2 = U.ids("loaderZ2")
local X2 = U.ids("loaderX2")
local V2 = U.ids("loaderV2", "loaderV2Boosted")

local X2_ID = Skill.find("loaderX2", "ror").value

local STATE_ZA       = H.state("loaderZA")
local STATE_ZB       = H.state("loaderZB")
local STATE_ZC       = H.state("loaderZC")
local STATE_Z2_START = H.state("loaderZ2Start")
local STATE_Z2_FIRE  = H.state("loaderZ2Fire")
local STATE_X2_SLAM  = H.state("loaderX2Slam")

local function find_buff(name)
    local buff = Buff.find(name, "ror")
    if not buff then error("vanilla buff ror-"..name.." not found") end
    return buff
end

local shadow_clone = find_buff("shadowClone")
local shield       = find_buff("loaderShield")
local beacon_haste = find_buff("loaderSpeed2")

local ROD    = gm.constants.oConsRod
local BEACON = gm.constants.oConsRodB

local function box_is(args, xs, ys)
    return args[8].value == xs and args[9].value == ys
end

local WAVE_W, WAVE_H, WAVE_KNOCKUP = 4, 6, 4

local firing_aftershock = false

H.on_explosion(function(actor, args, source)
    if firing_aftershock then return end

    if source then
        if source.object_index ~= ROD then return end
        local rank = U.rank_for(actor, V)
        if rank > 0 then args[9].value = args[9].value * (1 + T.loaderV.boltThickness * rank) end
        return
    end

    if box_is(args, 1, 2) then
        local finisher = H.in_state(actor, STATE_ZC)
        if not (finisher or H.in_state(actor, STATE_ZA) or H.in_state(actor, STATE_ZB)) then return end
        local rank = U.rank_for(actor, Z)
        if rank < 1 then return end
        H.scale_blast(args, 1 + T.loaderZ.size * rank)
        if not finisher then return "knuckleboom" end
        return
    end

    if box_is(args, 2, 3) and H.in_state(actor, STATE_Z2_FIRE) then
        local rank = U.rank_for(actor, Z2)
        if rank > 0 then H.scale_blast(args, 1 + T.loaderZ2.size * rank) end
        return
    end

    if H.in_state(actor, STATE_X2_SLAM) and (box_is(args, WAVE_W, WAVE_H) or box_is(args, 2, 5)) then
        local rank = U.rank_for(actor, X2)
        if rank > 0 then H.scale_blast(args, 1 + T.loaderX2.size * rank) end
    end
end)

H.watch_event("oConsRod", "Alarm_1")

local FINISHER_KNOCKBACK, FINISHER_KNOCKUP = 4, 6

H.after_explosion(function(actor, attack, args, source, tag)
    if tag ~= "knuckleboom" then return end
    local rank = U.rank_for(actor, Z)
    if math.random() < T.loaderZ.knockChance * rank then
        attack.knockback = (tonumber(attack.knockback) or 0) + FINISHER_KNOCKBACK
        attack.knockup = (tonumber(attack.knockup) or 0) + FINISHER_KNOCKUP
    end
end)

Callback.add(Skill.find("loaderX", "ror").on_activate, function(actor, skill, slot)
    if not Net.host or actor.object_index ~= OP then return end
    local rank = U.rank_for(actor, X)
    if rank < 1 then return end
    local seconds = math.min(T.loaderX.shieldSeconds * rank, T.loaderX.shieldSecondsMax)
    actor:buff_set_time(shield, actor:buff_get_time(shield) + math.floor(seconds * FPS))
end)

local pull_guard = SPP.Stats.timer()

Callback.add(ActorState.find("loaderCPull", "ror").on_exit, function(actor, data)
    if actor.object_index ~= OP or not S.bool(data.ran_once) then return end
    if U.rank_for(actor, C) > 0 then pull_guard.start(actor, T.loaderC.pullArmorSeconds * FPS) end
end)

RecalculateStats.add(function(actor, api)
    if actor.object_index ~= OP then return end

    if actor:buff_count(shield) > 0 then
        local rank = U.rank_for(actor, X)
        if rank > 0 then api.pHmax_mult(1 + T.loaderX.shieldSpeed * rank) end
    end

    if pull_guard.active(actor) then
        local rank = U.rank_for(actor, C)
        if rank > 0 then api.armor_add(T.loaderC.pullArmor * rank) end
    end
end)

local was_paired = false

Hook.add_pre("gml_Object_oConsRod_Step_2", function(self, other)
    was_paired = Instance.exists(self.partner)
end)

Hook.add_post("gml_Object_oConsRod_Step_2", function(self, other)
    if was_paired or not Net.host then return end
    local partner = self.partner
    if not Instance.exists(partner) then return end
    local parent = self.parent
    if not Instance.exists(parent) or parent.object_index ~= OP then return end
    local rank = U.rank_for(parent, V)
    if rank < 1 then return end

    local extra = math.floor(T.loaderV.boltSeconds * FPS * rank)
    for _, rod in ipairs({ self, partner }) do
        local left = tonumber(rod:alarm_get(0)) or -1
        if left > 0 then rod:alarm_set(0, left + extra) end
    end
end)

local CHARGE_MAX = 150

Callback.add(ActorState.find("loaderZ2Start", "ror").on_step, function(actor, data)
    if actor.object_index ~= OP or not H.in_state(actor, STATE_Z2_START) then return end
    local rank = U.rank_for(actor, Z2)
    if rank < 1 then return end

    local bonus = T.loaderZ2.punchChargeSpeed * rank
    local speed = actor.attack_speed
    data.charge = math.min(CHARGE_MAX, data.charge + speed * bonus)
    local bar = data.charge_bar
    if Instance.exists(bar) then bar.rate = speed * (1 + bonus) end
end)

local AFTERSHOCK_DELAY = 15
local slam_seen = {}
local aftershocks = {}

local slam = ActorState.find("loaderX2Slam", "ror")

Callback.add(slam.on_enter, function(actor, data)
    slam_seen[actor.id] = false
end)

Callback.add(slam.on_step, function(actor, data)
    if slam_seen[actor.id] or not S.bool(data.fired) then return end
    slam_seen[actor.id] = true
    if actor.object_index ~= OP or not S.bool(actor.local_client_is_authority) then return end

    local count = math.floor(U.rank_for(actor, X2) / T.loaderX2.aftershockEvery)
    if count < 1 then
        aftershocks[actor.id] = nil
        return
    end
    aftershocks[actor.id] = { x = actor.x, y = actor.y, left = count, due = S.frame + AFTERSHOCK_DELAY }
end)

local function fire_aftershock(actor, shock)
    local mult = 1 + T.loaderX2.size * U.rank_for(actor, X2)
    local damage = GM.SO.skill_get_damage(actor, actor, X2_ID) / 3
    firing_aftershock = true
    local ok, err = pcall(function()
        for i = 0, actor:buff_count(shadow_clone) do
            local attack = GM.SO.fire_explosion(actor, actor, 0, shock.x, shock.y, damage,
                gm.constants.sSparks1, 2, -1, WAVE_W * mult, WAVE_H * mult)
            attack.climb = i * 8 * 1.35
            attack.knockup = WAVE_KNOCKUP
        end
    end)
    firing_aftershock = false
    if not ok then error(err, 0) end
end

H.on_activity(function(actor, prev)
    local shock = aftershocks[actor.id]
    if not shock or S.frame < shock.due then return end

    shock.left = shock.left - 1
    if shock.left < 1 then
        aftershocks[actor.id] = nil
    else
        shock.due = S.frame + AFTERSHOCK_DELAY
    end
    fire_aftershock(actor, shock)
end)

H.on_first_step("oConsRodB", function(beacon)
    local parent = beacon.parent
    if not Instance.exists(parent) or parent.object_index ~= OP then return end
    local rank = U.rank_for(parent, V2)
    if rank > 0 then beacon.radius = beacon.radius * (1 + T.loaderV2.beaconRadius * rank) end
end)

RecalculateStats.add(function(actor, api)
    if actor:buff_count(beacon_haste) < 1 then return end
    local team = actor.team
    local best = 0
    for _, beacon in ipairs(Instance.find_all(BEACON)) do
        local parent = beacon.parent
        if beacon.team == team and Instance.exists(parent) and parent.object_index == OP then
            best = math.max(best, U.rank_for(parent, V2))
        end
    end
    if best > 0 then api.attack_speed_add(T.loaderV2.beaconAttackSpeed * best) end
end)

local function reset()
    slam_seen = {}
    aftershocks = {}
end

Callback.add(Callback.ON_GAME_START, reset)
Callback.add(Callback.ON_STAGE_START, reset)

SPP.Loader = T
