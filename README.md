# Unity + xLua 贪吃蛇（Lua 驱动 UI · 支持热更）

一个可直接运行的 Unity 贪吃蛇小游戏模板，演示国内游戏常见的热更架构：

- **C# 只做三件事**：Lua VM 生命周期、热更下载流程、UGUI 底层桥接
- **Lua 做全部游戏与 UI 逻辑**：界面搭建、按钮回调、对局逻辑都是 Lua，
  改 Lua 即可热更，不需要重新出包
- 界面不依赖任何 prefab / 图集 / 场景对象，**由 Lua 在运行期纯代码搭建**
  （预创建 20x20 个格子、只改颜色，性能足够）

```
┌────────────── Unity (C#) ──────────────┐
│ GameMain      启动序列 / 每帧 Tick       │
│ HotUpdateManager  版本比对 + 增量下载     │
│ LuaManager     xLua VM + 自定义加载器     │
│ LuaUI          薄 UGUI 桥(返回不透明句柄) │
└──────────────┬─────────────────────────┘
               │ xLua
┌──────────────▼─────────────┐   ┌──────────────┐
│ Lua: UIManager 面板管理      │◄──│ Update Server│
│ Lua: Main / Game / Result  │   │ (http)       │
│ Lua: Snake 逻辑 + Flow 流程  │   └──────────────┘
└────────────────────────────┘
```

## 目录结构

```
Assets/
├─ Lua/                      ← 全部游戏与 UI 逻辑（热更目标）
│  ├─ Framework/             Class / UIPanel / UIManager / UIUtil
│  └─ Game/
│     ├─ Main.lua            Lua 入口（注册 LuaEntry 给 C#）
│     ├─ Flow.lua            流程控制：菜单 ⇄ 对局 ⇄ 结算
│     ├─ Config.lua          参数与配色
│     ├─ Core/Snake.lua      蛇的逻辑（纯逻辑，与表现解耦）
│     └─ UI/                 Main/Game/Result 三个面板（纯 Lua UI）
├─ Scripts/
│  ├─ Main/GameMain.cs       自动引导入口
│  ├─ Lua/LuaManager.cs      LuaEnv 管理与加载器（热更优先级）
│  ├─ HotUpdate/             版本清单 / 下载器 / 内置安装
│  ├─ UI/                    LuaUI / LuaInput / AppInfo / 按钮组件
│  └─ Editor/HotUpdatePublish.cs  发布菜单工具
├─ StreamingAssets/
│  ├─ hotupdate.txt          更新服务器地址（可改）
│  ├─ lua/ + version.json    发布后生成的内置 Lua 包
Tools/UpdateServer/           模拟“远程更新服务器”（发布后 + 起 http）
```

## 热更文件加载优先级

Lua 模块由 `LuaManager` 自定义加载器按顺序查找：

1. `persistentDataPath/lua` —— **热更下载 / 首装内置副本**，重启 VM 后生效
2. `StreamingAssets/lua` —— 内置包（发布工具生成）
3. `Assets/Lua` —— 工程源码（仅编辑器便利，改完即跑）

## 如何运行

1. **准备 Unity 工程**
   - 用 Unity 打开本目录（`ProjectVersion.txt` 写的是 2019.4 LTS，若你的
     版本不同：用新版 Unity 打开会自动升级；或用你本机版本号覆盖该文件后
     再打开，其余 ProjectSettings 由 Unity 自动生成）。
   - 也可新建任意 Unity 工程，然后把本目录 `Assets`、`Tools` 拷入。

2. **导入 xLua**（本项目不内置 xLua，需自行放入）
   ```
   git clone --recursive https://github.com/Tencent/xLua.git
   ```
   把 `xLua/Assets/XLua` 与 `xLua/Assets/Plugins` 复制到工程 `Assets/` 下。

3. **生成桥接代码**（必须）
   菜单 `XLua > Generate Code`，等待编译无报错。
   > 本项目导出类型已打 `[LuaCallCSharp]` 标记（LuaUI / LuaInput / AppInfo），
   > 生成后调用走高效代码路径。

4. **运行**
   打开任意（空）场景直接 Play：
   `GameMain` 由 `RuntimeInitializeOnLoadMethod` 自动创建，无需搭场景。
   进入主菜单后按 **开始游戏**，用 **方向键 / WASD** 控制，
   **P** 暂停。左上角是编辑器调试控制台（Reload Lua / Check Update 等）。

> 若点 Play 后报 `CS` / `LuaUI` 相关错误，说明 xLua 未导入或未 Generate Code。

## 热更演示（重点）

1. 启动“更新服务器”（在 `Tools/UpdateServer/` 双击 `start_server.bat`，
   或 `cd Tools/UpdateServer && python -m http.server 8000`）。
2. 编辑器菜单 `HotUpdate > Publish to Update Server (demo)`
   —— 把 `Assets/Lua` 打包到 `Tools/UpdateServer/`（版本号自动 +1）。
3. Play。启动时会检查并**静默失败**（服务器没开会自动用内置版本）。
4. 修改任意 Lua（例如把 `Assets/Lua/Game/UI/Main.lua` 的标题改成
   “贪吃蛇 v2”），再次执行 `HotUpdate > Publish to Update Server (demo)`。
5. 在运行中的游戏点主菜单 **“检查更新（热更）”**（或用编辑器调试台
   `Check Update`）：下载新脚本 → 自动重启 Lua VM → **界面立刻变成新版**，
   无需重新编译出包。

想“回滚到内置版”或开发中不想被旧热更文件干扰：
`HotUpdate > Clear Local Lua Cache (persistent)` 或调试台 `Reset to Builtin`。

发布正式包前执行 `HotUpdate > Publish Builtin to StreamingAssets`，
再 Build 即带上内置 Lua。

## 常见问题

- **中文显示为方框**：UGUI 默认字体不带 CJK 字形。本项目启动时优先按
  “Microsoft YaHei / PingFang SC / Noto Sans CJK SC / SimHei” 动态创建系统
  字体；仍显示方框请在 `LuaUI.cs` 的 `GetFont` 字体名单里加入你系统有的中文字体。
- **点击无响应**：Player Settings 里 Active Input Handling 需为
  “Input Manager (Old)”或“Both”（不要只选 Input System）。
- **UI 逻辑怎么写**：新增一个面板 = 在 `Assets/Lua/Game/UI/` 加一个继承
  `Framework/UIPanel` 的 lua 文件，实现 `OnCreate()` 用 `UIUtil.*` 搭建即可，
  然后 `UIManager.Get():Open("面板名")` 打开（详见现有三个面板）。

## 说明

- 目标平台：编辑器 / Windows / macOS / Linux；Android / iOS 也已按
  StreamingAssets 通过 UnityWebRequest 读取的方式处理（可打包验证）。
- 逻辑与表现分离：`Snake.lua` 不依赖任何 UI/引擎对象，便于单测或复用。
- 本模板用于演示架构：真实项目通常再加 AssetBundle 资源热更、版本
  强制更新、加密与校验、断点续传等，思路一致。
