-- Улучшения навыков МАСТ-3Р. Числа - в таблице T.

SPP = SPP or {}

local S = SPP.State
local U = SPP.Upgrades
local H = SPP.Hooks

local OP = gm.constants.oP
local FPS = 60

local STUN_FRAMES = 90

local function constant(name)
    local value = gm.constants[name]
    if value == nil then error("vanilla constant "..name.." not found") end
    return value
end

local function buff(name)
    local found = Buff.find(name, "ror")
    if not found then error("vanilla buff ror-"..name.." not found") end
    return found
end

local T = {
    handZ  = { size = 0.20, droneChance = 0.10,
               text = { { "size", "pct" }, { "droneChance", "pct" } } },
    handX  = { charges = 1, healBonus = 0.25,
               text = { { "charges", "count" }, { "healBonus", "pct" } } },
    handC  = { overclockArmor = 15, overclockSeconds = 0.5,
               text = { { "overclockArmor", "count" }, { "overclockSeconds", "sec" } } },
    handV  = { size = 0.20, stun = 0.25, stunMax = 1.0,
               text = { { "size", "pct" }, { "stun", "sec", "stunMax" } } },
    handX2 = { charges = 1, hasteSeconds = 2,
               text = { { "charges", "count" }, { "hasteSeconds", "sec" } } },
    handX4 = { charges = 1, radius = 0.20,
               text = { { "charges", "count" }, { "radius", "pct" } } },
    handV2 = { hits = 1, size = 0.15,
               text = { { "hits", "count" }, { "size", "pct" } } },
}

U.register({ "handZ" }, T.handZ)
U.register({ "handX" }, T.handX)
U.register({ "handC" }, T.handC)
U.register({ "handV", "handVBoosted" }, T.handV)
U.register({ "handX2" }, T.handX2)
U.register({ "handX4" }, T.handX4)
U.register({ "handV2", "handV2Boosted" }, T.handV2)

local Z  = U.ids("handZ")
local X  = U.ids("handX")
local C  = U.ids("handC")
local V  = U.ids("handV", "handVBoosted")
local X2 = U.ids("handX2")
local X4 = U.ids("handX4")
local V2 = U.ids("handV2", "handV2Boosted")

local STATE_Z    = H.state("handZ")
local STATE_V2   = H.state("handV2Fire")
local STATE_V2B  = H.state("handV2FireBoosted")

local BABY = constant("oHANDBaby")

constant("survivor_hand_skill_id_to_drone_type")

local overclock   = buff("overclock")
local drone_haste = buff("handDroneSpeed")

local HEAL, HASTE = 0, 1

local function box_is(args, xs, ys)
    return args[8].value == xs and args[9].value == ys
end

local RETURNING = 3

local REASSEMBLY = 4

H.on_explosion(function(actor, args, source)
    if source then
        if source.object_index ~= BABY then return end
        local rank = U.rank_for(actor, X4)
        if rank > 0 then H.scale_blast(args, 1 + T.handX4.radius * rank) end
        return
    end

    if H.in_state(actor, STATE_Z) then
        if not box_is(args, 1.3, 3) then return end
        local rank = U.rank_for(actor, Z)
        if rank > 0 then H.scale_blast(args, 1 + T.handZ.size * rank) end
        return
    end

    if H.in_state(actor, STATE_V2) or H.in_state(actor, STATE_V2B) then
        if not box_is(args, 1.5, 4) then return end
        local rank = U.rank_for(actor, V2)
        if rank > 0 then H.scale_blast(args, 1 + T.handV2.size * rank) end
        return
    end

    if tonumber(actor.activity) == REASSEMBLY and box_is(args, 3, 6) then
        local rank = U.rank_for(actor, V)
        if rank < 1 then return end
        H.scale_blast(args, 1 + T.handV.size * rank)
        return "reassembly"
    end
end)

local pending_stun = {}

