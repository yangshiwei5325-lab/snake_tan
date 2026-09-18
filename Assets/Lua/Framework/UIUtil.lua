-- UIUtil.lua - 对 C# 侧 LuaUI 桥的轻封装，Lua UI 代码唯一需要关心的入口。
-- 坐标/尺寸使用 CanvasScaler 参考分辨率 1920x1080 的"设计单位"。
local UIUtil = {}

local CS = CS or _G.CS
local UI = CS.LuaUI

-- 颜色: r,g,b 0-255 -> int(0xRRGGBB)
function UIUtil.Color(r, g, b)
    return (r or 0) * 65536 + (g or 0) * 256 + (b or 0)
end

-- 全屏面板根节点（自带 Canvas，sortingOrder 决定层级）
function UIUtil.NewPanelRoot(name, order, bgColor)
    return UI.CreatePanelRoot(name, order or 0, bgColor or UIUtil.Color(10, 12, 16))
end

function UIUtil.Image(parent, name, color)
    return UI.CreateImage(parent, name, color or UIUtil.Color(255, 255, 255))
end

function UIUtil.Text(parent, name, text, size, color)
    return UI.CreateText(parent, name, text or "", size or 30, color or UIUtil.Color(255, 255, 255))
end

function UIUtil.Button(parent, name, label, fontSize, bgColor, textColor, onClick)
    return UI.CreateButton(parent, name, label, fontSize or 30,
        bgColor or UIUtil.Color(70, 130, 255), textColor or UIUtil.Color(255, 255, 255), onClick)
end

function UIUtil.SetText(go, s)
    UI.SetText(go, s)
end

function UIUtil.SetColor(go, c)
    UI.SetColor(go, c)
end

function UIUtil.SetPos(go, x, y)
    UI.SetPos(go, x, y)
end

function UIUtil.SetSize(go, w, h)
    UI.SetSize(go, w, h)
end

function UIUtil.SetParent(go, parent)
    UI.SetParent(go, parent)
end

function UIUtil.SetActive(go, active)
    UI.SetActive(go, active)
end

function UIUtil.Destroy(go)
    if go ~= nil then
        UI.Destroy(go)
    end
end

return UIUtil
