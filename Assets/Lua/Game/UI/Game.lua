-- Game/UI/Game.lua - 对局面板：负责棋盘渲染、输入轮询与每帧驱动蛇逻辑
-- 优化版本：减少Lua-C#交互，提高性能
local Class = require "Framework.Class"
local UIPanel = require "Framework.UIPanel"
local UIUtil = require "Framework.UIUtil"
local Config = require "Game.Config"
local CS = CS or _G.CS

local Game = Class.define(UIPanel)
local COLORS = Config.colors

function Game:ctor(args)
    UIPanel.ctor(self, args)
    self.name = "Game"
end

function Game:OnCreate()
    local cfg = Config
    local root = self:CreateRoot(COLORS.panelBg)
    self.flow = self.args.flow
    
    self.cols = cfg.cols
    self.rows = cfg.rows
    self.cell = cfg.cell
    self.boardX = cfg.boardX
    self.boardY = cfg.boardY
    
    -- 得分标题
    self._scoreLabel = UIUtil.Text(root, "Score", "得分 0    长度 3", 46, COLORS.text)
    UIUtil.SetSize(self._scoreLabel, 700, 70)
    UIUtil.SetPos(self._scoreLabel, 960, 860)
    
    -- 顶部操作按钮
    local btnRestart = UIUtil.Button(root, "BtnRestart", "重新开始", 24, 0x5D6D7E, COLORS.text,
        function()
            self.flow:StartGame()
        end)
    UIUtil.SetSize(btnRestart, 190, 58)
    UIUtil.SetPos(btnRestart, 1490, 900)
    
    local btnMenu = UIUtil.Button(root, "BtnMenu", "主菜单", 24, 0x5D6D7E, COLORS.text,
        function()
            self.flow:StartMainMenu()
        end)
    UIUtil.SetSize(btnMenu, 190, 58)
    UIUtil.SetPos(btnMenu, 1740, 900)
    
    -- 棋盘底色
    local boardBg = UIUtil.Image(root, "BoardBg", COLORS.boardBg)
    local boardSize = cfg.cols * cfg.cell
    UIUtil.SetSize(boardBg, boardSize, boardSize)
    UIUtil.SetPos(boardBg, self.boardX, self.boardY)
    
    -- 预创建全部格子，运行期只改颜色（避免每帧创建销毁）
    self._cells = {}
    self._cellKeys = {}
    local halfW = (cfg.cols - 1) * 0.5 * cfg.cell
    local halfH = (cfg.rows - 1) * 0.5 * cfg.cell
    local idx = 0
    for row = 1, cfg.rows do
        for col = 1, cfg.cols do
            idx = idx + 1
            local go = UIUtil.Image(root, "Cell" .. idx, COLORS.empty)
            UIUtil.SetSize(go, cfg.cell, cfg.cell)
            local px = self.boardX - halfW + (col - 1) * cfg.cell
            local py = self.boardY + halfH - (row - 1) * cfg.cell
            UIUtil.SetPos(go, px, py)
            self._cells[idx] = go
            self._cellKeys[idx] = -1
        end
    end
    
    -- 暂停提示
    self._pauseLabel = UIUtil.Text(root, "Pause", "已暂停  (P 继续)", 42, COLORS.yellow)
    UIUtil.SetSize(self._pauseLabel, 600, 70)
    UIUtil.SetPos(self._pauseLabel, 960, 620)
    UIUtil.SetActive(self._pauseLabel, false)
    
    -- 底部提示
    local hint = UIUtil.Text(root, "Hint", "方向键 / WASD 控制方向    P 暂停/继续", 24, COLORS.sub)
    UIUtil.SetSize(hint, 1400, 50)
    UIUtil.SetPos(hint, 960, 90)
    
    self._game = nil
    self._paused = false
    self._lastInputTime = 0 -- 优化：记录最后输入时间
    self._inputInterval = 0.05 -- 输入检查间隔（50ms）
end

-- Flow 创建蛇后调用
function Game:AttachGame(game)
    self._game = game
    self._paused = false
    for i = 1, #self._cellKeys do
        self._cellKeys[i] = -1
    end
    self:Refresh()
end

-- 优化：每帧更新 - 减少输入检查频率
function Game:OnTick(dt)
    local g = self._game
    if not g then
        return
    end
    
    -- 优化：减少每帧的输入检查，使用时间间隔
    self._lastInputTime = self._lastInputTime + dt
    if self._lastInputTime >= self._inputInterval then
        self._lastInputTime = 0
        
        -- 暂停控制
        local input = CS.LuaInput
        if input.IsKeyDown("P") then
            self._paused = not self._paused
            UIUtil.SetActive(self._pauseLabel, self._paused)
        end
        
        if not self._paused then
            -- 键盘输入（减少频繁检查）
            if input.IsKeyDown("Up") or input.IsKeyDown("W") then g:RequestDir("up") end
            if input.IsKeyDown("Down") or input.IsKeyDown("S") then g:RequestDir("down") end
            if input.IsKeyDown("Left") or input.IsKeyDown("A") then g:RequestDir("left") end
            if input.IsKeyDown("Right") or input.IsKeyDown("D") then g:RequestDir("right") end
        end
    end
    
    -- 蛇逻辑更新（保持原有频率）
    g:Update(dt)
end

-- 优化：依据蛇当前状态重绘棋盘（只在变化格子上调用 SetColor）
function Game:Refresh()
    local g = self._game
    if not g then
        return
    end
    
    -- 优化：使用局部变量，减少表访问
    local body = g:GetCells()
    local food = g:GetFood()
    
    -- 优化：使用更快的映射方法
    local map = {}
    local bodyLength = #body
    
    -- 预分配映射表空间
    for i = 1, bodyLength do
        local c = body[i]
        map[c.y * 1000 + c.x] = (i == 1) and 1 or 2 -- 1=head 2=body
    end
    
    if food then
        map[food.y * 1000 + food.x] = 3
    end
    
    -- 优化：批量更新，减少UI调用
    local idx = 0
    local changedCount = 0
    
    for row = 1, self.rows do
        for col = 1, self.cols do
            idx = idx + 1
            local key = map[row * 1000 + col] or 0
            
            -- 只更新变化的格子
            if self._cellKeys[idx] ~= key then
                self._cellKeys[idx] = key
                changedCount = changedCount + 1
                
                local color = COLORS.empty
                if key == 1 then color = COLORS.head
                elseif key == 2 then color = COLORS.snake
                elseif key == 3 then color = COLORS.food
                end
                
                UIUtil.SetColor(self._cells[idx], color)
            end
        end
    end
    
    -- 优化：只在需要时更新分数
    if changedCount > 0 then
        local head = body and body[1]
        if head then
            UIUtil.SetText(self._scoreLabel,
                string.format("得分 %d    长度 %d", g:GetScore(), bodyLength))
        end
    end
end

-- 优化：清理资源
function Game:Destroy()
    self._game = nil
    self._cells = nil
    self._cellKeys = nil
    UIPanel.Destroy(self)
end

return Game