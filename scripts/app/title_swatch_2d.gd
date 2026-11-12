class_name TitleSwatch2D
extends Node2D
## 开始界面、结束界面织片墙的静态织片：按一张小图纸用规则层把织片织完，再交给 FabricView2D 画出来
## （不带工作线），线圈几何与画法与关卡里完全一致。

@export var chart_rows: PackedStringArray = PackedStringArray(["KKKKK", "KKKKK"])
@export var area_size := Vector2(320, 160)

var _session: KnitSession
var _mapper := ScreenMapper2D.new()
var _view: FabricView2D


func _ready() -> void:
	var chart := PatternChart.new()
	chart.rows = chart_rows
	_session = KnitSession.new(chart, StitchRegistry.create_default())
	_knit_all(_session)
	var layout := FabricLayout.new(_session, ScreenMapper2D.LOOP_WIDTH)
	_mapper.fit_in(layout, Rect2(-area_size * 0.5, area_size))
	_view = FabricView2D.new()
	add_child(_view)
	_view.setup(_session, layout, _mapper, null, null)
	# 静态画面：画一帧即可。
	_view.set_process(false)
	_view.queue_redraw()


## 用规则层按顺序织完整张图纸（需要时切换线的前后）。
static func _knit_all(session: KnitSession) -> void:
	while not session.completed:
		if not session.is_yarn_ready():
			session.toggle_yarn()
		session.try_hook(session.next_column())

