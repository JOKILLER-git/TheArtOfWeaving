class_name HookResult
extends RefCounted
## 一次钩针请求的结果。

## BLOCKED（T006 追加在末尾，旧值不变）：织物上有预置错误，必须先剪断才能继续织。
enum Status { ACCEPTED, WRONG_SIDE, NOT_NEXT, LEVEL_DONE, BLOCKED }

var status: Status
var row: int
var col: int
var stitch: StitchType      # 按当前线状态钩出来的针法
var expected: StitchType    # 图纸在该位置要求的针法（LEVEL_DONE / BLOCKED 时可能为 null）


func _init(p_status: Status, p_row: int, p_col: int, p_stitch: StitchType, p_expected: StitchType) -> void:
	status = p_status
	row = p_row
	col = p_col
	stitch = p_stitch
	expected = p_expected


func is_accepted() -> bool:
	return status == Status.ACCEPTED
