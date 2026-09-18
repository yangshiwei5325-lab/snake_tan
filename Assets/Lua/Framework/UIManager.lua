-- UIManager.lua - Lua 侧的 UI 管理（单例）。
-- 面板类文件约定放在 Game/UI/<名字>.lua，导出类（继承 UIPanel）。
-- Open(name, args) 时按名字 require、实例化、自动分配递增的 sortingOrder。
local Class = require "Framework.Class"
local UIPanel = require "Framework.UIPanel"

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
    self._layer = 100
end

-- 打开面板。已打开时直接返回旧实例；重复打开同名会先关闭旧的。
function UIManager:Open(name, args)
    local exist = self._panels[name]
    if exist and exist:IsOpen() then
        return exist
    end
    if exist then
        exist:Destroy()
        self._panels[name] = nil
    end

    local ok, cls = pcall(require, "Game.UI." .. name)
    if not ok then
        print("[UIManager] open panel failed:", name, tostring(cls))
        return nil
    end

    local panel = cls.new(args or {})
    if not panel.name then
        panel.name = name
    end
    panel.order = self._layer
    self._layer = self._layer + 10

    panel:OnCreate()
    self._panels[name] = panel
    return panel
end

function UIManager:Close(name)
    local p = self._panels[name]
    if p then
        p:Destroy()
        self._panels[name] = nil
    end
end

function UIManager:CloseAll()
    for name, _ in pairs(self._panels) do
        self:Close(name)
    end
end

function UIManager:Get(name)
    local p = self._panels[name]
    if p and p:IsOpen() then
        return p
    end
    return nil
end

return UIManager
