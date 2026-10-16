-- Строка улучшения внизу описания навыка.

SPP = SPP or {}

local U = SPP.Upgrades

local OP = gm.constants.oP
local PREFIX = "SkillPlusPlus.skillDesc."

local T = {}

SPP.vanilla_tokens = SPP.vanilla_tokens or {}
local vanilla_tokens = SPP.vanilla_tokens

local token_skill = {}

function T.claim_tokens()
    for skill_id in pairs(U.slot_of) do
        local skill = Skill.wrap(skill_id)
        local token = PREFIX..skill.namespace.."-"..skill.identifier
        if skill.token_description ~= token then
            vanilla_tokens[token] = skill.token_description
            skill.token_description = token
        end
        token_skill[token] = skill_id
    end
end

T.claim_tokens()
Callback.add(Callback.ON_GAME_START, T.claim_tokens)

Initialize.add(Callback.Priority.AFTER * 2, function()
    U.build_maps()
    T.claim_tokens()
end)

Hook.add_post(gm.constants.translate, function(self, other, result, args)
    local skill_id = token_skill[args[1].value]
    if not skill_id then return end

    local vanilla = vanilla_tokens[args[1].value]
    if type(vanilla) ~= "string" then return end
    result.value = gm.translate(vanilla).."\n"..U.describe(U.def(skill_id, U.slot_of[skill_id]))
end)

Hook.add_post(gm.constants._survivor_chef_update_skill_empower, function(self, other, result, args)
    local skill = args[1].value
    local vanilla = skill.description
    if type(vanilla) ~= "string" or token_skill[vanilla] then return end

    local token = PREFIX..vanilla
    vanilla_tokens[token] = vanilla
    token_skill[token] = skill.skill_id
    skill.description = token
end)

function T.claimed()
    local n = 0
    for _ in pairs(token_skill) do n = n + 1 end
    return n
end

local frame = 0
local hovered = {}

Callback.add(Callback.POST_STEP, function()
    frame = frame + 1
end)

function T.hovered(player)
    local h = hovered[player.id]
    if h and h.frame == frame then return h.slot end
    return nil
end

Hook.add_post(gm.constants.hud_draw_skill_info, function(self, other, result, args)
    local actor = args[1].value
    if not Instance.exists(actor) or actor.object_index ~= OP then return end
    hovered[actor.id] = { slot = math.floor(args[2].value), frame = frame }
end)

SPP.Tooltip = T
