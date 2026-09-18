-- ObjectPool.lua - 对象池系统，减少频繁创建销毁的UI元素
local Class = require "Framework.Class"

local ObjectPool = Class.define()

function ObjectPool.new(createFunc, destroyFunc, initialSize)
    local self = setmetatable({}, ObjectPool)
    self._createFunc = createFunc or function() return {} end
    self._destroyFunc = destroyFunc or function(obj) end
    self._pool = {}
    self._activeObjects = {}
    
    -- 初始化对象池
    for i = 1, initialSize or 10 do
        local obj = self._createFunc()
        table.insert(self._pool, obj)
    end
    
    return self
end

-- 获取对象
function ObjectPool:Get()
    local obj
    
    if #self._pool > 0 then
        obj = table.remove(self._pool)
    else
        obj = self._createFunc()
    end
    
    table.insert(self._activeObjects, obj)
    return obj
end

-- 回收对象
function ObjectPool:Recycle(obj)
    -- 检查对象是否在活动列表中
    for i, activeObj in ipairs(self._activeObjects) do
        if activeObj == obj then
            table.remove(self._activeObjects, i)
            break
        end
    end
    
    -- 调用销毁函数（如果有的话）
    self._destroyFunc(obj)
    
    -- 添加到池中
    table.insert(self._pool, obj)
end

-- 回收所有活动对象
function ObjectPool:RecycleAll()
    for _, obj in ipairs(self._activeObjects) do
        self._destroyFunc(obj)
    end
    
    self._activeObjects = {}
    self._pool = {}
    
    -- 重新初始化池
    for i = 1, 10 do
        local obj = self._createFunc()
        table.insert(self._pool, obj)
    end
end

-- 获取池大小
function ObjectPool:GetPoolSize()
    return #self._pool
end

-- 获取活动对象数量
function ObjectPool:GetActiveCount()
    return #self._activeObjects
end

-- 清理池
function ObjectPool:Clear()
    self:RecycleAll()
end

return ObjectPool