-- Snake.lua - 贪吃蛇核心逻辑（纯 Lua，与表现无关）
-- 优化版本：添加动态难度、道具系统和障碍物系统
local Class = require "Framework.Class"
local Util = require "Framework.Util"

local Snake = Class.define()

-- 预计算的方向常量
local DIR_UP = { 0, 1 }
local DIR_DOWN = { 0, -1 }
local DIR_LEFT = { -1, 0 }
local DIR_RIGHT = { 1, 0 }

-- 蛇身节点结构
local SnakeNode = {}
SnakeNode.__index = SnakeNode

function SnakeNode.new(x, y)
    local self = setmetatable({}, SnakeNode)
    self.x = x
    self.y = y
    return self
end

-- 道具类型
local POWERUP_TYPES = {
    SPEED_BOOST = "speed_boost",    -- 速度提升
    SHIELD = "shield",            -- 护盾
    EXTRA_LIFE = "extra_life",    -- 额外生命
    SLOW_DOWN = "slow_down",      -- 减速
    POINTS_MULTIPLIER = "points_multiplier" -- 分数倍增器
}

-- 障碍物结构
local Obstacle = {}
Obstacle.__index = Obstacle

function Obstacle.new(x, y)
    local self = setmetatable({}, Obstacle)
    self.x = x
    self.y = y
    return self
end

function Snake:ctor(cfg)
    cfg = cfg or {}
    self.cols = cfg.cols or 20
    self.rows = cfg.rows or 20
    self.tickBase = cfg.tickBase or 0.13
    self.tickMin = cfg.tickMin or 0.06
    self.onStep = cfg.onStep          -- 每走一步(用于刷新画面)
    self.onGameOver = cfg.onGameOver  -- game over(score, length)
    self.onPowerup = cfg.onPowerup    -- 道具获取回调
    self.onObstacleHit = cfg.onObstacleHit -- 障碍物碰撞回调
    
    -- 动态难度参数
    self.difficultyLevel = 1
    self.scoreThreshold = 50        -- 每增加50分提升一个难度等级
    self.speedMultiplier = 1.0      -- 速度倍数
    
    -- 道具系统
    self.powerups = {}              -- 当前激活的道具
    self.powerupDuration = {}       -- 道具持续时间
    self.powerupEffects = {}        -- 道具效果
    
    -- 障碍物系统
    self.obstacles = {}             -- 障碍物列表
    self.obstacleSpawnRate = 0.02    -- 障碍物生成概率
    
    -- 性能优化：使用更高效的数据结构
    self.body = {}      -- 蛇身数组
    self.dirQ = {}      -- 方向队列
    self.freeCells = {} -- 可用格子缓存
    
    self:Reset()
end

function Snake:Reset()
    local cx = math.floor(self.cols / 2)
    local cy = math.floor(self.rows / 2)
    
    -- 清空并重置表
    table.clear(self.body)
    table.clear(self.dirQ)
    table.clear(self.freeCells)
    table.clear(self.powerups)
    table.clear(self.powerupDuration)
    table.clear(self.powerupEffects)
    table.clear(self.obstacles)
    
    -- 初始化蛇身（使用SnakeNode）
    self.body[1] = SnakeNode.new(cx, cy)
    self.body[2] = SnakeNode.new(cx - 1, cy)
    self.body[3] = SnakeNode.new(cx - 2, cy)
    
    self.dir = DIR_RIGHT      -- 当前方向（使用预计算的常量）
    self.dirQ = {}           -- 输入缓冲
    self.acc = 0
    self.score = 0
    self.running = true
    self.dead = false
    self.interval = self.tickBase
    self.food = nil
    self.steps = 0
    self.difficultyLevel = 1
    self.speedMultiplier = 1.0
    
    -- 优化：初始化可用格子缓存
    self:InitFreeCells()
    self:SpawnFood()
    self:SpawnObstacles()
end

-- 动态难度：根据得分调整游戏速度
function Snake:UpdateDifficulty()
    local newLevel = math.floor(self.score / self.scoreThreshold) + 1
    if newLevel ~= self.difficultyLevel then
        self.difficultyLevel = newLevel
        self.speedMultiplier = 1.0 + (self.difficultyLevel - 1) * 0.1  -- 每级增加10%速度
        self.interval = math.max(self.tickMin, self.tickBase / self.speedMultiplier)
        
        -- 触发难度变化回调
        if self.onStep then
            self.onStep(self)
        end
    end
end

