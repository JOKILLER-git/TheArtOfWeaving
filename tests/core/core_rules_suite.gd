extends RefCounted
## core 层规则测试：只用 RefCounted / Resource，不需要场景，可无头运行。
## 入口：run() 返回 {passed, checks, failures}；命令行见 run_core_tests.gd。

var checks: int = 0
var failures: Array[String] = []
var _registry := StitchRegistry.create_default()


func run() -> Dictionary:
	for method in get_method_list():
		var method_name: String = method["name"]
		if method_name.begins_with("test_"):
			call(method_name)
	return {"passed": failures.is_empty(), "checks": checks, "failures": failures}


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error("FAIL: " + message)


## 按元素比较（不区分类型化数组与普通数组）。
func same(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for k in a.size():
		if a[k] != b[k]:
			return false
	return true


func make_session(rows: PackedStringArray) -> KnitSession:
	var chart := PatternChart.new()
	chart.rows = rows
	return KnitSession.new(chart, _registry)


## 按顺序把本行剩下的针都织完（自动切换线状态）。
func knit_rest_of_row(session: KnitSession) -> void:
	var row := session.current_row
	while not session.completed and session.current_row == row:
		if not session.is_yarn_ready():
			session.toggle_yarn()
		session.try_hook(session.next_column())


# ---------------------------------------------------------------- 规则

func test_knit_with_yarn_back_is_accepted() -> void:
	var s := make_session(PackedStringArray(["KK"]))
	var made: Array[StitchType] = []
	s.stitch_made.connect(func(_r: int, _c: int, st: StitchType) -> void: made.append(st))
	var result := s.try_hook(s.next_column())
	check(result.status == HookResult.Status.ACCEPTED, "线在后钩下针目标应被接受")
	check(result.stitch is KnitStitch, "钩出的是下针")
	check(s.fabric.stitch_at(1, 0) is KnitStitch, "织物 (1,0) 记录为下针")
	check(made.size() == 1, "发出 stitch_made")


func test_yarn_front_on_knit_target_is_wrong_side() -> void:
	var s := make_session(PackedStringArray(["KK"]))
	var rejected: Array[HookResult] = []
	s.stitch_rejected.connect(func(r: HookResult) -> void: rejected.append(r))
	s.toggle_yarn()
	var result := s.try_hook(s.next_column())
	check(result.status == HookResult.Status.WRONG_SIDE, "线在前钩下针目标应为 WRONG_SIDE")
	check(result.stitch is PurlStitch and result.expected is KnitStitch, "结果附带钩出的针法与要求的针法")
	check(not s.fabric.has_stitch(1, 0), "WRONG_SIDE 不改动织物")
	check(rejected.size() == 1, "发出 stitch_rejected")


func test_purl_with_yarn_front_is_accepted() -> void:
	var s := make_session(PackedStringArray(["PP"]))
	check(not s.is_yarn_ready(), "上针目标、线在后：线状态不对")
	check(s.toggle_yarn(), "可以切换线状态")
	check(s.yarn.side == Yarn.Face.FRONT, "切换后线在前")
	var result := s.try_hook(s.next_column())
	check(result.is_accepted() and result.stitch is PurlStitch, "线在前钩上针目标被接受")


func test_hook_other_eye_is_not_next() -> void:
	var s := make_session(PackedStringArray(["KKKK"]))
	check(s.next_column() == 0, "第 1 行从左往右，下一针在第 0 列")
	var result := s.try_hook(2)
	check(result.status == HookResult.Status.NOT_NEXT, "钩非下一针的眼应为 NOT_NEXT")
	check(s.stitches_in_row == 0, "NOT_NEXT 不推进")


func test_direction_reverses_after_row() -> void:
	var s := make_session(PackedStringArray(["KKK", "KKK"]))
	var finished: Array[int] = []
	s.row_completed.connect(func(r: int) -> void: finished.append(r))
	check(s.next_column() == 0, "奇数行从左边开始")
	knit_rest_of_row(s)
	check(same(finished, [1]), "第 1 行完成时发出 row_completed(1)")
	check(s.current_row == 2, "进入第 2 行")
	check(s.next_column() == 2, "偶数行从右边开始（方向反转）")
	s.try_hook(2)
	check(s.next_column() == 1, "偶数行向左推进")


func test_level_completed_once_and_then_level_done() -> void:
	var s := make_session(PackedStringArray(["KP", "KP"]))
	var done_count := [0]
	s.level_completed.connect(func() -> void: done_count[0] += 1)
	knit_rest_of_row(s)
	check(done_count[0] == 0, "还没织完不发 level_completed")
	knit_rest_of_row(s)
	check(s.completed, "全部织完后 completed")
	check(done_count[0] == 1, "整关完成发出一次 level_completed")
	check(s.try_hook(0).status == HookResult.Status.LEVEL_DONE, "完成后再钩为 LEVEL_DONE")
	check(not s.toggle_yarn(), "完成后不再切换线状态")
	check(s.fabric.stitch_at(2, 1) is PurlStitch, "罗纹第 2 行第 1 列为上针")


func test_registry_and_chart() -> void:
	check(_registry.for_side(Yarn.Face.BACK) is KnitStitch, "线在后 → 下针")
	check(_registry.for_side(Yarn.Face.FRONT) is PurlStitch, "线在前 → 上针")
	check(_registry.by_id("P") is PurlStitch, "按 id 查针法")
	var bad := PatternChart.new()
	bad.rows = PackedStringArray(["KK", "K"])
	check(not bad.is_valid(_registry), "行宽不一致的图纸无效")


func test_level_catalog_resources() -> void:
	var catalog := load("res://resources/levels/level_catalog.tres") as LevelCatalog
	check(catalog != null and catalog.count() == 4, "目录里有 4 关")
	if catalog == null:
		return
	var expected := [["KK"], ["KKKK"], ["PPPP"], ["KPKP", "KPKP"]]
	for i in catalog.count():
		var level := catalog.get_level(i)
		check(level.chart.is_valid(_registry), "第 %d 关图纸有效" % (i + 1))
		check(same(Array(level.chart.rows), expected[i]), "第 %d 关图纸内容" % (i + 1))


# ---------------------------------------------------------------- 手势

## 下针关第 1 行：锚点 (-0.5, 0.22)，下一针的眼 (0, 0.42)。
func make_gestures(rows: PackedStringArray) -> Dictionary:
	var s := make_session(rows)
	var layout := FabricLayout.new(s)
	var wrap_gesture := WrapGesture.new(layout)
	var hook := HookGesture.new(s, layout, wrap_gesture)
	var hooks: Array[int] = []
	var wraps := [0]
	hook.hook_requested.connect(func(c: int) -> void: hooks.append(c))
	wrap_gesture.wrap_completed.connect(func() -> void: wraps[0] += 1)
	return {"session": s, "layout": layout, "wrap": wrap_gesture, "hook": hook, "hooks": hooks, "wraps": wraps}


## 把一串织物坐标点按 0.05 列宽补采样后喂给识别器（与 PointerInput2D 相同）。
func feed_path(recognizers: Array[GestureRecognizer], pts: Array[Vector2]) -> void:
	for k in range(1, pts.size()):
		var steps := maxi(1, ceili(pts[k - 1].distance_to(pts[k]) / 0.05))
		for s in range(1, steps + 1):
			var q := pts[k - 1].lerp(pts[k], float(s) / steps)
			for r in recognizers:
				r.feed(q)


func circle_path(center: Vector2, radius: float, from_deg: float, to_deg: float) -> Array[Vector2]:
	var pts: Array[Vector2] = []
	var n := 72
	for k in n + 1:
		var a := deg_to_rad(lerpf(from_deg, to_deg, float(k) / n))
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
	return pts


func test_hook_gesture_below_to_above_triggers() -> void:
	var g := make_gestures(PackedStringArray(["KKKK"]))
	var layout: FabricLayout = g["layout"]
	var eye := layout.eye_center(0, 0)
	var recognizers: Array[GestureRecognizer] = [g["hook"]]
	var path: Array[Vector2] = [eye + Vector2(0, -0.8), eye + Vector2(0, 0.8)]
	feed_path(recognizers, path)
	check(same(g["hooks"], [0]), "下进上出触发钩针（第 0 列）")


func test_hook_gesture_above_to_below_does_not_trigger() -> void:
	var g := make_gestures(PackedStringArray(["KKKK"]))
	var layout: FabricLayout = g["layout"]
	var eye := layout.eye_center(0, 0)
	var recognizers: Array[GestureRecognizer] = [g["hook"]]
	var path: Array[Vector2] = [eye + Vector2(0, 0.8), eye + Vector2(0, -0.8)]
	feed_path(recognizers, path)
	var side_path: Array[Vector2] = [eye + Vector2(-0.8, 0), eye + Vector2(0.8, 0)]
	feed_path(recognizers, side_path)
	check((g["hooks"] as Array).is_empty(), "上进下出、横穿都不触发")


func test_wrap_gesture_full_circle_triggers() -> void:
	var g := make_gestures(PackedStringArray(["PPPP"]))
	var layout: FabricLayout = g["layout"]
	var recognizers: Array[GestureRecognizer] = [g["wrap"], g["hook"]]
	feed_path(recognizers, circle_path(layout.anchor(), 0.9, -90.0, 290.0))
	check(g["wraps"][0] == 1, "绕锚点一圈触发一次切换")
	var clockwise := make_gestures(PackedStringArray(["PPPP"]))
	var cw_rec: Array[GestureRecognizer] = [clockwise["wrap"]]
	feed_path(cw_rec, circle_path(layout.anchor(), 0.9, 270.0, -110.0))
	check(clockwise["wraps"][0] == 1, "顺时针绕一圈同样有效")


func test_wrap_gesture_zigzag_does_not_trigger() -> void:
	var g := make_gestures(PackedStringArray(["KKKK"]))
	var layout: FabricLayout = g["layout"]
	var a := layout.anchor()
	var path: Array[Vector2] = []
	for k in 12:
		path.append(a + Vector2(0.2 + 0.15 * k, -0.6 if k % 2 == 0 else 0.5))
	var recognizers: Array[GestureRecognizer] = [g["wrap"]]
	feed_path(recognizers, path)
	check(g["wraps"][0] == 0, "锯齿路径不触发绕线")


## T003 遗留误触：小圈逆时针绕线顺路从下方穿过下一针的眼，不应被判成钩针。
func test_small_wrap_through_eye_does_not_hook() -> void:
	for radius in [0.45, 0.54, 0.65]:
		var g := make_gestures(PackedStringArray(["KKKK"]))
		var layout: FabricLayout = g["layout"]
		var recognizers: Array[GestureRecognizer] = [g["wrap"], g["hook"]]
		var start := -120.0
		feed_path(recognizers, circle_path(layout.anchor(), radius, start, start + 360.0))
		check((g["hooks"] as Array).is_empty(), "半径 %.2f 的逆时针小圈不触发钩针" % radius)
		check(g["wraps"][0] == 1, "半径 %.2f 的小圈仍完成绕线" % radius)
	# 对照：没有绕线守卫时同一路径会误触发，说明上面的测试确实覆盖了误触。
	var bare := make_gestures(PackedStringArray(["KKKK"]))
	var s: KnitSession = bare["session"]
	var bare_layout: FabricLayout = bare["layout"]
	var unguarded := HookGesture.new(s, bare_layout)
	var hits: Array[int] = []
	unguarded.hook_requested.connect(func(c: int) -> void: hits.append(c))
	var only_hook: Array[GestureRecognizer] = [unguarded]
	feed_path(only_hook, circle_path(bare_layout.anchor(), 0.54, -120.0, 240.0))
	check(same(hits, [0]), "对照：无守卫时小圈会误触发钩针")


## 正常锯齿钩针（从静止线头出发，下进上出，再落下去钩下一针）不能被守卫误伤。
func test_sawtooth_hooks_still_work_with_guard() -> void:
	var g := make_gestures(PackedStringArray(["KKKK"]))
	var s: KnitSession = g["session"]
	var layout: FabricLayout = g["layout"]
	var hook: HookGesture = g["hook"]
	var wrap_gesture: WrapGesture = g["wrap"]
	hook.hook_requested.connect(s.try_hook)
	wrap_gesture.wrap_completed.connect(s.toggle_yarn)
	var recognizers: Array[GestureRecognizer] = [wrap_gesture, hook]
	var p := layout.rest_tip()
	for k in 4:
		var eye := layout.eye_center(s.next_column(), 0)
		# 先从旁边落到眼的正下方，再向上穿过，出眼后略向前上方偏。
		var path: Array[Vector2] = [p, eye + Vector2(-0.15, -0.55), eye + Vector2(0.05, 0.1), eye + Vector2(0.3, 0.7)]
		feed_path(recognizers, path)
		p = path[path.size() - 1]
	check(same(g["hooks"], [0, 1, 2, 3]), "连续 4 次锯齿钩针都触发")
	check(s.completed, "一行下针织完")
