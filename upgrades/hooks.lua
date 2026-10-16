-- Общие хуки на ванильные функции; файлы выживших добавляют в них свои правила.

SPP = SPP or {}

local OP = gm.constants.oP

local H = {}

local bullet_rules    = {}
local bullet_after    = {}
local explosion_rules = {}
local explosion_after = {}
local activity_rules  = {}

function H.on_bullet(fn) bullet_rules[#bullet_rules + 1] = fn end

function H.after_bullet(fn) bullet_after[#bullet_after + 1] = fn end

function H.on_explosion(fn) explosion_rules[#explosion_rules + 1] = fn end

function H.after_explosion(fn) explosion_after[#explosion_after + 1] = fn end

function H.on_activity(fn) activity_rules[#activity_rules + 1] = fn end

local skill_recalc_rules = {}
function H.on_skill_recalc(fn) skill_recalc_rules[#skill_recalc_rules + 1] = fn end

Hook.add_post(gm.constants["skill_recalculate_stats@anon@8392@ActorSkill@scr_actor_skills"], function(self, other, result, args)
    if #skill_recalc_rules == 0 then return end
    local actor = self.parent
    if not Instance.exists(actor) or actor.object_index ~= OP then return end
    for _, fn in ipairs(skill_recalc_rules) do fn(self, actor) end
end)

local bullet_calls = {}

Hook.add_pre(gm.constants.fire_bullet, Callback.Priority.BEFORE * 2, function(self, other, result, args)
    if #bullet_after == 0 or self.object_index ~= OP then return end
    local values = {}
    for i = 1, #args do values[i] = args[i].value end
    bullet_calls[#bullet_calls + 1] = values
end)

Hook.add_post(gm.constants.fire_bullet, Callback.Priority.AFTER * 2, function(self, other, result, args)
    if #bullet_after == 0 or self.object_index ~= OP then return end
    bullet_calls[#bullet_calls] = nil
end)

Hook.add_pre(gm.constants.fire_bullet, function(self, other, result, args)
    if #bullet_rules == 0 or self.object_index ~= OP then return end
    for _, fn in ipairs(bullet_rules) do fn(self, args) end
end)

Hook.add_post(gm.constants.fire_bullet, function(self, other, result, args)
    if #bullet_after == 0 or self.object_index ~= OP then return end
    local vanilla = bullet_calls[#bullet_calls]
    for _, fn in ipairs(bullet_after) do fn(self, result.value, args, vanilla) end
end)

local sources = {}

local tag = nil

Hook.add_pre(gm.constants.fire_explosion, function(self, other, result, args)
    tag = nil
    if #explosion_rules == 0 or self.object_index ~= OP then return end
    local source = sources[#sources]
    for _, fn in ipairs(explosion_rules) do
        tag = fn(self, args, source) or tag
    end
end)

Hook.add_post(gm.constants.fire_explosion, function(self, other, result, args)
    if #explosion_after == 0 or self.object_index ~= OP then return end
    local source = sources[#sources]
    for _, fn in ipairs(explosion_after) do fn(self, result.value, args, source, tag) end
    tag = nil
end)

local first_step_count = 0

function H.on_first_step(object_name, fn, event)
    first_step_count = first_step_count + 1
    local key = "firstStep"..first_step_count
    Hook.add_pre("gml_Object_"..object_name.."_"..(event or "Step_2"), function(self, other)
        local data = Instance.get_data(self, key, SPP.Config.namespace)
        if data.seen then return end
        data.seen = true
        fn(self)
    end)
end

local after_event = {}

function H.watch_event(object_name, event, fn)
    local name = "gml_Object_"..object_name.."_"..event
    if not after_event[name] then
        after_event[name] = {}
        Hook.add_pre(name, function(self, other) sources[#sources + 1] = self end)
        Hook.add_post(name, function(self, other)
            sources[#sources] = nil
            for _, f in ipairs(after_event[name]) do f(self) end
        end)
    end
    if fn then table.insert(after_event[name], fn) end
end

function H.watch_destroy(object_name, fn)
    H.watch_event(object_name, "Destroy_0", fn)
end

local last = {}

Hook.add_post(gm.constants.skill_system_update, function(self, other, result, args)
    if #activity_rules == 0 or self.object_index ~= OP then return end

    local id = self.id
    local prev = last[id]
    if not prev then
        prev = { activity = 0, var1 = 0 }
        last[id] = prev
    end
    for _, fn in ipairs(activity_rules) do fn(self, prev) end
    prev.activity = tonumber(self.activity) or 0
    prev.var1 = tonumber(self.activity_var1) or 0
end)

Callback.add(Callback.ON_GAME_START, function()
    last = {}
    sources = {}
    bullet_calls = {}
end)

function H.state(name)
    local state = ActorState.find(name, "ror")
    if not state then error("vanilla actor state ror-"..name.." not found") end
    return state.value
end

function H.state_at(id, name)
    local state = ActorState.wrap(id)
    if state.identifier ~= name then
        error("vanilla actor state "..id.." is "..tostring(state.identifier)..", not "..name)
    end
    return state
end

function H.in_state(actor, state_id)
    return tonumber(actor.actor_state_current_id) == state_id
end

function H.scale_blast(args, mult)
    args[8].value = args[8].value * mult
    args[9].value = args[9].value * mult
end

SPP.Hooks = H
