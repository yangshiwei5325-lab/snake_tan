-- Game/UI/Result.lua - 结算面板
local Class = require "Framework.Class"
local UIPanel = require "Framework.UIPanel"
local UIUtil = require "Framework.UIUtil"
local Config = require "Game.Config"

local Result = Class.define(UIPanel)
local COLORS = Config.colors

function Result:ctor(args)
    UIPanel.ctor(self, args)
    self.name = "Result"
end

function Result:OnCreate()
    local root = self:CreateRoot(0x1B0A0E)
    local flow = self.args.flow
    local score = self.args.score or 0
    local len = self.args.len or 3

    local title = UIUtil.Text(root, "Title", "游戏结束", 100, COLORS.danger)
    UIUtil.SetSize(title, 800, 140)
    UIUtil.SetPos(title, 960, 820)

    local scoreText = UIUtil.Text(root, "Score",
        string.format("最终得分: %d      长度: %d", score, len), 48, COLORS.text)
    UIUtil.SetSize(scoreText, 1000, 70)
    UIUtil.SetPos(scoreText, 960, 660)

    local btnAgain = UIUtil.Button(root, "BtnAgain", "再来一局", 36, COLORS.btn, COLORS.text,
        function()
            flow:StartGame()
        end)
    UIUtil.SetSize(btnAgain, 340, 86)
    UIUtil.SetPos(btnAgain, 960, 480)

    local btnMenu = UIUtil.Button(root, "BtnMenu", "返回主菜单", 32, 0x5D6D7E, COLORS.text,
        function()
            flow:StartMainMenu()
        end)
    UIUtil.SetSize(btnMenu, 320, 80)
    UIUtil.SetPos(btnMenu, 960, 360)
end

return Result
