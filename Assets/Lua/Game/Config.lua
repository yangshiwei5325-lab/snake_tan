-- Config.lua - 游戏与 UI 参数集中配置
return {
    -- 棋盘
    cols = 20,
    rows = 20,
    cell = 26,          -- 每格像素
    boardX = 960,       -- 棋盘中心(设计坐标)
    boardY = 470,

    -- 速度
    tickBase = 0.13,    -- 初始每步间隔(秒)
    tickMin = 0.06,     -- 最快间隔

    -- 颜色 (0xRRGGBB)
    colors = {
        panelBg    = 0x0C0F14,
        boardBg    = 0x141A22,
        empty      = 0x1E2530,
        snake      = 0x58D68D,
        head       = 0x98F5B0,
        food       = 0xE74C3C,
        text       = 0xECF0F1,
        sub        = 0x95A5A6,
        btn        = 0x2E86DE,
        titleGreen = 0x2ECC71,
        danger     = 0xE74C3C,
        yellow     = 0xF1C40F,
    },
}
