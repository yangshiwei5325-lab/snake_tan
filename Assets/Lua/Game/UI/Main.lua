-- Game/UI/Main.lua - 主菜单面板
local Class = require "Framework.Class"
local UIPanel = require "Framework.UIPanel"
local UIUtil = require "Framework.UIUtil"
local Config = require "Game.Config"
local CS = CS or _G.CS

local Main = Class.define(UIPanel)
local COLORS = Config.colors

function Main:ctor(args)
    UIPanel.ctor(self, args)
    self.name = "MainMenu"
end

function Main:OnCreate()
    local root = self:CreateRoot(COLORS.panelBg)
    local flow = self.args.flow

    -- 标题
    local title = UIUtil.Text(root, "Title", "贪吃蛇", 110, COLORS.titleGreen)
    UIUtil.SetSize(title, 700, 160)
    UIUtil.SetPos(title, 960, 800)

    local sub = UIUtil.Text(root, "Sub", "Unity + xLua | Lua 驱动 UI | 逻辑热更演示", 30, COLORS.sub)
    UIUtil.SetSize(sub, 1000, 60)
    UIUtil.SetPos(sub, 960, 700)

    -- 开始游戏
    local btnStart = UIUtil.Button(root, "BtnStart", "开始游戏", 40, COLORS.btn, COLORS.text,
        function()
            flow:StartGame()
        end)
    UIUtil.SetSize(btnStart, 380, 96)
    UIUtil.SetPos(btnStart, 960, 560)

    -- 检查更新（热更演示入口）
    local btnUpdate = UIUtil.Button(root, "BtnUpdate", "检查更新（热更）", 30, 0x5D6D7E, COLORS.text,
        function()
            CS.AppInfo.CheckUpdate()
        end)
    UIUtil.SetSize(btnUpdate, 340, 70)
    UIUtil.SetPos(btnUpdate, 960, 430)

    -- 退出
    local btnQuit = UIUtil.Button(root, "BtnQuit", "退出游戏", 28, 0xCB4335, COLORS.text,
        function()
            CS.AppInfo.Quit()
        end)
    UIUtil.SetSize(btnQuit, 260, 66)
    UIUtil.SetPos(btnQuit, 960, 330)

    -- 热更日志（会被 Flow:OnHotUpdateDone 刷新）
    self._updateLabel = UIUtil.Text(root, "UpdateLog", CS.AppInfo.GetUpdateLog() or "", 24, COLORS.sub)
    UIUtil.SetSize(self._updateLabel, 1700, 50)
    UIUtil.SetPos(self._updateLabel, 960, 160)

    -- 底部版本号
    local ver = UIUtil.Text(root, "Ver", "game version: " .. CS.AppInfo.Version()
        .. "   |   platform: " .. CS.AppInfo.Platform(), 20, 0x566573)
    UIUtil.SetSize(ver, 1200, 40)
    UIUtil.SetPos(ver, 960, 90)
end

function Main:SetUpdateLog(log)
    if self._updateLabel then
        UIUtil.SetText(self._updateLabel, log or "")
    end
end

return Main
