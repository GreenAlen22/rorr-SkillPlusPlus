-- API для модов с выжившими: register, rank и правила выстрелов. Остальные хуки внутренние.

SPP = SPP or {}

local U = SPP.Upgrades
local S = SPP.State

local OP = gm.constants.oP

local A = {}

local COOLDOWN_SUSPICIOUS = 0.5

local external = {}

local rule_count = 0

local function skill_list(skills, fn_name)
    if type(skills) == "Skill" then return { skills } end
    if type(skills) ~= "table" or #skills == 0 then
        error(fn_name..": expected a Skill or a list of Skills, got "..type(skills), 3)
    end
    for i, skill in ipairs(skills) do
        if type(skill) ~= "Skill" then
            error(fn_name..": item "..i.." of the list is "..type(skill)..", not a Skill", 3)
        end
    end
    return skills
end

local function name_of(skill)
    return skill.namespace.."-"..skill.identifier
end

function A.register(skills, def)
    local list = skill_list(skills, "register")
    local each = {}
    for i, skill in ipairs(list) do each[i] = name_of(skill) end
    local names = table.concat(each, ", ")

    if def ~= false and type(def) ~= "table" then
        error("register "..names..": the upgrade table must be a table or false, got "..type(def), 2)
    end
    if def then
        local problem = U.def_problem(def)
        if problem then error("register "..names..": "..problem, 2) end
        if def.cooldown and def.cooldown < COOLDOWN_SUSPICIOUS then
            log.warning("SkillPlusPlus: "..names..": cooldown "..def.cooldown
                .." is a multiplier per level - 0.92 means -8% per level")
        end
    end

    local reads_id = nil
    if def and def.reads ~= nil then
        if type(def.reads) ~= "Skill" then
            error("register "..names..": reads must be a Skill, got "..type(def.reads), 2)
        end
        if not def.damage then
            error("register "..names..": reads needs damage - without it there is nothing to scale", 2)
        end
        for _, skill in ipairs(list) do
            if skill.value == def.reads.value then
                error("register "..names..": reads names "..name_of(def.reads)
                    ..", one of the skills being registered; an Ancient Scepter version"
                    .." asking for its base skill is found by Skills++ itself", 2)
            end
        end
        reads_id = def.reads.value
    end

    local ids = {}
    for _, skill in ipairs(list) do
        if skill.namespace == "ror" then
            error("register "..names..": "..name_of(skill)
                .." is a vanilla skill; its upgrades belong to Skills++", 2)
        end
        if external[skill.value] then
            log.warning("SkillPlusPlus: "..name_of(skill).." registered again; the new table replaces the old one")
        end
        ids[#ids + 1] = skill.value
    end

    U.register_external(ids, def, list[1].namespace..".skillPlusPlus", reads_id)
    for _, id in ipairs(ids) do external[id] = true end
end

local function holds(skills, id)
    if type(skills) == "Skill" then return skills.value == id end
    for _, skill in ipairs(skills) do
        if skill.value == id then return true end
    end
    return false
end

function A.rank(actor, skills)
    local kind = type(skills)
    if kind ~= "Skill" and kind ~= "table" then
        error("rank: expected a Skill or a list of Skills, got "..kind, 2)
    end
    if not Instance.exists(actor) or actor.object_index ~= OP then return 0 end
    for slot = 0, 3 do
        if holds(skills, U.ranked_skill(actor, slot)) then
            return S.rank(actor, slot)
        end
    end
    return 0
end

function A.count()
    local n = 0
    for _ in pairs(external) do n = n + 1 end
    return n
end

local function external_rule(fn, name)
    if type(fn) ~= "function" then
        error(name..": expected a function, got "..type(fn), 3)
    end
    local info = debug.getinfo(fn, "S")
    local origin = info.short_src..":"..info.linedefined
    rule_count = rule_count + 1
    return function(...)
        local ok, err = pcall(fn, ...)
        if not ok then
            if err == nil or err == "C++ exception" then err = "GameMaker error (see above)" end
            log.warning("SkillPlusPlus: "..name.." rule at "..origin.." failed: "..tostring(err))
        end
    end
end

function A.on_bullet(fn)  SPP.Hooks.on_bullet(external_rule(fn, "on_bullet")) end
function A.after_bullet(fn) SPP.Hooks.after_bullet(external_rule(fn, "after_bullet")) end
function A.on_direct(fn)  SPP.Hooks.on_direct(external_rule(fn, "on_direct")) end
function A.after_direct(fn) SPP.Hooks.after_direct(external_rule(fn, "after_direct")) end

function A.on_explosion(fn)
    local rule = external_rule(fn, "on_explosion")
    SPP.Hooks.on_explosion(function(actor, args) rule(actor, args) end)
end

function A.after_explosion(fn)
    local rule = external_rule(fn, "after_explosion")
    SPP.Hooks.after_explosion(function(actor, attack, args, source, tag, vanilla)
        rule(actor, attack, args, vanilla)
    end)
end

function A.rules()
    return rule_count
end

SPP.Api = A

api.register        = A.register
api.rank            = A.rank
api.on_bullet       = A.on_bullet
api.after_bullet    = A.after_bullet
api.on_explosion    = A.on_explosion
api.after_explosion = A.after_explosion
api.on_direct       = A.on_direct
api.after_direct    = A.after_direct
setmetatable(api, { __index = function(_, key)
    if key == "RAPI" then return nil end
    error("Skills++ API has no "..tostring(key).."; it has register, rank, on_bullet, after_bullet,"
        .." on_explosion, after_explosion, on_direct and after_direct", 2)
end })
