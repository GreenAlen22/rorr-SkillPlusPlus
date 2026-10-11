-- Улучшения навыков Бродяги. Числа - в таблице T.

SPP = SPP or {}

local S = SPP.State
local U = SPP.Upgrades
local H = SPP.Hooks

local OP = gm.constants.oP

local function constant(name)
    local value = gm.constants[name]
    if value == nil then error("vanilla constant "..name.." not found") end
    return value
end

local T = {
    drifterZ  = { size = 0.15, scrapChance = 0.10,
                  text = { { "size", "pct" }, { "scrapChance", "pct" } } },
    drifterX  = { projectiles = 1, specialChance = 0.10,
                  text = { { "projectiles", "count" }, { "specialChance", "pct" } } },
    drifterC  = { consumeScrap = 1, stock_every = 2,
                  text = { { "consumeScrap", "count" } } },
    drifterV  = { itemEvery = 2, rarityChance = 0.10,
                  text = { { "itemEvery", "every" }, { "rarityChance", "pct" } } },
    drifterX2 = { pushSpeed = 0.15, cubeBlast = 0.20,
                  text = { { "pushSpeed", "pct" }, { "cubeBlast", "pct" } } },
    drifterC2 = { spinArmor = 15, stock_every = 2,
                  text = { { "spinArmor", "count" } } },
    drifterV2 = { rarityChance = 0.15, copyChance = 0.15,
                  text = { { "rarityChance", "pct" }, { "copyChance", "pct" } } },
}

U.register({ "drifterZ" }, T.drifterZ)
U.register({ "drifterX" }, T.drifterX)
U.register({ "drifterC" }, T.drifterC)
U.register({ "drifterV", "drifterVBoosted" }, T.drifterV)
U.register({ "drifterX2" }, T.drifterX2)
U.register({ "drifterC2" }, T.drifterC2)
U.register({ "drifterV2", "drifterV2Boosted" }, T.drifterV2)

local Z  = U.ids("drifterZ")
local X  = U.ids("drifterX")
local C  = U.ids("drifterC")
local V  = U.ids("drifterV", "drifterVBoosted")
local X2 = U.ids("drifterX2")
local C2 = U.ids("drifterC2")
local V2 = U.ids("drifterV2", "drifterV2Boosted")

local STATE_Z        = H.state("drifterZ")
local STATE_C2       = H.state("drifterC2")
local STATE_V2_FIRE  = H.state("drifterV2Fire")
local STATE_V2B_FIRE = H.state("drifterV2BoostedFire")

local shadow_clone = Buff.find("shadowClone", "ror")
if not shadow_clone then error("vanilla buff ror-shadowClone not found") end

H.on_explosion(function(actor, args, source)
    if source or not H.in_state(actor, STATE_Z) then return end
    if args[8].value ~= 1.5 or args[9].value ~= 2 then return end
    local rank = U.rank_for(actor, Z)
    if rank > 0 then H.scale_blast(args, 1 + T.drifterZ.size * rank) end
end)

local SCRAP_BITS  = 1024 | 2048
local SPIN_SPARKS = constant("sSparks14")
local SCRAP       = constant("oDrifterRec")

Callback.add(Callback.ON_ATTACK_HIT, function(hit_info)
    if not Net.host then return end
    local attack = hit_info.attack_info
    local flags = math.floor(tonumber(attack.attack_flags) or 0)
    if flags & SCRAP_BITS == 0 or tonumber(attack.hit_effect) == SPIN_SPARKS then return end
    local parent = attack.parent
    if not Instance.exists(parent) or parent.object_index ~= OP then return end

    local rank = U.rank_for(parent, Z)
    if rank < 1 or math.random() >= T.drifterZ.scrapChance * rank then return end
    local scrap = GM.instance_create(hit_info.x, hit_info.y - 5, SCRAP)
    scrap.direction = 90 + math.random() * 90 - 45
end)

local CLEANUP = 2
local JUNK = constant("oDrifterJunk")
local SPECIAL_FIRST = 5

local function make_special(junk)
    local last = math.floor(tonumber(junk.image_number) or 0) - 1
    junk.image_index = math.random(SPECIAL_FIRST, math.max(SPECIAL_FIRST, last))
end

H.on_activity(function(actor, prev)
    if not Net.host then return end
    if tonumber(actor.activity) ~= CLEANUP or prev.var1 ~= 0 or tonumber(actor.activity_var1) ~= 1 then return end
    local rank = U.rank_for(actor, X)
    if rank < 1 then return end

    local xs = actor.image_xscale
    local damage = actor:get_active_skill(1).damage
    for i = 0, actor:buff_count(shadow_clone) do
        for _ = 1, T.drifterX.projectiles * rank do
            local junk = GM.instance_create(actor.x, actor.y + 18 * i, JUNK)
            junk.damage_coeff = damage
            junk.direction = 90 - (math.random() * 60 + 35) * xs
            junk.speed = 4 + math.random() * 3
            junk.parent = actor
            junk.team = actor.team
            junk.image_index = math.random(0, 4)
            if math.random() * 100 < actor.critical_chance then make_special(junk) end
        end
    end

    local chance = T.drifterX.specialChance * rank
    for _, junk in ipairs(Instance.find_all(JUNK)) do
        local parent = junk.parent
        if Instance.exists(parent) and parent.id == actor.id and not S.bool(junk.init)
                and junk.image_index < SPECIAL_FIRST and math.random() < chance then
            make_special(junk)
        end
    end
end)

