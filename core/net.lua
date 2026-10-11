-- Сеть: покупка и отмена уровня идут на хост, хост рассылает всем итоговое состояние игрока.

SPP = SPP or {}

local N = {}

N.sent, N.received = 0, 0

N.buy = Packet.new("buyRank")
N.buy:set_serializers(
    function(buffer, slot)
        buffer:write_byte(slot)
    end,
    function(buffer, player)
        local slot = buffer:read_byte()
        N.received = N.received + 1
        if not Net.host then return end
        if not player or not Instance.exists(player) then return end
        SPP.State.try_buy(player, slot)
    end
)

N.state = Packet.new("rankState")
N.state:set_serializers(
    function(buffer, player, interval, spent, bonus, rank)
        buffer:write_instance(player)
        buffer:write_byte(interval)
        buffer:write_ushort(spent)
        buffer:write_ushort(bonus)
        for slot = 0, 3 do
            buffer:write_byte(rank[slot])
        end
    end,
    function(buffer, sender)
        local player   = buffer:read_instance()
        local interval = math.floor(buffer:read_byte())
        local spent    = math.floor(buffer:read_ushort())
        local bonus    = math.floor(buffer:read_ushort())
        local rank     = {}
        for slot = 0, 3 do
            rank[slot] = math.floor(buffer:read_byte())
        end
        N.received = N.received + 1

        if Net.host then return end
        if not Instance.exists(player) then return end
        SPP.State.apply(player, interval, spent, bonus, rank)
    end
)

N.sync = Packet.new("rankSync")
N.sync:set_serializers(
    function(buffer) end,
    function(buffer, player)
        N.received = N.received + 1
        if not Net.host then return end
        SPP.State.broadcast_all()
    end
)

N.refund = Packet.new("refundRank")
N.refund:set_serializers(
    function(buffer) end,
    function(buffer, player)
        N.received = N.received + 1
        if not Net.host then return end
        if not player or not Instance.exists(player) then return end
        SPP.State.try_refund(player)
    end
)

function N.request_buy(slot)
    if Net.host then return end
    N.buy:send_to_host(slot)
    N.sent = N.sent + 1
end

function N.request_refund()
    if Net.host then return end
    N.refund:send_to_host()
    N.sent = N.sent + 1
end

function N.request_sync()
    if Net.host then return end
    N.sync:send_to_host()
    N.sent = N.sent + 1
end

function N.send_state(player)
    if not (Net.online and Net.host) then return end
    local rec = SPP.State.get(player)
    N.state:send_to_all(player, SPP.State.interval() or 0, rec.spent, rec.bonus, rec.rank)
    N.sent = N.sent + 1
end

SPP.Net = N
