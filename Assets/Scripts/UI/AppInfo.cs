using UnityEngine;
using XLua;

// Runtime info and platform actions exported to Lua.
[LuaCallCSharp]
public static class AppInfo
{
    // Last hot-update log line; survives Lua VM reboots.
    public static string UpdateLog = "";

    public static string GetUpdateLog()
    {
        return UpdateLog;
    }

    public static string Version()
    {
        string v = Application.version;
        return string.IsNullOrEmpty(v) ? "1.0.0" : v;
    }

    public static string Platform()
    {
        return Application.platform.ToString();
    }

    public static void Quit()
    {
#if UNITY_EDITOR
        UnityEditor.EditorApplication.isPlaying = false;
#else
        Application.Quit();
#endif
    }

    // Triggered from the Lua main menu ("Check update" button).
    public static void CheckUpdate()
    {
        if (GameMain.Instance != null)
        {
            GameMain.Instance.RunHotUpdateCheck();
        }
        else
        {
            Debug.LogError("[AppInfo] GameMain is not ready");
        }
    }
}
