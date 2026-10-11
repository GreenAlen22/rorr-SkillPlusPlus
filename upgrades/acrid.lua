-- Улучшения навыков Акрида. Числа - в таблице T.

SPP = SPP or {}

local S = SPP.State
local U = SPP.Upgrades
local H = SPP.Hooks

local OP = gm.constants.oP
local FPS = 60

local T = {
    acridZ  = { damage = 0.10, poisonSeconds = 1,
                text = { { "poisonSeconds", "sec" } } },
    acridX  = { spitRange = 0.20, stun = 0.25, stunMax = 1.5,
                text = { { "spitRange", "pct" }, { "stun", "sec", "stunMax" } } },
    acridC  = { sludgeArmor = 10, sludgeSeconds = 0.5,
                text = { { "sludgeArmor", "count" }, { "sludgeSeconds", "sec" } } },
    acridV  = { damage = 0.10, spreadRange = 0.20,
                text = { { "spreadRange", "pct" } } },
    acridZ2 = { corrodeChance = 0.10, biteSize = 0.15,
                text = { { "corrodeChance", "pct" }, { "biteSize", "pct" } } },
    acridX2 = { radius = 0.20, bubbleEvery = 3,
                text = { { "radius", "pct" }, { "bubbleEvery", "every" } } },
    acridC2 = { warpInvuln = 0.2, warpInvulnMax = 1.0, warpSize = 0.20,
                text = { { "warpInvuln", "sec", "warpInvulnMax" }, { "warpSize", "pct" } } },
}

U.register({ "acridZ" }, T.acridZ)
U.register({ "acridX" }, T.acridX)
U.register({ "acridC" }, T.acridC)
U.register({ "acridV", "acridVBoosted" }, T.acridV)
U.register({ "acridZ2" }, T.acridZ2)
U.register({ "acridX2" }, T.acridX2)
U.register({ "acridC2" }, T.acridC2)

local Z  = U.ids("acridZ")
local X  = U.ids("acridX")
local C  = U.ids("acridC")
local V  = U.ids("acridV", "acridVBoosted")
local Z2 = U.ids("acridZ2")
local X2 = U.ids("acridX2")
local C2 = U.ids("acridC2")

local BITE, SPIT = 1, 2

local function find_buff(name)
    local buff = Buff.find(name, "ror")
    if not buff then error("vanilla buff ror-"..name.." not found") end
    return buff
end

local shadow_clone = find_buff("shadowClone")
local poison_trail = find_buff("poisonTrail")
local armorstrip   = find_buff("acridArmorstrip")

local POISON_FLAG  = 2
local CORRODE_FLAG = 2097152

local DOT = gm.constants.oDot
local POISON_COLOR = 5108425
local POISON_TICKS = 6
local POISON_TICKS_PER_SECOND = FPS / 30

local CORRODE_FRAMES = 300

local function extend_poison(parent, target, rank)
    local extra = math.floor(T.acridZ.poisonSeconds * POISON_TICKS_PER_SECOND * rank)
    for _, dot in ipairs(Instance.find_all(DOT)) do
        if tonumber(dot.ticks) == POISON_TICKS and tonumber(dot.textColor) == POISON_COLOR
                and dot.parent == parent and dot.target == target then
            dot.ticks = POISON_TICKS + extra
            return
        end
    end
end

Callback.add(Callback.ON_ATTACK_HIT, function(hit_info)
    if not Net.host then return end
    local attack = hit_info.attack_info
    local flags = math.floor(tonumber(attack.attack_flags) or 0)
    if flags & (POISON_FLAG | CORRODE_FLAG) == 0 then return end
    local parent = attack.parent
    if not Instance.exists(parent) or parent.object_index ~= OP then return end

    if flags & POISON_FLAG ~= 0 then
        local rank = U.rank_for(parent, Z)
        if rank > 0 then extend_poison(parent, hit_info.target_true, rank) end
    end

    if flags & CORRODE_FLAG ~= 0 then
        local rank = U.rank_for(parent, Z2)
        local target = hit_info.target
        if rank > 0 and Instance.exists(target) and math.random() < T.acridZ2.corrodeChance * rank then
            GM.apply_buff(target, armorstrip, CORRODE_FRAMES, 1)
        end
    end
end)

local NEUROTOXIN_RANGE = 160

H.on_bullet(function(actor, args)
    if tonumber(actor.activity) ~= SPIT or args[6].value ~= NEUROTOXIN_RANGE then return end
    local rank = U.rank_for(actor, X)
    if rank > 0 then args[6].value = args[6].value * (1 + T.acridX.spitRange * rank) end
end)

local TRACER_ACRID = 23
local STUN_FRAMES = 90

Callback.add(Callback.ON_ATTACK_HANDLE_START, function(attack)
    if not Net.host or tonumber(attack.tracer_kind) ~= TRACER_ACRID then return end
    local parent = attack.parent
    if not Instance.exists(parent) or parent.object_index ~= OP then return end
    local rank = U.rank_for(parent, X)
    if rank < 1 then return end
    local seconds = math.min(T.acridX.stun * rank, T.acridX.stunMax)
    attack.stun = attack.stun + seconds * FPS / STUN_FRAMES
end)

