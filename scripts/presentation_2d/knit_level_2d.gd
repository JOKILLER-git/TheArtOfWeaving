class_name KnitLevel2D
extends Control
## 2D 关卡的组合根：按 LevelCatalog 加载关卡，创建规则（KnitSession）、几何、识别器和各视图并连接信号。
## R 重来 / H 提示 / N 下一关（完成后）。

const SETTLE_ROW := 1.0
const SETTLE_LEVEL := 2.2

@export var catalog: LevelCatalog
@export var start_index: int = 0

var level_index: int = 0
var session: KnitSession

var _registry := StitchRegistry.create_default()
var _level: LevelDefinition
var _layout: FabricLayout
var _mapper: ScreenMapper2D
var _hook: HookGesture
var _wrap: WrapGesture
var _settle_tween: Tween

@onready var _fabric_view: FabricView2D = %FabricView
@onready var _hint_view: HintView2D = %HintView
@onready var _yarn_view: WorkingYarn2D = %WorkingYarn
@onready var _chart_card: ChartCard2D = %ChartCard
@onready var _pointer: PointerInput2D = %PointerInput
@onready var _sound: SoundBank = %SoundBank
@onready var _title: Label = %Title
@onready var _done_label: Label = %DoneLabel


func _ready() -> void:
	assert(catalog != null and catalog.count() > 0, "KnitLevel2D 需要关卡目录")
	start_level(clampi(start_index, 0, catalog.count() - 1))


func start_level(index: int) -> void:
	level_index = index
	_level = catalog.get_level(index)
	session = KnitSession.new(_level.chart, _registry)
	_layout = FabricLayout.new(session)
	_mapper = ScreenMapper2D.new()
	_mapper.fit(_layout)
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

	_yarn_view.setup(session, _layout, _mapper)
	_fabric_view.setup(session, _layout, _mapper, _hook, _yarn_view)
	_hint_view.setup(session, _layout, _mapper, _level)
	_chart_card.setup(session, _yarn_view)
	var recognizers: Array[GestureRecognizer] = [_wrap, _hook]
	_pointer.setup(_mapper, _yarn_view, recognizers)

	if _settle_tween:
		_settle_tween.kill()
	_title.text = "针织  %d / %d  ·  %s" % [index + 1, catalog.count(), _level.title]
	_done_label.visible = false


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_R:
			start_level(level_index)
		KEY_H:
			_hint_view.toggle()
		KEY_N:
			if session.completed:
				start_level(catalog.next_index(level_index))


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
	_done_label.visible = true
	_sound.play_level_done()
	_pulse_settle(SETTLE_LEVEL)


## 一行完成时布面轻微收紧再弹回。
func _pulse_settle(amount: float) -> void:
	if _settle_tween:
		_settle_tween.kill()
	var mapper := _mapper
	var apply := func(v: float) -> void: mapper.settle = v
	_settle_tween = create_tween()
	_settle_tween.tween_method(apply, 0.0, amount, 0.07)
	_settle_tween.tween_method(apply, amount, 0.0, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
