-- Flow.lua - 游戏流程控制：主菜单 <-> 对局 <-> 结算
-- 优化版本：分离游戏逻辑和UI逻辑，减少全局变量
local UIManager = require "Framework.UIManager"
local Config = require "Game.Config"
local SnakeGame = require "Game.Core.SnakeGame"
local GameUI = require "UI.Game.GameUI"

local Flow = {}
Flow.__index = Flow

function Flow.new()
    local o = setmetatable({}, Flow)
    o.ui = UIManager.Get()
    o.state = "menu"
    o.gameLogic = nil
    o.gameUI = nil
    return o
end

function Flow:StartMainMenu()
    self:CloseAllPanels()
    self.gameLogic = nil
    self.gameUI = nil
    self.state = "menu"
    return self.ui:Open("Main", { flow = self })
end

function Flow:StartGame()
    self:CloseAllPanels()
    self.gameLogic = nil
    
    -- 创建游戏UI
    self.gameUI = self.ui:Open("Game", { flow = self })
    
    -- 创建游戏逻辑
    self.gameLogic = SnakeGame.new(self.gameUI)
    self.gameLogic:StartGame()
    
    self.state = "game"
    return self.gameUI
end

function Flow:ShowResult(score, length)
    self.state = "over"
    self.ui:Open("Result", { flow = self, score = score, len = length })
end

-- 手动检查更新后的回调（由 C# 触发）
function Flow:OnHotUpdateDone(log)
    local panel = self.ui:Get("Main")
    if panel and panel.SetUpdateLog then
        panel:SetUpdateLog(log or "")
    end
end

-- 每帧更新
function Flow:Update(dt)
    if self.gameUI and self.gameUI:IsOpen() then
        self.gameUI:OnTick(dt)
    end
end

-- 批量关闭面板
function Flow:CloseAllPanels()
    self.ui:Close("Result")
    self.ui:Close("Game")
end

-- 清理资源
function Flow:Cleanup()
    self:CloseAllPanels()
    self.gameLogic = nil
    self.gameUI = nil
    self.state = "menu"
    collectgarbage("collect") -- 强制垃圾回收
end

return Flow