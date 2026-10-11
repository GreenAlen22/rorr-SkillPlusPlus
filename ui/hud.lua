-- HUD: уровень над иконкой навыка, свободные очки, заливка при покупке.

SPP = SPP or {}

local C = SPP.Config
local S = SPP.State

local H = C.hud

local fa_left, fa_center = 0, 1
local fa_top, fa_middle            = 0, 1
local c_white, c_black             = 0xFFFFFF, 0x000000

local HUD = {}

local seen = {}
local points_flash = {}
local icon_flash   = {}

Callback.add(Callback.ON_GAME_START, function()
    seen, points_flash, icon_flash = {}, {}, {}
end)

Callback.add(Callback.POST_STEP, function()
    if not S.level() then return end

    for _, player in ipairs(S.players()) do
        local id = player.id
        if points_flash[id] and points_flash[id] > 0 then points_flash[id] = points_flash[id] - 1 end
        local flashes = icon_flash[id]
        if flashes then
            for slot, alpha in pairs(flashes) do flashes[slot] = math.max(0, alpha - H.icon_flash_decay) end
        end

        local free = S.free(player)
        if free and S.bool(player.is_local) then
            local rec = S.get(player)
            local rank = rec.rank
            local last = seen[id]
            if last then
                if free > last.free and rec.spent >= last.spent then
                    SPP.Assets.play("point")
                    points_flash[id] = H.flash_frames
                end
                for slot = 0, 3 do
                    if rank[slot] > last.rank[slot] then
                        SPP.Assets.play("buy")
                        icon_flash[id] = icon_flash[id] or {}
                        icon_flash[id][slot] = 1
                    end
                end
            end
            seen[id] = { free = free, spent = rec.spent, rank = { [0] = rank[0], rank[1], rank[2], rank[3] } }
        end
    end
end)

local function split_screen()
    return tonumber(Global.coop) == 1
end

local function icon_layout(player)
    if split_screen() and (tonumber(player.input_player_index) or 0) ~= 0 then
        return 18, function(slot) return slot * 20 end
    end
    return 24, function(slot) return slot * 30 + (slot > 1 and 3 or 0) end
end

local function text_with_shadow(x, y, text, colour)
    gm.draw_set_colour(c_black)
    gm.draw_text(x + 1, y + 1, text)
    gm.draw_set_colour(colour)
    gm.draw_text(x, y, text)
end

Callback.add(Callback.ON_PLAYER_HUD_DRAW, function(player, x, y)
    if not Instance.exists(player) then return end
    if Instance.exists(player.player_drone) then return end

    local id = player.id
    local rank = S.get(player).rank
    local size, offset = icon_layout(player)
    local pixel = gm.constants.sSinglePixel

    gm.gpu_set_colorwriteenable(true, true, true, false)

    local fill_slot, fill = SPP.Input.progress(player)
    if fill_slot then
        local ix = x + offset(fill_slot)
        local h = math.floor(size * fill + 0.5)
        gm.draw_sprite_ext(pixel, 0, ix, y + size - h, size, h, 0, H.fill_colour, H.fill_alpha)
        gm.draw_sprite_ext(pixel, 0, ix, y + size - h, size, 1, 0, c_white, H.edge_alpha)
    end

    local flashes = icon_flash[id]
    if flashes then
        for slot, alpha in pairs(flashes) do
            if alpha > 0 then
                gm.draw_sprite_ext(pixel, 0, x + offset(slot), y, size, size, 0, c_white, alpha)
            end
        end
    end

    gm.gpu_set_colorwriteenable(true, true, true, true)

    gm.draw_set_font(gm.variable_global_get("fntSkillStockNum"))
    gm.draw_set_halign(fa_center)
    gm.draw_set_valign(fa_middle)
    local locked = tonumber(player.artifact_lock_choice)
    for slot = 0, 3 do
        if rank[slot] > 0 and slot ~= locked then
            local skill = player:get_active_skill(slot)
            local has_stock = skill.max_stock > 1 or skill.stock > 1
            local dy = has_stock and H.rank_dy_over_stock or H.rank_dy
            text_with_shadow(x + offset(slot) + math.floor(size / 2), y + dy, tostring(rank[slot]), H.rank_colour)
        end
    end

    gm.draw_set_font(gm.constants.fntNormal)

    local free = S.free(player)
    if free and free > 0 then
        gm.draw_set_halign(fa_center)
        gm.draw_set_valign(fa_middle)
        local colour = (points_flash[id] or 0) > 0 and c_white or H.points_colour
        local dx, dy = H.points_dx, H.points_dy
        if split_screen() then dx, dy = H.points_dx_coop, H.points_dy_coop end
        text_with_shadow(x + dx, y + dy, "+"..free, colour)
    end

    gm.draw_set_colour(c_white)
    gm.draw_set_halign(fa_left)
    gm.draw_set_valign(fa_top)
end)

SPP.Hud = HUD
