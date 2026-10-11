-- Улучшения навыков Инженера. Числа - в таблице T.

SPP = SPP or {}

local S = SPP.State
local U = SPP.Upgrades
local H = SPP.Hooks

local OP = gm.constants.oP

local T = {
    engineerZ  = { grenadeEvery = 2, radius = 0.15,
                   text = { { "grenadeEvery", "every" }, { "radius", "pct" } } },
    engineerX  = { radius = 0.20, mineEvery = 3,
                   text = { { "radius", "pct" }, { "mineEvery", "every" } } },
    engineerC  = { harpoonEvery = 2, stock_every = 2,
                   text = { { "harpoonEvery", "every" } } },
    engineerV  = { turretAttackSpeed = 0.15, stock_every = 2,
                   text = { { "turretAttackSpeed", "pct" } } },
    engineerZ2 = { radius = 0.20, shellEvery = 3,
                   text = { { "radius", "pct" }, { "shellEvery", "every" } } },
    engineerX2 = { mineTriggers = 1, radius = 0.20,
                   text = { { "mineTriggers", "count" }, { "radius", "pct" } } },
    engineerV2 = { turretChargeSpeed = 0.15, turretArmor = 20,
                   text = { { "turretChargeSpeed", "pct" }, { "turretArmor", "count" } } },
}

U.register({ "engineerZ" }, T.engineerZ)
U.register({ "engineerX" }, T.engineerX)
U.register({ "engineerC" }, T.engineerC)
U.register({ "engineerV", "engineerVBoosted" }, T.engineerV)
U.register({ "engineerZ2" }, T.engineerZ2)
U.register({ "engineerX2" }, T.engineerX2)
U.register({ "engineerV2", "engineerV2Boosted" }, T.engineerV2)

local Z  = U.ids("engineerZ")
local X  = U.ids("engineerX")
local C  = U.ids("engineerC")
local V  = U.ids("engineerV", "engineerVBoosted")
local Z2 = U.ids("engineerZ2")
local X2 = U.ids("engineerX2")
local V2 = U.ids("engineerV2", "engineerV2Boosted")

local Z_ID  = Skill.find("engineerZ", "ror").value
local C_ID  = Skill.find("engineerC", "ror").value
local Z2_ID = Skill.find("engineerZ2", "ror").value

local shadow_clone = Buff.find("shadowClone", "ror")
if not shadow_clone then error("vanilla buff ror-shadowClone not found") end

local function cracked(actor)
    return (tonumber(actor.z_count) or 0) == 0
end

local GRENADE = gm.constants.oEngiGrenade
local MORTAR  = gm.constants.oEngiMortar
local MINE    = gm.constants.oEngiMine
local MINE2   = gm.constants.oEngiMine2

H.watch_destroy("oEngiGrenade")
H.watch_destroy("oEngiMortar")
H.watch_event("oEngiMine", "Step_2")
H.watch_event("oEngiMine2", "Step_2")

local blast_of = {
    [GRENADE] = { ids = Z,  def = T.engineerZ },
    [MORTAR]  = { ids = Z2, def = T.engineerZ2 },
    [MINE]    = { ids = X,  def = T.engineerX },
    [MINE2]   = { ids = X2, def = T.engineerX2 },
}

H.on_explosion(function(actor, args, source)
    if not source then return end
    local blast = blast_of[source.object_index]
    if not blast then return end
    local rank = U.rank_for(actor, blast.ids)
    if rank > 0 then H.scale_blast(args, 1 + blast.def.radius * rank) end
end)

local ARCS = 5
local thrown = {}

local state_z = ActorState.find("engineerZ", "ror")

Callback.add(state_z.on_enter, function(actor, data)
    thrown[actor.id] = false
end)

Callback.add(state_z.on_step, function(actor, data)
    if thrown[actor.id] or tonumber(actor.activity_var1) ~= 1 then return end
    thrown[actor.id] = true
    if cracked(actor) then return end

    local extra = math.floor(U.rank_for(actor, Z) / T.engineerZ.grenadeEvery)
    if extra < 1 then return end

    local xs = actor.image_xscale
    local damage = GM.SO.skill_get_damage(actor, actor, Z_ID)
    for i = 0, actor:buff_count(shadow_clone) do
        for k = 1, extra do
            local t = (k - 1) % ARCS + 0.5
            local grenade = GM.instance_create(actor.x, actor.y - 6, GRENADE)
            grenade.damage_coeff = damage
            grenade.direction = 90 - (55 + t * 5 + i * 3) * xs
            grenade.speed = (2.5 + t + i) * 2
            grenade.parent = actor
            grenade.team = actor.team
            grenade:actor_skin_skinnable_set_skin(actor)
        end
    end
end)

local SHOT_FRAMES = { [2] = true, [6] = true }
local volley = {}

local state_z2 = ActorState.find("engineerZ2", "ror")

Callback.add(state_z2.on_enter, function(actor, data)
    volley[actor.id] = 0
end)

