-- Улучшения навыков Снайпера. Числа - в таблице T.

SPP = SPP or {}

local S = SPP.State
local U = SPP.Upgrades
local H = SPP.Hooks

local OP = gm.constants.oP
local FPS = 60

local STUN_FRAMES = 90

local T = {
    sniperZ  = { perfectTime = 0.25, damage = 0.10,
                 text = { { "perfectTime", "pct" } } },
    sniperX  = { aimSpeed = 0.15, pierceFalloff = 0.15,
                 text = { { "aimSpeed", "pct" }, { "pierceFalloff", "pct" } } },
    sniperC  = { flipAttackSpeed = 0.15, flipSeconds = 2, stock_every = 2,
                 text = { { "flipAttackSpeed", "pct", "flipSeconds", "sec" } } },
    sniperV  = { chainChance = 0.15, markDamage = 0.10,
                 text = { { "chainChance", "pct" }, { "markDamage", "pct" } } },
    sniperZ2 = { size = 0.20, stunChance = 0.10, stunSeconds = 0.5,
                 text = { { "size", "pct" }, { "stunChance", "pct", "stunSeconds", "sec" } } },
    sniperX2 = { reticleSize = 0.20, critChance = 0.10,
                 text = { { "reticleSize", "pct" }, { "critChance", "pct" } } },
    sniperC2 = { recoilInvuln = 0.2, recoilInvulnMax = 1.0, shotWidth = 0.20,
                 text = { { "recoilInvuln", "sec", "recoilInvulnMax" }, { "shotWidth", "pct" } } },
}

U.register({ "sniperZ", "sniperZReload" }, T.sniperZ)
U.register({ "sniperX" }, T.sniperX)
U.register({ "sniperC" }, T.sniperC)
U.register({ "sniperV", "sniperVBoosted", "sniperVRecall" }, T.sniperV)
U.register({ "sniperZ2" }, T.sniperZ2)
U.register({ "sniperX2" }, T.sniperX2)
U.register({ "sniperC2" }, T.sniperC2)

local X  = U.ids("sniperX")
local C  = U.ids("sniperC")
local Z2 = U.ids("sniperZ2")
local X2 = U.ids("sniperX2")
local C2 = U.ids("sniperC2")

local Z_ID = Skill.find("sniperZ", "ror").value
local V_ID = Skill.find("sniperV", "ror").value

local STATE_XFIRE    = H.state("sniperXFire")
local STATE_Z2_FAR   = H.state("sniperZ2Far")
local STATE_Z2_CLOSE = H.state("sniperZ2Close")
local STATE_X2_HOLD  = H.state("sniperX2Hold")
local STATE_C2       = H.state("sniperC2")

local function constant(name)
    local value = gm.constants[name]
    if value == nil then error("vanilla asset "..name.." not found") end
    return value
end

local ENEMY      = constant("pEnemy")
local SPARKS_AIM = constant("sSparks8s")
local SPARKS_C2  = constant("sSparks21r")

local function slot_rank(actor, slot, id)
    if actor:get_default_skill(slot).skill_id ~= id then return 0 end
    return S.rank(actor, slot)
end

local function box_is(args, xs, ys)
    return args[8].value == xs and args[9].value == ys
end

local PERFECT_LO, PERFECT_HI, MARKER_STEP = 18, 26, 2
local PERFECT_FRAMES = (PERFECT_HI - PERFECT_LO) / MARKER_STEP + 1

H.watch_event("oSniperBar", "Step_2", function(bar)
    if tonumber(bar.moving) ~= 1 then return end
    local player = bar.parent
    if not Instance.exists(player) or player.object_index ~= OP then return end
    local rank = slot_rank(player, 0, Z_ID)
    if rank < 1 then return end

    local dir = tonumber(bar.pos_direction) or 1
    local from = (tonumber(bar.position) or 0) - MARKER_STEP * dir
    if from < PERFECT_LO or from > PERFECT_HI then return end

    local frames = PERFECT_FRAMES * (1 + T.sniperZ.perfectTime * rank)
    local to = from + dir * (PERFECT_HI - PERFECT_LO) / (frames - 1)
    if to > PERFECT_HI then
        to = PERFECT_HI + MARKER_STEP
    elseif to < PERFECT_LO then
        to = PERFECT_LO - MARKER_STEP
    end
    bar.position = to
end)

local CHARGE_FULL = 150

Callback.add(ActorState.find("sniperXCharge", "ror").on_step, function(actor, data)
    if actor.object_index ~= OP or S.bool(data.release) then return end
    local rank = U.rank_for(actor, X)
    if rank < 1 then return end

    local extra = T.sniperX.aimSpeed * rank
    data.charge = math.min(CHARGE_FULL, (tonumber(data.charge) or 0) + actor.attack_speed * extra)
    local bar = data.charge_bar
    if Instance.exists(bar) then bar.rate = 1 + extra end
end)

local VANILLA_FALLOFF = 0.5
local aimed = {}

