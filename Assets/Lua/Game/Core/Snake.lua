-- Snake.lua - 贪吃蛇核心逻辑（纯 Lua，与表现无关）
local Class = require "Framework.Class"

local Snake = Class.define()

local DIRS = {
    up    = {  0,  1 },
    down  = {  0, -1 },
    left  = { -1,  0 },
    right = {  1,  0 },
}

function Snake:ctor(cfg)
    cfg = cfg or {}
    self.cols = cfg.cols or 20
    self.rows = cfg.rows or 20
    self.tickBase = cfg.tickBase or 0.13
    self.tickMin = cfg.tickMin or 0.06
    self.onStep = cfg.onStep          -- 每走一步(用于刷新画面)
    self.onGameOver = cfg.onGameOver  -- game over(score, length)
    self:Reset()
end

function Snake:Reset()
    local cx = math.floor(self.cols / 2)
    local cy = math.floor(self.rows / 2)
    self.body = {
        { x = cx,     y = cy },
        { x = cx - 1, y = cy },
        { x = cx - 2, y = cy },
    }
    self.dir = { 1, 0 }      -- 当前方向
    self.dirQ = {}           -- 输入缓冲
    self.acc = 0
    self.score = 0
    self.running = true
    self.dead = false
    self.interval = self.tickBase
    self.food = nil
    self:SpawnFood()
end

-- 外部输入: RequestDir("up"/"down"/"left"/"right")
function Snake:RequestDir(key)
    local d = DIRS[key]
    if not d then
        return
    end
    local last = self.dirQ[#self.dirQ] or self.dir
    if d[1] == last[1] and d[2] == last[2] then
        return -- 同向忽略
    end
    if d[1] == -last[1] and d[2] == -last[2] then
        return -- 禁止 180 度掉头
    end
    if #self.dirQ < 3 then
        table.insert(self.dirQ, d)
    end
end

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
end

function Snake:Step()
    local d = table.remove(self.dirQ, 1) or self.dir
    self.dir = d

    local head = self.body[1]
    local nx = head.x + d[1]
    local ny = head.y + d[2]

    -- 撞墙
    if nx < 1 or nx > self.cols or ny < 1 or ny > self.rows then
        self:Die()
        return
    end

    local ate = self.food ~= nil and nx == self.food.x and ny == self.food.y
    if not ate then
        table.remove(self.body) -- 尾巴前移
    end

    -- 撞自己（尾巴已移除，若吃到食物则尾巴保留并同时可能撞到它也算撞）
    for i = 1, #self.body do
        local c = self.body[i]
        if c.x == nx and c.y == ny then
            self:Die()
            return
        end
    end

    table.insert(self.body, 1, { x = nx, y = ny })
    self.steps = self.steps + 1

    if ate then
        self.score = self.score + 10
        local len = #self.body
        self.interval = math.max(self.tickMin, self.tickBase - (len - 3) * 0.005)
        self:SpawnFood()
    end

    if self.onStep then
        self.onStep(self)
    end
end

function Snake:SpawnFood()
    local free = {}
    for y = 1, self.rows do
        for x = 1, self.cols do
            local occupied = false
            for i = 1, #self.body do
                local c = self.body[i]
                if c.x == x and c.y == y then
                    occupied = true
                    break
                end
            end
            if not occupied then
                free[#free + 1] = { x = x, y = y }
            end
        end
    end
    if #free == 0 then
        self.food = nil -- 棋盘填满
        return
    end
    local f = free[math.random(1, #free)]
    self.food = { x = f.x, y = f.y }
end

function Snake:Die()
    self.dead = true
    self.running = false
    if self.onGameOver then
        self.onGameOver(self.score, #self.body)
    end
end

function Snake:GetCells()
    return self.body
end

function Snake:GetFood()
    return self.food
end

function Snake:IsDead()
    return self.dead
end

function Snake:GetScore()
    return self.score
end

return Snake
