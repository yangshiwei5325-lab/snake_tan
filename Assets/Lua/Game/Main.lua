-- Main.lua - Lua 侧入口。
-- require 本模块时会立即启动主菜单；同时向全局表 LuaEntry 注册 C# 需要的
-- 回调（Update / HotUpdateDone），C# 的 LuaManager 在 Boot 后从这里取函数。
local Flow = require "Game.Flow"
local CS = CS or _G.CS

math.randomseed(os.time())

local flow = nil

local M = {}

function M.Update(dt)
    if flow then
        flow:Update(dt)
    end
end

function M.HotUpdateDone(log)
    if flow then
        flow:OnHotUpdateDone(log or "")
    end
end

_G.LuaEntry = M

-- 启动主菜单
flow = Flow.new()
flow:StartMainMenu()

return M
