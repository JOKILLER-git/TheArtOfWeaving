class_name KnitSession
extends RefCounted
## 一关的规则状态机：当前行、下一针、往返方向、线状态，以及所有无效操作的处理。
## 表现层只调用 try_hook / toggle_yarn / cut 并监听信号。
## 可选的预置织物（set_preset）：与图纸不符时进入「需要剪断」状态，钩针返回 BLOCKED，cut() 后回到起始行。

signal stitch_made(row: int, col: int, stitch: StitchType)
signal stitch_rejected(result: HookResult)
signal yarn_toggled(side: Yarn.Face)
signal row_completed(row: int)
signal level_completed
## 织物被剪断、回到起始行（T006）。
signal fabric_cut

var chart: PatternChart
var registry: StitchRegistry
var fabric: Fabric
var yarn: Yarn = Yarn.new()
var current_row: int = 1        # 正在织的织物行（第 0 行是起始行）
var stitches_in_row: int = 0    # 本行已完成的针数
var completed: bool = false
var needs_cut: bool = false     # 预置织物有错，必须先剪断（T006）
var _preset := PackedStringArray()


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
	needs_cut = false
	_apply_preset()


## 设置预置织物（起始行之上已经织好的若干整行，写法同图纸）并重新开始。空数组表示没有预置。
func set_preset(rows: PackedStringArray) -> void:
	assert(_is_valid_preset(rows), "预置织物无效")
	_preset = rows
	restart()


## 剪断：去掉预置和所有新织的线圈，回到只有起始行的状态（之后不再出现预置）。
func cut() -> void:
	_preset = PackedStringArray()
	restart()
	fabric_cut.emit()


## 织物上与图纸不符的线圈，Vector2i(列, 行)。
func mistake_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for row in range(1, fabric.height):
		for col in width():
			var st := fabric.stitch_at(row, col)
			if st != null and st != expected_stitch(row, col):
				out.append(Vector2i(col, row))
	return out


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
	if completed or needs_cut:
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
	if needs_cut:
		return _reject(HookResult.Status.BLOCKED, col, null)
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


## 切换线的前后。整关完成后、或需要剪断时不再切换，返回 false。
func toggle_yarn() -> bool:
	if completed or needs_cut:
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


func _is_valid_preset(rows: PackedStringArray) -> bool:
	if rows.size() > chart.height():
		return false
	for line in rows:
		if line.length() != width():
			return false
		for k in line.length():
			if not registry.has(line[k]):
				return false
	return true


## 把预置行织进织物。有错 → 需要剪断（停在最后一个预置行的末尾）；
## 全对 → 从下一行接着织（预置覆盖全部行时直接完成，不发信号）。
func _apply_preset() -> void:
	if _preset.is_empty():
		return
	for i in _preset.size():
		for col in width():
			fabric.place(i + 1, col, registry.by_id(_preset[i][col]))
	if not mistake_cells().is_empty():
		needs_cut = true
		current_row = _preset.size()
		stitches_in_row = width()
	elif _preset.size() >= last_row():
		current_row = last_row()
		completed = true
	else:
		current_row = _preset.size() + 1