Callback.add(state_z2.on_step, function(actor, data)
    local var1 = tonumber(actor.activity_var1) or 0
    local fired = var1 ~= volley[actor.id] and SHOT_FRAMES[var1]
    volley[actor.id] = var1
    if not fired or not Net.host or cracked(actor) then return end

    local extra = math.floor(U.rank_for(actor, Z2) / T.engineerZ2.shellEvery)
    if extra < 1 then return end

    local xs = actor.image_xscale2
    local barrel = tonumber(actor.activity_var2) or 1
    local damage = GM.SO.skill_get_damage(actor, actor, Z2_ID)
    for i = 0, actor:buff_count(shadow_clone) do
        for k = 1, extra do
            local shell = GM.instance_create(actor.x + 16 * barrel * xs, actor.y - 16, MORTAR)
            shell.damage_coeff = damage
            shell.direction = (90 - 40 * xs) + 5 * i * xs - 5 * ((k - 1) % 4 + 1) * xs + math.random() * 10 - 5
            shell.image_angle = shell.direction
            shell.parent = actor
            shell.team = actor.team
            shell:actor_skin_skinnable_set_skin(actor)
        end
    end
end)

local VOLLEY = 4
local harpoons = {}

local state_c = ActorState.find("engineerC", "ror")

Callback.add(state_c.on_enter, function(actor, data)
    harpoons[actor.id] = 0
end)

Callback.add(state_c.on_step, function(actor, data)
    local shots = tonumber(actor.activity_var1) or 0
    local last = harpoons[actor.id] or 0
    harpoons[actor.id] = shots
    if shots <= last or not Net.host then return end

    local extra = math.floor(U.rank_for(actor, C) / T.engineerC.harpoonEvery)
    if extra < 1 then return end

    local xs = actor.image_xscale
    local damage = GM.SO.skill_get_damage(actor, actor, C_ID)
    local clones = actor:buff_count(shadow_clone)
    for shot = last + 1, shots do
        local count = extra >= shot and math.floor((extra - shot) / VOLLEY) + 1 or 0
        local side = ((shot - 1) % 2 == 0) and 1 or -1
        for _ = 0, clones do
            for _ = 1, count do
                local harpoon = GM.instance_create(actor.x - 2 * xs + 12 * xs * side, actor.y - 24, gm.constants.oEngiHarpoon)
                harpoon.damage_coeff = damage
                harpoon.parent = actor
                harpoon.team = actor.team
            end
        end
    end
end)

local MINE_SPACING = 12

Callback.add(Skill.find("engineerX", "ror").on_activate, function(actor, skill, slot)
    if not Net.host then return end
    local extra = math.floor(U.rank_for(actor, X) / T.engineerX.mineEvery)
    if extra < 1 then return end

    for k = 1, extra do
        local offset = MINE_SPACING * math.ceil(k / 2) * (k % 2 == 1 and 1 or -1)
        if actor:is_colliding(gm.constants.pBlock, actor.x + offset, actor.y) then offset = 0 end
        local mine = GM.instance_create(actor.x + offset, actor.y, MINE)
        mine.damage_coeff = skill.damage
        mine.parent = actor
        mine:actor_skin_skinnable_set_skin(actor)
    end
end)

local MINE2_LIFE, MINE2_TRIGGERS = 900, 3

H.on_first_step("oEngiMine2", function(mine)
    local parent = mine.parent
    if not Instance.exists(parent) or parent.object_index ~= OP then return end
    local extra = T.engineerX2.mineTriggers * U.rank_for(parent, X2)
    if extra < 1 then return end

    mine.charge = mine.charge + extra
    if Net.host then
        local left = tonumber(mine:alarm_get(1)) or -1
        if left > 0 then mine:alarm_set(1, left + extra * MINE2_LIFE / MINE2_TRIGGERS) end
    end
end)

local TURRETS = {
    [gm.constants.oEngiTurret] = { ids = V, apply = function(api, rank)
        api.attack_speed_add(T.engineerV.turretAttackSpeed * rank)
    end },
    [gm.constants.oEngiTurretB] = { ids = V2, apply = function(api, rank)
        api.armor_add(T.engineerV2.turretArmor * rank)
    end },
}
local special_rank = {}

RecalculateStats.add(function(actor, api)
    local object = actor.object_index
    local turret = TURRETS[object]
    if turret then
        local parent = actor.parent
        if not Instance.exists(parent) or parent.object_index ~= OP then return end
        local rank = U.rank_for(parent, turret.ids)
        if rank > 0 then turret.apply(api, rank) end
    elseif object == OP then
        local rank = S.rank(actor, 3)
        if special_rank[actor.id] == rank then return end
        special_rank[actor.id] = rank
        for turret_object in pairs(TURRETS) do
            for _, standing in ipairs(Instance.find_all(turret_object)) do
                local parent = standing.parent
                if Instance.exists(parent) and parent.id == actor.id then standing:queue_recalculate_stats() end
            end
        end
    end
end)

Callback.add(Callback.ON_GAME_START, function()
    special_rank = {}
end)

H.on_first_step("oEngiTurretB", function(turret)
    local parent = turret.parent
    if not Instance.exists(parent) or parent.object_index ~= OP then return end
    local rank = U.rank_for(parent, V2)
    if rank > 0 then
        turret.charge_max = turret.charge_max / (1 + T.engineerV2.turretChargeSpeed * rank)
    end
end, "Step_0")

SPP.Engineer = T
