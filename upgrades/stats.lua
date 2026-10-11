-- Перезарядка, заряды и урон навыка от уровня; временные бонусы к статам.

SPP = SPP or {}

local S = SPP.State
local U = SPP.Upgrades

local OP = gm.constants.oP

local ST = {}

local function rank_of(actor, slot)
    return S.get(actor).rank[slot]
end

local slot_api = { [1] = "skill_secondary", [2] = "skill_utility", [3] = "skill_special" }

RecalculateStats.add(function(actor, api)
    if actor.object_index ~= OP then return end
    for slot = 1, 3 do
        local rank = rank_of(actor, slot)
        if rank > 0 then
            local def = U.def(actor:get_active_skill(slot).skill_id, slot)
            if def then
                local skill_api = api[slot_api[slot]]
                if def.cooldown then skill_api.cooldown_mult(def.cooldown ^ rank) end
                if def.stock_every then skill_api.max_stock_add(math.floor(rank / def.stock_every)) end
            end
        end
    end
end)

SPP.Hooks.on_skill_recalc(function(skill, actor)
    local slot = math.floor(skill.slot_index)
    local rank = rank_of(actor, slot)
    if rank < 1 then return end

    local def = U.def(skill.skill_id, slot)
    if def and def.damage then
        skill.damage = skill.damage * (1 + def.damage * rank)
    end
end)

Hook.add_post(gm.constants.skill_get_damage, function(self, other, result, args)
    local asked = args[1].value
    if not U.asked[asked] then return end
    if not Instance.exists(self) or self.object_index ~= OP then return end

    for slot = 0, 3 do
        local active = self:get_active_skill(slot).skill_id
        if U.asks_for[active] == asked then
            local rank = rank_of(self, slot)
            local def = rank > 0 and U.def(active, slot)
            if def and def.damage then
                result.value = result.value * (1 + def.damage * rank)
            end
            return
        end
    end
end)

local timers = {}

function ST.timer()
    local until_frame = {}
    timers[#timers + 1] = until_frame

    local timer = {}
    function timer.start(actor, frames)
        until_frame[actor.id] = S.frame + frames
        actor:queue_recalculate_stats()
    end
    function timer.active(actor)
        local frame = until_frame[actor.id]
        return frame ~= nil and S.frame < frame
    end
    return timer
end

Callback.add(Callback.POST_STEP, function()
    for _, until_frame in ipairs(timers) do
        for id, frame in pairs(until_frame) do
            if S.frame >= frame then
                until_frame[id] = nil
                if Instance.exists(id) then Instance.wrap(id):queue_recalculate_stats() end
            end
        end
    end
end)

Callback.add(Callback.ON_GAME_START, function()
    for _, until_frame in ipairs(timers) do
        for id in pairs(until_frame) do until_frame[id] = nil end
    end
end)

SPP.Stats = ST
