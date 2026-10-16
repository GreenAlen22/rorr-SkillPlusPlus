-- Реестр улучшений: какая таблица у навыка и как выглядит строка в подсказке.

SPP = SPP or {}

local G = SPP.Generic

local U = {}

local function skill_id(identifier)
    local skill = Skill.find(identifier, "ror")
    if not skill then error("vanilla skill ror-"..identifier.." not found") end
    return skill.value
end

function U.ids(...)
    local set = {}
    for _, identifier in ipairs({ ... }) do set[skill_id(identifier)] = true end
    return set
end

local without_damage = {}
for slot, def in pairs(G.slots) do
    if def.cooldown or def.stock_every then
        without_damage[slot] = { cooldown = def.cooldown, stock_every = def.stock_every }
    end
end

local no_damage_ids = U.ids(table.unpack(G.no_damage))

local registered = {}

local roots = {}
local OWN_ROOT = "SkillPlusPlus.upgrade"

function U.def(id, slot)
    local own = registered[id]
    if own ~= nil then return own or nil end
    if no_damage_ids[id] then return without_damage[slot] end
    return G.slots[slot]
end

function U.ranked_skill(actor, slot)
    local id = actor:get_active_skill(slot).skill_id
    if U.slot_of[id] == nil then id = actor:get_default_skill(slot).skill_id end
    return id
end

function U.rank_for(actor, ids)
    for slot = 0, 3 do
        if ids[U.ranked_skill(actor, slot)] then
            return SPP.State.rank(actor, slot)
        end
    end
    return 0
end

local alias_ids = {}
for identifier, asked in pairs(G.reads_other) do
    alias_ids[skill_id(identifier)] = skill_id(asked)
end

U.slot_of = {}
U.asks_for = {}
U.asked = {}

local outside = {}

function U.build_maps()
    local slot_of, asks_for = {}, {}
    for id, asked in pairs(alias_ids) do asks_for[id] = asked end
    local survivors = Global.class_survivor
    for i = 0, #survivors - 1 do
        local survivor = Survivor.wrap(i)
        for slot = 0, 3 do
            for _, skill in ipairs(survivor:get_skills(slot)) do
                local id = skill.value
                if slot_of[id] == nil then slot_of[id] = slot end

                local upgrade = slot == 3 and tonumber(skill.upgrade_skill)
                if upgrade and upgrade > 0 then
                    if asks_for[upgrade] == nil then asks_for[upgrade] = id end
                    if slot_of[upgrade] == nil then slot_of[upgrade] = 3 end
                end
            end
        end
    end
    for id, slot in pairs(outside) do
        if slot_of[id] == nil then slot_of[id] = slot end
    end
    local asked = {}
    for _, id in pairs(asks_for) do asked[id] = true end
    U.slot_of, U.asks_for, U.asked = slot_of, asks_for, asked
end

U.build_maps()

function U.show_line(identifier, slot)
    outside[skill_id(identifier)] = slot
    U.build_maps()
end

Callback.add(Callback.ON_GAME_START, U.build_maps)

local function percent(fraction)
    return tostring(math.floor(fraction * 100 + 0.5))
end

local function t(key, ...)
    return gm.translate("SkillPlusPlus.upgrade."..key, ...)
end

local function decimal(x)
    local s = string.format("%.2f", x):gsub("0+$", ""):gsub("%.$", "")
    return (s:gsub("%.", t("decimal")))
end

local FORMATS = {
    pct   = function(v) local p = percent(v); return p, p end,
    count = function(v) local n = tostring(v); return n, n end,
    sec   = function(v) local s = decimal(v); return s, s end,
    every = function(v) return tostring(v) end,
    from  = function(v) return tostring(v) end,
    share = function(v) return percent(v) end,
}

function U.def_problem(def)
    for _, key in ipairs({ "damage", "cooldown", "stock_every" }) do
        if def[key] ~= nil and type(def[key]) ~= "number" then
            return key.." must be a number"
        end
    end
    if def.cooldown and not (def.cooldown > 0 and def.cooldown <= 1) then
        return "cooldown is a multiplier per level and must be in (0, 1]: 0.92 = -8% per level"
    end
    if def.stock_every and (def.stock_every < 1 or def.stock_every % 1 ~= 0) then
        return "stock_every must be a whole number of levels, 1 or more"
    end
    for _, entry in ipairs(def.text or {}) do
        local field, format, extra, extra_format = entry[1], entry[2], entry[3], entry[4]
        if type(def[field]) ~= "number" then
            return "upgrade text names a missing or non-number field: "..tostring(field)
        end
        if extra and type(def[extra]) ~= "number" then
            return "upgrade text names a missing or non-number field: "..tostring(extra)
        end
        if not FORMATS[format] then return "unknown upgrade text format: "..tostring(format) end
        if extra_format and not FORMATS[extra_format] then
            return "unknown upgrade text format: "..tostring(extra_format)
        end
    end
    return nil
end

local function store(ids, def, root)
    if def then roots[def] = root end
    for _, id in ipairs(ids) do registered[id] = def end
    U.build_maps()
end

function U.register(identifiers, def)
    local problem = U.def_problem(def)
    if problem then error(problem, 2) end
    local ids = {}
    for _, identifier in ipairs(identifiers) do
        local id = skill_id(identifier)
        ids[#ids + 1] = id
        if def.reads then alias_ids[id] = skill_id(def.reads) end
    end
    store(ids, def, OWN_ROOT)
end

function U.register_external(ids, def, root)
    store(ids, def, root)
end

function U.describe(def)
    if not def then return t("line", t("none")) end

    local parts = {}
    if def.damage then parts[#parts + 1] = t("damage", FORMATS.pct(def.damage)) end
    if def.cooldown then parts[#parts + 1] = t("cooldown", FORMATS.pct(1 - def.cooldown)) end
    for _, entry in ipairs(def.text or {}) do
        local field, format, extra, extra_format = entry[1], entry[2], entry[3], entry[4]
        local args = { FORMATS[format](def[field]) }
        if extra then args[#args + 1] = (FORMATS[extra_format or format](def[extra])) end
        parts[#parts + 1] = gm.translate(roots[def].."."..field, table.unpack(args))
    end
    if def.stock_every == 1 then
        parts[#parts + 1] = t("stockPerLevel")
    elseif def.stock_every then
        parts[#parts + 1] = t("stockEvery", FORMATS.every(def.stock_every))
    end
    local line = table.concat(parts, ", ")
    if line:sub(-1) ~= "." then line = line.."." end
    return t("line", line)
end

SPP.Upgrades = U