H.after_bullet(function(actor, attack, args)
    if not H.in_state(actor, STATE_XFIRE) then return end
    if args[6].value ~= 4000 or args[7].value ~= SPARKS_AIM then return end
    if U.rank_for(actor, X) < 1 then return end
    local list = aimed[actor.id]
    if not list then
        list = {}
        aimed[actor.id] = list
    end
    list[#list + 1] = attack
end)

Callback.add(ActorState.find("sniperXFire", "ror").on_step, function(actor, data)
    local list = aimed[actor.id]
    if not list then return end
    aimed[actor.id] = nil
    local falloff = VANILLA_FALLOFF * math.max(0, 1 - T.sniperX.pierceFalloff * U.rank_for(actor, X))
    for _, attack in ipairs(list) do attack.damage_degrade = falloff end
end)

local flip_haste = SPP.Stats.timer()

Callback.add(ActorState.find("sniperCbackwards", "ror").on_exit, function(actor, data)
    if actor.object_index ~= OP or U.rank_for(actor, C) < 1 then return end
    flip_haste.start(actor, T.sniperC.flipSeconds * FPS)
end)

RecalculateStats.add(function(actor, api)
    if actor.object_index ~= OP or not flip_haste.active(actor) then return end
    local rank = U.rank_for(actor, C)
    if rank > 0 then api.attack_speed_add(T.sniperC.flipAttackSpeed * rank) end
end)

local REACH = 960
local mark_of = {}

local function enemy_in_reach(player)
    local px, py = player.x, player.y
    for _, enemy in ipairs(Instance.find_all(ENEMY)) do
        if Instance.exists(enemy) and S.bool(GM.actor_canhit(player, enemy)) then
            local dx, dy = enemy.x - px, enemy.y - py
            if dx * dx + dy * dy < REACH * REACH then return true end
        end
    end
    return false
end

H.watch_event("oSniperDrone", "Step_2", function(drone)
    local player = drone.master
    if not Instance.exists(player) or player.object_index ~= OP then return end
    local id = player.id

    local target = drone.tt
    if Instance.exists(target) then
        mark_of[id] = Instance.wrap(target).id
        return
    end

    local lost = mark_of[id]
    mark_of[id] = nil
    if not lost or Instance.exists(lost) then return end

    if not S.bool(player.local_client_is_authority) or S.bool(player.dead) then return end
    local rank = slot_rank(player, 3, V_ID)
    if rank < 1 or math.random() >= T.sniperV.chainChance * rank then return end
    if not enemy_in_reach(player) then return end

    GM.SO._survivor_sniper_v_skill(player, player, player)

    local marked = drone.tt
    if Instance.exists(marked) then
        mark_of[id] = Instance.wrap(marked).id
    else
        local spotter = player:get_active_skill(3)
        spotter:override_cooldown(spotter.cooldown)
    end
end)

DamageCalculate.add(function(api)
    if next(mark_of) == nil then return end
    local parent = api.parent
    if not Instance.exists(parent) or parent.object_index ~= OP then return end
    local target = mark_of[parent.id]
    if not target then return end
    local hit = api.hit
    if not Instance.exists(hit) or hit.id ~= target then return end

    local rank = slot_rank(parent, 3, V_ID)
    if rank > 0 then api.damage_mult(1 + T.sniperV.markDamage * rank) end
end)

H.on_explosion(function(actor, args, source)
    if source then return end

    if (H.in_state(actor, STATE_Z2_FAR) and box_is(args, 1.5, 3))
    or (H.in_state(actor, STATE_Z2_CLOSE) and box_is(args, 1.25, 3)) then
        local rank = U.rank_for(actor, Z2)
        if rank < 1 then return end
        H.scale_blast(args, 1 + T.sniperZ2.size * rank)
        return "improvise"
    end

    if H.in_state(actor, STATE_X2_HOLD) and box_is(args, 1, 4) then
        local rank = U.rank_for(actor, X2)
        if rank < 1 then return end
        H.scale_blast(args, 1 + T.sniperX2.reticleSize * rank)
        return "quickscope"
    end

    if H.in_state(actor, STATE_C2) and args[9].value == 1.5 and args[5].value == SPARKS_C2 then
        local rank = U.rank_for(actor, C2)
        if rank > 0 then args[9].value = args[9].value * (1 + T.sniperC2.shotWidth * rank) end
    end
end)

local IMPROVISE_STUN = T.sniperZ2.stunSeconds * FPS / STUN_FRAMES

H.after_explosion(function(actor, attack, args, source, tag)
    if tag == "improvise" then
        if math.random() < T.sniperZ2.stunChance * U.rank_for(actor, Z2) then
            attack.stun = math.max(tonumber(attack.stun) or 0, IMPROVISE_STUN)
        end
    elseif tag == "quickscope" then
        if math.random() < T.sniperX2.critChance * U.rank_for(actor, X2) then
            AttackInfo.wrap(attack):set_critical(true)
        end
    end
end)

Callback.add(ActorState.find("sniperX2Hold", "ror").on_enter, function(actor, data)
    if actor.object_index ~= OP then return end
    local rank = U.rank_for(actor, X2)
    if rank < 1 then return end
    local reticle = data.reticle
    if not Instance.exists(reticle) then return end
    local mult = 1 + T.sniperX2.reticleSize * rank
    reticle.image_xscale = reticle.image_xscale * mult
    reticle.image_yscale = reticle.image_yscale * mult
end)

local recoil_done = {}
local recoil = ActorState.find("sniperC2", "ror")

Callback.add(recoil.on_enter, function(actor, data)
    recoil_done[actor.id] = false
end)

Callback.add(recoil.on_step, function(actor, data)
    if recoil_done[actor.id] or not S.bool(data.fired) then return end
    recoil_done[actor.id] = true
    if actor.object_index ~= OP then return end
    local rank = U.rank_for(actor, C2)
    if rank < 1 then return end
    local seconds = math.min(T.sniperC2.recoilInvuln * rank, T.sniperC2.recoilInvulnMax)
    actor.invincible = math.max(tonumber(actor.invincible) or 0, math.floor(seconds * FPS))
end)

Callback.add(Callback.ON_STAGE_START, function()
    mark_of = {}
end)

Callback.add(Callback.ON_GAME_START, function()
    mark_of = {}
    aimed = {}
    recoil_done = {}
end)

SPP.Sniper = T
