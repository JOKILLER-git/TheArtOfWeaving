# 新增章节与关卡

## 三层数据

```text
resources/catalog/main_catalog.tres [WeaveCatalog]
└── Chapters: Array[WeaveChapter]
    └── chapter_01.tres
        └── Stages: Array[WeaveStage]
            ├── 平纹 → resources/lessons/first_weave.tres
            └── 斜纹 → resources/lessons/second_weave.tres
```

数组顺序就是界面顺序和“下一关”顺序；无需注册脚本、编辑按钮或修改分支代码。全部关卡可直接选择，没有解锁门槛。完成后下一关可以跨章节，自动跳过空章节。

## 在现有章节增加一关

1. 在 Godot 文件系统面板复制一个 `resources/lessons/*.tres`，例如另存为 `third_weave.tres`。
2. 修改 Intro Title 与 Target Rows。当前标准织框为十根经线，每个字符串十位，使用 0/1，共支持 1–4 行。
3. 打开 `resources/catalog/chapter_01.tres`，在 Inspector 展开 Stages，增加一个元素，选择“新建 WeaveStage”。
4. 填写 Id（例如 `chapter_01_third`，全目录唯一且非空）、Title（选关显示名称），把新 Lesson 拖入 Lesson 属性。
5. Scene 可留空，表示使用 `game_browser.tscn` 中的 Default Level Scene，也就是当前通用织布场景。
6. 保存资源，按 F5。新关卡自动出现在本章末尾；拖动 Stages 数组项即可调整顺序。

复制条目时要将资源设为唯一并修改 Id，避免两张卡片引用同一条目。更改共享 Lesson 会影响所有引用它的关卡。

## 新增章节

1. 在 Godot 文件系统面板新建 WeaveChapter 资源，保存到 `resources/catalog/chapter_02.tres`。
2. 填写唯一 Id、Title，按上述方法填入 Stages。
3. 打开 `main_catalog.tres`，在 Chapters 数组增加该资源，保存后 F5。

空章节会显示“暂无关卡”，不会导致崩溃。空数组中的 null 条目、重复 ID、缺少 Lesson 会在选择界面显示配置错误，修好后重启运行。

## 不同布局的关卡

复制 `scenes/first_weave.tscn`，保留 WeaveLevel 根脚本及其组件约定，调整织框布局。把新 PackedScene 拖入对应 WeaveStage 的 Scene 属性。导航器在实例进入场景树前注入该条目的 Lesson，不会改写共享 Lesson 资源。

独立场景 F6 仍使用场景自身的 Lesson 与旧 next_lesson 字段，便于单关调试；从 F5 选关入口进入时，下一关完全由 Catalog 顺序决定，忽略 next_lesson。后续新关卡无需维护 next_lesson 链。

## 场景与职责

- `GameBrowser`：持有 Catalog、关卡实例和本次运行的完成 ID；负责返回与下一关。离开关卡时移除并销毁实例。
- `LevelSelection`：根据目录生成章节按钮与关卡按钮，发出选择信号。
- `chapter_button.tscn` / `stage_button.tscn`：可由美术或 UI 开发者直接编辑的按钮模板。
- `WeaveLevel`：管理单关玩法与完成判定，不读取选关列表。

主界面使用原生 Container 和 ScrollContainer，内容增加后可以滚动。重排章节不会串改完成记录，记录以稳定的关卡 Id 为键。本版本未实现跨运行存档；返回选关后再进入关卡会从头开始，完成勾号仍保留到退出游戏。

## 检查

```powershell
& '<Godot executable>' --headless --path . --script res://tests/level_selection_smoke.gd
& '<Godot executable>' --headless --path . --script res://tests/first_weave_smoke.gd
```

选关测试在内存中临时添加章节和关卡，不改写正式目录；验证按钮点击、独立第二关、目录排序、跨章、空章、ID 校验、动画期间返回。截图模式去掉 `--headless` 并追加 `-- --capture`，生成 `.local/level-selection.png`。
