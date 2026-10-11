-- Улучшения навыков ПОВАРА. Числа - в таблице T.

SPP = SPP or {}

local S = SPP.State
local U = SPP.Upgrades
local H = SPP.Hooks

local OP = gm.constants.oP
local FPS = 60
local NS = SPP.Config.namespace

local T = {
    chefZ  = { cleaverEvery = 2, cleaverSize = 0.20,
               text = { { "cleaverEvery", "every" }, { "cleaverSize", "pct" } } },
    chefX  = { igniteChance = 0.10, searSize = 0.20,
               text = { { "igniteChance", "pct" }, { "searSize", "pct" } } },
    chefC  = { glideInvuln = 0.1, glideInvulnMax = 0.5, stock_every = 2,
               text = { { "glideInvuln", "sec", "glideInvulnMax" } } },
    chefV  = { helpingEvery = 2, boostedDamage = 0.10,
               text = { { "helpingEvery", "every" }, { "boostedDamage", "pct" } } },
    chefZ2 = { size = 0.20, glazeChance = 0.10, glazeSeconds = 3,
               text = { { "size", "pct" }, { "glazeChance", "pct", "glazeSeconds", "sec" } } },
    chefC2 = { oilArmor = 15, stock_every = 2,
               text = { { "oilArmor", "count" } } },
    chefV2 = { hits = 1, mealChance = 0.10,
               text = { { "hits", "count" }, { "mealChance", "pct" } } },
}

U.register({ "chefZ" }, T.chefZ)
U.register({ "chefX" }, T.chefX)
U.register({ "chefC" }, T.chefC)
U.register({ "chefV", "chefVBoosted" }, T.chefV)
U.register({ "chefZ2" }, T.chefZ2)
U.register({ "chefC2" }, T.chefC2)
U.register({ "chefV2", "chefV2Boosted" }, T.chefV2)

local Z  = U.ids("chefZ")
local X  = U.ids("chefX")
local C  = U.ids("chefC")
local V  = U.ids("chefV", "chefVBoosted")
local Z2 = U.ids("chefZ2")
local C2 = U.ids("chefC2")
local V2 = U.ids("chefV2", "chefV2Boosted")

local STATE_Z2  = H.state("chefZ2")
local STATE_Z2E = H.state("chefZ2Empowered")

local oil = Buff.find("oil", "ror")
if not oil then error("vanilla buff ror-oil not found") end

local chef = Survivor.find("chef", "ror")
if not chef then error("vanilla survivor ror-chef not found") end
local CHEF_CLASS = chef.value

local IGNITE_FLAG = 4
local FOOD_FLAG   = 1048576

local GLAZE_FRAMES = 180

local SEAR  = 1.2
local RIDES = { 3.1, 3.2 }

local function is_activity(actor, value)
    return math.abs((tonumber(actor.activity) or 0) - value) < 0.01
end

local function box_is(args, xs, ys)
    return args[8].value == xs and args[9].value == ys
end

local KNIFE = gm.constants.oChefKnife

local FAN_DEGREES = 5

