-- Улучшения навыков Шахтёра. Числа - в таблице T.

SPP = SPP or {}

local S = SPP.State
local U = SPP.Upgrades
local H = SPP.Hooks

local OP = gm.constants.oP

local T = {
    minerZ  = { size = 0.15, crushHeat = 0.20,
                text = { { "size", "pct" }, { "crushHeat", "pct" } } },
    minerX  = { drillHeat = 0.15, drillReach = 0.20,
                text = { { "drillHeat", "pct" }, { "drillReach", "pct" } } },
    minerC  = { backblastHeat = 5, stock_every = 2,
                text = { { "backblastHeat", "count" } } },
    minerV  = { starBlasts = 1, blastSize = 0.15,
                text = { { "starBlasts", "count" }, { "blastSize", "pct" } } },
    minerZ2 = { pickaxeEvery = 2, pickaxeSize = 0.20,
                text = { { "pickaxeEvery", "every" }, { "pickaxeSize", "pct" } } },
    minerX2 = { size = 0.20, drillSpeed = 0.15,
                text = { { "size", "pct" }, { "drillSpeed", "pct" } } },
    minerC2 = { radius = 0.20, burnoutHeal = 0.15,
                text = { { "radius", "pct" }, { "burnoutHeal", "pct" } } },
}

U.register({ "minerZ" }, T.minerZ)
U.register({ "minerX" }, T.minerX)
U.register({ "minerC" }, T.minerC)
U.register({ "minerV", "minerVBoosted" }, T.minerV)
U.register({ "minerZ2" }, T.minerZ2)
U.register({ "minerX2" }, T.minerX2)
U.register({ "minerC2" }, T.minerC2)

local Z  = U.ids("minerZ")
local X  = U.ids("minerX")
local C  = U.ids("minerC")
local V  = U.ids("minerV", "minerVBoosted")
local Z2 = U.ids("minerZ2")
local X2 = U.ids("minerX2")
local C2 = U.ids("minerC2")

local Z2_ID = Skill.find("minerZ2", "ror").value
local VB_ID = Skill.find("minerVBoosted", "ror").value

local STATE_Z        = H.state("minerZ")
local STATE_X_FIRE   = H.state("minerXFire")
local STATE_X2_DRILL = H.state("minerX2drill")
local STATE_C2       = H.state("minerC2")

local function constant(name)
    local value = gm.constants[name]
    if value == nil then error("vanilla asset "..name.." not found") end
    return value
end

local HEAT_ADD   = constant("_survivor_miner_heat_add")
constant("_survivor_miner_heat_sync")
local HEAT_BAR   = constant("oMinerBar")
local PICK       = constant("oMinerPick")
local SPARKS_V   = constant("sSparks1")
local STARS      = constant("sMinerExplosion")
local STARS_SCEPTER = constant("sMinerExplosion2")

local shadow_clone = Buff.find("shadowClone", "ror")
if not shadow_clone then error("vanilla buff ror-shadowClone not found") end

local function box_is(args, xs, ys)
    return args[8].value == xs and args[9].value == ys
end

local HEAT_ON_HIT  = 5
local DRILL_DRAIN  = -1.1

Hook.add_pre(HEAT_ADD, function(self, other, result, args)
    local actor = args[1].value
    if not Instance.exists(actor) or actor.object_index ~= OP then return end
    local amount = args[2].value

    if amount == HEAT_ON_HIT then
        local rank = U.rank_for(actor, Z)
        if rank > 0 then args[2].value = amount * (1 + T.minerZ.crushHeat * rank) end
        return
    end

    if math.abs(amount - DRILL_DRAIN) < 1e-6 and H.in_state(actor, STATE_X_FIRE) then
        local rank = U.rank_for(actor, X)
        if rank > 0 then args[2].value = amount * (1 - T.minerX.drillHeat) ^ rank end
    end
end)

local DRILL_RANGE = 160

H.on_bullet(function(actor, args)
    if not H.in_state(actor, STATE_X_FIRE) or args[6].value ~= DRILL_RANGE then return end
    local rank = U.rank_for(actor, X)
    if rank > 0 then args[6].value = args[6].value * (1 + T.minerX.drillReach * rank) end
end)

local firing_stars = false

H.on_explosion(function(actor, args, source)
    if source then return end

    if H.in_state(actor, STATE_Z) and box_is(args, 1, 3) then
        local rank = U.rank_for(actor, Z)
        if rank > 0 then H.scale_blast(args, 1 + T.minerZ.size * rank) end
        return
    end

    if H.in_state(actor, STATE_X2_DRILL) and box_is(args, 1.5, 4) then
        local rank = U.rank_for(actor, X2)
        if rank > 0 then H.scale_blast(args, 1 + T.minerX2.size * rank) end
        return
    end

    if H.in_state(actor, STATE_C2) and box_is(args, 2, 3) then
        local rank = U.rank_for(actor, C2)
        if rank > 0 then H.scale_blast(args, 1 + T.minerC2.radius * rank) end
        return
    end

    if firing_stars then return end
    local sprite = args[7].value
    if sprite ~= STARS and sprite ~= STARS_SCEPTER then return end
    local rank = U.rank_for(actor, V)
    if rank < 1 then return end
    H.scale_blast(args, 1 + T.minerV.blastSize * rank)
    return "stars"
end)

local STAR_SPACING  = 40
local STAR_AHEAD    = 24
local SCEPTER_STUN  = 0.5
local star_casts = {}

H.after_explosion(function(actor, attack, args, source, tag)
    if tag ~= "stars" then return end
    star_casts[actor.id] = {
        x      = actor.x,
        y      = actor.y,
        xs     = actor.image_xscale < 0 and -1 or 1,
        damage = args[4].value,
        sprite = args[7].value,
    }
end)