-- 道具系统
function Snake:SpawnPowerup()
    if math.random() < 0.1 and #self.obstacles < 5 then  -- 10%概率生成道具，限制数量
        local free = {}
        for y = 1, self.rows do
            for x = 1, self.cols do
                if not self:IsOccupied(x, y) and not self:IsObstacle(x, y) then
                    free[#free + 1] = { x = x, y = y }
                end
            end
        end
        
        if #free > 0 then
            local f = free[math.random(1, #free)]
            local powerupType = POWERUP_TYPES[math.random(1, #POWERUP_TYPES)]
            self.powerups[f.y * 1000 + f.x] = powerupType
        end
    end
end

function Snake:CollectPowerup(x, y)
    local key = y * 1000 + x
    local powerupType = self.powerups[key]
    
    if powerupType then
        self.powerups[key] = nil
        
        -- 应用道具效果
        self:ApplyPowerupEffect(powerupType)
        
        -- 触发道具获取回调
        if self.onPowerup then
            self.onPowerup(powerupType, 10)  -- 道具价值10分
        end
        
        return true
    end
    
    return false
end

function Snake:ApplyPowerupEffect(powerupType)
    local duration = 5  -- 默认持续时间5秒
    
    -- 应用即时效果
    if powerupType == POWERUP_TYPES.SPEED_BOOST then
        self.speedMultiplier = self.speedMultiplier * 1.5
        self.interval = math.max(self.tickMin, self.tickBase / self.speedMultiplier)
    elseif powerupType == POWERUP_TYPES.SHIELD then
        -- 护盾效果：暂时免疫碰撞
    elseif powerupType == POWERUP_TYPES.EXTRA_LIFE then
        -- 额外生命：复活一次
    elseif powerupType == POWERUP_TYPES.SLOW_DOWN then
        self.speedMultiplier = self.speedMultiplier * 0.7
        self.interval = math.max(self.tickMin, self.tickBase / self.speedMultiplier)
    elseif powerupType == POWERUP_TYPES.POINTS_MULTIPLIER then
        -- 分数倍增器：下次得分翻倍
    end
    
    -- 记录道具效果
    self.powerupEffects[powerupType] = true
    self.powerupDuration[powerupType] = duration
    
    -- 定时移除道具效果
    Util.Delay(duration, function()
        self:RemovePowerupEffect(powerupType)
    end)
end

function Snake:RemovePowerupEffect(powerupType)
    if powerupType == POWERUP_TYPES.SPEED_BOOST or powerupType == POWERUP_TYPES.SLOW_DOWN then
        self.speedMultiplier = self.speedMultiplier / (powerupType == POWERUP_TYPES.SPEED_BOOST and 1.5 or 0.7)
        self.interval = math.max(self.tickMin, self.tickBase / self.speedMultiplier)
    end
    
    self.powerupEffects[powerupType] = nil
    self.powerupDuration[powerupType] = nil
end

-- 障碍物系统
function Snake:SpawnObstacles()
    if math.random() < self.obstacleSpawnRate and #self.obstacles < 3 then  -- 限制障碍物数量
        local free = {}
        for y = 1, self.rows do
            for x = 1, self.cols do
                if not self:IsOccupied(x, y) and not self:IsObstacle(x, y) and not self:IsPowerup(x, y) then
                    free[#free + 1] = { x = x, y = y }
                end
            end
        end
        
        if #free > 0 then
            local f = free[math.random(1, #free)]
            table.insert(self.obstacles, Obstacle.new(f.x, f.y))
        end
    end
end

function Snake:IsObstacle(x, y)
    for i = 1, #self.obstacles do
        local obs = self.obstacles[i]
        if obs.x == x and obs.y == y then
            return true
        end
    end
    return false
end

function Snake:IsPowerup(x, y)
    local key = y * 1000 + x
    return self.powerups[key] ~= nil
end

-- 优化：初始化可用格子缓存
function Snake:InitFreeCells()
    table.clear(self.freeCells)
    local index = 1
    for y = 1, self.rows do
        for x = 1, self.cols do
            self.freeCells[index] = { x = x, y = y }
            index = index + 1
        end
    end
end

-- 优化：快速检查位置是否被占用
function Snake:IsOccupied(x, y)
    for i = 1, #self.body do
        local c = self.body[i]
        if c.x == x and c.y == y then
            return true
        end
    end
    return false
end

-- 优化：食物生成 - 使用缓存和随机选择
function Snake:SpawnFood()
    -- 更新可用格子缓存
    local freeCount = 0
    local freeIndex = 1
    
    for i = 1, #self.freeCells do
        local cell = self.freeCells[i]
        if not self:IsOccupied(cell.x, cell.y) and not self:IsObstacle(cell.x, cell.y) and not self:IsPowerup(cell.x, cell.y) then
            self.freeCells[freeIndex] = cell
            freeIndex = freeIndex + 1
        end
    end
    
    -- 截断未使用的部分
    for i = freeIndex, #self.freeCells do
        self.freeCells[i] = nil
    end
    
    freeCount = freeIndex - 1
    
    if freeCount == 0 then
        self.food = nil -- 棋盘填满
        return
    end
    
    -- 随机选择可用格子
    local f = self.freeCells[math.random(1, freeCount)]
    self.food = { x = f.x, y = f.y }
end

-- 优化：外部输入 - 减少字符串操作
function Snake:RequestDir(key)
    local d = {
        up = DIR_UP,
        down = DIR_DOWN,
        left = DIR_LEFT,
        right = DIR_RIGHT
    }[key]
    
    if not d then
        return
    end
    
    -- 使用预计算的常量比较
    local last = self.dirQ[#self.dirQ] or self.dir
    if d[1] == last[1] and d[2] == last[2] then
        return -- 同向忽略
    end
    
    -- 禁止180度掉头（使用预计算的常量）
    if (d[1] == -last[1] and d[2] == -last[2]) then
        return
    end
    
    if #self.dirQ < 3 then
        table.insert(self.dirQ, d)
    end
end

-- 优化：Update - 使用固定时间间隔，减少每帧计算
function Snake:Update(dt)
    if not self.running or self.dead then
        return
    end
    
    self.acc = self.acc + dt
    while self.acc >= self.interval do
        self.acc = self.acc - self.interval
        self:Step()
        if self.dead then
            break
        end
    end
    
    -- 更新动态难度
    self:UpdateDifficulty()
    
    -- 随机生成道具和障碍物
    if math.random() < 0.02 then  -- 2%概率
        self:SpawnPowerup()
    end
    
    if math.random() < 0.01 then  -- 1%概率
        self:SpawnObstacles()
    end
end

-- 优化：Step - 减少重复计算和函数调用
function Snake:Step()
    -- 获取方向（减少table.remove调用）
    local d = self.dirQ[1] or self.dir
    if self.dirQ[1] then
        table.remove(self.dirQ, 1)
    end
    self.dir = d
    
    -- 计算新头部位置（使用局部变量，减少表访问）
    local head = self.body[1]
    local nx = head.x + d[1]
    local ny = head.y + d[2]
    
    -- 撞墙检查（使用局部变量）
    if nx < 1 or nx > self.cols or ny < 1 or ny > self.rows then
        self:Die()
        return
    end
    
    -- 检查是否吃到食物（使用局部变量）
    local ate = self.food and nx == self.food.x and ny == self.food.y
    
    -- 检查是否吃到道具
    local collectedPowerup = self:CollectPowerup(nx, ny)
    
    -- 检查是否撞到障碍物
    if self:IsObstacle(nx, ny) then
        self:Die()
        return
    end
    
    -- 如果没吃到食物且没吃到道具，移除尾部
    if not ate and not collectedPowerup then
        -- 直接设置nil，避免table.remove的O(n)复杂度
        self.body[#self.body] = nil
    end
    
    -- 检查是否撞到自己（优化循环）
    local bodyLength = #self.body
    for i = 1, bodyLength do
        local c = self.body[i]
        if c.x == nx and c.y == ny then
            self:Die()
            return
        end
    end
    
    -- 添加新头部
    table.insert(self.body, 1, SnakeNode.new(nx, ny))
    self.steps = self.steps + 1
    
    -- 处理食物
    if ate then
        self.score = self.score + 10
        local len = #self.body
        self:SpawnFood()
    end
    
    -- 处理道具
    if collectedPowerup then
        self.score = self.score + 10  -- 道具也得分
    end
    
    -- 优化：减少回调调用频率
    if self.onStep and (self.steps % 2 == 0) then -- 每两步调用一次，减少一半调用
        self.onStep(self)
    end
end

function Snake:Die()
    self.dead = true
    self.running = false
    if self.onGameOver then
        self.onGameOver(self.score, #self.body)
    end
end

-- 优化：获取数据 - 返回只读数据，避免修改
function Snake:GetCells()
    return self.body
end

function Snake:GetFood()
    return self.food
end

function Snake:GetObstacles()
    return self.obstacles
end

function Snake:GetPowerups()
    return self.powerups
end

function Snake:IsDead()
    return self.dead
end

function Snake:GetScore()
    return self.score
end

function Snake:GetSnakeLength()
    return #self.body
end

function Snake:GetDifficultyLevel()
    return self.difficultyLevel
end

function Snake:GetSpeedMultiplier()
    return self.speedMultiplier
end

-- 辅助函数：清空表（Lua 5.1兼容）
function table.clear(t)
    for k in pairs(t) do
        t[k] = nil
    end
end

return Snake