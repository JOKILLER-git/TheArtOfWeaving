# 开发入口

按 F5 从 scenes/game_browser.tscn 进入章节与关卡选择；单关调试可打开 scenes/first_weave.tscn 后按 F6。先选择每梭要抬起的经线，再确认引纬；四行织纹全部吻合才可进入下一关。

新增内容请看 [新增章节与关卡](docs/adding_levels.md)。选关界面读取 resources/catalog/main_catalog.tres，添加目录条目即可，不需要修改导航代码。

## 常见修改

| 内容 | 编辑位置 |
|---|---|
| 章节标题 | Lesson.intro_title |
| 目标织纹 | Lesson.target_rows：每行由 0/1 组成，长度等于经线数 |
| 章节、关卡、下一关顺序 | Catalog.Chapters / Chapter.Stages 数组顺序；next_lesson 仅兼容独立 F6 |
| 提经按钮位置、经线间隔 | Loom/Warps 的实例位置，运行时按横坐标排序 |
| 梭口位置 | Loom.start_point / finish_x |
| 引纬、打纬时长及线色 | Loom/WeaveSurface 的导出参数 |
| 横梁、完成徽标 | loom.tscn 中原有 Sprite2D / AnimationPlayer |
| 目标和底部操作布局 | weave_hud.tscn |

1 = 经线在纬线上方；0 = 经线在下方。默认目标是四行平纹，第二关为四行斜纹。资源校验要求 1–4 行、每行等宽且只含 0/1。织面必须能容纳所有成布行，且经线位于轨道内。

## 组织约定

- 场景负责布局，脚本负责行为，Resource 负责目标数据。
- WeaveLevel 只协调组件与状态；输入和绘制在 WeaveSurface，文案在 WeaveHUD。
- UI 通过信号请求确认、撤销、重试、下一关，不直接修改织面。
- @tool 只负责编辑器布局；运行时提经按钮由非 @tool 的 WeaveSurface 创建。
- 游戏代码不依赖 Godot AI 插件。
- 保留旧 Thread / WarpStrand 场景供独立使用和编辑器预览；主关卡运行时隐藏它们，passes_over 不再决定实际织纹。
- 主画布为 1280×800，canvas_items 缩放；暂未实现任意屏幕比例下的重新排版。

## 验证

```powershell
& '<Godot executable>' --headless --path . --script res://tests/first_weave_smoke.gd
```

核心测试在 tests/weave_flow_suite.gd，可在编辑器启动的新游戏进程中运行：

```gdscript
var suite = load("res://tests/weave_flow_suite.gd").new()
var result = await suite.run(get_tree().current_scene, true)
```

第二个参数控制截图；独立入口用 `-- --capture`。覆盖鼠标、触摸、确认锁定、提经端点、持久交错、撤销恢复、错误目标阻挡、正确目标与换关、末关完成、动画中重试、无效配置恢复。

本次 Windows 环境的独立 Mono 命令行进程报 Assemblies not found，实际验证通过现有编辑器启动的新游戏进程完成。截图和记录见 docs/weaving_validation.md。
