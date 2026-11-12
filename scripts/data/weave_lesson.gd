class_name WeaveLesson
extends Resource
## 每行从左到右，1 表示经线在纬线上方，0 表示经线在下方。
@export var intro_title: String = "第一章 · 第一节"
@export_group("目标织纹")
@export var target_rows: PackedStringArray = PackedStringArray(["1010101010", "0101010101", "1010101010", "0101010101"])
@export var next_lesson: Resource
# 保留旧资源的手感字段，供独立拖线场景使用。
@export_group("交互手感")
@export_range(16.0, 80.0) var grab_radius: float = 40.0
@export_range(0.0, 40.0) var snap_distance: float = 16.0

func is_valid(warp_count: int) -> bool:
	if warp_count < 2 or target_rows.is_empty() or target_rows.size() > 4:
		return false
	for row in target_rows:
		if row.length() != warp_count:
			return false
		for cell in row:
			if cell != "0" and cell != "1":
				return false
	return true

func matches(rows: Array[String]) -> bool:
	return PackedStringArray(rows) == target_rows
