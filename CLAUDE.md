# 织间 · The Art of Weaving —— 实现规范

本文件给负责「实现」的 AI 读。设计决定不在这里，在「编织艺术」Project 文档的 `design/` 下；任务在 `tasks/` 下。

## 分工
- 主策（设计对话）：写 `design/` 文档和 `tasks/Txxx-*.md` 任务卡，定义目标与验收标准。
- 程序（实现对话 / 子代理）：只按任务卡实现。任务卡没写的设计问题，不要自己拍板；在回报里列出来交给主策。
- 任务卡是唯一依据。完成后在任务卡末尾追加「## 回报」（用 Projects 工具读出全文、追加后整份写回同一路径）。

## 项目基本信息
- Godot 4.7，GL Compatibility，主画布 1280×800，canvas_items 缩放。
- 主入口 `scenes/game_browser.tscn`（选关 → 关卡）。旧的「经纬织布」玩法在 `scripts/gameplay/`、`scripts/first_weave.gd`。
- 针织原型：`scenes/prototypes/knit_prototype.tscn` + `scripts/prototypes/knit_prototype.gd`。
- 用户在 Windows 上用 Godot 编辑器；文件夹挂载在 device_bash 的 `$HOME/mnt/TheArtOfWeaving`。

## 代码约定
- GDScript 带静态类型；类名 PascalCase，函数/变量 snake_case；注释用中文，简短。
- 场景负责布局，脚本负责行为，Resource 负责关卡数据（沿用现有项目约定，见 DEVELOPING.md）。
- 原型代码放 `prototypes/` 子目录，不改动现有织布玩法，除非任务卡要求。
- 不要依赖 Godot AI 插件写游戏逻辑（插件只用于开发时验证）。

## 修改文件的方式
- 读、搜、改文件用 device_bash 在 `$HOME/mnt/TheArtOfWeaving` 下操作（sed/python 原地修改）；不要凭工具输出重新敲整份文件。
- 也可以用 godot-ai 的 script_patch / script_create / scene_* 工具。
- 场景 .tscn 若正在编辑器中打开，改完要让编辑器重新加载，避免被旧版本覆盖保存。
- 文件夹里删除文件默认被禁止；需要删除时列在回报里。

## 验证（必须做，才算完成）
1. 用 godot-ai 运行目标场景（project_run 等），用 logs_read 读输出，确保没有脚本错误；有警告也列出来。
2. 截图（editor_screenshot 或游戏截图）确认画面符合预期。
3. 能模拟输入时，模拟一次关键操作（例如拖拽）验证逻辑。
4. 结束时停止运行中的游戏，不要让编辑器处于运行状态。
5. 回报写清：改了哪些文件、验证了什么、截图结论、未解决的问题、需要主策决定的事。

## 禁止
- 不改 `addons/`、`project.godot` 的插件配置，除非任务卡要求。
- 不做任务卡范围之外的「顺手优化」；发现问题写进回报。
