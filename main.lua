-- Skills++: загрузчик. Модули грузятся по порядку из списка modules,
-- после загрузки сверяется, что каждый создал свою ветку в SPP.

mods["ReturnsAPI-ReturnsAPI"].auto{
    namespace = "SkillPlusPlus",
    mp        = true,
}

local PATH = _ENV["!plugins_mod_folder_path"].."\\"

local modules = {
    "core/config",

    "core/net",

    "core/state",

    "core/assets",

    "upgrades/generic",
    "upgrades/upgrades",
    "upgrades/hooks",
    "upgrades/stats",

    "upgrades/commando",
    "upgrades/huntress",
    "upgrades/enforcer",
    "upgrades/bandit",
    "upgrades/engineer",
    "upgrades/arti",
    "upgrades/mercenary",
    "upgrades/acrid",
    "upgrades/loader",
    "upgrades/chef",
    "upgrades/drifter",
    "upgrades/sniper",
    "upgrades/hand",
    "upgrades/miner",
    "upgrades/pilot",
    "upgrades/robomando",

    "ui/tooltip",
    "ui/input",
    "ui/hud",

    "settings/options",

    "settings/debug",
}

local function load(name)
    local file = (PATH..name..".lua"):gsub("/", "\\")

    local f = io.open(file, "r")
    if not f then
        log.warning("SkillPlusPlus: file not found -> "..file)
        return false
    end
    f:close()

    local ok, err = pcall(function() require(file) end)
    if not ok then
        log.warning("SkillPlusPlus: FAILED to load "..name.." -> "..tostring(err))
        return false
    end
    return true
end

local expected = {
    "Config", "Net", "State", "Assets",
    "Generic", "Upgrades", "Hooks", "Stats",
    "Commando", "Huntress", "Enforcer", "Bandit",
    "Engineer", "Arti", "Mercenary", "Acrid",
    "Loader", "Chef", "Drifter", "Sniper",
    "Hand", "Miner", "Pilot", "Robomando",
    "Tooltip", "Input", "Hud",
    "Options", "Debug",
}

Initialize.add_hotloadable(Callback.Priority.BEFORE, function()
    SPP = SPP or {}

    local loaded = 0
    for _, name in ipairs(modules) do
        if load(name) then loaded = loaded + 1 end
    end

    local missing = {}
    for _, key in ipairs(expected) do
        if not SPP[key] then missing[#missing + 1] = key end
    end

    SPP.Boot = {
        loaded  = loaded,
        total   = #modules,
        missing = #missing > 0 and table.concat(missing, ", ") or "-",
    }

    if loaded == #modules and #missing == 0 then
        log.info("SkillPlusPlus: initialized ("..loaded.."/"..#modules.." modules)")
    else
        log.warning("SkillPlusPlus: initialized PARTIALLY ("..loaded.."/"..#modules
            .." modules; missing SPP: "..SPP.Boot.missing..")")
    end
end)
