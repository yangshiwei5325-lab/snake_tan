using System;
using System.IO;
using System.Text;
using UnityEngine;
using XLua;

// Owns the single xLua LuaEnv used by the game.
//
// Custom loader search order:
//   1. persistent/lua        (hot-updated / installed files, takes effect after reboot)
//   2. StreamingAssets/lua   (built-in package published by the editor tool)
//   3. Assets/Lua            (source files, editor-only convenience so you can
//                             run before publishing StreamingAssets)
//
// Entry protocol: Game.Main registers a global table "LuaEntry" with
//   Update(dt)      - called every frame by Unity
//   HotUpdateDone(log) - called after a manual hot-update check
public static class LuaManager
{
    private static LuaEnv _env;
    private static LuaTable _entry;
    private static LuaFunction _updateFn;
    private static LuaFunction _hotUpdateDoneFn;

    public static bool IsRunning
    {
        get { return _env != null; }
    }

    public static void Boot()
    {
        Shutdown();
        try
        {
            LuaEnv env = new LuaEnv();
            env.AddLoader(CustomLoader);
            env.DoString("require('Game.Main')");

            _env = env;
            _entry = env.Global.Get<LuaTable>("LuaEntry");
            if (_entry != null)
            {
                _updateFn = _entry.Get<LuaFunction>("Update");
                _hotUpdateDoneFn = _entry.Get<LuaFunction>("HotUpdateDone");
            }
            Debug.Log("[LuaManager] boot ok, entry found: " + (_entry != null));
        }
        catch (Exception e)
        {
            Debug.LogError("[LuaManager] boot failed: " + e);
            Shutdown();
        }
    }

    public static void Shutdown()
    {
        _updateFn = null;
        _hotUpdateDoneFn = null;
        _entry = null;
        if (_env != null)
        {
            try
            {
                _env.Dispose();
            }
            catch (Exception e)
            {
                Debug.LogWarning("[LuaManager] dispose failed: " + e.Message);
            }
            _env = null;
        }
    }

    public static void Tick(float dt)
    {
        if (_env == null || _updateFn == null)
        {
            return;
        }
        try
        {
            _updateFn.Call(dt);
        }
        catch (Exception e)
        {
            Debug.LogError("[LuaManager] tick error: " + e);
        }
    }

    public static void NotifyHotUpdateDone(string log)
    {
        if (_env == null || _hotUpdateDoneFn == null)
        {
            return;
        }
        try
        {
            _hotUpdateDoneFn.Call(log ?? "");
        }
        catch (Exception e)
        {
            Debug.LogError("[LuaManager] notify error: " + e);
        }
    }

    private static byte[] CustomLoader(string name)
    {
        string rel = name.Replace('.', '/');
        if (!rel.EndsWith(".lua", StringComparison.Ordinal))
        {
            rel += ".lua";
        }

        string[] roots =
        {
            Path.Combine(Application.persistentDataPath, "lua"),
            Path.Combine(Application.streamingAssetsPath, "lua"),
            Path.Combine(Application.dataPath, "Lua")
        };

        foreach (string root in roots)
        {
            try
            {
                string path = Path.Combine(root, rel);
                if (File.Exists(path))
                {
                    return File.ReadAllBytes(path);
                }
            }
            catch
            {
                // keep searching other roots
            }
        }

        return Encoding.UTF8.GetBytes("error('lua module not found: " + name + "')");
    }
}
