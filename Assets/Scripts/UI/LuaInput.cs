using System;
using System.Collections.Generic;
using UnityEngine;
using XLua;

// Unity legacy input, exported to Lua.
[LuaCallCSharp]
public static class LuaInput
{
    private static readonly Dictionary<string, KeyCode> Map = new Dictionary<string, KeyCode>
    {
        { "Up", KeyCode.UpArrow },
        { "Down", KeyCode.DownArrow },
        { "Left", KeyCode.LeftArrow },
        { "Right", KeyCode.RightArrow },
        { "W", KeyCode.W },
        { "A", KeyCode.A },
        { "S", KeyCode.S },
        { "D", KeyCode.D },
        { "P", KeyCode.P },
        { "R", KeyCode.R },
        { "Space", KeyCode.Space },
        { "Enter", KeyCode.Return },
        { "Escape", KeyCode.Escape }
    };

    public static bool IsKeyDown(string key)
    {
        KeyCode? code = Resolve(key);
        return code.HasValue && Input.GetKeyDown(code.Value);
    }

    public static bool IsKey(string key)
    {
        KeyCode? code = Resolve(key);
        return code.HasValue && Input.GetKey(code.Value);
    }

    private static KeyCode? Resolve(string key)
    {
        if (string.IsNullOrEmpty(key))
        {
            return null;
        }
        KeyCode code;
        if (Map.TryGetValue(key, out code))
        {
            return code;
        }
        KeyCode parsed;
        if (Enum.TryParse(key, true, out parsed))
        {
            return parsed;
        }
        return null;
    }
}
