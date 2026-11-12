class_name LevelDefinition
extends Resource
## 一关的数据：标题、图纸、提示参数，以及可选的星级阈值和预置织物（T006）。

@export var id: StringName = &""
@export var title: String = ""
@export var chart: PatternChart
## 多久没有进展就自动显示铅笔提示（秒）。
@export var idle_hint_seconds: float = 8.0
## 针法不对（线状态不对）时立即显示提示。
@export var hint_on_wrong_side: bool = true

@export_group("Stars")
## 失误次数不超过此值得 3 星。
@export var three_star_max_mistakes: int = 0
## 失误次数不超过此值得 2 星；更多为 1 星。
@export var two_star_max_mistakes: int = 2

@export_group("Preset")
## 关卡开始时已经织好的行（在起始行之上，写法同图纸，每行等宽）。为空表示没有预置。
## 预置内容与图纸不符时，KnitSession 进入「需要剪断」状态。
@export var preset_rows: PackedStringArray = PackedStringArray()


func has_preset() -> bool:
	return not preset_rows.is_empty()
