class_name Fabric
extends RefCounted
## 已织好的线圈网格。第 0 行是给定的起始行，往上是玩家织的行。

var width: int
var height: int     # 含起始行的总行数
var _cells: Array[StitchType] = []


func _init(p_width: int, p_height: int, base: StitchType) -> void:
	width = p_width
	height = p_height
	_cells.resize(width * height)
	for col in width:
		_cells[col] = base


func is_inside(row: int, col: int) -> bool:
	return row >= 0 and row < height and col >= 0 and col < width


## 该格的针法；没织或越界时返回 null。
func stitch_at(row: int, col: int) -> StitchType:
	if not is_inside(row, col):
		return null
	return _cells[row * width + col]


func has_stitch(row: int, col: int) -> bool:
	return stitch_at(row, col) != null


func place(row: int, col: int, stitch: StitchType) -> void:
	assert(is_inside(row, col))
	_cells[row * width + col] = stitch


func count_in_row(row: int) -> int:
	var n := 0
	for col in width:
		if has_stitch(row, col):
			n += 1
	return n


func is_row_full(row: int) -> bool:
	return count_in_row(row) == width
