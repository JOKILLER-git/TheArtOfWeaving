class_name LevelDefinition
extends Resource
## 一关的数据：标题、图纸和提示参数。

@export var id: StringName = &""
@export var title: String = ""
@export var chart: PatternChart
## 多久没有进展就自动显示铅笔提示（秒）。
@export var idle_hint_seconds: float = 8.0
## 针法不对（线状态不对）时立即显示提示。
@export var hint_on_wrong_side: bool = true
