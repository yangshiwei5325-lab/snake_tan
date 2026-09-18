using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Security.Cryptography;
using System.Text;
using System.Threading.Tasks;
using UnityEngine;
using UnityEngine.Networking;

// 热更新服务接口
public interface IHotUpdateService
{
    string BaseUrl { get; }
    string AppliedPath { get; }
    UpdateResult CheckAndApply(bool force, Action<UpdateResult> done);
}

// 热更新结果
public class UpdateResult
{
    public bool reachable;   // update server reachable
    public bool updated;     // a new version was applied (or version changed)
    public int changedCount; // how many files downloaded
    public string version = "";
    public string log = "";
    public float downloadTime; // total download time in seconds
}

// 热更新服务实现
public class HotUpdateService : IHotUpdateService
{
    public const string ManifestName = "version.json";
    private const string DefaultBaseUrl = "http://127.0.0.1:8000/";
    private const int MaxConcurrentDownloads = 5; // 最大并发下载数
    private const int DownloadTimeout = 10; // 下载超时时间（秒）
    private const int MaxRetryCount = 3; // 最大重试次数
    
    private string _baseUrl = DefaultBaseUrl;
    private Dictionary<string, string> _md5Cache = new Dictionary<string, string>(); // MD5缓存
    private DateTime _lastCacheClearTime = DateTime.MinValue;

    public string BaseUrl => _baseUrl;
    public string AppliedPath => Path.Combine(Application.persistentDataPath, "applied_version.json");

    // 清理MD5缓存（避免内存无限增长）
    private void ClearMd5CacheIfNeeded()
    {
        if ((DateTime.Now - _lastCacheClearTime).TotalHours > 1) // 每小时清理一次
        {
            _md5Cache.Clear();
            _lastCacheClearTime = DateTime.Now;
        }
    }

    public UpdateResult CheckAndApply(bool force, Action<UpdateResult> done)
    {
        var result = new UpdateResult();
        var stopwatch = System.Diagnostics.Stopwatch.StartNew();
        
        // 加载配置
        LoadConfig().Run();
        result.reachable = true;

        // 获取远程版本信息
        var remoteJsonTask = GetRemoteText(ManifestName);
        remoteJsonTask.Wait();
        string remoteJson = remoteJsonTask.Result;
        
        if (string.IsNullOrEmpty(remoteJson))
        {
            result.reachable = false;
            result.log = "[HotUpdate] cannot reach update server: " + _baseUrl;
            result.downloadTime = stopwatch.ElapsedMilliseconds / 1000f;
            if (done != null) done(result);
            return result;
        }

        // 解析版本清单
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
            result.log = "[HotUpdate] bad remote manifest";
            result.downloadTime = stopwatch.ElapsedMilliseconds / 1000f;
            if (done != null) done(result);
            return result;
        }

        result.version = manifest.version;
        string applied = ReadAppliedVersion();
        if (!force && applied == manifest.version)
        {
            result.log = "[HotUpdate] already up to date, applied v" + applied;
            result.downloadTime = stopwatch.ElapsedMilliseconds / 1000f;
            if (done != null) done(result);
            return result;
        }

        // 并发下载文件
        var downloadTasks = new List<Task<DownloadResult>>();
        var downloadQueue = new Queue<ManifestEntry>(manifest.files);
        
        while (downloadQueue.Count > 0 || downloadTasks.Count > 0)
        {
            // 添加新的下载任务（最多MaxConcurrentDownloads个并发）
            while (downloadTasks.Count < MaxConcurrentDownloads && downloadQueue.Count > 0)
            {
                var entry = downloadQueue.Dequeue();
                downloadTasks.Add(DownloadFileAsync(entry));
            }

            // 等待至少一个下载完成
            if (downloadTasks.Count > 0)
            {
                var completedTask = Task.WhenAny(downloadTasks).Result;
                downloadTasks.Remove(completedTask);
                
                var downloadResult = completedTask.Result;
                if (downloadResult.success)
                {
                    result.changedCount++;
                    Debug.Log("[HotUpdate] downloaded: " + downloadResult.path);
                }
                else
                {
                    Debug.LogWarning("[HotUpdate] download failed: " + downloadResult.path + " - " + downloadResult.error);
                }
            }
        }

