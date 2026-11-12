extends SceneTree
## Godot --path . --script res://tests/presentation_3d/run_presentation_3d_tests.gd
## （需要渲染窗口：CameraMapper3D 依赖相机投影，不要加 --headless。）


func _initialize() -> void:
	var suite: RefCounted = load("res://tests/presentation_3d/presentation_3d_suite.gd").new()
	var result: Dictionary = suite.call("run")
	print("Presentation 3D checks: ", result)
	quit(0 if result["passed"] else 1)
