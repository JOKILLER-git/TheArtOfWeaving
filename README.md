# 织间 · The Art of Weaving

Godot 4.7 / GDScript 的 2D 编织原型。打开 project.godot，按 F5 运行。

F5 首先进入章节与关卡选择。当前第一章包含平纹、斜纹两关，均可直接进入；游玩时左上角返回选关。通关后可按目录顺序进入下一关，支持跨章节。完成勾号只记录本次运行，返回选关后重新进入会重置该关的未完成织纹。

**新增关卡无需修改导航代码**：编辑 `resources/catalog/chapter_01.tres` 的 Stages 数组，添加一个 WeaveStage，填写唯一 ID、标题和 Lesson。新增章节则编辑 `resources/catalog/main_catalog.tres` 的 Chapters 数组。完整步骤见 [新增章节与关卡](docs/adding_levels.md)。

## 玩法

1. 对照上方目标织纹，从第一行开始。每行从左到右对应经线 1–10；↑ 表示经线在纬线上方，↓ 表示在下方。
2. 点击织框上方的编号按钮抬起或放下经线。确认前可以反复调整；弯曲、偏移、分离的阴影和箭头共同表示提经。
3. 点击“确认提经 · 引纬”，自动播放梭子穿过梭口与打纬。本梭动画期间不能调整组合或重复确认。
4. 共织四行，全部与目标一致才可进入下一关。第一节是平纹，第二节是斜纹。
5. 已织交叉点不能点击修改。“撤销一行”退回上一梭并恢复原组合，可连续撤销；“重新开始”清空本关。

没有计时或失败惩罚。错误行在目标旁标记 ×；织满但不正确时仍可撤销、重试。当前组合会沿用到下一梭，需要玩家自行调整。

## 实现入口

- `scripts/first_weave.gd`：状态协调和过关门控。
- `scenes/game_browser.tscn`、`scripts/game_browser.gd`：应用入口与导航。
- `scenes/ui/level_selection.tscn`：章节和关卡列表；按钮模板也放在此目录。
- `resources/catalog/`：章节、关卡顺序和场景引用。
- `scripts/gameplay/weave_surface.gd`：提经输入、引纬打纬动画、逐行交错绘制。
- `scripts/data/weave_lesson.gd`、`resources/lessons/`：目标织纹（next_lesson 仅为独立 F6 运行兼容字段）。
- `scripts/ui/weave_hud.gd`、`scenes/ui/weave_hud.tscn`：目标及操作界面。

详见 [开发入口](DEVELOPING.md) 和 [制作管线](docs/production_pipeline.md)。原有独立拖线场景和脚本保留，主玩法不再使用拖线作为过关条件。

## 验证

```powershell
& '<Godot executable>' --headless --path . --script res://tests/first_weave_smoke.gd
& '<Godot executable>' --headless --path . --script res://tests/level_selection_smoke.gd
```

去掉 `--headless` 并追加 `-- --capture` 可在 `.local/` 保存截图。当前无跨会话存档、自由绳索物理或音效；标准布局支持 1–4 行目标。中文使用系统字体。