local CONSUME_SCRAP = 4

Hook.add_pre(constant("_survivor_drifter_scrap_add"), function(self, other, result, args)
    if args[2].value ~= CONSUME_SCRAP then return end
    local actor = Instance.wrap(args[1].value)
    if not Instance.exists(actor) or actor.object_index ~= OP then return end
    local rank = U.rank_for(actor, C)
    if rank > 0 then args[2].value = CONSUME_SCRAP + T.drifterC.consumeScrap * rank end
end)

local SALVAGE = 4
local SALVAGE_LOOP = {
    [Skill.find("drifterV", "ror").value]        = { last = 4, rewind_to = 1, var1 = 1 },
    [Skill.find("drifterVBoosted", "ror").value] = { last = 3, rewind_to = 4, var1 = 2 },
}

H.on_activity(function(actor, prev)
    if tonumber(actor.activity) ~= SALVAGE then return end
    local loop = SALVAGE_LOOP[actor:get_active_skill(3).skill_id]
    if not loop then return end

    local var2 = tonumber(actor.activity_var2) or 0
    if var2 < loop.last then return end
    local extra = math.floor(U.rank_for(actor, V) / T.drifterV.itemEvery)
    if var2 >= loop.last + extra then return end

    local n = actor.image_number
    local index = actor.image_index
    if index < n - 2 or index >= n - 1 then return end
    actor.image_index = loop.rewind_to
    actor.activity_var1 = loop.var1
end)

local NEXT_POOL = { [0] = 1, [1] = 2 }

local function raise_rarity(pool)
    local next_pool = NEXT_POOL[math.floor(tonumber(pool) or -1)]
    if not next_pool then return nil end
    local pickup = GM.treasure_loot_pool_roll(next_pool)
    if (tonumber(pickup) or -1) < 0 then return nil end
    return pickup
end

Hook.add_post(constant("_survivor_drifter_roll_item"), function(self, other, result, args)
    if not Net.host or not self or self.object_index ~= OP then return end
    local rank = U.rank_for(self, V)
    if rank < 1 or math.random() >= T.drifterV.rarityChance * rank then return end
    local better = raise_rarity(GM.pickup_object_to_tier(result.value))
    if better then result.value = better end
end)

local COPIES = { [STATE_V2_FIRE] = 0, [STATE_V2B_FIRE] = 1 }
local TEMPORARY = 1

Hook.add_post(constant("treasure_loot_pool_roll_with_blacklisted_pickup"), function(self, other, result, args)
    if not Net.host or not self or self.object_index ~= OP then return end
    local copies = COPIES[tonumber(self.actor_state_current_id)]
    if not copies then return end
    local rank = U.rank_for(self, V2)
    if rank < 1 then return end

    if math.random() < T.drifterV2.rarityChance * rank then
        local better = raise_rarity(args[1].value)
        if better then result.value = better end
    end

    local pickup = result.value
    if GM.object_to_item(pickup) < 0 or math.random() >= T.drifterV2.copyChance * rank then return end
    local xs = self.image_xscale
    local copy = GM.instance_create(self.x + (48 + (copies + 1) * 38) * xs, self.y, pickup)
    copy.item_stack_kind = TEMPORARY
    copy.xstart = self.x
    copy.ystart = self.y + 5
    copy.x = copy.xstart
    copy.y = copy.ystart
end)

Hook.add_pre(constant("_survivor_drifter_push_cube"), function(self, other, result, args)
    local actor = Instance.wrap(args[1].value)
    if not Instance.exists(actor) or actor.object_index ~= OP then return end
    local rank = U.rank_for(actor, X2)
    if rank > 0 then args[6].value = args[6].value * (1 + T.drifterX2.pushSpeed * rank) end
end)

local CUBE = constant("oDrifterCube")
H.watch_event("oDrifterCube", "Step_2")

H.on_explosion(function(actor, args, source)
    if not source or source.object_index ~= CUBE then return end
    local rank = U.rank_for(actor, X2)
    if rank > 0 then H.scale_blast(args, 1 + T.drifterX2.cubeBlast * rank) end
end)

RecalculateStats.add(function(actor, api)
    if actor.object_index ~= OP or not H.in_state(actor, STATE_C2) then return end
    local rank = U.rank_for(actor, C2)
    if rank > 0 then api.armor_add(T.drifterC2.spinArmor * rank) end
end)

SPP.Drifter = T
