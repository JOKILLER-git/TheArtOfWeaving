class_name KnitSession
extends RefCounted
## 一关的规则状态机：当前行、下一针、往返方向、线状态，以及所有无效操作的处理。
## 表现层只调用 try_hook / toggle_yarn 并监听信号。

signal stitch_made(row: int, col: int, stitch: StitchType)
signal stitch_rejected(result: HookResult)
signal yarn_toggled(side: Yarn.Face)
signal row_completed(row: int)
signal level_completed

var chart: PatternChart
var registry: StitchRegistry
var fabric: Fabric
var yarn: Yarn = Yarn.new()
var current_row: int = 1        # 正在织的织物行（第 0 行是起始行）
var stitches_in_row: int = 0    # 本行已完成的针数
var completed: bool = false


func _init(p_chart: PatternChart, p_registry: StitchRegistry) -> void:
	assert(p_chart.is_valid(p_registry), "图纸无效")
	chart = p_chart
	registry = p_registry
	restart()


func restart() -> void:
	fabric = Fabric.new(chart.width(), chart.height() + 1, registry.base_stitch())
	yarn.reset()
	current_row = 1
	stitches_in_row = 0
	completed = false


func width() -> int:
	return chart.width()


## 最后一行的织物行号。
func last_row() -> int:
	return chart.height()


## 奇数行从左往右（+1），偶数行从右往左（-1）：真实织片每行翻面，来回往返。
static func row_direction(row: int) -> int:
	return 1 if row % 2 == 1 else -1


## 第 row 行按织的顺序第 k 针所在的列。
func column_at(row: int, k: int) -> int:
	return k if row_direction(row) > 0 else width() - 1 - k


## 下一针的列；整关完成时返回 -1。
func next_column() -> int:
	if completed:
		return -1
	return column_at(current_row, stitches_in_row)


## 本行刚织完的那一针的列；本行还没起针时返回 -1。
func last_made_column() -> int:
	if completed or stitches_in_row == 0:
		return -1
	return column_at(current_row, stitches_in_row - 1)


## 图纸在织物第 row 行第 col 列要求的针法（第 0 行为起始行针法）。
func expected_stitch(row: int, col: int) -> StitchType:
	if row == 0:
		return registry.base_stitch()
	return registry.by_id(chart.stitch_at(row - 1, col))


## 下一针要求的针法；完成后返回 null。
func next_expected() -> StitchType:
	var col := next_column()
	return expected_stitch(current_row, col) if col >= 0 else null


## 以当前线状态钩针会得到的针法。
func hooked_stitch() -> StitchType:
	return registry.for_side(yarn.side)


## 线状态是否符合下一针（完成后恒为 true）。
func is_yarn_ready() -> bool:
	var want := next_expected()
	return want == null or want.required_side() == yarn.side


## 请求在 col 列钩针。返回结果；非 ACCEPTED 时同时发出 stitch_rejected。
func try_hook(col: int) -> HookResult:
	if completed:
		return _reject(HookResult.Status.LEVEL_DONE, col, null)
	var want: StitchType = null
	if col >= 0 and col < width():
		want = expected_stitch(current_row, col)
	if col != next_column():
		return _reject(HookResult.Status.NOT_NEXT, col, want)
	var made := hooked_stitch()
	if made != want:
		return _reject(HookResult.Status.WRONG_SIDE, col, want)
	var row := current_row
	fabric.place(row, col, made)
	stitches_in_row += 1
	stitch_made.emit(row, col, made)
	if stitches_in_row >= width():
		_finish_row()
	return HookResult.new(HookResult.Status.ACCEPTED, row, col, made, want)


## 切换线的前后。整关完成后不再切换，返回 false。
func toggle_yarn() -> bool:
	if completed:
		return false
	yarn.toggle()
	yarn_toggled.emit(yarn.side)
	return true


func _reject(status: HookResult.Status, col: int, want: StitchType) -> HookResult:
	var result := HookResult.new(status, current_row, col, hooked_stitch(), want)
	stitch_rejected.emit(result)
	return result


func _finish_row() -> void:
	var finished := current_row
	if finished >= last_row():
		completed = true
		stitches_in_row = 0
		row_completed.emit(finished)
		level_completed.emit()
		return
	current_row += 1
	stitches_in_row = 0
	row_completed.emit(finished)
