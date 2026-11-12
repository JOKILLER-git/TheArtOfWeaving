class_name YarnHandle
extends RefCounted
## 线头（玩家抓住拖动的那一点）的共享状态：屏幕位置、是否被抓住、抓取半径。
## 工作线视图（WorkingYarn2D / WorkingYarn3D）拥有它并每帧更新半径；
## 指针输入、图纸卡、调试层只依赖它，不关心线是 2D 画的还是 3D 网格。

var tip := Vector2.ZERO     # 线头位置（画布像素）
var held: bool = false      # 玩家正在拖线头
var grab_radius: float = 44.0
var enabled: bool = true    # 整关完成后不能再抓


func can_grab(p: Vector2) -> bool:
	return enabled and p.distance_to(tip) <= grab_radius
