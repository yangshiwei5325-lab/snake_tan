-- GameUI.lua - 对局面板UI逻辑（纯 Lua）
-- 优化版本：添加道具系统、障碍物和音效支持
local Class = require "Framework.Class"
local UIPanel = require "Framework.UIPanel"
local UIUtil = require "Framework.UIUtil"
local Config = require "Game.Config"
local ObjectPool = require "Framework.ObjectPool"
local RenderOptimizer = require "Framework.RenderOptimizer"
local CS = CS or _G.CS

local GameUI = Class.define(UIPanel)
local COLORS = Config.colors

function GameUI:ctor(args)
    UIPanel.ctor(self, args)
    self.name = "Game"
    
    -- 初始化对象池
    self._cellPool = ObjectPool.new(
        function() return { x = 0, y = 0, width = 0, height = 0, color = 0 } end,
        function(obj) end,
        400 -- 初始池大小（20x20的格子）
    )
    
    -- 初始化渲染优化器
    self._renderOptimizer = RenderOptimizer.new()
    
    -- 音效系统
    self._audioSource = CS.UnityEngine.GameObject.Find("AudioManager").GetComponent(CS.UnityEngine.AudioSource)
    self._eatSound = CS.UnityEngine.Resources.Load(CS.UnityEngine.AudioClip, "Sounds/Eat")
    self._dieSound = CS.UnityEngine.Resources.Load(CS.UnityEngine.AudioClip, "Sounds/Die")
    self._powerupSound = CS.UnityEngine.Resources.Load(CS.UnityEngine.AudioClip, "Sounds/Powerup")
    
    -- 道具和障碍物显示
    self._powerupIndicators = {}
    self._obstacleIndicators = {}
end

