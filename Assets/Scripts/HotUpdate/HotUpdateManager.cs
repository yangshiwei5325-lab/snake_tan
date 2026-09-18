using System;
using System.Collections;
using System.IO;
using System.Security.Cryptography;
using System.Text;
using UnityEngine;
using UnityEngine.Networking;

// Result of one hot-update check.
public class UpdateResult
{
    public bool reachable;   // update server reachable
    public bool updated;     // a new version was applied (or version changed)
    public int changedCount; // how many files downloaded
    public string version = "";
    public string log = "";
}

// Hot update workflow:
//  1. read remote base url from StreamingAssets/hotupdate.txt (optional)
//  2. GET  <base>/version.json
//  3. compare with the applied version stored in persistent storage
//  4. download files whose md5 differs (or that are missing) into
//     persistent/lua/... and finally store the new applied version
// Lua files are later loaded from persistent/lua first, so the updated
// scripts take effect after the Lua VM is rebooted.
public static class HotUpdateManager
{
    public const string ManifestName = "version.json";
    private const string DefaultBaseUrl = "http://127.0.0.1:8000/";

    private static string _baseUrl = DefaultBaseUrl;

    public static string BaseUrl
    {
        get { return _baseUrl; }
    }

    private static string AppliedPath
    {
        get { return Path.Combine(Application.persistentDataPath, "applied_version.json"); }
    }

    public static string ReadAppliedVersion()
    {
        try
        {
            if (File.Exists(AppliedPath))
            {
                AppliedVersion av = JsonUtility.FromJson<AppliedVersion>(File.ReadAllText(AppliedPath));
                return av == null ? "" : av.version;
            }
        }
        catch (Exception e)
        {
            Debug.LogWarning("[HotUpdate] read applied version failed: " + e.Message);
        }
        return "";
    }

    public static string Md5File(string path)
    {
        using (MD5 md5 = MD5.Create())
        using (FileStream fs = File.OpenRead(path))
        {
            byte[] hash = md5.ComputeHash(fs);
            StringBuilder sb = new StringBuilder();
            for (int i = 0; i < hash.Length; i++)
            {
                sb.Append(hash[i].ToString("x2"));
            }
            return sb.ToString();
        }
    }

    public static IEnumerator CheckAndApply(bool force, Action<UpdateResult> done)
    {
        yield return LoadConfig();

        string remoteJson = null;
        yield return GetRemoteText(ManifestName, s => remoteJson = s);
        if (string.IsNullOrEmpty(remoteJson))
        {
            if (done != null)
            {
                done(new UpdateResult
                {
                    reachable = false,
                    log = "[HotUpdate] cannot reach update server: " + _baseUrl
                });
            }
            yield break;
        }

        VersionManifest manifest = null;
        try
        {
            manifest = JsonUtility.FromJson<VersionManifest>(remoteJson);
        }
        catch (Exception e)
        {
            Debug.LogWarning("[HotUpdate] parse manifest failed: " + e.Message);
        }
        if (manifest == null || string.IsNullOrEmpty(manifest.version))
        {
            if (done != null)
            {
                done(new UpdateResult
                {
                    reachable = true,
                    log = "[HotUpdate] bad remote manifest"
                });
            }
            yield break;
        }

        UpdateResult result = new UpdateResult { reachable = true, version = manifest.version };
        string applied = ReadAppliedVersion();
        if (!force && applied == manifest.version)
        {
            result.log = "[HotUpdate] already up to date, applied v" + applied;
            if (done != null) done(result);
            yield break;
        }

        int count = 0;
        if (manifest.files != null)
        {
            foreach (ManifestEntry entry in manifest.files)
            {
                string localPath = Path.Combine(Application.persistentDataPath, entry.path);
                if (File.Exists(localPath) && Md5File(localPath) == entry.md5)
                {
                    continue; // unchanged
                }

                byte[] data = null;
                yield return GetRemoteBytes(entry.path, b => data = b);
                if (data == null)
                {
                    Debug.LogWarning("[HotUpdate] download failed: " + entry.path);
                    continue;
                }
                PlatformIO.WriteFile(localPath, data);
                count++;
                Debug.Log("[HotUpdate] downloaded: " + entry.path);
            }
        }

        WriteApplied(manifest.version);
        result.updated = true;
        result.changedCount = count;
        result.log = count > 0
            ? "[HotUpdate] updated " + applied + " -> v" + manifest.version + ", files: " + count
            : "[HotUpdate] version changed " + applied + " -> v" + manifest.version + " (no download needed)";
        if (done != null) done(result);
    }

    private static void WriteApplied(string version)
    {
        AppliedVersion av = new AppliedVersion
        {
            version = version,
            time = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss")
        };
        try
        {
            PlatformIO.WriteFileText(AppliedPath, JsonUtility.ToJson(av));
        }
        catch (Exception e)
        {
            Debug.LogWarning("[HotUpdate] write applied version failed: " + e.Message);
        }
    }

    private static IEnumerator LoadConfig()
    {
        string text = null;
        yield return PlatformIO.ReadStreamingText("hotupdate.txt", s => text = s);
        if (!string.IsNullOrEmpty(text))
        {
            string url = text.Trim();
            if (url.Length > 0)
            {
                _baseUrl = url;
                Debug.Log("[HotUpdate] base url: " + _baseUrl);
            }
        }
    }

    private static IEnumerator GetRemoteBytes(string relPath, Action<byte[]> done)
    {
        string url = _baseUrl.TrimEnd('/') + "/" + relPath;
        using (UnityWebRequest req = UnityWebRequest.Get(url))
        {
            req.timeout = 5;
            yield return req.SendWebRequest();
            if (req.isNetworkError || req.isHttpError)
            {
                done(null);
            }
            else
            {
                done(req.downloadHandler.data);
            }
        }
    }

    private static IEnumerator GetRemoteText(string relPath, Action<string> done)
    {
        byte[] data = null;
        yield return GetRemoteBytes(relPath, b => data = b);
        done(data != null ? Encoding.UTF8.GetString(data) : null);
    }
}
