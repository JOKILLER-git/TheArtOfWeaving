class_name DraggableThread
extends Node2D
## Horizontal drag in local coordinates. Artwork never defines the hit area.

signal progress_changed(progress: float)
signal dragging_changed(active: bool)
signal end_reached

@onready var strand: Line2D = $Strand
@onready var tip: Sprite2D = $Tip
@onready var halo: Sprite2D = $Tip/Halo
@onready var pulse: AnimationPlayer = $AnimationPlayer

var tip_position: Vector2:
	get:
		return tip.position
var dragging: bool = false
var finished: bool = false
var _start := Vector2.ZERO
var _finish := Vector2.RIGHT
var _grab_radius: float = 40.0
var _snap_distance: float = 16.0
var _pointer_id: int = -2
var _grab_offset: float = 0.0
var _enabled: bool = false


## Standalone object scenes stay inert until a level supplies a valid track.
func _ready() -> void:
	set_enabled(false)


func set_enabled(value: bool) -> void:
	_enabled = value
	set_process_input(value)
	set_process_unhandled_input(value)
	if not value:
		cancel_drag()


func configure(start: Vector2, finish: Vector2, grab_radius: float, snap_distance: float) -> void:
	if not start.is_finite() or not finish.is_finite() or finish.x <= start.x:
		set_enabled(false)
		return
	set_enabled(true)
	cancel_drag()
	_start = start
	_finish = Vector2(finish.x, start.y)
	_grab_radius = grab_radius
	_snap_distance = minf(snap_distance, (finish.x - start.x) * 0.25)
	finished = false
	tip.show()
	halo.show()
	tip.position = _start
	$Tail.position = _start
	_update_strand()
	pulse.play("breathe")
	progress_changed.emit(0.0)


func _unhandled_input(event: InputEvent) -> void:
	# UI gets first refusal; once grabbed, _input handles movement and release.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_try_grab(event.position, -1)
	elif event is InputEventScreenTouch and event.pressed:
		_try_grab(event.position, event.index)


func _input(event: InputEvent) -> void:
	if not dragging:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and _pointer_id == -1:
		cancel_drag()
	elif event is InputEventMouseMotion and _pointer_id == -1:
		_move_to(event.position)
	elif event is InputEventScreenTouch and not event.pressed and event.index == _pointer_id:
		cancel_drag()
	elif event is InputEventScreenDrag and event.index == _pointer_id:
		_move_to(event.position)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		cancel_drag()


func cancel_drag() -> void:
	var was_dragging := dragging
	dragging = false
	_pointer_id = -2
	if was_dragging:
		dragging_changed.emit(false)


func _try_grab(viewport_position: Vector2, pointer: int) -> void:
	var local_position := get_global_transform_with_canvas().affine_inverse() * viewport_position
	if not _enabled or finished or dragging or local_position.distance_to(tip.position) > _grab_radius:
		return
	dragging = true
	_pointer_id = pointer
	_grab_offset = local_position.x - tip.position.x
	dragging_changed.emit(true)
	get_viewport().set_input_as_handled()


func _move_to(viewport_position: Vector2) -> void:
	var local_position := get_global_transform_with_canvas().affine_inverse() * viewport_position
	tip.position.x = clampf(local_position.x - _grab_offset, _start.x, _finish.x)
	var reached := tip.position.x >= _finish.x - _snap_distance
	if reached:
		tip.position = _finish
	_update_strand()
	progress_changed.emit((tip.position.x - _start.x) / (_finish.x - _start.x))
	if reached:
		finished = true
		cancel_drag()
		pulse.stop()
		halo.hide()
		end_reached.emit()


func _update_strand() -> void:
	strand.points = PackedVector2Array([_start, tip.position + Vector2(0.01, 0)])