local function new_knives(actor)
    local list = {}
    for _, knife in ipairs(Instance.find_all(KNIFE)) do
        if knife.parent == actor then
            local data = Instance.get_data(knife, "chefKnife", NS)
            if not data.seen then
                data.seen = true
                list[#list + 1] = knife
            end
        end
    end
    return list
end

local function on_throw(actor, mince)
    local knives = new_knives(actor)
    if #knives == 0 then return end

    local rank_z = U.rank_for(actor, Z)
    local all = knives

    local extra = mince and 0 or math.floor(rank_z / T.chefZ.cleaverEvery)
    if extra > 0 then
        all = {}
        local side = (tonumber(actor.image_xscale) or 1) < 0 and -1 or 1
        local is_chef = tonumber(actor.class) == CHEF_CLASS
        for _, base in ipairs(knives) do
            all[#all + 1] = base
            for k = 1, extra do
                local knife = GM.instance_create(base.x, base.y, KNIFE)
                knife.direction = base.direction + k * FAN_DEGREES * side
                knife.damage_coeff = base.damage_coeff
                knife.parent = actor
                knife.team = actor.team
                if is_chef then actor.cleaver_count = actor.cleaver_count + 1 end
                Instance.get_data(knife, "chefKnife", NS).seen = true
                all[#all + 1] = knife
            end
        end
    end

    local size  = 1 + T.chefZ.cleaverSize * rank_z
    local boost = mince and 1 + T.chefV.boostedDamage * U.rank_for(actor, V) or 1
    if size == 1 and boost == 1 then return end
    for _, knife in ipairs(all) do
        knife.image_xscale = knife.image_xscale * size
        knife.image_yscale = knife.image_yscale * size
        knife.damage_coeff = knife.damage_coeff * boost
    end
end

local thrown = {}

for _, spec in ipairs({ { "chefZ", false }, { "chefZEmpowered", true } }) do
    local state, mince = ActorState.find(spec[1], "ror"), spec[2]

    Callback.add(state.on_enter, function(actor, data)
        thrown[actor.id] = false
    end)

    Callback.add(state.on_step, function(actor, data)
        if thrown[actor.id] or tonumber(actor.activity_var1) ~= 1 then return end
        thrown[actor.id] = true
        if actor.object_index ~= OP then return end
        on_throw(actor, mince)
    end)
end

local FLAMBE_SPRITE = gm.constants.sChefShoot2_2

local function boost_damage(actor, args)
    local rank = U.rank_for(actor, V)
    if rank > 0 then args[4].value = args[4].value * (1 + T.chefV.boostedDamage * rank) end
end

H.on_explosion(function(actor, args, source)
    if source then return end

    if is_activity(actor, SEAR) and box_is(args, 4, 3) then
        local rank = U.rank_for(actor, X)
        if rank > 0 then H.scale_blast(args, 1 + T.chefX.searSize * rank) end
        if actor.sprite_index == FLAMBE_SPRITE then boost_damage(actor, args) end
        return
    end

    local slice = H.in_state(actor, STATE_Z2) and box_is(args, 2.3, 4)
    local butcher = H.in_state(actor, STATE_Z2E) and box_is(args, 2, 4)
    if slice or butcher then
        local rank = U.rank_for(actor, Z2)
        if rank > 0 then H.scale_blast(args, 1 + T.chefZ2.size * rank) end
        if butcher then boost_damage(actor, args) end
    end
end)

Callback.add(Callback.ON_HIT_PROC, function(attacker, target, hit_info)
    if not Net.host then return end
    local flags = math.floor(tonumber(hit_info.attack_info.attack_flags) or 0)
    if flags & IGNITE_FLAG == 0 or attacker.object_index ~= OP then return end
    local rank = U.rank_for(attacker, X)
    if rank < 1 or S.bool(GM.has_buff(target, oil)) then return end
    if math.random() < T.chefX.igniteChance * rank then
        GM.apply_buff(target, oil, GLAZE_FRAMES, 1)
    end
end)

local SLICE_SPARKS = gm.constants.sSparks10
local GLAZE_SLICE_FRAMES = math.floor(T.chefZ2.glazeSeconds * FPS)

Callback.add(Callback.ON_ATTACK_HIT, function(hit_info)
    if not Net.host then return end
    local attack = hit_info.attack_info
    if attack.hit_effect ~= SLICE_SPARKS then return end
    local flags = math.floor(tonumber(attack.attack_flags) or 0)
    if flags & FOOD_FLAG ~= 0 then return end
    local parent = attack.parent
    if not Instance.exists(parent) or parent.object_index ~= OP then return end
    local rank = U.rank_for(parent, Z2)
    if rank < 1 then return end
    local target = hit_info.target
    if Instance.exists(target) and math.random() < T.chefZ2.glazeChance * rank then
        GM.apply_buff(target, oil, GLAZE_SLICE_FRAMES, 1)
    end
end)

Callback.add(Skill.find("chefC", "ror").on_activate, function(actor, skill, slot)
    if actor.object_index ~= OP then return end
    local rank = U.rank_for(actor, C)
    if rank < 1 then return end
    local seconds = math.min(T.chefC.glideInvuln * rank, T.chefC.glideInvulnMax)
    actor.invincible = math.max(tonumber(actor.invincible) or 0, math.floor(seconds * FPS + 0.5))
end)

for _, name in ipairs({ "chefV", "chefVBoosted" }) do
    Callback.add(Skill.find(name, "ror").on_activate, function(actor, skill, slot)
        if actor.object_index ~= OP then return end
        local extra = math.floor(U.rank_for(actor, V) / T.chefV.helpingEvery)
        if extra > 0 then actor.empower = (tonumber(actor.empower) or 0) + extra end
    end)
end

local was_oiled = {}

H.on_activity(function(actor, prev)
    if U.rank_for(actor, C2) < 1 then return end
    local oiled = S.bool(actor.oil_slide)
    if oiled ~= (was_oiled[actor.id] or false) then
        was_oiled[actor.id] = oiled
        actor:queue_recalculate_stats()
    end
end)

RecalculateStats.add(function(actor, api)
    if actor.object_index ~= OP or not S.bool(actor.oil_slide) then return end
    local rank = U.rank_for(actor, C2)
    if rank > 0 then api.armor_add(T.chefC2.oilArmor * rank) end
end)

local LAST_HIT_FRAME = 7
local HIT_FRAMES = 6
local cook_left = {}

for _, name in ipairs({ "chefV2", "chefV2Boosted" }) do
    local state = ActorState.find(name, "ror")

    Callback.add(state.on_enter, function(actor, data)
        if actor.object_index ~= OP then return end
        cook_left[actor.id] = T.chefV2.hits * U.rank_for(actor, V2)
    end)

    Callback.add(state.on_step, function(actor, data)
        local left = cook_left[actor.id] or 0
        if left < 1 or tonumber(actor.activity_var1) ~= LAST_HIT_FRAME then return end
        local n = math.min(left, HIT_FRAMES)
        cook_left[actor.id] = left - n
        actor.image_index = LAST_HIT_FRAME + 1 - n
        actor.activity_var1 = LAST_HIT_FRAME - n
    end)
end

Hook.add_pre("gml_Object_oChefPot_Step_2", function(self, other)
    if not Net.host then return end
    local count = math.floor(tonumber(self.itemSet) or 0)
    local data = Instance.get_data(self, "chefMeal", NS)
    local counted = data.counted or 0
    if count <= counted then return end

    local cook = self.parent
    local rank = 0
    if Instance.exists(cook) and cook.object_index == OP then rank = U.rank_for(cook, V2) end

    local extra = 0
    for _ = counted + 1, count do
        if math.random() < T.chefV2.mealChance * rank then extra = extra + 1 end
    end
    if extra > 0 then self.itemSet = count + extra end
    data.counted = count + extra
end)

Callback.add(Callback.ON_GAME_START, function()
    thrown = {}
    was_oiled = {}
    cook_left = {}
end)

SPP.Chef = T
