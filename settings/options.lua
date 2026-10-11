-- Настройки мода: интервал очков и клавиша покупки.

SPP = SPP or {}

local C = SPP.Config

local O = {}

O.page = ModOptions.new()

for _, key in ipairs({ 18, 164, 165 }) do
    gm.input_ignore_key_remove(key)
end

O.upgrade = O.page:find("upgrade") or O.page:add_keybind("upgrade", C.upgrade_key, C.upgrade_gamepad)

local file = TOML.new()

local function clamp(v)
    v = math.floor(tonumber(v) or C.interval_default)
    return math.max(C.interval_min, math.min(C.interval_max, v))
end

local ok, saved = pcall(file.read, file)
if not ok then
    log.warning("SkillPlusPlus: settings file unreadable, using defaults -> "..tostring(saved))
    saved = nil
end
local interval = clamp((saved or {}).interval)

local slider = O.page:find("interval")
    or O.page:add_slider("interval", ModOptionsSlider.DisplayType.RAW, C.interval_min, C.interval_max, true)
slider:add_getter(function() return interval end)
slider:add_setter(function(value)
    interval = clamp(value)
    file:write({ interval = interval })
end)

function O.interval()
    return interval
end

SPP.Options = O
