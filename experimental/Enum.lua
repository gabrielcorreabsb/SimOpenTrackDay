local Enum = {}

-- Use LuaJIT bit.* library instead of Lua 5.3 native bitwise operators.
-- CSP/AC runs LuaJIT 2.0/2.1 (Lua 5.2 compatible), where & | ~ are not operators.

function Enum.hasFlag(state, flag)
    return bit.band(state, flag) ~= 0
end

function Enum.add(state, flag)
    return bit.bor(state, flag)
end

function Enum.remove(state, flag)
    return bit.band(state, bit.bnot(flag))
end

return Enum