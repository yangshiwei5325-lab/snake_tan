-- UIManager.lua - Lua 侧的 UI 管理（单例）。
-- 面板类文件约定放在 Game/UI/<名字>.lua，导出类（继承 UIPanel）。
-- Open(name, args) 时按名字 require、实例化、自动分配递增的 sortingOrder。
local Class = require "Framework.Class"
local UIPanel = require "Framework.UIPanel"
local Util = require "Framework.Util" -- 添加工具类

local UIManager = Class.define()
local _instance = nil

function UIManager.Get()
    if not _instance then
        _instance = UIManager.new()
    end
    return _instance
end

function UIManager:ctor()
    self._panels = {}
    self._panelOrder = 100 -- 使用更明确的名称
    self._destroyedPanels = {} -- 跟踪已销毁的面板，用于调试
    self._maxPanelCount = 50 -- 最大面板数量限制，防止内存泄漏
    self._panelCount = 0
end

-- 打开面板。已打开时直接返回旧实例；重复打开同名会先关闭旧的。
function UIManager:Open(name, args)
    -- 参数检查
    if not name or type(name) ~= "string" or name == "" then
        print("[UIManager] invalid panel name:", tostring(name))
        return nil
    end
    
    local exist = self._panels[name]
    if exist and exist:IsOpen() then
        return exist
    end
    
    -- 检查面板数量限制
    if self._panelCount >= self._maxPanelCount then
        print("[UIManager] Warning: Maximum panel count reached (" .. self._maxPanelCount .. "). " ..
              "Consider closing unused panels. Current count: " .. self._panelCount)
    end
    
    -- 如果面板已存在但未打开，先销毁
    if exist then
        self:Close(name)
    end
    
    -- 加载面板类
    local panelClass, loadError = self:LoadPanelClass(name)
    if not panelClass then
        print("[UIManager] Failed to load panel class:", name, loadError)
        return nil
    end
    
    -- 创建面板实例
    local panel = panelClass.new(args or {})
    if not panel then
        print("[UIManager] Failed to create panel instance:", name)
        return nil
    end
    
    -- 设置面板属性
    panel.name = name
    panel.order = self._panelOrder
    self._panelOrder = self._panelOrder + 10
    
    -- 初始化面板
    if not self:InitializePanel(panel) then
        print("[UIManager] Failed to initialize panel:", name)
        return nil
    end
    
    -- 添加到面板列表
    self._panels[name] = panel
    self._panelCount = self._panelCount + 1
    
    return panel
end

function UIManager:Close(name)
    local panel = self._panels[name]
    if not panel then
        return
    end
    
    -- 记录销毁的面板信息（用于调试）
    self._destroyedPanels[name] = {
        destroyTime = os.time(),
        className = tostring(panel.__class__)
    }
    
    -- 销毁面板
    if panel and panel.Destroy then
        pcall(function()
            panel:Destroy()
        end)
    end
    
    -- 从列表中移除
    self._panels[name] = nil
    self._panelCount = math.max(0, self._panelCount - 1)
end

function UIManager:CloseAll()
    -- 创建面板名称的副本，避免在遍历时修改表
    local panelNames = {}
    for name, _ in pairs(self._panels) do
        table.insert(panelNames, name)
    end
    
    for _, name in ipairs(panelNames) do
        self:Close(name)
    end
    
    -- 清理销毁的面板记录（保留最近销毁的）
    local currentTime = os.time()
    for name, info in pairs(self._destroyedPanels) do
        if currentTime - info.destroyTime > 300 then -- 5分钟后清理
            self._destroyedPanels[name] = nil
        end
    end
end

function UIManager:Get(name)
    local panel = self._panels[name]
    if panel and panel:IsOpen() then
        return panel
    end
    return nil
end

-- 加载面板类，带有错误处理
function UIManager:LoadPanelClass(name)
    local ok, result = pcall(require, "Game.UI." .. name)
    if not ok then
        return nil, result -- 返回错误信息
    end
    
    if type(result) ~= "table" or not result.__class then
        return nil, "Invalid panel class format"
    end
    
    return result
end

-- 初始化面板，带有错误处理
function UIManager:InitializePanel(panel)
    if not panel.OnCreate then
        print("[UIManager] Panel missing OnCreate method:", panel.name)
        return false
    end
    
    local ok, err = pcall(function()
        panel:OnCreate()
    end)
    
    if not ok then
        print("[UIManager] Panel initialization failed:", panel.name, err)
        return false
    end
    
    return true
end

-- 调试信息：获取当前面板状态
function UIManager:GetPanelStatus()
    local status = {
        totalPanels = self._panelCount,
        maxPanels = self._maxPanelCount,
        openPanels = {},
        destroyedPanels = self._destroyedPanels
    }
    
    for name, panel in pairs(self._panels) do
        status.openPanels[name] = {
            className = tostring(panel.__class__),
            isOpen = panel:IsOpen(),
            order = panel.order
        }
    end
    
    return status
end

-- 清理方法：强制清理所有资源
function UIManager:Cleanup()
    self:CloseAll()
    self._panels = {}
    self._destroyedPanels = {}
    self._panelOrder = 100
    self._panelCount = 0
    collectgarbage("collect") -- 强制垃圾回收
end

return UIManager