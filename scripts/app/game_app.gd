class_name GameApp
extends Control
## 游戏外壳（app 层）：开始界面 → 按 LevelCatalog 顺序进行每一关 → 结束界面，可重玩。
## F11 切换全屏 / 窗口（默认全屏启动，见 project.godot）。
## 只管流程与界面切换。每一关的玩法交给 KnitLevel2D：它报告「本关完成」，星级动画播完后请求下一关，
## 本类据此自动进入下一关。顶部的进度珠显示每关是否完成过。Esc：关卡中或结束界面回到开始界面。
## T008：
## - 玩家进度（PlayerProgress，core）记录每关最好星数，由 ProgressStore（app）存到 user://；进度珠、选关、织片墙共用这一份。
## - 选关晾衣绳（LevelClothesline2D）：打开时暂停关卡（处理与输入都停，关闭后原样继续）；选中某关则直接进入该关。
## - 开始界面剪断拉线 → 画面淡出 → quit_handler（默认 get_tree().quit()；测试可替换）。

enum Screen { TITLE, PLAYING, FINISHED }

const LEVEL_SCENE := preload("res://scenes/knit/knit_level_2d.tscn")
const QUIT_FADE := 0.6

@export var catalog: LevelCatalog

var screen: Screen = Screen.TITLE
var sequence: LevelSequence
var level_view: KnitLevel2D
var progress: PlayerProgress
## 进度的存储；在加入场景树之前替换可以改存储位置（测试用 ProgressStore.new("") 只放内存）。
var progress_store: ProgressStore
## 退出游戏的动作（淡出结束后调用）。
var quit_handler: Callable
var quitting: bool = false

@onready var _level_host: Control = %LevelHost
@onready var _beads: ProgressBeads2D = %Beads
@onready var _picker: LevelClothesline2D = %Clothesline
@onready var _title_screen: TitleScreen = %TitleScreen
@onready var _end_screen: EndScreen = %EndScreen
@onready var _fade: ColorRect = %Fade


func _ready() -> void:
	sequence = LevelSequence.new(catalog)
	if progress_store == null:
		# 演示版：每次启动都从零开始，进度只在本次运行内有效（不读写存档）。
		# 需要跨次保存时改为 ProgressStore.new()（默认路径 user://progress.json）。
		progress_store = ProgressStore.new("")
	progress = progress_store.load_progress()
	if not quit_handler.is_valid():
		quit_handler = func() -> void: get_tree().quit()
	_picker.setup(_beads, catalog, progress)
	_picker.level_chosen.connect(play_level)
	_picker.active_changed.connect(_on_picker_active_changed)
	_title_screen.start_requested.connect(start_game)
	_title_screen.quit_requested.connect(quit_game)
	_end_screen.play_again_requested.connect(start_game)
	show_title()


## 回到开始界面（关卡被释放）。
func show_title() -> void:
	_close_level()
	screen = Screen.TITLE
	_end_screen.close()
	_title_screen.open()


## 从第 1 关开始（开始游戏与重玩共用）。
func start_game() -> void:
	play_level(0)


## 进入第 index 关（开始游戏、重玩、选关共用）。之后照常按目录往后走。
func play_level(index: int) -> void:
	if not sequence.select(index):
		return
	_title_screen.close()
	_end_screen.close()
	screen = Screen.PLAYING
	if level_view == null:
		level_view = LEVEL_SCENE.instantiate() as KnitLevel2D
		level_view.level_finished.connect(_on_level_finished)
		level_view.next_requested.connect(advance)
	# 先指定关卡再加入场景树，KnitLevel2D 就不会先开始它的默认关卡。
	_play_current()
	if not level_view.is_inside_tree():
		_level_host.add_child(level_view)


## 当前关已完成时进入下一关；最后一关之后进入结束界面。未完成时忽略。
func advance() -> void:
	if screen != Screen.PLAYING or level_view == null or not level_view.is_completed():
		return
	if sequence.advance():
		_play_current()
	else:
		_show_end()


## 进度珠：当前关是否已完成（本次完成，或以前完成过）。
func is_current_bead_done() -> bool:
	return _beads.is_done(sequence.index)


## 选关晾衣绳（测试与验证用）。
func clothesline() -> LevelClothesline2D:
	return _picker


## 关卡是否被选关暂停。
func is_level_paused() -> bool:
	return level_view != null and level_view.process_mode == Node.PROCESS_MODE_DISABLED


## 开始界面剪断拉线：淡出后退出。
func quit_game() -> void:
	if quitting:
		return
	quitting = true
	_fade.show()
	_fade.color.a = 0.0
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, QUIT_FADE)
	tw.tween_callback(func() -> void: quit_handler.call())


func _play_current() -> void:
	level_view.play(sequence.current())
	_picker.set_current(sequence.index)
	_refresh_beads()
	_beads.show()
	_picker.show()


func _refresh_beads() -> void:
	var flags: Array[bool] = []
	for i in sequence.count():
		flags.append(progress.is_completed(catalog.get_level(i).id))
	_beads.set_completed(flags)
	var done := level_view != null and level_view.is_completed()
	_beads.set_progress(sequence.count(), sequence.index, done)


func _show_end() -> void:
	_close_level()
	screen = Screen.FINISHED
	_end_screen.open(sequence.catalog, progress)


func _close_level() -> void:
	_picker.force_close()
	_picker.hide()
	_beads.hide()
	if level_view != null:
		level_view.queue_free()
		level_view = null


func _on_level_finished(level: LevelDefinition) -> void:
	if progress.record(level.id, level_view.stars_earned()):
		progress_store.save(progress)
	_refresh_beads()


## 选关打开时暂停关卡（处理、动画、输入都停）；关闭后原样继续。
func _on_picker_active_changed(active: bool) -> void:
	if level_view != null:
		level_view.process_mode = Node.PROCESS_MODE_DISABLED if active else Node.PROCESS_MODE_INHERIT


## 全屏 ↔ 窗口。
static func toggle_fullscreen() -> void:
	var mode := DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_F11:
		get_viewport().set_input_as_handled()
		toggle_fullscreen()
		return
	if key.keycode != KEY_ESCAPE:
		return
	if screen != Screen.TITLE:
		get_viewport().set_input_as_handled()
		show_title()
