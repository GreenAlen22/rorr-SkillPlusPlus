-- Общий бонус за уровень для навыков без своей таблицы.

SPP = SPP or {}

local G = {}

G.slots = {
    [0] = { damage = 0.15 },
    [1] = { damage = 0.10, cooldown = 0.92 },
    [2] = { cooldown = 0.90, stock_every = 2 },
    [3] = { damage = 0.10, cooldown = 0.92 },
}

G.no_damage = {
    "engineerV", "engineerVBoosted", "engineerV2", "engineerV2Boosted",
    "sniperV", "sniperVBoosted",
    "mercenaryV2", "mercenaryV2Boosted",
    "loaderX",
    "chefV", "chefVBoosted",
    "pilotV", "pilotVBoosted",
    "drifterX2", "drifterV", "drifterVBoosted", "drifterV2", "drifterV2Boosted",
    "robomandoV", "robomandoVBoosted",
}

G.reads_other = {
    handX2           = "handX",
    handX3           = "handX",
    loaderV2         = "loaderV",
    loaderV2Boosted  = "loaderVBoosted",
}

SPP.Generic = G
