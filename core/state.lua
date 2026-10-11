-- Очки и уровни навыков игроков. Записывает только хост (или одиночная игра).

SPP = SPP or {}

local C = SPP.Config

local S = {}

function S.bool(v)
    if type(v) == "number" then return v > 0.5 end
    return v and true or false
end

function S.level()
    if not S.bool(Global.__run_exists) then return nil end
    local director = Global.director
    if not Instance.exists(director) then return nil end
    return math.floor(tonumber(director.player_level) or 0)
end

local run_interval = nil

function S.interval()
    if run_interval then return run_interval end
    if Net.host then
        run_interval = SPP.Options.interval()
        return run_interval
    end
    return nil
end

function S.get(player)
    local rec = Instance.get_data(player, "rank", C.namespace)
    if not rec.rank then
        rec.spent = 0
        rec.bonus = 0
        rec.rank  = { [0] = 0, 0, 0, 0 }
    end
    return rec
end

function S.rank(player, slot)
    return S.get(player).rank[slot]
end

function S.free(player)
    local level, interval = S.level(), S.interval()
    if not level or not interval then return nil end
    local rec = S.get(player)
    return math.floor(level / interval) + rec.bonus - rec.spent
end

function S.players()
    return Instance.find_all(gm.constants.oP)
end

local RANK_MAX, POINTS_MAX = 255, 65535

function S.rankable(player, slot)
    if tonumber(player.artifact_lock_choice) == slot then return false end
    if S.get(player).rank[slot] >= RANK_MAX then return false end
    return SPP.Upgrades.def(player:get_active_skill(slot).skill_id, slot) ~= nil
end

function S.apply(player, interval, spent, bonus, rank)
    if not Instance.exists(player) then return end
    if interval > 0 then run_interval = interval end

    local rec = S.get(player)
    rec.spent = spent
    rec.bonus = bonus
    for slot = 0, 3 do
        rec.rank[slot] = rank[slot]
    end

    player:queue_recalculate_stats()
end

S.frame = 0

local last_buy = {}

local function set_rank(player, slot, delta)
    local rec  = S.get(player)
    local rank = { [0] = rec.rank[0], rec.rank[1], rec.rank[2], rec.rank[3] }
    rank[slot] = rank[slot] + delta
    S.apply(player, S.interval(), rec.spent + delta, rec.bonus, rank)
    SPP.Net.send_state(player)
end

function S.try_buy(player, slot)
    if not Instance.exists(player) then return end
    slot = math.floor(tonumber(slot) or -1)
    if slot < 0 or slot > 3 then return end

    local free = S.free(player)
    if not free or free < 1 then return end
    if not S.rankable(player, slot) then return end
    if S.get(player).spent >= POINTS_MAX then return end

    set_rank(player, slot, 1)
    last_buy[player.id] = { slot = slot, frame = S.frame }
end

function S.try_refund(player)
    if not Instance.exists(player) then return end
    local last = last_buy[player.id]
    last_buy[player.id] = nil
    if not last then return end
    if S.frame - last.frame > C.undo_frames + C.undo_net_frames then return end
    if S.get(player).rank[last.slot] < 1 then return end

    set_rank(player, last.slot, -1)
end

function S.buy(player, slot)
    if Net.host then
        S.try_buy(player, slot)
    else
        SPP.Net.request_buy(slot)
    end
end

function S.refund(player)
    if Net.host then
        S.try_refund(player)
    else
        SPP.Net.request_refund()
    end
end

function S.grant(n)
    if not Net.host then return end
    for _, player in ipairs(S.players()) do
        local rec = S.get(player)
        local bonus = math.max(0, math.min(POINTS_MAX, rec.bonus + n))
        S.apply(player, S.interval(), rec.spent, bonus, rec.rank)
        SPP.Net.send_state(player)
    end
end

function S.broadcast_all()
    for _, player in ipairs(S.players()) do
        SPP.Net.send_state(player)
    end
end

Callback.add(Callback.ON_GAME_START, function()
    run_interval = nil
    last_buy = {}
end)

Callback.add(Callback.ON_STAGE_START, function()
    if Net.host then S.broadcast_all() end
end)

local frames_since_sync = 0

Callback.add(Callback.POST_STEP, function()
    S.frame = S.frame + 1

    if not Net.client or run_interval then return end
    if not S.level() then return end

    frames_since_sync = frames_since_sync + 1
    if frames_since_sync >= C.sync_retry_frames then
        frames_since_sync = 0
        SPP.Net.request_sync()
    end
end)

SPP.State = S
