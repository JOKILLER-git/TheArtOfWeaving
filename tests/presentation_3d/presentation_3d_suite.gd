extends "res://tests/app/app_flow_suite.gd"
## 3D 表现层测试（T009）。
## 1. 继承 app 层测试，把 GameApp 换成 3D 主场景（game_app_3d.tscn）：全部 GameApp 流程检查对 3D 关卡再跑一遍
##    （开始 → 11 关 → 结束、选关暂停、成绩记录、结束织片墙……），证明 GameApp 只依赖 KnitLevelView。
## 2. CameraMapper3D：织物 → 屏幕 → 织物的往返误差、屏幕 → 织物 → 屏幕的往返误差（含转动视角）、各关织物在可视区域内。
## 3. 接口替换（里氏替换）：两个映射器都是 FabricScreenMapper，两个关卡视图都是 KnitLevelView。
## 4. 3D 关卡的剪刀：剪到织物 → 回到起始行。
## 入口：run() 返回 {passed, checks, failures}；命令行见 run_presentation_3d_tests.gd。

const APP_3D_SCENE := "res://scenes/app/game_app_3d.tscn"
const LEVEL_3D_SCENE := "res://scenes/knit/knit_level_3d.tscn"
const ROUND_TRIP_TOL := 1e-3    # 织物坐标往返误差上限（列宽）
const SCREEN_TOL := 0.05        # 屏幕坐标往返误差上限（像素）

## 最近一次往返测试的最大误差 [织物（列宽）, 屏幕（像素）]，便于回报。
var round_trip_report: Array = []


func make_app(quits: Array = [0]) -> GameApp:
	var app := (load(APP_3D_SCENE) as PackedScene).instantiate() as GameApp
	app.progress_store = ProgressStore.new("")
	app.quit_handler = func() -> void: quits[0] += 1
	(Engine.get_main_loop() as SceneTree).root.add_child(app)
	return app


func make_level_3d(index: int) -> KnitLevel3D:
	var view := (load(LEVEL_3D_SCENE) as PackedScene).instantiate() as KnitLevel3D
	view.play(load_catalog().get_level(index))
	(Engine.get_main_loop() as SceneTree).root.add_child(view)
	return view


func test_3d_app_uses_3d_level_view() -> void:
	var app := make_app()
	app.start_game()
	check(app.level_view is KnitLevel3D, "3D 主场景实例化的是 KnitLevel3D")
	check(app.level_view is KnitLevelView, "KnitLevel3D 是 KnitLevelView")
	app.queue_free()


func test_3d_interfaces_are_substitutable() -> void:
	var view := make_level_3d(0)
	var mappers: Array[FabricScreenMapper] = [ScreenMapper2D.new(), view.mapper()]
	for m in mappers:
		m.fit(view.layout(), view.get_viewport_rect())
		var p := m.to_screen(Vector2(0.0, 0.42))
		check(m.to_fabric(p).distance_to(Vector2(0.0, 0.42)) < ROUND_TRIP_TOL, "%s 满足 FabricScreenMapper 往返约定" % m.get_script().get_global_name())
		check(m.col_px > 1.0 and m.scale_k() > 0.0 and m.yarn_width() > 0.0, "%s 提供局部缩放" % m.get_script().get_global_name())
	view.queue_free()


## 每一关：织物网格上的点 织物 → 屏幕 → 织物 误差很小；屏幕 → 织物 → 屏幕 也一样；转动视角后仍然成立。
func test_3d_camera_mapper_round_trip() -> void:
	var catalog := load_catalog()
	var view := make_level_3d(0)
	var worst := 0.0
	var worst_px := 0.0
	for i in catalog.count():
		view.play(catalog.get_level(i))
		var m := view.mapper()
		var lay := view.layout()
		for orbit: Vector2 in [Vector2.ZERO, Vector2(15, -10), Vector2(-20, 20)]:
			view.set_orbit(orbit)
			for row in range(-1, lay.rows() + 1):
				for c in range(-1, lay.columns() + 1):
					var f := Vector2(c * 1.0 + 0.3, row * 1.0 + 0.42)
					var s := m.to_screen(f)
					worst = maxf(worst, m.to_fabric(s).distance_to(f))
					worst_px = maxf(worst_px, m.to_screen(m.to_fabric(s)).distance_to(s))
		view.set_orbit(Vector2.ZERO)
	round_trip_report = [worst, worst_px]
	check(worst < ROUND_TRIP_TOL, "织物 → 屏幕 → 织物 往返误差 %.7f 列宽（上限 %s）" % [worst, str(ROUND_TRIP_TOL)])
	check(worst_px < SCREEN_TOL, "屏幕 → 织物 → 屏幕 往返误差 %.5f 像素（上限 %s）" % [worst_px, str(SCREEN_TOL)])
	view.queue_free()


## 每一关织物（含线尾和左右提示圆）都在可视区域内，且列宽不超过上限。
func test_3d_camera_fit_inside_view() -> void:
	var catalog := load_catalog()
	var view := make_level_3d(0)
	var rect := view.get_viewport_rect()
	for i in catalog.count():
		view.play(catalog.get_level(i))
		var m := view.mapper()
		var lay := view.layout()
		var ok := true
		for f: Vector2 in [
			Vector2(lay.edge_x(-1) - WrapGesture.HINT_RADIUS, lay.sinker_y(0)),
			Vector2(lay.edge_x(1) + WrapGesture.HINT_RADIUS, lay.sinker_y(0)),
			Vector2(lay.edge_x(-1), float(lay.rows() - 1) + FabricLayout.LOOP_TOP),
			Vector2(lay.edge_x(1), float(lay.rows() - 1) + FabricLayout.LOOP_TOP),
			lay.rest_tip(),
		]:
			ok = ok and rect.has_point(m.to_screen(f))
		check(ok, "第 %d 关织物与提示圆在可视区域内" % (i + 1))
		check(m.col_px <= CameraMapper3D.MAX_COL_PX + 0.5, "第 %d 关列宽不超过上限" % (i + 1))
	view.queue_free()


## 第 3 关（3D）：剪刀落在空白处无效；落在织物上 → 回到起始行；之后能织完。
func test_3d_snip_cut_flow() -> void:
	var view := make_level_3d(2)
	check(view.session.needs_cut, "第 3 关开始时需要剪断（3D）")
	var rect := view.get_viewport_rect()
	check(not view.hits_yarn_or_fabric(Vector2(rect.get_center().x, rect.position.y + 30.0)), "剪刀落在空白处不算剪到（3D）")
	var center := view.fabric_rect().get_center()
	check(view.hits_yarn_or_fabric(center), "剪刀落在织物上算剪到（3D）")
	view.cut_at(center)
	check(not view.session.needs_cut and view.session.current_row == 1, "剪断后回到起始行（3D）")
	finish_level(view)
	check(view.is_completed() and view.stars_earned() == 3, "剪断后重织完成，3 星（3D）")
	view.queue_free()


## 工作线的深度：线在后面时在 z < 0，切到前面后 z > 0（翻面补间结束后）。
func test_3d_yarn_side_depth() -> void:
	var view := make_level_3d(3)
	var yarn := view.yarn_view()
	check(not view.session.yarn.is_front() and yarn.side_depth() < 0.0, "开始时线在织物后面（z < 0）")
	view.session.toggle_yarn()
	yarn.front_v = 1.0   # 跳过翻面动画
	check(yarn.side_depth() > 0.0, "切换后线在织物前面（z > 0）")
	view.queue_free()
