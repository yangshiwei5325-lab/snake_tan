-- UIUtilOptimized.lua - 优化后的UI工具类，包含对象池和批量渲染功能
local Class = require "Framework.Class"
local Util = require "Framework.Util"

local UIUtilOptimized = {}

-- 对象池管理
local ObjectPool = Class.define()

function ObjectPool:ctor(createFunc, resetFunc, maxSize)
    self._createFunc = createFunc
    self._resetFunc = resetFunc
    self._maxSize = maxSize or 50
    self._pool = {}
    self._activeCount = 0
end

function ObjectPool:Get()
    local obj = table.remove(self._pool)
    if not obj then
        obj = self._createFunc()
        self._activeCount = self._activeCount + 1
    else
        if self._resetFunc then
            self._resetFunc(obj)
        end
    end
    return obj
end

function ObjectPool:Return(obj)
    if self._activeCount > 0 and #self._pool < self._maxSize then
        table.insert(self._pool, obj)
    else
        -- 超过池大小或没有活跃对象，直接销毁
        self:Destroy(obj)
    end
end

function ObjectPool:Destroy(obj)
    -- 实际销毁逻辑
    if obj and obj.Destroy then
        obj:Destroy()
    end
    self._activeCount = math.max(0, self._activeCount - 1)
end

function ObjectPool:Clear()
    for _, obj in ipairs(self._pool) do
        self:Destroy(obj)
    end
    self._pool = {}
    self._activeCount = 0
end

-- UI对象池
local UIPools = {}

-- 颜色: r,g,b 0-255 -> int(0xRRGGBB)
function UIUtilOptimized.Color(r, g, b)
    return (r or 0) * 65536 + (g or 0) * 256 + (b or 0)
end

-- 创建或获取对象池
local function GetOrCreatePool(poolName, createFunc, resetFunc, maxSize)
    if not UIPools[poolName] then
        UIPools[poolName] = ObjectPool.new(createFunc, resetFunc, maxSize)
    end
    return UIPools[poolName]
end

-- 全屏面板根节点（自带 Canvas，sortingOrder 决定层级）
function UIUtilOptimized.NewPanelRoot(name, order, bgColor)
    return UI.CreatePanelRoot(name, order or 0, bgColor or UIUtilOptimized.Color(10, 12, 16))
end

-- 优化后的Image创建 - 使用对象池
function UIUtilOptimized.Image(parent, name, color)
    local pool = GetOrCreatePool("ImagePool", 
        function() return UI.CreateImage(parent, name, color or UIUtilOptimized.Color(255, 255, 255)) end,
        function(obj) UI.SetColor(obj, color or UIUtilOptimized.Color(255, 255, 255)) end,
        100)
    return pool:Get()
end

-- 优化后的Text创建 - 使用对象池
function UIUtilOptimized.Text(parent, name, text, size, color)
    local pool = GetOrCreatePool("TextPool", 
        function() return UI.CreateText(parent, name, text or "", size or 30, color or UIUtilOptimized.Color(255, 255, 255)) end,
        function(obj) 
            UI.SetText(obj, text or "")
            UI.SetSize(obj, 100, 30) -- 默认大小
            UI.SetColor(obj, color or UIUtilOptimized.Color(255, 255, 255))
        end,
        50)
    local textObj = pool:Get()
    UI.SetText(textObj, text or "")
    UI.SetSize(textObj, 100, 30) -- 默认大小
    UI.SetColor(textObj, color or UIUtilOptimized.Color(255, 255, 255))
    return textObj
end

-- 优化后的Button创建 - 使用对象池
function UIUtilOptimized.Button(parent, name, label, fontSize, bgColor, textColor, onClick)
    local pool = GetOrCreatePool("ButtonPool", 
        function() return UI.CreateButton(parent, name, label, fontSize or 30,
            bgColor or UIUtilOptimized.Color(70, 130, 255), textColor or UIUtilOptimized.Color(255, 255, 255), onClick) end,
        function(obj) 
            UI.SetText(obj, label)
            UI.SetSize(obj, 100, 30) -- 默认大小
            UI.SetColor(obj, bgColor or UIUtilOptimized.Color(70, 130, 255))
            UI.SetTextColor(obj, textColor or UIUtilOptimized.Color(255, 255, 255))
        end,
        30)
    local btn = pool:Get()
    UI.SetText(btn, label)
    UI.SetSize(btn, 100, 30) -- 默认大小
    UI.SetColor(btn, bgColor or UIUtilOptimized.Color(70, 130, 255))
    UI.SetTextColor(btn, textColor or UIUtilOptimized.Color(255, 255, 255))
    return btn
end

-- 批量设置文本（减少调用次数）
function UIUtilOptimized.BatchSetText(objects, text)
    for _, obj in ipairs(objects) do
        UI.SetText(obj, text)
    end
end

-- 批量设置颜色（减少调用次数）
function UIUtilOptimized.BatchSetColor(objects, color)
    for _, obj in ipairs(objects) do
        UI.SetColor(obj, color)
    end
end

-- 批量设置位置（减少调用次数）
function UIUtilOptimized.BatchSetPos(objects, x, y)
    for _, obj in ipairs(objects) do
        UI.SetPos(obj, x, y)
    end
end

-- 批量设置大小（减少调用次数）
function UIUtilOptimized.BatchSetSize(objects, w, h)
    for _, obj in ipairs(objects) do
        UI.SetSize(obj, w, h)
    end
end

-- 批量设置父对象（减少调用次数）
function UIUtilOptimized.BatchSetParent(objects, parent)
    for _, obj in ipairs(objects) do
        UI.SetParent(obj, parent)
    end
end

-- 批量设置激活状态（减少调用次数）
function UIUtilOptimized.BatchSetActive(objects, active)
    for _, obj in ipairs(objects) do
        UI.SetActive(obj, active)
    end
end

-- 返回对象到池
function UIUtilOptimized.ReturnToPool(obj)
    -- 根据对象类型返回到对应的池
    if obj and obj.name then
        local poolName = "UnknownPool"
        if string.find(obj.name, "Image") then
            poolName = "ImagePool"
        elseif string.find(obj.name, "Text") then
            poolName = "TextPool"
        elseif string.find(obj.name, "Button") then
            poolName = "ButtonPool"
        end
        
        if UIPools[poolName] then
            UIPools[poolName]:Return(obj)
        else
            UIUtilOptimized.Destroy(obj)
        end
    else
        UIUtilOptimized.Destroy(obj)
    end
end

-- 批量返回对象到池
function UIUtilOptimized.BatchReturnToPool(objects)
    for _, obj in ipairs(objects) do
        UIUtilOptimized.ReturnToPool(obj)
    end
end

-- 清理所有对象池
function UIUtilOptimized.ClearAllPools()
    for _, pool in pairs(UIPools) do
        pool:Clear()
    end
    UIPools = {}
end

-- 原有功能保持不变
function UIUtilOptimized.SetText(go, s)
    UI.SetText(go, s)
end

function UIUtilOptimized.SetColor(go, c)
    UI.SetColor(go, c)
end

function UIUtilOptimized.SetPos(go, x, y)
    UI.SetPos(go, x, y)
end

function UIUtilOptimized.SetSize(go, w, h)
    UI.SetSize(go, w, h)
end

function UIUtilOptimized.SetParent(go, parent)
    UI.SetParent(go, parent)
end

function UIUtilOptimized.SetActive(go, active)
    UI.SetActive(go, active)
end

function UIUtilOptimized.Destroy(go)
    if go ~= nil then
        UI.Destroy(go)
    end
end

return UIUtilOptimized