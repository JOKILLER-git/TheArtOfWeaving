class_name TitleScreen
extends Control
## 开始界面：游戏名（logo 文字）、中央一个大线圈（T008）、一段可以拉的线和左下角的剪刀。
## 把线头拉到右边发光的小线轴 → 开始（回车是快捷键）。
## T008：把剪刀拖到这段线上松开 → 线被剪断（剪断动画和声音同关卡）→ 发出 quit_requested（由 GameApp 淡出并退出）。
## 剪到空白处无反应。剪刀节点排在拉线之后，先收到鼠标事件，两者互不干扰。
## 元素随可视区域居中（T007）：标题条用锚点，线圈和拉线在 resized 时摆放。

signal start_requested
## 线被剪断：请求退出游戏。
signal quit_requested
## 请求切换 2D / 3D 关卡视图（演示用的普通按钮）。
signal view_toggle_requested

const LOGO_OFFSET := Vector2(0, -10)    # 线圈相对画面中心
const QUIT_DELAY := 0.45               # 剪断动画先播一会儿再请求退出

@onready var _pull: YarnPull2D = %Pull
@onready var _logo: YarnLoopLogo2D = %Logo
@onready var _scissors: Scissors2D = %Scissors
@onready var _effects: Node2D = %Effects

var _sound: SoundBank
var _view_button: Button


func _ready() -> void:
	_sound = SoundBank.new()
	add_child(_sound)
	_pull.pulled.connect(_on_pulled)
	_scissors.dropped.connect(_on_scissors_dropped)
	_view_button = Button.new()
	_view_button.focus_mode = Control.FOCUS_NONE
	_view_button.custom_minimum_size = Vector2(150, 48)
	_view_button.pressed.connect(func() -> void: view_toggle_requested.emit())
	add_child(_view_button)
	resized.connect(_layout)
	_layout()


func _layout() -> void:
	var view := Rect2(Vector2.ZERO, size)
	_logo.position = view.get_center() + LOGO_OFFSET
	_pull.fit_to(view)
	if _view_button != null:
		_view_button.size = _view_button.custom_minimum_size
		_view_button.position = Vector2(view.end.x - _view_button.size.x - 32.0, 32.0)


func open() -> void:
	show()
	_pull.reset()
	_scissors.reset_home()


func close() -> void:
	hide()


## 剪刀在 point 处松手：落在线上才剪断。返回是否剪到。
func cut_at(point: Vector2) -> bool:
	if not visible or not _pull.hits_strand(point):
		return false
	var effect := UnravelEffect2D.new()
	_effects.add_child(effect)
	var no_loops: Array[PackedVector2Array] = []
	effect.start(no_loops, _pull.strand_points(), point, YarnPull2D.WIDTH)
	_pull.cut()
	_scissors.snip()
	_sound.play_snip()
	get_tree().create_timer(QUIT_DELAY).timeout.connect(_request_quit)
	return true


func is_cut() -> bool:
	return _pull.is_cut


func _request_quit() -> void:
	if visible and _pull.is_cut:
		quit_requested.emit()


func _on_scissors_dropped(at: Vector2) -> void:
	cut_at(at)


func _on_pulled() -> void:
	if visible:
		start_requested.emit()


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or _pull.is_cut:
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and (key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER):
		get_viewport().set_input_as_handled()
		start_requested.emit()


## 显示当前视图模式；没有可切换的另一版本时隐藏按钮。
func set_view_label(label: String, can_toggle: bool) -> void:
	_view_button.text = "View: " + label
	_view_button.visible = can_toggle
