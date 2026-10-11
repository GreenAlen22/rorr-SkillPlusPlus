-- Улучшения навыков Бандита. Числа - в таблице T.

SPP = SPP or {}

local U = SPP.Upgrades
local H = SPP.Hooks

local OP = gm.constants.oP
local FPS = 60

local T = {
    banditZ = { damage = 0.10, pierceChance = 0.10,
                text = { { "pierceChance", "pct" } } },
    banditX = { radius = 0.20, stickEvery = 2,
                text = { { "radius", "pct" }, { "stickEvery", "every" } } },
    banditC = { invisibility = 0.5, damage = 0.20,
                text = { { "invisibility", "sec" } } },
    banditV = { damage = 0.10, execute = 0.10,
                text = { { "execute", "pct" } } },
    banditZ2 = { whipReach = 0.20, damage = 0.10,
                 text = { { "whipReach", "pct" } } },
    banditC2 = { flashRadius = 0.20, flashSeconds = 1,
                 text = { { "flashRadius", "pct" }, { "flashSeconds", "sec" } } },
    banditV2 = { standoffStack = 0.05, damage = 0.10,
                 text = { { "standoffStack", "pct" } } },
}

U.register({ "banditZ" }, T.banditZ)
U.register({ "banditX" }, T.banditX)
U.register({ "banditC" }, T.banditC)
U.register({ "banditV", "banditVBoosted" }, T.banditV)
U.register({ "banditZ2" }, T.banditZ2)
U.register({ "banditC2" }, T.banditC2)
U.register({ "banditV2", "banditV2Boosted" }, T.banditV2)

local Z  = U.ids("banditZ")
local X  = U.ids("banditX")
local C  = U.ids("banditC")
local V  = U.ids("banditV", "banditVBoosted")
local Z2 = U.ids("banditZ2")
local C2 = U.ids("banditC2")
local V2 = U.ids("banditV2", "banditV2Boosted")

local STATE_Z = H.state("banditZ")

H.on_bullet(function(actor, args)
    if not H.in_state(actor, STATE_Z) then return end
    local rank = U.rank_for(actor, Z)
    if rank > 0 and math.random() < T.banditZ.pierceChance * rank then args[4].value = 1 end
end)

local STATE_Z2 = H.state("banditZ2")

H.on_explosion(function(actor, args, source)
    if source or not H.in_state(actor, STATE_Z2) then return end
    local rank = U.rank_for(actor, Z2)
    if rank < 1 then return end
    local mult = 1 + T.banditZ2.whipReach * rank
    args[2].value = actor.x + (args[2].value - actor.x) * mult
    args[8].value = args[8].value * mult
end)

local FLASH = gm.constants.oBanditGrenade
H.watch_destroy("oBanditGrenade")

H.on_explosion(function(actor, args, source)
    if not source or source.object_index ~= FLASH then return end
    local rank = U.rank_for(actor, C2)
    if rank > 0 then H.scale_blast(args, 1 + T.banditC2.flashRadius * rank) end
end)

H.on_first_step("oEfBanditFlashCircle", function(field)
    if not Instance.exists(field.parent) then return end
    local rank = U.rank_for(field.parent, C2)
    if rank < 1 then return end

    local mult = 1 + T.banditC2.flashRadius * rank
    field.image_xscale = field.image_xscale * mult
    field.image_yscale = field.image_yscale * mult
    field.rad = field.rad * mult

    local left = tonumber(field:alarm_get(1)) or -1
    if left > 0 then
        field:alarm_set(1, left + math.floor(T.banditC2.flashSeconds * FPS * rank))
    end
end)

local skull = Buff.find("banditSkull", "ror")
if not skull then error("vanilla buff ror-banditSkull not found") end

RecalculateStats.add(function(actor, api)
    if actor.object_index ~= OP then return end
    local stacks = actor:buff_count(skull)
    if stacks < 1 then return end
    local rank = U.rank_for(actor, V2)
    if rank > 0 then api.damage_mult(1 + T.banditV2.standoffStack * rank * stacks) end
end)

local DYNAMITE = gm.constants.oBanditDynamite
H.watch_destroy("oBanditDynamite")

H.on_explosion(function(actor, args, source)
    if not source or source.object_index ~= DYNAMITE then return end
    local rank = U.rank_for(actor, X)
    if rank > 0 then H.scale_blast(args, 1 + T.banditX.radius * rank) end
end)

local THROW = 4

H.on_activity(function(actor, prev)
    if tonumber(actor.activity) ~= THROW or prev.var1 ~= 0 or tonumber(actor.activity_var1) ~= 1 then return end

    local extra = math.floor(U.rank_for(actor, X) / T.banditX.stickEvery)
    if extra < 1 then return end

    local xs = actor.image_xscale
    local damage = actor:get_active_skill(1).damage
    for k = 1, extra do
        local stick = GM.instance_create(actor.x + 4 * xs, actor.y - 16, DYNAMITE)
        stick.damage_coeff = damage
        stick.team = actor.team
        stick.parent = actor
        stick.direction = 90 - (80 - math.min(12 * k, 60)) * xs
    end
end)

local smokebomb = Buff.find("smokebomb", "ror")
if not smokebomb then error("vanilla buff ror-smokebomb not found") end

Callback.add(Skill.find("banditC", "ror").on_activate, function(actor, skill, slot)
    if not Net.host then return end
    local rank = U.rank_for(actor, C)
    if rank > 0 then
        local extra = math.floor(T.banditC.invisibility * 60 * rank)
        actor:buff_set_time(smokebomb, actor:buff_get_time(smokebomb) + extra)
    end
end)

local CD_RESET_ON_KILL = 1

DamageCalculate.add(function(api)
    if math.floor(tonumber(api.attack_flags) or 0) & CD_RESET_ON_KILL == 0 then return end
    local parent = api.parent
    if not Instance.exists(parent) or parent.object_index ~= OP then return end

    local rank = U.rank_for(parent, V)
    if rank < 1 then return end

    local hit = api.hit
    if not Instance.exists(hit) then return end
    local hp, maxhp = tonumber(hit.hp) or 0, tonumber(hit.maxhp) or 0
    if maxhp > 0 and hp < maxhp / 2 then
        api.damage_mult(1 + T.banditV.execute * rank)
    end
end)

SPP.Bandit = T
