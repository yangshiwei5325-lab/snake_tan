-- UIPanel.lua - 所有 UI 面板的基类。
-- 子类只需要：
--   1) ctor(args) 里调用 UIPanel.ctor(self, args)
--   2) 重写 OnCreate() 构建界面
--   3) （可选）重写 OnTick(dt) 做每帧逻辑
local Class = require "Framework.Class"
local UIUtil = require "Framework.UIUtil"

local UIPanel = Class.define()

function UIPanel:ctor(args)
    self.args = args or {}
    self.order = self.args.order or 0
    self.root = nil
    self.closed = false
end

-- 由 UIManager 调用：负责真正创建面板（子类重写并调用 CreateRoot）
function UIPanel:OnCreate()
end

-- 每帧回调（可选重写）
function UIPanel:OnTick(dt)
end

function UIPanel:CreateRoot(bgColor)
    self.root = UIUtil.NewPanelRoot(self.name or "Panel", self.order,
        bgColor or UIUtil.Color(10, 12, 16))
    return self.root
end

function UIPanel:Destroy()
    if self.root then
        UIUtil.Destroy(self.root)
        self.root = nil
    end
    self.closed = true
end

function UIPanel:IsOpen()
    return self.root ~= nil and not self.closed
end

return UIPanel
