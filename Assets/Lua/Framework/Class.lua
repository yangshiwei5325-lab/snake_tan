-- Class.lua - 极简 OOP 支持（热更演示中的基础框架）
local Class = {}

-- 创建一个新类；传入 base 则继承之
function Class.define(base)
    local cls = {}
    cls.__index = cls
    if base then
        cls.__base = base
        setmetatable(cls, { __index = base })
    end

    function cls.new(...)
        local obj = setmetatable({}, cls)
        if obj.ctor then
            obj:ctor(...)
        end
        return obj
    end

    return cls
end

return Class
