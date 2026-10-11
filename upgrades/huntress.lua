-- Улучшения навыков Охотницы. Числа - в таблице T.

SPP = SPP or {}

local C_ = SPP.Config
local S = SPP.State
local U = SPP.Upgrades
local H = SPP.Hooks

local FPS = 60

local T = {
    huntressZ  = { damage = 0.10, arrowEvery = 2,
                   text = { { "arrowEvery", "every" } } },
    huntressX  = { bounces = 1, damage = 0.10,
                   text = { { "bounces", "count" } } },
    huntressC  = { blinkInvuln = 0.1, blinkInvulnMax = 0.5, stock_every = 2,
                   text = { { "blinkInvuln", "sec", "blinkInvulnMax" } } },
    huntressV  = { bomblets = 2, bombletDamage = 0.15,
                   text = { { "bomblets", "count" }, { "bombletDamage", "pct" } } },
    huntressZ2 = { chargeSpeed = 0.10, damage = 0.10,
                   text = { { "chargeSpeed", "pct" } } },
    huntressX2 = { cycloneSize = 0.20, damage = 0.10,
                   text = { { "cycloneSize", "pct" } } },
    huntressC2 = { dartBlast = 0.25, stock_every = 2,
                   text = { { "dartBlast", "pct" } } },
}

U.register({ "huntressZ" }, T.huntressZ)
U.register({ "huntressX" }, T.huntressX)
U.register({ "huntressC" }, T.huntressC)
U.register({ "huntressV", "huntressVBoosted" }, T.huntressV)
U.register({ "huntressZ2" }, T.huntressZ2)
U.register({ "huntressX2" }, T.huntressX2)
U.register({ "huntressC2" }, T.huntressC2)

local Z  = U.ids("huntressZ")
local X  = U.ids("huntressX")
local C  = U.ids("huntressC")
local V  = U.ids("huntressV", "huntressVBoosted")
local Z2 = U.ids("huntressZ2")
local X2 = U.ids("huntressX2")
local C2 = U.ids("huntressC2")

local shadow_clone = Buff.find("shadowClone", "ror")
if not shadow_clone then error("vanilla buff ror-shadowClone not found") end

local shot_done = {}

local cracked = {}

Hook.add_post(gm.constants.skill_util_update_heaven_cracker, function(self, other, result, args)
    if self.object_index == gm.constants.oP then cracked[self.id] = S.bool(result.value) end
end)

Callback.add(ActorState.find("huntressZ", "ror").on_enter, function(actor, data)
    shot_done[actor.id] = false
end)

Callback.add(ActorState.find("huntressZ", "ror").on_step, function(actor, data)
    if shot_done[actor.id] or tonumber(actor.activity_var1) ~= 1 then return end
    shot_done[actor.id] = true
    if cracked[actor.id] then return end

    local extra = math.floor(U.rank_for(actor, Z) / T.huntressZ.arrowEvery)
    if extra < 1 then return end

    local xs = actor.image_xscale2
    local first = actor:buff_count(shadow_clone) + 1
    local damage = actor:get_active_skill(0).damage
    for i = first, first + extra - 1 do
        local bolt = GM.instance_create(actor.x + 28 * xs, actor.y - 20 * i - 4, gm.constants.oHuntressBolt1)
        bolt.damage_coeff = damage
        bolt.direction = 90 - 90 * xs
        bolt.image_angle = bolt.direction
        bolt.parent = actor
        bolt.team = actor.team
        bolt.local_client_is_authority = actor.local_client_is_authority
    end
end)

Hook.add_pre("gml_Object_oHuntressBoomerang_Step_2", function(self, other)
    if not Net.host or (tonumber(self.hit_count) or 0) < 4 then return end
    if not Instance.exists(self.parent) then return end

    local data = Instance.get_data(self, "glaive", C_.namespace)
    local used = data.used or 0
    if used < T.huntressX.bounces * U.rank_for(self.parent, X) then
        self.hit_count = self.hit_count - 1
        data.used = used + 1
    end
end)

Callback.add(Skill.find("huntressC", "ror").on_activate, function(actor, skill, slot)
    local rank = U.rank_for(actor, C)
    if rank < 1 then return end
    local seconds = math.min(T.huntressC.blinkInvuln * rank, T.huntressC.blinkInvulnMax)
    actor.invincible = math.max(tonumber(actor.invincible) or 0, math.floor(seconds * FPS))
end)

local function add_bomblets(bolt, scepter)
    local parent = bolt.parent
    if not Instance.exists(parent) then return end
    local count = T.huntressV.bomblets * U.rank_for(parent, V)
    if count < 1 then return end

    local at = Instance.exists(bolt.target) and bolt.target or bolt
    for _ = 1, count do
        local bomb = GM.instance_create(at.x, at.y, gm.constants.oHuntressGrenade)
        bomb.parent = parent
        bomb.team = bolt.team
        bomb.local_client_is_authority = bolt.local_client_is_authority
        if scepter then
            bomb.scepter = true
            bomb.image_blend = 0x6666CF
        end
    end
end

H.watch_destroy("oHuntressBolt2", function(bolt) add_bomblets(bolt, false) end)
H.watch_destroy("oHuntressBolt3", function(bolt) add_bomblets(bolt, true) end)

local GRENADE = gm.constants.oHuntressGrenade
local DART = gm.constants.oHuntressBolt4
H.watch_destroy("oHuntressGrenade")
H.watch_destroy("oHuntressBolt4")

H.on_explosion(function(actor, args, source)
    if not source then return end
    local object = source.object_index
    if object == GRENADE then
        local rank = U.rank_for(actor, V)
        if rank > 0 then args[4].value = args[4].value * (1 + T.huntressV.bombletDamage * rank) end
    elseif object == DART then
        local rank = U.rank_for(actor, C2)
        if rank > 0 then H.scale_blast(args, 1 + T.huntressC2.dartBlast * rank) end
    end
end)

Callback.add(ActorState.find("huntressZ2Draw", "ror").on_step, function(actor, data)
    local rank = U.rank_for(actor, Z2)
    if rank < 1 or data.charge >= data.chargeMax then return end
    local extra = actor.attack_speed * 1.5 * T.huntressZ2.chargeSpeed * rank
    data.charge = math.min(data.chargeMax, data.charge + extra)
end)

H.on_first_step("oHuntressTrirang", function(cyclone)
    if not Instance.exists(cyclone.parent) then return end
    local rank = U.rank_for(cyclone.parent, X2)
    if rank < 1 then return end
    local mult = 1 + T.huntressX2.cycloneSize * rank
    cyclone.image_xscale = cyclone.image_xscale * mult
    cyclone.image_yscale = cyclone.image_yscale * mult
end)

SPP.Huntress = T
