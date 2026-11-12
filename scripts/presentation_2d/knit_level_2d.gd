class_name KnitLevel2D
extends Control
## 一关 2D 针织的组合根：为一个 LevelDefinition 创建规则（KnitSession + LevelScore）、几何、识别器和各视图并连接信号。
## 只负责「这一关」；关卡顺序由外部（GameApp）决定。本类通过信号报告完成，星级动画播完后请求下一关。
## 画面里没有文字：重来用左下角的剪刀（拖到工作线或织物上松开），结算用星。
## 未被管理时（F6 单独运行）自动开始 default_level。快捷键：R 剪断重来 / H 提示 / N 跳过星级动画 / F3 手势调试层。
## 画面按可视区域（随窗口比例变化）布局：可视区域改变时重新计算织物缩放和位置（T007）。

## 本关织完（星级动画开始）。
signal level_finished(level: LevelDefinition)
## 星级动画播完（或按 N 跳过）：请求下一关。
signal next_requested

const SETTLE_ROW := 1.0
const SETTLE_LEVEL := 2.2
const CUT_HIT_PX := 26.0    # 剪刀离工作线多近算剪到（像素）

## 单独运行本场景时使用的关卡。
@export var default_level: LevelDefinition

var session: KnitSession
var score: LevelScore

var _registry := StitchRegistry.create_default()
var _level: LevelDefinition
var _layout: FabricLayout
var _mapper: ScreenMapper2D
var _hook: HookGesture
var _wrap: WrapGesture
var _settle_tween: Tween
var _debug: GestureDebugOverlay2D

@onready var _fabric_view: FabricView2D = %FabricView
@onready var _effects: Node2D = %Effects
@onready var _hint_view: HintView2D = %HintView
@onready var _yarn_view: WorkingYarn2D = %WorkingYarn
@onready var _chart_card: ChartCard2D = %ChartCard
@onready var _pointer: PointerInput2D = %PointerInput
@onready var _scissors: Scissors2D = %Scissors
@onready var _stars: StarRatingView2D = %Stars
@onready var _sound: SoundBank = %SoundBank


func _ready() -> void:
	_scissors.dropped.connect(_on_scissors_dropped)
	_stars.setup(_sound)
	_stars.finished.connect(next_requested.emit)
	_debug = GestureDebugOverlay2D.new()
	_debug.visible = false
	add_child(_debug)
	get_viewport().size_changed.connect(_on_view_resized)
	# 管理者可能在加入场景树之前就调用了 play()；否则用默认关卡。
	if _level == null:
		_level = default_level
	assert(_level != null, "KnitLevel2D 需要一个关卡（play() 或 default_level）")
	_start()


## 开始一关（新的会话、新的成绩）。
func play(level: LevelDefinition) -> void:
	_level = level
	if is_node_ready():
		_start()


## 剪断重来（R 键与剪刀共用）：剪口取在工作线锚点。
func restart() -> void:
	cut_at(_yarn_view.anchor_px())


func current_level() -> LevelDefinition:
	return _level


func is_completed() -> bool:
	return session != null and session.completed


## 本关当前的星级（按目前的失误次数）。
func stars_earned() -> int:
	return score.stars() if score != null else 0


## 剪刀在 point 处剪断：画面播放散开动画，规则层回到起始行（预置织物也一起剪掉）。完成后不再剪。
func cut_at(point: Vector2) -> void:
	if session == null or session.completed:
		return
	var effect := UnravelEffect2D.new()
	_effects.add_child(effect)
	effect.start(_fabric_view.snapshot_loops(1), _yarn_view.build_strand().points, point, _mapper.yarn_width())
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
	for p in _yarn_view.build_strand().points:
		if p.distance_to(point) <= CUT_HIT_PX:
			return true
	return fabric_rect().has_point(point)


## 织物现有部分在画面上的范围（像素）：从起始行到最高的一行已织线圈。
func fabric_rect() -> Rect2:
	var top_row := 0
	for r in _layout.rows():
		if session.fabric.count_in_row(r) > 0:
			top_row = r
	var top_left := _mapper.to_screen(Vector2(_layout.edge_x(-1), float(top_row) + FabricLayout.LOOP_TOP))
	var bottom_right := _mapper.to_screen(Vector2(_layout.edge_x(1), _layout.sinker_y(0)))
	return Rect2(top_left, bottom_right - top_left).abs().grow(8.0)


func _start() -> void:
	session = KnitSession.new(_level.chart, _registry)
	if _level.has_preset():
		session.set_preset(_level.preset_rows)
	score = LevelScore.new(StarRating.for_level(_level))
	score.track(session)
	_layout = FabricLayout.new(session, ScreenMapper2D.LOOP_WIDTH)
	_mapper = ScreenMapper2D.new()
	_mapper.fit(_layout, get_viewport_rect())
	_wrap = WrapGesture.new(_layout)
	_hook = HookGesture.new(session, _layout, _wrap)

	# 识别器只发出「请求」，由规则层判定。
	_hook.hook_requested.connect(session.try_hook)
	_wrap.wrap_completed.connect(session.toggle_yarn)
	session.stitch_made.connect(_on_stitch_made)
	session.stitch_rejected.connect(_on_stitch_rejected)
	session.yarn_toggled.connect(_on_yarn_toggled)
	session.row_completed.connect(_on_row_completed)
	session.level_completed.connect(_on_level_completed)

	if _settle_tween:
		_settle_tween.kill()
	_stars.stop()
	_scissors.reset_home()
	_bind_views()


## 把各视图接到当前会话（开始与剪断后都调用）。
func _bind_views() -> void:
	_hook.reset()
	_wrap.reset()
	_yarn_view.setup(session, _layout, _mapper)
	_fabric_view.setup(session, _layout, _mapper, _hook, _yarn_view)
	_hint_view.setup(session, _layout, _mapper, _level)
	_chart_card.setup(session, _yarn_view)
	var recognizers: Array[GestureRecognizer] = [_wrap, _hook]
	_pointer.setup(_mapper, _yarn_view, recognizers)
	_debug.setup(session, _layout, _mapper, _hook, _wrap, _yarn_view)
	_scissors.wiggle = session.needs_cut


## 手势调试层（F3）。
func debug_overlay() -> GestureDebugOverlay2D:
	return _debug


## 可视区域变了（全屏切换、改窗口大小）：织物重新缩放居中，线头回到静止位置。
func _on_view_resized() -> void:
	if _mapper == null:
		return
	_pointer.release()
	_mapper.fit(_layout, get_viewport_rect())
	_yarn_view.setup(session, _layout, _mapper)


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
			# 织物上有错：剪刀晃一下，铅笔圈加深。
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


## 一行完成时布面轻微收紧再弹回。
func _pulse_settle(amount: float) -> void:
	if _settle_tween:
		_settle_tween.kill()
	var mapper := _mapper
	var apply := func(v: float) -> void: mapper.settle = v
	_settle_tween = create_tween()
	_settle_tween.tween_method(apply, 0.0, amount, 0.07)
	_settle_tween.tween_method(apply, amount, 0.0, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
