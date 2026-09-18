// SnakeGame.cs - 贪吃蛇游戏核心逻辑（C#端）
// 优化版本：添加动态难度、道具系统和障碍物系统
using UnityEngine;
using System.Collections.Generic;

public class SnakeGame : ISnakeGame
{
    private Snake _snake;
    private GameUI _gameUI;
    private bool _isRunning = false;
    private bool _isPaused = false;
    private int _lastScore = 0;
    private int _lastLength = 0;
    private int _lastDifficultyLevel = 1;
    private float _lastSpeedMultiplier = 1.0f;

    // 音效和震动系统
    private AudioSource _audioSource;
    private AudioClip _eatSound;
    private AudioClip _dieSound;
    private AudioClip _powerupSound;
    private bool _vibrationEnabled = true;

    public SnakeGame(GameUI gameUI)
    {
        _gameUI = gameUI;
        _snake = new Snake();
        
        // 初始化音效系统
        _audioSource = gameUI.GetComponent<AudioSource>();
        if (_audioSource == null)
        {
            _audioSource = gameUI.gameObject.AddComponent<AudioSource>();
        }
        
        // 加载音效（这里假设已经存在）
        _eatSound = Resources.Load<AudioClip>("Sounds/Eat");
        _dieSound = Resources.Load<AudioClip>("Sounds/Die");
        _powerupSound = Resources.Load<AudioClip>("Sounds/Powerup");
    }

    public void StartGame()
    {
        _snake.Reset();
        _isRunning = true;
        _isPaused = false;
        _gameUI.AttachGame(this);
        _gameUI.Refresh();
    }

    public void PauseGame()
    {
        if (_isRunning && !_isPaused)
        {
            _isPaused = true;
            _gameUI.ShowPause();
        }
    }

    public void ResumeGame()
    {
        if (_isRunning && _isPaused)
        {
            _isPaused = false;
            _gameUI.HidePause();
        }
    }

    public void EndGame()
    {
        _isRunning = false;
        _isPaused = false;
        _gameUI.ShowGameOver(_snake.GetScore(), _snake.GetSnakeLength());
        PlaySound(_dieSound);
        TriggerVibration();
    }

    public void RestartGame()
    {
        StartGame();
    }

    public void UpdateGame(float deltaTime)
    {
        if (_isRunning && !_isPaused)
        {
            _snake.Update(deltaTime);
            
            // 检查分数和长度是否变化，只在变化时通知UI
            int currentScore = _snake.GetScore();
            int currentLength = _snake.GetSnakeLength();
            int currentDifficulty = _snake.GetDifficultyLevel();
            float currentSpeed = _snake.GetSpeedMultiplier();
            
            if (currentScore != _lastScore || currentLength != _lastLength)
            {
                _lastScore = currentScore;
                _lastLength = currentLength;
                _gameUI.MarkScoreDirty();
            }
            
            // 检查难度变化
            if (currentDifficulty != _lastDifficultyLevel || currentSpeed != _lastSpeedMultiplier)
            {
                _lastDifficultyLevel = currentDifficulty;
                _lastSpeedMultiplier = currentSpeed;
                _gameUI.UpdateDifficultyDisplay(currentDifficulty, currentSpeed);
            }
        }
    }

    public void HandleInput(string direction)
    {
        if (_isRunning && !_isPaused)
        {
            _snake.RequestDir(direction);
        }
    }

    public int GetScore()
    {
        return _snake.GetScore();
    }

    public int GetSnakeLength()
    {
        return _snake.GetSnakeLength();
    }

    public bool IsGameRunning()
    {
        return _isRunning;
    }

    public bool IsGamePaused()
    {
        return _isPaused;
    }

    public Snake GetSnake()
    {
        return _snake;
    }

    // 音效系统
    public void PlaySound(AudioClip clip)
    {
        if (_audioSource != null && clip != null)
        {
            _audioSource.PlayOneShot(clip);
        }
    }

    public void PlayEatSound()
    {
        PlaySound(_eatSound);
    }

    public void PlayDieSound()
    {
        PlaySound(_dieSound);
    }

    public void PlayPowerupSound()
    {
        PlaySound(_powerupSound);
    }

    // 震动反馈
    public void TriggerVibration()
    {
        if (_vibrationEnabled && SystemInfo.supportsVibration)
        {
            Handheld.Vibrate();
        }
    }

    // 道具系统回调
    public void OnPowerupCollected(string powerupType, int points)
    {
        _gameUI.ShowPowerupNotification(powerupType);
        PlayPowerupSound();
        TriggerVibration();
        
        // 更新分数
        _lastScore += points;
        _gameUI.MarkScoreDirty();
    }

    // 障碍物碰撞回调
    public void OnObstacleHit()
    {
        PlayDieSound();
        TriggerVibration();
        EndGame();
    }

    // 动态难度回调
    public void OnDifficultyChanged(int level, float speedMultiplier)
    {
        _gameUI.ShowDifficultyChange(level);
    }
}