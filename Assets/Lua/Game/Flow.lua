-- Flow.lua - 游戏流程控制：主菜单 <-> 对局 <-> 结算
local UIManager = require "Framework.UIManager"
local Config = require "Game.Config"

local Flow = {}
Flow.__index = Flow

function Flow.new()
    local o = setmetatable({}, Flow)
    o.ui = UIManager.Get()
    o.state = "menu"
    o.snake = nil
    return o
end

function Flow:StartMainMenu()
    self.ui:Close("Result")
    self.ui:Close("Game")
    self.snake = nil
    self.state = "menu"
    return self.ui:Open("Main", { flow = self })
end

function Flow:StartGame()
    self.ui:Close("Result")
    self.ui:Close("Game")
    self.snake = nil

    local panel = self.ui:Open("Game", { flow = self })
    local Snake = require "Game.Core.Snake"

    local snake = Snake.new({
        cols = Config.cols,
        rows = Config.rows,
        tickBase = Config.tickBase,
        tickMin = Config.tickMin,
        onStep = function()
            if panel:IsOpen() then
                panel:Refresh()
            end
        end,
        onGameOver = function(score, len)
            self:ShowResult(score, len)
        end,
    })

    self.snake = snake
    panel:AttachGame(snake)
    self.state = "game"
    return panel
end

function Flow:ShowResult(score, len)
    self.state = "over"
    self.ui:Open("Result", { flow = self, score = score, len = len })
end

-- 手动检查更新后的回调（由 C# 触发）
function Flow:OnHotUpdateDone(log)
    local panel = self.ui:Get("Main")
    if panel and panel.SetUpdateLog then
        panel:SetUpdateLog(log or "")
    end
end

-- 每帧转发给当前对局面板
function Flow:Update(dt)
    local panel = self.ui:Get("Game")
    if panel then
        panel:OnTick(dt)
    end
end

return Flow
