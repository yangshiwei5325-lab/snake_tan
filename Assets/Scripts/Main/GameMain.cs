using System.Collections;
using UnityEngine;

// Bootstrap of the whole demo.
//
// Sequence on startup:
//   1. copy built-in lua (StreamingAssets) into persistent storage once
//   2. try to hot-update from the update server (falls back silently when the
//      server is not reachable)
//   3. boot the Lua VM, which builds all UI and starts the game
//
// The object is created automatically (RuntimeInitializeOnLoadMethod), so the
// game runs from any empty scene - no prefab / scene wiring needed.
public class GameMain : MonoBehaviour
{
    public static GameMain Instance { get; private set; }

    private string _status = "starting...";

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.BeforeSceneLoad)]
    private static void Bootstrap()
    {
        if (FindObjectOfType<GameMain>() == null)
        {
            GameObject go = new GameObject("_GameMain_");
            DontDestroyOnLoad(go);
            go.AddComponent<GameMain>();
        }
    }

    private void Awake()
    {
        Instance = this;
    }

    private IEnumerator Start()
    {
        _status = "install built-in lua...";
        yield return BuiltinLuaInstaller.EnsureInstalled();

        bool updated = false;
        _status = "checking hot update...";
        yield return HotUpdateManager.CheckAndApply(false, delegate(UpdateResult r)
        {
            AppInfo.UpdateLog = r.log;
            updated = r.updated;
        });

        _status = updated
            ? "hot update applied, boot lua"
            : "hot update checked, boot lua";
        BootLua();
    }

    private void Update()
    {
        if (LuaManager.IsRunning)
        {
            LuaManager.Tick(Time.deltaTime);
        }
    }

    public void BootLua()
    {
        LuaUI.Reset();      // clear any UI left by the previous VM
        LuaManager.Boot();  // dispose old VM, re-require everything from disk
        _status = LuaManager.IsRunning ? "lua running" : "lua boot FAILED, see console";
    }

    // Called from the Lua main menu ("Check update" button).
    public void RunHotUpdateCheck()
    {
        StartCoroutine(HotUpdateManager.CheckAndApply(false, OnManualHotUpdateDone));
    }

    private void OnManualHotUpdateDone(UpdateResult r)
    {
        AppInfo.UpdateLog = r.log;
        if (r.updated)
        {
            // New scripts were downloaded: reboot the VM so the change is
            // visible immediately (this is the live hot-update demo).
            BootLua();
            LuaManager.NotifyHotUpdateDone(r.log);
        }
        else
        {
            LuaManager.NotifyHotUpdateDone(r.log);
        }
    }

    // ---- editor-only dev console ------------------------------------------

    private void OnGUI()
    {
        if (!Application.isEditor)
        {
            return;
        }
        GUI.Label(new Rect(8f, 4f, 900f, 24f), "Lua Snake | status: " + _status);
        GUI.Label(new Rect(8f, 30f, 1400f, 24f), "update log: " + AppInfo.UpdateLog);

        float y = 58f;
        if (GUI.Button(new Rect(8f, y, 130f, 26f), "Reload Lua"))
        {
            BootLua();
            return;
        }
        if (GUI.Button(new Rect(146f, y, 150f, 26f), "Check Update"))
        {
            RunHotUpdateCheck();
            return;
        }
        if (GUI.Button(new Rect(304f, y, 200f, 26f), "Reset to Builtin"))
        {
            StartCoroutine(ResetToBuiltin());
            return;
        }
        if (GUI.Button(new Rect(512f, y, 240f, 26f), "Persistent Path"))
        {
            AppInfo.UpdateLog = Application.persistentDataPath;
            return;
        }
    }

    private IEnumerator ResetToBuiltin()
    {
        _status = "clearing local lua cache...";
        BuiltinLuaInstaller.ClearLocalCache();
        yield return BuiltinLuaInstaller.EnsureInstalled();
        BootLua();
    }
}
