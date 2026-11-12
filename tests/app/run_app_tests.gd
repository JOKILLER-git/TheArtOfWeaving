extends SceneTree
## Godot --headless --path . --script res://tests/app/run_app_tests.gd


func _initialize() -> void:
	var suite: RefCounted = load("res://tests/app/app_flow_suite.gd").new()
	var result: Dictionary = suite.call("run")
	print("App flow checks: ", result)
	quit(0 if result["passed"] else 1)
