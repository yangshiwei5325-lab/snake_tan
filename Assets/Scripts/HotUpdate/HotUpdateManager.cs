using System;
using UnityEngine;

// 热更新管理器 - 负责协调热更新服务
public class HotUpdateManager : MonoBehaviour
{
    private IHotUpdateService _hotUpdateService;
    private bool _isUpdating = false;

    void Awake()
    {
        // 初始化热更新服务
        _hotUpdateService = new HotUpdateService();
    }

    // 检查并应用更新
    public void CheckAndApplyUpdate(bool force = false, Action<UpdateResult> onComplete = null)
    {
        if (_isUpdating)
        {
            Debug.LogWarning("[HotUpdateManager] Update already in progress");
            return;
        }

        _isUpdating = true;
        StartCoroutine(PerformUpdate(force, onComplete));
    }

    // 执行更新流程
    private IEnumerator PerformUpdate(bool force, Action<UpdateResult> onComplete)
    {
        var result = _hotUpdateService.CheckAndApply(force, onComplete);
        
        // 等待更新完成
        while (_isUpdating)
        {
            yield return null;
        }

        if (onComplete != null)
        {
            onComplete(result);
        }
    }

    // 取消更新（如果需要）
    public void CancelUpdate()
    {
        _isUpdating = false;
    }

    // 获取热更新服务（供其他模块使用）
    public IHotUpdateService GetService()
    {
        return _hotUpdateService;
    }

    void OnDestroy()
    {
        CancelUpdate();
    }
}