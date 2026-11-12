class_name WeaveHUD
extends Control
signal restart_requested
signal confirm_requested
signal undo_requested
signal next_requested
@export_group("入场节奏")
@export_range(0.1, 2.0) var intro_fade_in := 0.4
@export_range(0.0, 5.0) var intro_hold := 1.2
@export_range(0.1, 2.0) var intro_fade_out := 0.6
@onready var intro_title: Label = %IntroTitle
@onready var restart_button: Button = %Restart
@onready var error_message: Label = %ConfigurationError
@onready var target: Label = %Target
@onready var status: Label = %Status
@onready var confirm_button: Button = %Confirm
@onready var undo_button: Button = %Undo
@onready var next_button: Button = %Next
var _lesson: WeaveLesson
var has_next_level := false
var _intro_tween: Tween
var _intro_shown := false

func _ready() -> void:
	confirm_button.pressed.connect(func(): confirm_requested.emit())
	undo_button.pressed.connect(func(): undo_requested.emit())
	next_button.pressed.connect(func(): next_requested.emit())

func configure(lesson: WeaveLesson) -> void:
	if _lesson != lesson:
		_intro_shown = false
	_lesson = lesson
	has_next_level = lesson.next_lesson is WeaveLesson
	intro_title.text = lesson.intro_title

func reset() -> void:
	_stop_tweens()
	error_message.hide()
	restart_button.show()
	restart_button.modulate.a = 1.0
	$PlayControls.show()
	intro_title.hide()
	if not _intro_shown:
		_intro_shown = true
		intro_title.show()
		intro_title.modulate.a = 0.0
		_intro_tween = create_tween()
		_intro_tween.tween_property(intro_title, "modulate:a", 1.0, intro_fade_in)
		_intro_tween.tween_interval(intro_hold)
		_intro_tween.tween_property(intro_title, "modulate:a", 0.0, intro_fade_out)
		_intro_tween.tween_callback(intro_title.hide)

func update_state(rows: Array[String], selection: String, busy: bool, completed: bool) -> void:
	var full := rows.size() == _lesson.target_rows.size()
	var text_rows := "目标织纹（从上到下逐梭织入）    ↑ 经在上 · ↓ 经在下\n"
	for i in _lesson.target_rows.size():
		var symbols := ""
		for cell in _lesson.target_rows[i]:
			symbols += ("↑  " if cell == "1" else "↓  ")
		var mark := ""
		if i < rows.size():
			mark = "  ✓" if rows[i] == _lesson.target_rows[i] else "  ×"
		elif i == rows.size():
			mark = "  ← 当前"
		text_rows += "%d   %s%s\n" % [i + 1, symbols, mark]
	target.text = text_rows.strip_edges()
	confirm_button.disabled = busy or completed or full
	undo_button.disabled = busy or rows.is_empty()
	next_button.visible = completed and has_next_level
	confirm_button.visible = not completed
	if completed:
		status.text = "织纹正确，已完成。" + ("可以进入下一关。" if has_next_level else "本次练习完成。")
	elif busy:
		status.text = "引纬 → 打纬… 本梭提经已锁定"
	elif full:
		status.text = "织纹尚不吻合。撤销末行，逐行退回需要修改处，或重新开始。"
	else:
		status.text = "第 %d / %d 梭 · 点击经线上方按钮提经（已抬起 %d 根），确认后自动引纬。" % [rows.size() + 1, _lesson.target_rows.size(), selection.count("1")]

func show_configuration_error() -> void:
	_stop_tweens()
	intro_title.hide()
	restart_button.hide()
	$PlayControls.hide()
	error_message.show()

func _stop_tweens() -> void:
	if _intro_tween != null:
		_intro_tween.kill()

func _on_restart_pressed() -> void:
	restart_requested.emit()
