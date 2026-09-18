using System;
using System.Collections;
using System.IO;
using UnityEngine;

// On the first launch, copies the built-in lua scripts from StreamingAssets
// into the persistent storage and records the built-in version as the applied
// version. Afterwards everything is read from persistent storage, which keeps
// the load path uniform on all platforms and lets hot-updated files simply
// overwrite the built-in ones.
public static class BuiltinLuaInstaller
{
    private static string AppliedPath
    {
        get { return Path.Combine(Application.persistentDataPath, "applied_version.json"); }
    }

    public static IEnumerator EnsureInstalled()
    {
        if (File.Exists(AppliedPath))
        {
            yield break; // already installed / updated before
        }

        string json = null;
        yield return PlatformIO.ReadStreamingText(HotUpdateManager.ManifestName, s => json = s);
        if (string.IsNullOrEmpty(json))
        {
            Debug.Log("[Builtin] no built-in manifest found, skip install");
            yield break;
        }

        VersionManifest manifest = null;
        try
        {
            manifest = JsonUtility.FromJson<VersionManifest>(json);
        }
        catch (Exception e)
        {
            Debug.LogWarning("[Builtin] parse manifest failed: " + e.Message);
        }
        if (manifest == null || manifest.files == null)
        {
            yield break;
        }

        int copied = 0;
        foreach (ManifestEntry entry in manifest.files)
        {
            byte[] data = null;
            yield return PlatformIO.ReadStreamingBytes(entry.path, b => data = b);
            if (data == null)
            {
                Debug.LogWarning("[Builtin] streaming file missing: " + entry.path);
                continue;
            }
            PlatformIO.WriteFile(Path.Combine(Application.persistentDataPath, entry.path), data);
            copied++;
        }

        AppliedVersion av = new AppliedVersion
        {
            version = manifest.version,
            time = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss")
        };
        PlatformIO.WriteFileText(AppliedPath, JsonUtility.ToJson(av));
        Debug.Log("[Builtin] built-in lua installed, v" + manifest.version + ", files: " + copied);
    }

    // Deletes downloaded/built-in lua files in persistent storage so that the
    // next boot falls back to the built-in package again.
    public static void ClearLocalCache()
    {
        try
        {
            if (Directory.Exists(PlatformIO.PersistentLuaDir))
            {
                Directory.Delete(PlatformIO.PersistentLuaDir, true);
            }
            if (File.Exists(AppliedPath))
            {
                File.Delete(AppliedPath);
            }
            Debug.Log("[Builtin] local lua cache cleared");
        }
        catch (Exception e)
        {
            Debug.LogWarning("[Builtin] clear cache failed: " + e.Message);
        }
    }
}
