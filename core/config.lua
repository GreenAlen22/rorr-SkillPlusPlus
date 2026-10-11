-- Числа системы: интервал очков, удержание клавиши, окно отмены, звуки, цвета HUD.

SPP = SPP or {}

local FPS = 60

SPP.Config = {

    namespace = "SkillPlusPlus",

    interval_default = 5,
    interval_min     = 1,
    interval_max     = 10,

    hold_frames = math.floor(0.5 * FPS),

    undo_frames     = 3 * FPS,
    undo_net_frames = math.floor(0.5 * FPS),

    sync_retry_frames = 2 * FPS,

    upgrade_key     = 18,
    upgrade_gamepad = 32779,

    sounds = {
        point = { "wUI_Ready", 1.0, 1.0 },
        buy   = { "wPickup",   1.0, 1.0 },
    },

    hud = {
        fill_colour = 0x55D8F2,
        fill_alpha  = 0.55,
        edge_alpha  = 0.35,

        rank_colour = 0x55D8F2,

        rank_dy           = -7,
        rank_dy_over_stock = -16,

        points_dx = -19,
        points_dy = -3,
        points_dx_coop = -13,
        points_dy_coop = 11,
        points_colour = 0x55D8F2,

        flash_frames = FPS,

        icon_flash_decay = 0.1,
    },
}
