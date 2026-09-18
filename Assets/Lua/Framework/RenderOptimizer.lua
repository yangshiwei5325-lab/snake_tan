-- RenderOptimizer.lua - 渲染优化系统，合并UI元素减少绘制调用
local Class = require "Framework.Class"
local ObjectPool = require "Framework.ObjectPool"

local RenderOptimizer = Class.define()

function RenderOptimizer.new()
    local self = setmetatable({}, RenderOptimizer)
    self._cellPool = ObjectPool.new(
        function() return { x = 0, y = 0, width = 0, height = 0, color = 0 } end,
        function(obj) end,
        100 -- 初始池大小
    )
    self._renderQueue = {}
    self._tempRects = {}
    return self
end

-- 添加渲染任务
function RenderOptimizer:AddRenderTask(x, y, width, height, color)
    table.insert(self._renderQueue, {
        x = x,
        y = y,
        width = width,
        height = height,
        color = color
    })
end

-- 优化渲染队列，合并相邻的同色区域
function RenderOptimizer:OptimizeRenderQueue()
    -- 清空临时矩形列表
    table.clear(self._tempRects)
    
    -- 按颜色分组
    local colorGroups = {}
    
    for _, task in ipairs(self._renderQueue) do
        local color = task.color
        if not colorGroups[color] then
            colorGroups[color] = {}
        end
        table.insert(colorGroups[color], task)
    end
    
    -- 对每个颜色组进行合并
    self._renderQueue = {}
    
    for color, tasks in pairs(colorGroups) do
        -- 按x坐标排序
        table.sort(tasks, function(a, b) return a.x < b.x end)
        
        -- 合并相邻的同色区域
        local mergedRects = {}
        local currentRect = nil
        
        for _, task in ipairs(tasks) do
            if not currentRect then
                currentRect = {
                    x = task.x,
                    y = task.y,
                    width = task.width,
                    height = task.height,
                    color = color
                }
            else
                -- 检查是否可以合并
                if task.y == currentRect.y and task.height == currentRect.height and
                   task.x == currentRect.x + currentRect.width then
                    -- 可以水平合并
                    currentRect.width = currentRect.width + task.width
                else
                    -- 不能合并，保存当前矩形并开始新的
                    table.insert(mergedRects, currentRect)
                    currentRect = {
                        x = task.x,
                        y = task.y,
                        width = task.width,
                        height = task.height,
                        color = color
                    }
                end
            end
        end
        
        -- 添加最后一个矩形
        if currentRect then
            table.insert(mergedRects, currentRect)
        end
        
        -- 添加到最终渲染队列
        for _, rect in ipairs(mergedRects) do
            table.insert(self._renderQueue, rect)
        end
    end
end

-- 执行渲染
function RenderOptimizer:ExecuteRender(UIUtil)
    for _, rect in ipairs(self._renderQueue) do
        -- 这里可以使用更高效的渲染方法，比如批量渲染
        -- 目前使用简单的单个元素渲染
        UIUtil.SetColor(rect.x, rect.y, rect.width, rect.height, rect.color)
    end
end

-- 清空渲染队列
function RenderOptimizer:Clear()
    self._renderQueue = {}
end

-- 获取渲染队列大小
function RenderOptimizer:GetRenderQueueSize()
    return #self._renderQueue
end

-- 辅助函数：清空表
function table.clear(t)
    for k in pairs(t) do
        t[k] = nil
    end
end

return RenderOptimizer