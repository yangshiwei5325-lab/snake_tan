using System;
using System.IO;
using System.Security.Cryptography;
using UnityEditor;
using UnityEngine;

// Editor menu tools for the hot-update demo:
//
//   HotUpdate / Publish Builtin to StreamingAssets
//       Copies Assets/Lua into Assets/StreamingAssets/lua and writes
//       Assets/StreamingAssets/version.json (the built-in package).
//
//   HotUpdate / Publish to Update Server (demo)
//       Copies Assets/Lua into Tools/UpdateServer/lua and writes
//       Tools/UpdateServer/version.json with a bumped version. Serve that
//       folder over http://127.0.0.1:8000/ to act as the update server.
//
//   HotUpdate / Clear Local Lua Cache (persistent)
//       Deletes the persistent copy of the lua files for this project,
//       useful to force a fresh install of the built-in package.
public static class HotUpdatePublish
{
    private static string LuaSourceDir
    {
        get { return Application.dataPath + "/Lua"; }
    }

    private static string StreamingLuaDir
    {
        get { return Application.dataPath + "/StreamingAssets/lua"; }
    }

    private static string StreamingManifestPath
    {
        get { return Application.dataPath + "/StreamingAssets/" + HotUpdateManager.ManifestName; }
    }

    private static string ServerRoot
    {
        get { return Path.GetFullPath(Path.Combine(Application.dataPath, "..", "Tools", "UpdateServer")); }
    }

    private static string ServerManifestPath
    {
        get { return Path.Combine(ServerRoot, HotUpdateManager.ManifestName); }
    }

    private static string BuildCounterPath
    {
        get { return Path.Combine(ServerRoot, "build.txt"); }
    }

    [MenuItem("HotUpdate/Publish Builtin to StreamingAssets")]
    public static void PublishBuiltin()
    {
        if (!Directory.Exists(LuaSourceDir))
        {
            Debug.LogError("[Publish] Assets/Lua not found: " + LuaSourceDir);
            return;
        }
        string version = ReadManifestVersion(StreamingManifestPath);
        if (string.IsNullOrEmpty(version))
        {
            version = "1.0.0";
        }
        int count = WriteManifest(StreamingLuaDir, StreamingManifestPath, version);
        AssetDatabase.Refresh();
        Debug.Log("[Publish] built-in package -> StreamingAssets, v" + version + ", files: " + count);
    }

    [MenuItem("HotUpdate/Publish to Update Server (demo)")]
    public static void PublishServer()
    {
        if (!Directory.Exists(LuaSourceDir))
        {
            Debug.LogError("[Publish] Assets/Lua not found: " + LuaSourceDir);
            return;
        }
        Directory.CreateDirectory(ServerRoot);

        int n = 0;
        if (File.Exists(BuildCounterPath))
        {
            int.TryParse(File.ReadAllText(BuildCounterPath).Trim(), out n);
        }
        n += 1;
        string version = "1.0." + n;

        int count = WriteManifest(Path.Combine(ServerRoot, "lua"), ServerManifestPath, version);
        File.WriteAllText(BuildCounterPath, n.ToString());
        Debug.Log("[Publish] update server package -> " + ServerRoot + ", v" + version + ", files: " + count);
    }

    [MenuItem("HotUpdate/Clear Local Lua Cache (persistent)")]
    public static void ClearLocalCache()
    {
        BuiltinLuaInstaller.ClearLocalCache();
    }

    // ---- helpers -----------------------------------------------------------

    private static int WriteManifest(string luaDir, string manifestPath, string version)
    {
        Directory.CreateDirectory(luaDir);

        VersionManifest manifest = new VersionManifest();
        manifest.version = version;

        string[] files = Directory.GetFiles(LuaSourceDir, "*.lua", SearchOption.AllDirectories);
        Array.Sort(files, StringComparer.Ordinal);
        foreach (string file in files)
        {
            string relNoPrefix = GetRelative(LuaSourceDir, file);
            string rel = "lua/" + relNoPrefix.Replace('\\', '/');

            string dest = Path.Combine(luaDir, relNoPrefix);
            string destDir = Path.GetDirectoryName(dest);
            if (!string.IsNullOrEmpty(destDir))
            {
                Directory.CreateDirectory(destDir);
            }
            File.Copy(file, dest, true);

            ManifestEntry entry = new ManifestEntry
            {
                path = rel,
                md5 = Md5File(dest),
                size = (int)new FileInfo(dest).Length
            };
            manifest.files.Add(entry);
        }

        File.WriteAllText(manifestPath, JsonUtility.ToJson(manifest, true));
        return manifest.files.Count;
    }

    private static string ReadManifestVersion(string manifestPath)
    {
        if (!File.Exists(manifestPath))
        {
            return null;
        }
        try
        {
            VersionManifest manifest = JsonUtility.FromJson<VersionManifest>(File.ReadAllText(manifestPath));
            return manifest != null ? manifest.version : null;
        }
        catch
        {
            return null;
        }
    }

    private static string GetRelative(string root, string full)
    {
        if (full.StartsWith(root, StringComparison.Ordinal))
        {
            return full.Substring(root.Length).TrimStart('\\', '/');
        }
        Uri r = new Uri(root.TrimEnd(Path.DirectorySeparatorChar) + Path.DirectorySeparatorChar);
        Uri f = new Uri(full);
        return Uri.UnescapeDataString(r.MakeRelativeUri(f).ToString());
    }

    private static string Md5File(string path)
    {
        using (MD5 md5 = MD5.Create())
        using (FileStream fs = File.OpenRead(path))
        {
            byte[] hash = md5.ComputeHash(fs);
            System.Text.StringBuilder sb = new System.Text.StringBuilder();
            for (int i = 0; i < hash.Length; i++)
            {
                sb.Append(hash[i].ToString("x2"));
            }
            return sb.ToString();
        }
    }
}