        // 写入应用版本
        WriteApplied(manifest.version);
        result.updated = true;
        result.downloadTime = stopwatch.ElapsedMilliseconds / 1000f;
        
        result.log = result.changedCount > 0
            ? "[HotUpdate] updated " + applied + " -> v" + manifest.version + ", files: " + result.changedCount + 
              ", time: " + result.downloadTime.ToString("F2") + "s"
            : "[HotUpdate] version changed " + applied + " -> v" + manifest.version + " (no download needed), time: " + 
              result.downloadTime.ToString("F2") + "s";
        
        if (done != null) done(result);
        return result;
    }

    private void WriteApplied(string version)
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

    private IEnumerator LoadConfig()
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

    private IEnumerator GetRemoteBytes(string relPath, Action<byte[]> done)
    {
        string url = _baseUrl.TrimEnd('/') + "/" + relPath;
        using (UnityWebRequest req = UnityWebRequest.Get(url))
        {
            req.timeout = DownloadTimeout;
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

    private Task<string> GetRemoteText(string relPath)
    {
        byte[] data = null;
        var getBytesTask = new Task<byte[]>(done => 
        {
            StartCoroutine(GetRemoteBytes(relPath, b => done(b)));
        });
        getBytesTask.Start();
        
        return getBytesTask.ContinueWith(t => 
        {
            if (t.IsFaulted || t.IsCanceled)
                return null;
            return Encoding.UTF8.GetString(t.Result);
        });
    }

    private async Task<DownloadResult> DownloadFileAsync(ManifestEntry entry)
    {
        int retryCount = 0;
        Exception lastError = null;
        
        while (retryCount < MaxRetryCount)
        {
            try
            {
                string url = _baseUrl.TrimEnd('/') + "/" + entry.path;
                using (UnityWebRequest req = UnityWebRequest.Get(url))
                {
                    req.timeout = DownloadTimeout;
                    await req.SendWebRequestAsync();
                    
                    if (req.isNetworkError || req.isHttpError)
                    {
                        throw new Exception(req.error);
                    }
                    
                    string localPath = Path.Combine(Application.persistentDataPath, entry.path);
                    Directory.CreateDirectory(Path.GetDirectoryName(localPath));
                    PlatformIO.WriteFile(localPath, req.downloadHandler.data);
                    
                    return new DownloadResult
                    {
                        success = true,
                        path = entry.path,
                        error = null
                    };
                }
            }
            catch (Exception e)
            {
                lastError = e;
                retryCount++;
                if (retryCount < MaxRetryCount)
                {
                    await Task.Delay(500 * retryCount); // 指数退避
                }
            }
        }
        
        return new DownloadResult
        {
            success = false,
            path = entry.path,
            error = lastError?.Message ?? "Unknown error"
        };
    }

    private string ReadAppliedVersion()
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

    private string Md5File(string path)
    {
        ClearMd5CacheIfNeeded();
        
        if (_md5Cache.TryGetValue(path, out string cachedMd5))
        {
            return cachedMd5;
        }

        try
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
                string md5Result = sb.ToString();
                _md5Cache[path] = md5Result;
                return md5Result;
            }
        }
        catch (Exception e)
        {
            Debug.LogWarning("[HotUpdate] calculate MD5 failed for " + path + ": " + e.Message);
            return "";
        }
    }

    // 下载结果
    private class DownloadResult
    {
        public bool success;
        public string path;
        public string error;
    }
}

// 异步UnityWebRequest扩展
public static class UnityWebRequestExtensions
{
    public static Task<UnityWebRequestAsyncOperation> SendWebRequestAsync(this UnityWebRequest request)
    {
        var tcs = new TaskCompletionSource<UnityWebRequestAsyncOperation>();
        var operation = request.SendWebRequest();
        
        operation.completed += _ => 
        {
            if (request.isNetworkError || request.isHttpError)
            {
                tcs.SetException(new Exception(request.error));
            }
            else
            {
                tcs.SetResult(operation);
            }
        };
        
        return tcs.Task;
    }
}