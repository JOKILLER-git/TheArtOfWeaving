class_name PointerInput2D
extends Node2D
## 鼠标输入适配：抓住线头拖动，把像素换算成织物坐标后按小步长补采样喂给手势识别器。
## 只依赖 FabricScreenMapper 与 YarnHandle，2D 与 3D 关卡共用（3D 中放在 2D 叠加层里）。

const SAMPLE_STEP := 0.05   # 补采样步长（列宽）：鼠标事件可能跳过很小的眼

var _mapper: FabricScreenMapper
var _yarn: YarnHandle
var _recognizers: Array[GestureRecognizer] = []
var _last := Vector2.ZERO   # 上一个喂给识别器的织物坐标


func setup(mapper: FabricScreenMapper, yarn: YarnHandle, recognizers: Array[GestureRecognizer]) -> void:
	_mapper = mapper
	_yarn = yarn
	_recognizers = recognizers
	release()


## 松开线头（玩家松手、窗口失焦或整关完成）。
func release() -> void:
	if _yarn != null:
		_yarn.held = false
	for r in _recognizers:
		r.reset()


func _unhandled_input(event: InputEvent) -> void:
	if _mapper == null or not (event is InputEventMouse):
		return
	var local := make_input_local(event)
	var button := local as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed and _yarn.can_grab(button.position):
			_grab(button.position)
		elif not button.pressed and _yarn.held:
			release()
		return
	var motion := local as InputEventMouseMotion
	if motion != null and _yarn.held:
		_drag_to(motion.position)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		release()


func _grab(p: Vector2) -> void:
	for r in _recognizers:
		r.reset()
	_yarn.held = true
	_last = _mapper.to_fabric(p)


func _drag_to(p: Vector2) -> void:
	_yarn.tip = p
	var target := _mapper.to_fabric(p)
	var steps := maxi(1, ceili(_last.distance_to(target) / SAMPLE_STEP))
	for s in range(1, steps + 1):
		var q := _last.lerp(target, float(s) / steps)
		for r in _recognizers:
			r.feed(q)
		if not _yarn.held:
			break
	_last = target