function GameUI:OnCreate()
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
            self:RestartGame()
        end)
    UIUtil.SetSize(btnRestart, 190, 58)
    UIUtil.SetPos(btnRestart, 1490, 900)
    
    local btnMenu = UIUtil.Button(root, "BtnMenu", "主菜单", 24, 0x5D6D7E, COLORS.text,
        function()
            self:GoToMainMenu()
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
    
    -- 道具提示
    self._powerupLabel = UIUtil.Text(root, "Powerup", "", 24, COLORS.green)
    UIUtil.SetSize(self._powerupLabel, 400, 50)
    UIUtil.SetPos(self._powerupLabel, 960, 200)
    UIUtil.SetActive(self._powerupLabel, false)
    
    -- 难度显示
    self._difficultyLabel = UIUtil.Text(root, "Difficulty", "难度: 1", 24, COLORS.red)
    UIUtil.SetSize(self._difficultyLabel, 200, 50)
    UIUtil.SetPos(self._difficultyLabel, 960, 150)
    
    self._game = nil
    self._paused = false
    self._lastInputTime = 0 -- 优化：记录最后输入时间
    self._inputInterval = 0.05 -- 输入检查间隔（50ms）
    self._lastRefreshTime = 0 -- 优化：记录最后刷新时间
    self._refreshInterval = 0.1 -- 刷新间隔（100ms）
    self._scoreDirty = false -- 分数是否需要更新
    self._powerupNotification = ""
    self._powerupNotificationTime = 0
end

-- 关联游戏逻辑
function GameUI:AttachGame(game)
    self._game = game
    self._paused = false
    for i = 1, #self._cellKeys do
        self._cellKeys[i] = -1
    end
    self:Refresh()
end

-- 每帧更新
function GameUI:OnTick(dt)
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
            self:TogglePause()
        end
        
        if not self._paused then
            -- 键盘输入（减少频繁检查）
            if input.IsKeyDown("Up") or input.IsKeyDown("W") then g:HandleInput("up") end
            if input.IsKeyDown("Down") or input.IsKeyDown("S") then g:HandleInput("down") end
            if input.IsKeyDown("Left") or input.IsKeyDown("A") then g:HandleInput("left") end
            if input.IsKeyDown("Right") or input.IsKeyDown("D") then g:HandleInput("right") end
        end
    end
    
    -- 游戏逻辑更新
    g:UpdateGame(dt)
    
    -- 优化：只在需要时刷新UI，减少不必要的更新
    self._lastRefreshTime = self._lastRefreshTime + dt
    if self._lastRefreshTime >= self._refreshInterval or self._scoreDirty then
        self._lastRefreshTime = 0
        self:Refresh()
        self._scoreDirty = false
    end
    
    -- 更新道具通知
    if self._powerupNotificationTime > 0 then
        self._powerupNotificationTime = self._powerupNotificationTime - dt
        if self._powerupNotificationTime <= 0 then
            UIUtil.SetActive(self._powerupLabel, false)
            self._powerupNotification = ""
        end
    end
end

-- 优化：只在必要时刷新UI
function GameUI:Refresh()
    local g = self._game
    if not g then
        return
    end
    
    -- 清空渲染队列
    self._renderOptimizer:Clear()
    
    -- 优化：使用局部变量，减少表访问
    local body = g:GetCells()
    local food = g:GetFood()
    local obstacles = g.GetObstacles and g:GetObstacles() or {}
    local powerups = g.GetPowerups and g:GetPowerups() or {}
    
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
    
    -- 添加障碍物到映射
    for i = 1, #obstacles do
        local obs = obstacles[i]
        map[obs.y * 1000 + obs.x] = 4 -- 4=obstacle
    end
    
    -- 添加道具到映射
    for key, powerupType in pairs(powerups) do
        map[key] = 5 -- 5=powerup
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
                elseif key == 4 then color = COLORS.obstacle
                elseif key == 5 then color = COLORS.powerup
                end
                
                -- 添加到渲染队列而不是直接设置颜色
                local cellX = self.boardX - ((self.cols - 1) * 0.5 * self.cell) + (col - 1) * self.cell
                local cellY = self.boardY + ((self.rows - 1) * 0.5 * self.cell) - (row - 1) * self.cell
                
                self._renderOptimizer:AddRenderTask(cellX, cellY, self.cell, self.cell, color)
            end
        end
    end
    
    -- 优化渲染队列，合并相邻的同色区域
    self._renderOptimizer:OptimizeRenderQueue()
    
    -- 执行渲染
    self._renderOptimizer:ExecuteRender(UIUtil)
    
    -- 优化：只在需要时更新分数
    if changedCount > 0 or self._scoreDirty then
        UIUtil.SetText(self._scoreLabel,
            string.format("得分 %d    长度 %d", g:GetScore(), g:GetSnakeLength()))
        self._scoreDirty = false
    end
end

-- 显示暂停界面
function GameUI:ShowPause()
    UIUtil.SetActive(self._pauseLabel, true)
end

-- 隐藏暂停界面
function GameUI:HidePause()
    UIUtil.SetActive(self._pauseLabel, false)
end

-- 显示游戏结束
function GameUI:ShowGameOver(score, length)
    self:GoToResult(score, length)
end

-- 重新开始游戏
function GameUI:RestartGame()
    if self._game then
        self._game:RestartGame()
    end
end

-- 返回主菜单
function GameUI:GoToMainMenu()
    self.flow:StartMainMenu()
end

-- 返回结果界面
function GameUI:GoToResult(score, length)
    self.flow:ShowResult(score, length)
end

-- 切换暂停状态
function GameUI:TogglePause()
    if self._paused then
        self:HidePause()
    else
        self:ShowPause()
    end
end

-- 标记分数需要更新
function GameUI:MarkScoreDirty()
    self._scoreDirty = true
end

-- 显示道具通知
function GameUI:ShowPowerupNotification(powerupType)
    local powerupNames = {
        ["speed_boost"] = "速度提升！",
        ["shield"] = "护盾激活！",
        ["extra_life"] = "额外生命！",
        ["slow_down"] = "减速效果！",
        ["points_multiplier"] = "分数倍增！"
    }
    
    self._powerupNotification = powerupNames[powerupType] or "获得道具！"
    UIUtil.SetText(self._powerupLabel, self._powerupNotification)
    UIUtil.SetActive(self._powerupLabel, true)
    self._powerupNotificationTime = 2.0 -- 显示2秒
    
    -- 播放音效
    if self._audioSource and self._powerupSound then
        self._audioSource.PlayOneShot(self._powerupSound)
    end
    
    -- 震动反馈
    CS.UnityEngine.Handheld.Vibrate()
end

-- 更新难度显示
function GameUI:UpdateDifficultyDisplay(level, speedMultiplier)
    UIUtil.SetText(self._difficultyLabel, string.format("难度: %d (速度: %.1fx)", level, speedMultiplier))
    
    -- 播放音效
    if self._audioSource and self._eatSound then
        self._audioSource.PlayOneShot(self._eatSound)
    end
end

-- 显示难度变化
function GameUI:ShowDifficultyChange(level)
    UIUtil.SetText(self._difficultyLabel, string.format("难度提升到 %d！", level))
    UIUtil.SetActive(self._difficultyLabel, true)
    
    -- 2秒后隐藏
    Util.Delay(2.0, function()
        UIUtil.SetActive(self._difficultyLabel, false)
    end)
end

-- 清理资源
function GameUI:Destroy()
    self._game = nil
    self._cells = nil
    self._cellKeys = nil
    self._cellPool:Clear()
    self._renderOptimizer:Clear()
    UIPanel.Destroy(self)
end

return GameUI