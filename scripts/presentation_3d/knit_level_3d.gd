class_name KnitLevel3D
extends KnitLevelView
## KnitLevelView 的 3D 实现：一关 3D 针织的组合根。
## 规则、成绩、几何与手势识别器与 2D 完全相同（core：KnitSession、LevelScore、FabricLayout、HookGesture、WrapGesture）；
## 不同的只有表现层：
## - 3D 世界：CameraMapper3D（相机 + 射线投到织物平面）、FabricView3D（线圈扫成管子，前后是真实深度）、WorkingYarn3D。
## - 2D 叠加层：直接复用 presentation_2d 的提示、图纸卡、剪刀、星级、指针输入、剪断效果与 F3 调试层，
##   它们只依赖 FabricScreenMapper / YarnHandle 接口。
## 右键拖动：相机小范围转动（±ORBIT_MAX 度），松开回弹。快捷键同 2D：R 剪断重来 / H 提示 / N 跳过星级 / F3 调试层。

const SETTLE_ROW := 1.0
const SETTLE_LEVEL := 2.2
const SETTLE_SQUEEZE := 0.02
const CUT_HIT_PX := 26.0     # 剪刀离工作线多近算剪到（像素）
const ORBIT_MAX := 20.0      # 右键转动的最大角度（度）
const ORBIT_PER_PX := 0.12   # 每像素转多少度

var _registry := StitchRegistry.create_default()
var _level: LevelDefinition
var _layout: FabricLayout
var _mapper: CameraMapper3D
var _hook: HookGesture
var _wrap: WrapGesture
var _settle_tween: Tween
var _orbit_tween: Tween
var _orbit_from := Vector2.ZERO
var _orbit_start := Vector2.ZERO
var _orbiting: bool = false
var _debug: GestureDebugOverlay2D

@onready var _camera: Camera3D = %Camera
@onready var _fabric_view: FabricView3D = %FabricView
@onready var _yarn_view: WorkingYarn3D = %WorkingYarn
@onready var _effects: Node2D = %Effects
@onready var _hint_view: HintView2D = %HintView
@onready var _chart_card: ChartCard2D = %ChartCard
@onready var _pointer: PointerInput2D = %PointerInput
@onready var _scissors: Scissors2D = %Scissors
@onready var _stars: StarRatingView2D = %Stars
@onready var _sound: SoundBank = %SoundBank


func _ready() -> void:
	_mapper = CameraMapper3D.new(_camera)
	_scissors.dropped.connect(_on_scissors_dropped)
	_stars.setup(_sound)
	_stars.finished.connect(next_requested.emit)
	_debug = GestureDebugOverlay2D.new()
	_debug.visible = false
	add_child(_debug)
	# 延迟到空闲时处理：Windows 改窗口大小时信号可能在其他节点的 _process 中途同步发出。
	get_viewport().size_changed.connect(_on_view_resized, CONNECT_DEFERRED)
	if _level == null:
		_level = default_level
	assert(_level != null, "KnitLevel3D 需要一个关卡（play() 或 default_level）")
	_start()


func play(level: LevelDefinition) -> void:
	_level = level
	if is_node_ready():
		_start()


func restart() -> void:
	cut_at(_yarn_view.anchor_px())


func current_level() -> LevelDefinition:
	return _level


## 3D 相机映射（测试与验证用）。
func mapper() -> CameraMapper3D:
	return _mapper


func layout() -> FabricLayout:
	return _layout


func yarn_handle() -> YarnHandle:
	return _yarn_view.handle


func yarn_view() -> WorkingYarn3D:
	return _yarn_view


## 手势调试层（F3）。
func debug_overlay() -> GestureDebugOverlay2D:
	return _debug


## 相机转动（度），x 偏航 / y 俯仰，限制在 ±ORBIT_MAX。
func set_orbit(deg: Vector2) -> void:
	if _orbit_tween:
		_orbit_tween.kill()
	_mapper.orbit = deg.clamp(Vector2.ONE * -ORBIT_MAX, Vector2.ONE * ORBIT_MAX)


## 剪刀在 point 处剪断：叠加层播放散开动画（线圈投影成 2D 折线），规则层回到起始行。
func cut_at(point: Vector2) -> void:
	if session == null or session.completed:
		return
	var effect := UnravelEffect2D.new()
	_effects.add_child(effect)
	effect.start(_fabric_view.snapshot_loops(1), _yarn_view.screen_points(), point, _mapper.yarn_width())
	_scissors.snip()
	_sound.play_snip()
	_pointer.release()
	session.cut()
	_bind_views()
	_hint_view.note_progress()


## point 是否落在工作线或织物上（剪刀松手时判断）。
func hits_yarn_or_fabric(point: Vector2) -> bool:
	if session == null or session.completed:
		return false
	for p in _yarn_view.screen_points():
		if p.distance_to(point) <= CUT_HIT_PX:
			return true
	return fabric_rect().has_point(point)


## 织物现有部分投影到屏幕上的外接矩形（像素）。
func fabric_rect() -> Rect2:
	var top_row := 0
	for r in _layout.rows():
		if session.fabric.count_in_row(r) > 0:
			top_row = r
	var x0 := _layout.edge_x(-1)
	var x1 := _layout.edge_x(1)
	var y0 := _layout.sinker_y(0)
	var y1 := float(top_row) + FabricLayout.LOOP_TOP
	var rect := Rect2(_mapper.to_screen(Vector2(x0, y0)), Vector2.ZERO)
	for c: Vector2 in [Vector2(x1, y0), Vector2(x0, y1), Vector2(x1, y1)]:
		rect = rect.expand(_mapper.to_screen(c))
	return rect.grow(8.0)


