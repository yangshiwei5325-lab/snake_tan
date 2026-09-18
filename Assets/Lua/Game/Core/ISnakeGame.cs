// ISnakeGame.cs - 贪吃蛇游戏接口（C#端）
using UnityEngine;

public interface ISnakeGame
{
    void StartGame();
    void PauseGame();
    void ResumeGame();
    void EndGame();
    void RestartGame();
    void UpdateGame(float deltaTime);
    void HandleInput(string direction);
    int GetScore();
    int GetSnakeLength();
    bool IsGameRunning();
    bool IsGamePaused();
}