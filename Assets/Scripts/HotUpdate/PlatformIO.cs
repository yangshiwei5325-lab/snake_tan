using System;
using System.Collections;
using System.IO;
using UnityEngine;
using UnityEngine.Networking;

// File access helpers.
// StreamingAssets is read through UnityWebRequest so the same code works on
// desktop, Android (jar://) and iOS (file:// inside the app bundle).
// Writes always target Application.persistentDataPath which is writable.
public static class PlatformIO
{
    public static string PersistentRoot
    {
        get { return Application.persistentDataPath; }
    }

    public static string PersistentLuaDir
    {
        get { return Path.Combine(Application.persistentDataPath, "lua"); }
    }

    public static IEnumerator ReadStreamingBytes(string relPath, Action<byte[]> onDone)
    {
        string url = Path.Combine(Application.streamingAssetsPath, relPath).Replace('\\', '/');
        if (!url.Contains("://"))
        {
            // Desktop / editor: absolute local path needs a file:// scheme.
            url = "file://" + url;
        }
        using (UnityWebRequest req = UnityWebRequest.Get(url))
        {
            req.timeout = 5;
            yield return req.SendWebRequest();
            if (req.isNetworkError || req.isHttpError)
            {
                onDone(null);
            }
            else
            {
                onDone(req.downloadHandler.data);
            }
        }
    }

    public static IEnumerator ReadStreamingText(string relPath, Action<string> onDone)
    {
        byte[] data = null;
        yield return ReadStreamingBytes(relPath, b => data = b);
        onDone(data != null ? System.Text.Encoding.UTF8.GetString(data) : null);
    }

    // Copy a local (persistent dir) file to disk, creating folders as needed.
    public static void WriteFile(string absPath, byte[] data)
    {
        string dir = Path.GetDirectoryName(absPath);
        if (!string.IsNullOrEmpty(dir))
        {
            Directory.CreateDirectory(dir);
        }
        File.WriteAllBytes(absPath, data);
    }

    public static void WriteFileText(string absPath, string content)
    {
        string dir = Path.GetDirectoryName(absPath);
        if (!string.IsNullOrEmpty(dir))
        {
            Directory.CreateDirectory(dir);
        }
        File.WriteAllText(absPath, content);
    }
}