func _start() -> void:
	session = KnitSession.new(_level.chart, _registry)
	if _level.has_preset():
		session.set_preset(_level.preset_rows)
	score = LevelScore.new(StarRating.for_level(_level))
	score.track(session)
	_layout = FabricLayout.new(session, CameraMapper3D.LOOP_WIDTH)
	_mapper.fit(_layout, get_viewport_rect())
	_wrap = WrapGesture.new(_layout)
	_hook = HookGesture.new(session, _layout, _wrap)

	# 识别器只发出「请求」，由规则层判定（与 2D 相同）。
	_hook.hook_requested.connect(session.try_hook)
	_wrap.wrap_completed.connect(session.toggle_yarn)
	session.stitch_made.connect(_on_stitch_made)
	session.stitch_rejected.connect(_on_stitch_rejected)
	session.yarn_toggled.connect(_on_yarn_toggled)
	session.row_completed.connect(_on_row_completed)
	session.level_completed.connect(_on_level_completed)

	if _settle_tween:
		_settle_tween.kill()
	_fabric_view.scale = Vector3.ONE
	_stars.stop()
	_scissors.reset_home()
	_bind_views()


func _bind_views() -> void:
	_hook.reset()
	_wrap.reset()
	_yarn_view.setup(session, _layout, _mapper, _hook)
	_fabric_view.setup(session, _layout, _mapper, _hook, _yarn_view)
	_hint_view.setup(session, _layout, _mapper, _level)
	_chart_card.setup(session, _yarn_view.handle)
	var recognizers: Array[GestureRecognizer] = [_wrap, _hook]
	_pointer.setup(_mapper, _yarn_view.handle, recognizers)
	_debug.setup(session, _layout, _mapper, _hook, _wrap, _yarn_view.handle)
	_scissors.wiggle = session.needs_cut


func _on_view_resized() -> void:
	if _mapper == null or _layout == null:
		return
	_pointer.release()
	_mapper.fit(_layout, get_viewport_rect())
	_yarn_view.setup(session, _layout, _mapper, _hook)


## 右键拖动转动相机，松开回弹。
func _unhandled_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_RIGHT:
		if button.pressed:
			_orbiting = true
			_orbit_from = button.position
			_orbit_start = _mapper.orbit
			if _orbit_tween:
				_orbit_tween.kill()
		elif _orbiting:
			_orbiting = false
			_spring_back()
		get_viewport().set_input_as_handled()
		return
	var motion := event as InputEventMouseMotion
	if motion != null and _orbiting:
		if (motion.button_mask & MOUSE_BUTTON_MASK_RIGHT) == 0:
			# 右键松开的事件丢了（例如移出窗口）：按松开处理。
			_orbiting = false
			_spring_back()
			return
		var d := (motion.position - _orbit_from) * ORBIT_PER_PX
		set_orbit(_orbit_start + Vector2(-d.x, -d.y))


func _spring_back() -> void:
	if _orbit_tween:
		_orbit_tween.kill()
	var m := _mapper
	_orbit_tween = create_tween()
	_orbit_tween.tween_method(func(v: Vector2) -> void: m.orbit = v, m.orbit, Vector2.ZERO, 0.6) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and _orbiting:
		_orbiting = false
		_spring_back()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_R:
			restart()
		KEY_H:
			_hint_view.toggle()
		KEY_F3:
			_debug.toggle()
		KEY_N:
			if session.completed:
				_stars.stop()
				next_requested.emit()
		_:
			return
	get_viewport().set_input_as_handled()


func _on_scissors_dropped(at: Vector2) -> void:
	if hits_yarn_or_fabric(at):
		cut_at(at)


func _on_stitch_made(row: int, col: int, stitch: StitchType) -> void:
	_fabric_view.grow_stitch(row, col)
	_sound.play_stitch(session.stitches_in_row - 1, stitch)
	_hint_view.note_progress()


func _on_stitch_rejected(result: HookResult) -> void:
	match result.status:
		HookResult.Status.WRONG_SIDE:
			_fabric_view.show_rejected(result.row, result.col)
			_sound.play_reject()
			if _level.hint_on_wrong_side:
				_hint_view.show_hint()
		HookResult.Status.NOT_NEXT:
			_fabric_view.flash_next_eye()
		HookResult.Status.BLOCKED:
			_scissors.nudge()
			_hint_view.flash_mistakes()
			_sound.play_reject()


func _on_yarn_toggled(side: Yarn.Face) -> void:
	_yarn_view.flip_to(side)
	_sound.play_swish(side == Yarn.Face.FRONT)
	if session.is_yarn_ready():
		_hint_view.note_progress()
	else:
		_hint_view.reset_idle()


func _on_row_completed(row: int) -> void:
	_pulse_settle(SETTLE_ROW)
	if row < session.last_row():
		_sound.play_row_done()


func _on_level_completed() -> void:
	_pointer.release()
	_sound.play_level_done()
	_pulse_settle(SETTLE_LEVEL)
	_stars.play(score.stars())
	level_finished.emit(_level)


## 一行完成时布面轻微收紧再弹回（织物节点纵向缩放）。
func _pulse_settle(amount: float) -> void:
	if _settle_tween:
		_settle_tween.kill()
	var view := _fabric_view
	var apply := func(v: float) -> void: view.scale = Vector3(1.0, 1.0 - SETTLE_SQUEEZE * v, 1.0)
	_settle_tween = create_tween()
	_settle_tween.tween_method(apply, 0.0, amount, 0.07)
	_settle_tween.tween_method(apply, amount, 0.0, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
