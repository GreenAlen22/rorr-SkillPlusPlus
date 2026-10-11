-- Улучшения навыков Изобретателя. Числа - в таблице T.

SPP = SPP or {}

local S = SPP.State
local U = SPP.Upgrades
local H = SPP.Hooks

local OP = gm.constants.oP

local T = {
    artiZ   = { chakramEvery = 2, chakramRange = 0.15,
                text = { { "chakramEvery", "every" }, { "chakramRange", "pct" } } },
    artiX   = { radius = 0.20, damage = 0.10,
                text = { { "radius", "pct" } } },
    artiC   = { wallHealth = 0.25, stock_every = 2,
                text = { { "wallHealth", "pct" } } },
    artiV   = { flameBursts = 2, flameReach = 0.15,
                text = { { "flameBursts", "count" }, { "flameReach", "pct" } } },
    artiX2  = { pulseSize = 0.20, damage = 0.10,
                text = { { "pulseSize", "pct" } } },
    artiC2  = { surgeRadius = 0.20, stock_every = 2,
                text = { { "surgeRadius", "pct" } } },
    artiV2  = { starSize = 0.20, damage = 0.10,
                text = { { "starSize", "pct" } } },
}

U.register({ "artiZ" }, T.artiZ)
U.register({ "artiX" }, T.artiX)
U.register({ "artiC" }, T.artiC)
U.register({ "artiV", "artiVBoosted" }, T.artiV)
U.register({ "artiX2" }, T.artiX2)
U.register({ "artiC2" }, T.artiC2)
U.register({ "artiV2", "artiV2Boosted" }, T.artiV2)

local Z  = U.ids("artiZ")
local X  = U.ids("artiX")
local C  = U.ids("artiC")
local V  = U.ids("artiV", "artiVBoosted")
local X2 = U.ids("artiX2")
local C2 = U.ids("artiC2")
local V2 = U.ids("artiV2", "artiV2Boosted")

local Z_ID = Skill.find("artiZ", "ror").value

local STATE_V  = H.state("artiV")
local STATE_VB = H.state("artiVBoosted")
local STATE_C2 = H.state("artiC2")

local NANOBOMB = gm.constants.oArtiNanobomb
local BOLT     = gm.constants.oEfArtiNanobolt
local STAR     = gm.constants.oEfArtiStar

local function player_of(object)
    local parent = object.parent
    if Instance.exists(parent) and parent.object_index == OP then return parent end
    return nil
end

H.on_skill_recalc(function(skill, actor)
    if math.floor(skill.slot_index) ~= 0 or skill.skill_id ~= Z_ID then return end
    if S.bool(skill.disable_stock_regen) then return end
    local extra = math.floor(S.rank(actor, 0) / T.artiZ.chakramEvery)
    if extra > 0 then skill.max_stock = skill.max_stock + extra end
end)

H.on_first_step("oArtiChakram", function(chakram)
    local player = player_of(chakram)
    if not player then return end
    local rank = U.rank_for(player, Z)
    if rank < 1 then return end
    local mult = 1 + T.artiZ.chakramRange * rank
    chakram.tX = chakram.sX + (chakram.tX - chakram.sX) * mult
end)

H.on_first_step("oArtiSnap", function(wall)
    if not Net.host then return end
    local player = player_of(wall)
    if not player then return end
    local rank = U.rank_for(player, C)
    if rank < 1 then return end
    local mult = 1 + T.artiC.wallHealth * rank
    wall.maxhp_base = math.ceil(wall.maxhp_base * mult)
    wall.maxhp = math.ceil(wall.maxhp * mult)
    wall.hp = wall.hp * mult
end, "Step_1")

local bursts_added = {}

for _, name in ipairs({ "artiV", "artiVBoosted" }) do
    local state = ActorState.find(name, "ror")
    if not state then error("vanilla actor state ror-"..name.." not found") end

    Callback.add(state.on_enter, function(actor, data)
        bursts_added[actor.id] = false
    end)

    Callback.add(state.on_step, function(actor, data)
        if bursts_added[actor.id] or (tonumber(actor.activity_var1) or 0) < 1 then return end
        bursts_added[actor.id] = true
        local rank = U.rank_for(actor, V)
        if rank > 0 then
            actor.activity_var2 = actor.activity_var2 + T.artiV.flameBursts * rank
        end
    end)
end

Callback.add(Callback.ON_GAME_START, function()
    bursts_added = {}
end)

H.watch_destroy("oArtiNanobomb")
H.watch_destroy("oEfArtiStar")

H.on_explosion(function(actor, args, source)
    if source then
        local object = source.object_index
        if object == NANOBOMB then
            local rank = U.rank_for(actor, X)
            if rank > 0 then H.scale_blast(args, 1 + T.artiX.radius * rank) end
        elseif object == STAR then
            local rank = U.rank_for(actor, V2)
            if rank > 0 then H.scale_blast(args, 1 + T.artiV2.starSize * rank) end
        end
        return
    end

    if (H.in_state(actor, STATE_V) or H.in_state(actor, STATE_VB))
            and args[8].value == 2 and args[9].value == 4 then
        local rank = U.rank_for(actor, V)
        if rank < 1 then return end
        local mult = 1 + T.artiV.flameReach * rank
        args[2].value = actor.x + (args[2].value - actor.x) * mult
        args[8].value = args[8].value * mult
        return
    end

    if H.in_state(actor, STATE_C2) and args[8].value == 1.5 and args[9].value == 3 then
        local rank = U.rank_for(actor, C2)
        if rank > 0 then H.scale_blast(args, 1 + T.artiC2.surgeRadius * rank) end
    end
end)

H.on_first_step("oEfArtiStar", function(star)
    local player = player_of(star)
    if not player then return end
    local rank = U.rank_for(player, V2)
    if rank < 1 then return end
    local mult = 1 + T.artiV2.starSize * rank
    star.image_xscale = star.image_xscale * mult
    star.image_yscale = star.image_yscale * mult
end)

Hook.add_pre(gm.constants.find_characters_rectangle, function(self, other, result, args)
    if self.object_index ~= BOLT then return end
    local player = player_of(self)
    if not player then return end
    local rank = U.rank_for(player, X2)
    if rank < 1 then return end

    local mult = 1 + T.artiX2.pulseSize * rank
    local gx, gy = self.ghost_x, self.ghost_y
    args[1].value = gx + (args[1].value - gx) * mult
    args[2].value = gy + (args[2].value - gy) * mult
    args[3].value = gx + (args[3].value - gx) * mult
    args[4].value = gy + (args[4].value - gy) * mult
end)

SPP.Arti = T
