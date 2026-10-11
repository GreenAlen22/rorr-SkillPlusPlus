-- Улучшения навыков Защитника. Числа - в таблице T.

SPP = SPP or {}

local S = SPP.State
local U = SPP.Upgrades
local H = SPP.Hooks

local OP = gm.constants.oP

local STUN_FRAMES = 90

local T = {
    enforcerZ  = { range = 0.20, damage = 0.10,
                   text = { { "range", "pct" } } },
    enforcerX  = { size = 0.20, stun = 0.25, stunMax = 1.5,
                   text = { { "size", "pct" }, { "stun", "sec", "stunMax" } } },
    enforcerC  = { bunkerArmor = 15, bunkerCooldown = 0.08,
                   text = { { "bunkerArmor", "count" }, { "bunkerCooldown", "pct" } } },
    enforcerV  = { radius = 0.15, stun = 0.5, stunMax = 2.0,
                   text = { { "radius", "pct" }, { "stun", "sec", "stunMax" } } },
    enforcerVBoosted = { radius = 0.15,
                         text = { { "radius", "pct" } } },
    enforcerZ2 = { magazine = 1, radius = 0.15,
                   text = { { "magazine", "count" }, { "radius", "pct" } } },
    enforcerX3 = { tackleSpeed = 0.15, size = 0.20,
                   text = { { "tackleSpeed", "pct" }, { "size", "pct" } } },
    enforcerV2 = { blastSize = 0.20, stun = 0.25, stunMax = 1.5,
                   text = { { "blastSize", "pct" }, { "stun", "sec", "stunMax" } } },
    enforcerV2Boosted = { blastSize = 0.20,
                          text = { { "blastSize", "pct" } } },
}

U.register({ "enforcerZ" }, T.enforcerZ)
U.register({ "enforcerX" }, T.enforcerX)
U.register({ "enforcerC" }, T.enforcerC)
U.register({ "enforcerV" }, T.enforcerV)
U.register({ "enforcerVBoosted" }, T.enforcerVBoosted)
U.register({ "enforcerZ2" }, T.enforcerZ2)
U.register({ "enforcerX3" }, T.enforcerX3)
U.register({ "enforcerV2" }, T.enforcerV2)
U.register({ "enforcerV2Boosted" }, T.enforcerV2Boosted)

local Z   = U.ids("enforcerZ")
local X   = U.ids("enforcerX")
local C   = U.ids("enforcerC")
local V   = U.ids("enforcerV")
local VB  = U.ids("enforcerVBoosted")
local X3  = U.ids("enforcerX3")
local V2  = U.ids("enforcerV2")
local V2B = U.ids("enforcerV2Boosted")

local Z2_ID = Skill.find("enforcerZ2", "ror").value

local STATE_Z    = H.state("enforcerZ")
local STATE_X3   = H.state("enforcerX3")
local STATE_V2   = H.state("enforcerV2")
local STATE_V2B  = H.state("enforcerV2Boosted")

local function add_stun(attack, def, rank)
    local seconds = math.min(def.stun * rank, def.stunMax)
    attack.stun = attack.stun + seconds * 60 / STUN_FRAMES
end

H.on_bullet(function(actor, args)
    if not H.in_state(actor, STATE_Z) then return end
    local rank = U.rank_for(actor, Z)
    if rank > 0 then args[6].value = args[6].value * (1 + T.enforcerZ.range * rank) end
end)

local SLAM = 2

local GRENADE = gm.constants.oEnforcerGrenade

H.on_explosion(function(actor, args, source)
    if source then
        if source.object_index ~= GRENADE then return end
        local def, rank = T.enforcerV, U.rank_for(actor, V)
        if rank < 1 then def, rank = T.enforcerVBoosted, U.rank_for(actor, VB) end
        if rank > 0 then H.scale_blast(args, 1 + def.radius * rank) end
        return
    end

    if args[8].value == 1.25 and args[9].value == 3 and actor:get_default_skill(0).skill_id == Z2_ID then
        local rank = S.rank(actor, 0)
        if rank > 0 then H.scale_blast(args, 1 + T.enforcerZ2.radius * rank) end
        return
    end

    if H.in_state(actor, STATE_X3) then
        local rank = U.rank_for(actor, X3)
        if rank > 0 then H.scale_blast(args, 1 + T.enforcerX3.size * rank) end
        return
    end

    if H.in_state(actor, STATE_V2) or H.in_state(actor, STATE_V2B) then
        local base = H.in_state(actor, STATE_V2)
        local rank = U.rank_for(actor, base and V2 or V2B)
        if rank > 0 then
            H.scale_blast(args, 1 + T.enforcerV2.blastSize * rank)
            if base then return "disperse" end
        end
        return
    end

    if tonumber(actor.activity) == SLAM and args[8].value == 1 and args[9].value == 3 then
        local rank = U.rank_for(actor, X)
        if rank > 0 then
            H.scale_blast(args, 1 + T.enforcerX.size * rank)
            return "slam"
        end
    end
end)

H.after_explosion(function(actor, attack, args, source, tag)
    if tag == "slam" then
        add_stun(attack, T.enforcerX, U.rank_for(actor, X))
    elseif tag == "disperse" then
        add_stun(attack, T.enforcerV2, U.rank_for(actor, V2))
    end
end)

H.watch_destroy("oEnforcerGrenade", function(grenade)
    if not Net.host or S.bool(grenade.scepter) then return end
    local parent = grenade.parent
    if not Instance.exists(parent) then return end
    local rank = U.rank_for(parent, V)
    if rank < 1 then return end

    local blast = Global.attack_bullet
    if not Instance.exists(blast) then return end
    add_stun(blast.attack_info, T.enforcerV, rank)
end)

Callback.add(ActorState.find("enforcerX3", "ror").on_step, function(actor, data)
    if math.floor(actor.image_index) < 1 then return end
    local rank = U.rank_for(actor, X3)
    if rank > 0 then actor.pHspeed = actor.pHspeed * (1 + T.enforcerX3.tackleSpeed * rank) end
end)

RecalculateStats.add(function(actor, api)
    if actor.object_index ~= OP or not S.bool(actor.bunker) then return end
    local rank = U.rank_for(actor, C)
    if rank > 0 then api.armor_add(T.enforcerC.bunkerArmor * rank) end
end)

H.on_skill_recalc(function(skill, actor)
    if math.floor(skill.slot_index) ~= 0 then return end

    if skill.skill_id == Z2_ID then
        local rank = S.rank(actor, 0)
        if rank > 0 then skill.max_stock = skill.max_stock + T.enforcerZ2.magazine * rank end
        return
    end

    if S.bool(actor.bunker) then
        local rank = U.rank_for(actor, C)
        if rank > 0 then
            skill.cooldown = math.max(1, math.floor(skill.cooldown * (1 - T.enforcerC.bunkerCooldown) ^ rank))
        end
    end
end)

SPP.Enforcer = T