H.after_explosion(function(actor, attack, args, source, tag)
    if tag ~= "reassembly" then return end
    local list = pending_stun[actor.id]
    if not list then
        list = {}
        pending_stun[actor.id] = list
    end
    list[#list + 1] = attack
end)

H.on_activity(function(actor, prev)
    local list = pending_stun[actor.id]
    if not list then return end
    pending_stun[actor.id] = nil

    local rank = U.rank_for(actor, V)
    local seconds = math.min(T.handV.stun * rank, T.handV.stunMax)
    local extra = seconds * FPS / STUN_FRAMES
    for _, attack in ipairs(list) do
        attack.stun = (tonumber(attack.stun) or 0) + extra
    end
end)

local STEAM_1 = 256

Callback.add(Callback.ON_ATTACK_HIT, function(hit_info)
    if not Net.host then return end
    local attack = hit_info.attack_info
    local flags = math.floor(tonumber(attack.attack_flags) or 0)
    if flags & STEAM_1 == 0 then return end
    local parent = attack.parent
    if not Instance.exists(parent) or parent.object_index ~= OP then return end

    local rank = U.rank_for(parent, Z)
    if rank < 1 or math.random() >= T.handZ.droneChance * rank then return end
    local drone_type = tonumber(GM.survivor_hand_skill_id_to_drone_type(parent:get_active_skill(1).skill_id)) or -1
    if drone_type < 0 then return end

    local drone = GM.instance_create(hit_info.x, hit_info.y, BABY)
    drone.parent = parent.id
    drone.team = parent.team
    drone.set_type(drone_type)
end)

local DRONE_SKILLS = { { X, T.handX }, { X2, T.handX2 }, { X4, T.handX4 } }

RecalculateStats.add(function(actor, api)
    if actor.object_index ~= OP then return end
    for _, entry in ipairs(DRONE_SKILLS) do
        local rank = U.rank_for(actor, entry[1])
        if rank > 0 then
            api.skill_secondary.max_stock_add(entry[2].charges * rank)
            return
        end
    end
end)

local HEAL_FRACTION = 0.08
local HASTE_FRAMES  = 600

H.watch_destroy("oHANDBaby", function(drone)
    if not Net.host or tonumber(drone.state) ~= RETURNING then return end
    local parent = drone.parent
    if not Instance.exists(parent) or parent.object_index ~= OP or S.bool(parent.dead) then return end
    if not drone:is_colliding(parent) then return end

    local drone_type = tonumber(drone.drone_type)
    if drone_type == HEAL then
        local rank = U.rank_for(parent, X)
        if rank < 1 then return end
        GM.actor_heal_networked(parent, math.ceil(parent.maxhp * HEAL_FRACTION * T.handX.healBonus * rank), false)
    elseif drone_type == HASTE then
        local rank = U.rank_for(parent, X2)
        if rank < 1 then return end
        local want = HASTE_FRAMES + math.floor(T.handX2.hasteSeconds * FPS * rank)
        if parent:buff_get_time(drone_haste) < want then parent:buff_set_time(drone_haste, want) end
    end
end)

local OVERCLOCK_FRAMES = 200

Callback.add(Skill.find("handC", "ror").on_activate, function(actor, skill, slot)
    if not Net.host or actor.object_index ~= OP then return end
    local rank = U.rank_for(actor, C)
    if rank < 1 then return end
    actor:buff_set_time(overclock, OVERCLOCK_FRAMES + math.floor(T.handC.overclockSeconds * FPS * rank))
end)

local OVERCLOCK_ID = overclock.value

local function keep_overclock(self, other, result, args)
    if math.floor(tonumber(args[2].value) or -1) ~= OVERCLOCK_ID then return end
    local actor = args[1].value
    if not Instance.exists(actor) or actor.object_index ~= OP or U.rank_for(actor, C) < 1 then return end
    local now = tonumber(GM.get_buff_time(actor, overclock)) or -1
    if (tonumber(args[3].value) or 0) < now then args[3].value = now end
end

Hook.add_pre(constant("set_buff_time"), keep_overclock)
Hook.add_pre(constant("set_buff_time_nosync"), keep_overclock)

RecalculateStats.add(function(actor, api)
    if actor.object_index ~= OP or not S.bool(GM.has_buff(actor, overclock)) then return end
    local rank = U.rank_for(actor, C)
    if rank > 0 then api.armor_add(T.handC.overclockArmor * rank) end
end)

for _, name in ipairs({ "handV2Fire", "handV2FireBoosted" }) do
    Callback.add(ActorState.find(name, "ror").on_enter, function(actor, data)
        if actor.object_index ~= OP then return end
        local rank = U.rank_for(actor, V2)
        if rank > 0 then data.rev = (tonumber(data.rev) or 0) + T.handV2.hits * rank end
    end)
end

Callback.add(Callback.ON_GAME_START, function()
    pending_stun = {}
end)

SPP.Hand = T