Callback.add(Skill.find("acridC", "ror").on_activate, function(actor, skill, slot)
    if not Net.host then return end
    local rank = U.rank_for(actor, C)
    if rank > 0 then
        local extra = math.floor(T.acridC.sludgeSeconds * FPS * rank)
        actor:buff_set_time(poison_trail, actor:buff_get_time(poison_trail) + extra)
    end
end)

RecalculateStats.add(function(actor, api)
    if actor.object_index ~= OP or actor:buff_count(poison_trail) < 1 then return end
    local rank = U.rank_for(actor, C)
    if rank > 0 then api.armor_add(T.acridC.sludgeArmor * rank) end
end)

local DISEASE  = gm.constants.oAcridDisease
local DISEASE2 = gm.constants.oAcridDisease2
local PANDEMIC_POISON = gm.constants.sEfPoison6
local SPREAD_TRIES = 2
local SPREAD_RANGE = 280
local SPREAD_CAP = 25

local count_before = 0

Hook.add_pre("gml_Object_oDot2_Alarm_1", function(self, other)
    local master = self.master
    count_before = Instance.exists(master) and math.floor(tonumber(master.id_count) or 0) or 0
end)

Hook.add_post("gml_Object_oDot2_Alarm_1", function(self, other)
    if not Net.host then return end
    local acrid, master = self.true_parent, self.master
    if not Instance.exists(acrid) or acrid.object_index ~= OP or not Instance.exists(master) then return end
    local rank = U.rank_for(acrid, V)
    if rank < 1 then return end

    local range = SPREAD_RANGE * (1 + T.acridV.spreadRange * rank)
    local count = math.floor(tonumber(master.id_count) or 0)
    local object = (self.sprite_index == PANDEMIC_POISON) and DISEASE2 or DISEASE
    for _ = 1, SPREAD_TRIES - (count - count_before) do
        if count >= SPREAD_CAP then return end

        local marker = self:find_target_nearest_ignore(master.id_list)
        if not Instance.exists(marker) then return end
        local target = marker.parent
        if not Instance.exists(target) or self:distance_to_object(target) > range then return end

        local disease = GM.instance_create(self.x, self.y, object)
        disease.parent = acrid
        disease.master = master
        disease.target = target
        disease.direction = math.random() * 360

        count = count + 1
        master.id_count = count
        master.id_list:set(count, target)
    end
end)

H.on_explosion(function(actor, args, source)
    if source or tonumber(actor.activity) ~= BITE then return end
    if args[8].value ~= 1 or args[9].value ~= 3 then return end
    local rank = U.rank_for(actor, Z2)
    if rank > 0 then H.scale_blast(args, 1 + T.acridZ2.biteSize * rank) end
end)

local BUBBLE = gm.constants.oEfAcidBubble
local BUBBLE_W, BUBBLE_H = 1.4, 4
H.watch_destroy("oEfAcidBubble")

H.on_explosion(function(actor, args, source)
    if source then
        if source.object_index ~= BUBBLE then return end
    elseif args[8].value ~= BUBBLE_W or args[9].value ~= BUBBLE_H then
        return
    end
    local rank = U.rank_for(actor, X2)
    if rank > 0 then H.scale_blast(args, 1 + T.acridX2.radius * rank) end
end)

H.on_activity(function(actor, prev)
    if not Net.host then return end
    if tonumber(actor.activity) ~= SPIT or prev.var1 ~= 0 or tonumber(actor.activity_var1) ~= 1 then return end

    local extra = math.floor(U.rank_for(actor, X2) / T.acridX2.bubbleEvery)
    if extra < 1 then return end

    local xs = actor.image_xscale
    local damage = actor:get_active_skill(1).damage
    local last_speed = 2 + actor:buff_count(shadow_clone)
    for k = 1, extra do
        local bubble = GM.instance_create(actor.x + 32 * xs, actor.y - 8, BUBBLE)
        bubble.damage_coeff = damage
        bubble.parent = actor
        bubble.team = actor.team
        bubble.image_xscale = xs
        bubble.direction = 90 - 90 * xs
        bubble.speed = last_speed + 0.5 * k
    end
end)

local STATE_WARP = H.state("acridC2Teleport")

H.on_explosion(function(actor, args, source)
    if source or not H.in_state(actor, STATE_WARP) then return end
    if args[8].value ~= 2 or args[9].value ~= 2 then return end
    local rank = U.rank_for(actor, C2)
    if rank > 0 then H.scale_blast(args, 1 + T.acridC2.warpSize * rank) end
end)

Callback.add(ActorState.wrap(STATE_WARP).on_exit, function(actor, data)
    if not S.bool(data.fired) then return end
    local rank = U.rank_for(actor, C2)
    if rank < 1 then return end
    local seconds = math.min(T.acridC2.warpInvuln * rank, T.acridC2.warpInvulnMax)
    actor.invincible = math.max(tonumber(actor.invincible) or 0, math.floor(seconds * FPS))
end)

SPP.Acrid = T
