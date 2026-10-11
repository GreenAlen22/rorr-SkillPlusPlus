-- Улучшения навыков РОБОМАНДО. Числа - в таблице T.

SPP = SPP or {}

local S = SPP.State
local U = SPP.Upgrades
local H = SPP.Hooks

local OP = gm.constants.oP
local FPS = 60

local STUN_FRAMES = 90

local T = {
    robomandoZ = { damage = 0.10, stunChance = 0.10, stunSeconds = 0.5,
                   text = { { "stunChance", "pct", "stunSeconds", "sec" } } },
    robomandoX = { chargeRange = 0.20, stun = 0.25, stunMax = 1.5,
                   text = { { "chargeRange", "pct" }, { "stun", "sec", "stunMax" } } },
    robomandoC = { maneuverInvuln = 0.2, maneuverInvulnMax = 1.0, stock_every = 2,
                   text = { { "maneuverInvuln", "sec", "maneuverInvulnMax" } } },
    robomandoV = { hackDouble = 0.10, hackItem = 0.10,
                   text = { { "hackDouble", "pct" }, { "hackItem", "pct" } } },
}

U.register({ "robomandoZ" }, T.robomandoZ)
U.register({ "robomandoX" }, T.robomandoX)
U.register({ "robomandoC" }, T.robomandoC)
U.register({ "robomandoV", "robomandoVBoosted" }, T.robomandoV)

local Z = U.ids("robomandoZ")
local X = U.ids("robomandoX")
local C = U.ids("robomandoC")
local V = U.ids("robomandoV", "robomandoVBoosted")

local STATE_X        = H.state("robomandoX")
local STATE_C_END    = H.state("robomandoCEnd")
local STATE_V        = H.state("robomandoV")
local STATE_V_BOOST  = H.state("robomandoVBoosted")

local function constant(name)
    local value = gm.constants[name]
    if value == nil then error("vanilla constant "..name.." not found") end
    return value
end

local TRACER_Z, TRACER_X = 16, 17

local CHARGE_RANGE = 160

H.on_bullet(function(actor, args)
    if not H.in_state(actor, STATE_X) or args[6].value ~= CHARGE_RANGE then return end
    local rank = U.rank_for(actor, X)
    if rank > 0 then args[6].value = args[6].value * (1 + T.robomandoX.chargeRange * rank) end
end)

local Z_STUN = T.robomandoZ.stunSeconds * FPS / STUN_FRAMES

Callback.add(Callback.ON_ATTACK_HANDLE_START, function(attack)
    if not Net.host then return end
    local tracer = tonumber(attack.tracer_kind)
    if tracer ~= TRACER_Z and tracer ~= TRACER_X then return end
    local parent = attack.parent
    if not Instance.exists(parent) or parent.object_index ~= OP then return end

    if tracer == TRACER_Z then
        local rank = U.rank_for(parent, Z)
        if rank > 0 and math.random() < T.robomandoZ.stunChance * rank then
            attack.stun = math.max(tonumber(attack.stun) or 0, Z_STUN)
        end
        return
    end

    local rank = U.rank_for(parent, X)
    if rank < 1 then return end
    local seconds = math.min(T.robomandoX.stun * rank, T.robomandoX.stunMax)
    attack.stun = attack.stun + seconds * FPS / STUN_FRAMES
end)

Callback.add(ActorState.wrap(STATE_C_END).on_enter, function(actor, data)
    if actor.object_index ~= OP then return end
    local rank = U.rank_for(actor, C)
    if rank < 1 then return end
    local seconds = math.min(T.robomandoC.maneuverInvuln * rank, T.robomandoC.maneuverInvulnMax)
    actor.invincible = math.max(tonumber(actor.invincible) or 0, math.floor(seconds * FPS))
end)

constant("_survivor_drifter_roll_item")
local TEMPORARY = 1

local function give_temporary(actor)
    local pickup = tonumber(GM._survivor_drifter_roll_item()) or -1
    if pickup < 0 then return end
    GM.item_set_dibs(actor.id)
    local item = GM.instance_create(actor.x, actor.y, pickup)
    item.item_stack_kind = TEMPORARY
    item.xstart = actor.x
    item.ystart = actor.y - 10
    item.x = item.xstart
    item.y = item.ystart
end

Hook.add_pre(constant("interactable_set_active"), function(self, other, result, args)
    if not Net.host or self.object_index ~= OP then return end
    if not (H.in_state(self, STATE_V) or H.in_state(self, STATE_V_BOOST)) then return end
    if #args < 5 or not S.bool(args[4].value) then return end
    local rank = U.rank_for(self, V)
    if rank < 1 then return end
    if math.random() < T.robomandoV.hackItem * rank then give_temporary(self) end
    if S.bool(args[5].value) then return end
    if math.random() < T.robomandoV.hackDouble * rank then args[5].value = true end
end)

SPP.Robomando = T
