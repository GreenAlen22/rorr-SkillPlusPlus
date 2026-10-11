-- Ванильные звуки мода.

SPP = SPP or {}

local C = SPP.Config

local A = {}

A.sounds = {}

for event, s in pairs(C.sounds) do
    local id = gm.constants[s[1]]
    if not id then error("vanilla sound "..s[1].." not found") end
    A.sounds[event] = { id = id, volume = s[2], pitch = s[3] }
end

function A.play(event)
    local s = A.sounds[event]
    gm.sound_play_global(s.id, s.volume, s.pitch)
end

SPP.Assets = A