local function fire_stars(actor, cast)
    local rank = U.rank_for(actor, V)
    local extra = T.minerV.starBlasts * rank
    if extra < 1 then return end

    local boosted = actor:get_active_skill(3).skill_id == VB_ID
    local reach = (actor:buff_count(shadow_clone) + 1) * (boosted and 2 or 1)
    local mult = 1 + T.minerV.blastSize * rank

    firing_stars = true
    local ok, err = pcall(function()
        for k = 1, extra do
            local i = (reach + math.ceil(k / 2)) * (k % 2 == 1 and cast.xs or -cast.xs)
            local attack = GM.SO.fire_explosion(actor, actor, 0,
                cast.x + STAR_AHEAD * cast.xs + i * STAR_SPACING, cast.y,
                cast.damage, SPARKS_V, 2, cast.sprite, mult, mult)
            local blast = Global.attack_bullet
            blast:move_contact_solid(270, -1)
            attack.y = blast.y
            if boosted then attack.stun = SCEPTER_STUN end
        end
    end)
    firing_stars = false
    if not ok then error(err, 0) end
end

H.on_activity(function(actor, prev)
    local cast = star_casts[actor.id]
    if not cast then return end
    star_casts[actor.id] = nil
    fire_stars(actor, cast)
end)

local backblast_done = {}

local function heat_bar(actor)
    for _, bar in ipairs(Instance.find_all(HEAT_BAR)) do
        local parent = bar.parent
        if Instance.exists(parent) and parent.id == actor.id then return bar end
    end
    return nil
end

local backblast = ActorState.find("minerC", "ror")

Callback.add(backblast.on_enter, function(actor, data)
    backblast_done[actor.id] = false
end)

Callback.add(backblast.on_step, function(actor, data)
    if backblast_done[actor.id] or tonumber(actor.activity_var1) ~= 1 then return end
    backblast_done[actor.id] = true
    if actor.object_index ~= OP or not S.bool(actor.local_client_is_authority) then return end
    local rank = U.rank_for(actor, C)
    if rank < 1 then return end

    local bar = heat_bar(actor)
    if not bar then return end
    local before = bar.charge
    bar.charge = math.min(before + T.minerC.backblastHeat * rank, bar.chargeMax)
    if bar.charge > before then bar.offsetType = 2.9 end
    GM._survivor_miner_heat_sync(actor)
end)

local PICK_SPREAD = 8
local PICK_SPEED  = 6
local pick_done = {}

local throw = ActorState.find("minerZ2", "ror")

Callback.add(throw.on_enter, function(actor, data)
    pick_done[actor.id] = false
end)

Callback.add(throw.on_step, function(actor, data)
    if pick_done[actor.id] or tonumber(actor.activity_var1) ~= 1 then return end
    pick_done[actor.id] = true
    if actor.object_index ~= OP then return end
    local extra = math.floor(U.rank_for(actor, Z2) / T.minerZ2.pickaxeEvery)
    if extra < 1 then return end

    local xs = actor.image_xscale
    local damage = GM.SO.skill_get_damage(actor, actor, Z2_ID)
    local burning = S.bool(data.cN) and 1 or 0
    local face = S.bool(actor.charged) and 1 or 0
    local base = 90 - 40 * xs
    for k = 1, extra do
        local direction = base - PICK_SPREAD * ((k - 1) % 4 + 1) * xs
        for i = 0, actor:buff_count(shadow_clone) do
            local pick = GM.instance_create(actor.x, actor.y - 20 * i, PICK)
            pick.direction = direction
            pick.parent = actor
            pick.team = actor.team
            pick.burning = burning
            pick.damage_coeff = damage
            pick.image_index = face
            pick.image_xscale = xs
            pick.image_yscale = xs
            pick.speed = PICK_SPEED
            pick.hspeed = pick.hspeed + actor.pHspeed
            pick.vspeed = pick.vspeed + actor.pVspeed
            pick:actor_skin_skinnable_set_skin(actor)
        end
    end
end)

H.on_first_step("oMinerPick", function(pick)
    if S.bool(pick.is_proc) then return end
    local parent = pick.parent
    if not Instance.exists(parent) or parent.object_index ~= OP then return end
    local rank = U.rank_for(parent, Z2)
    if rank < 1 then return end
    local mult = 1 + T.minerZ2.pickaxeSize * rank
    pick.image_xscale = pick.image_xscale * mult
    pick.image_yscale = pick.image_yscale * mult
end)

local burnout_done = {}
local burnout = ActorState.find("minerC2", "ror")

Callback.add(burnout.on_enter, function(actor, data)
    burnout_done[actor.id] = false
end)

Callback.add(burnout.on_step, function(actor, data)
    if burnout_done[actor.id] or tonumber(actor.activity_var1) ~= 1 then return end
    burnout_done[actor.id] = true
    if not Net.host or actor.object_index ~= OP then return end
    local rank = U.rank_for(actor, C2)
    if rank < 1 then return end
    GM.actor_heal_networked(actor, actor.maxhp * T.minerC2.burnoutHeal * rank, false)
end)

Callback.add(ActorState.find("minerX2drill", "ror").on_step, function(actor, data)
    if actor.object_index ~= OP or not H.in_state(actor, STATE_X2_DRILL) then return end
    if tonumber(actor.activity_var2) ~= 0 then return end
    local rank = U.rank_for(actor, X2)
    if rank < 1 then return end
    actor.image_speed = math.min(1, actor.image_speed * (1 + T.minerX2.drillSpeed * rank))
end)

local function reset()
    star_casts = {}
    backblast_done = {}
    pick_done = {}
    burnout_done = {}
end

Callback.add(Callback.ON_GAME_START, reset)
Callback.add(Callback.ON_STAGE_START, reset)

SPP.Miner = T
