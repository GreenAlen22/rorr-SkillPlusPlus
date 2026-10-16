-- Дрон погибшего игрока: потраченные очки идут в его атаку. Числа - в таблице T.

SPP = SPP or {}

local S = SPP.State
local U = SPP.Upgrades

local OP     = gm.constants.oP
local PDRONE = gm.constants.oPDrone

local T = {
    playerDroneZ = { droneDamage = 0.20, droneHeal = 0.10,
                     text = { { "droneDamage", "pct" }, { "droneHeal", "share" } } },
}

U.register({ "playerDroneZ" }, T.playerDroneZ)
U.show_line("playerDroneZ", 0)

local D = { T = T }

function D.level(drone)
    if not Instance.exists(drone) or drone.object_index ~= PDRONE then return 0 end
    local owner = drone.owner
    if not Instance.exists(owner) or owner.object_index ~= OP then return 0 end
    return S.get(owner).spent
end

DamageCalculate.add(function(api)
    local parent = api.parent
    if not Instance.exists(parent) or parent.object_index ~= PDRONE then return end
    local level = D.level(parent)
    if level > 0 then api.damage_mult(1 + T.playerDroneZ.droneDamage * level) end
end)

local function nearest_ally(drone, owner)
    local best, best_distance = nil, math.huge
    for _, player in ipairs(S.players()) do
        if player.id ~= owner.id and player.team == drone.team and not S.bool(player.dead) then
            local distance = gm.point_distance(drone.x, drone.y, player.x, player.y)
            if distance < best_distance then best, best_distance = player, distance end
        end
    end
    return best
end

Callback.add(Callback.ON_HIT_PROC, function(attacker, target, hit_info)
    if not Net.host then return end
    if D.level(attacker) < 1 then return end
    local ally = nearest_ally(attacker, attacker.owner)
    if ally then ally:heal(hit_info.damage_true * T.playerDroneZ.droneHeal) end
end)

SPP.Drone = D
