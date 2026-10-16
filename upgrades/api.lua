-- API для модов с выжившими: register и rank. Больше наружу ничего не отдаётся.

SPP = SPP or {}

local U = SPP.Upgrades
local S = SPP.State

local OP = gm.constants.oP

local A = {}

local COOLDOWN_SUSPICIOUS = 0.5

local external = {}

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

    U.register_external(ids, def, list[1].namespace..".skillPlusPlus")
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

SPP.Api = A

api.register = A.register
api.rank = A.rank
setmetatable(api, { __index = function(_, key)
    if key == "RAPI" then return nil end
    error("Skills++ API has no "..tostring(key).."; it has register and rank", 2)
end })
