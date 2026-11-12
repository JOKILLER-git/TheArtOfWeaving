@abstract
class_name FabricScreenMapper
extends RefCounted
## 织物坐标（列 / 行）↔ 屏幕坐标（画布像素）的抽象。
## 规则层与手势识别器只认织物坐标；表现层用这个接口把它们画到屏幕上、把鼠标换回织物坐标。
## 实现：ScreenMapper2D（平面缩放 + 平移）、CameraMapper3D（相机投影 + 射线与织物平面求交）。
## 叠加层（提示、调试层、指针输入、剪刀命中）只依赖本接口，2D 与 3D 共用。

## 线粗、抓取半径、提示大小等按 loop_px() / REF_COL_PX 等比放大。
const REF_COL_PX := 84.0

## 一列在屏幕上大约多少像素（3D 透视下取织物中心附近的局部值）。
var col_px: float = REF_COL_PX
## 一行在屏幕上大约多少像素。
var row_px: float = 70.0
## 线圈占列宽的比例（与 FabricLayout.loop_width 一致）。
var loop_width: float = 1.0


## 织物坐标 → 屏幕像素。
@abstract func to_screen(fabric_point: Vector2) -> Vector2


## 屏幕像素 → 织物坐标（3D 中为鼠标射线与织物平面的交点）。
@abstract func to_fabric(screen_point: Vector2) -> Vector2


## 按关卡与可视区域调整（缩放、居中 / 相机距离）。view 为画布坐标的可视区域。
@abstract func fit(layout: FabricLayout, view: Rect2) -> void


## 线圈宽（像素）。
func loop_px() -> float:
	return col_px * loop_width


## 相对参考线圈宽的缩放倍数。
func scale_k() -> float:
	return loop_px() / REF_COL_PX


## 线在屏幕上的粗细（像素）。
func yarn_width() -> float:
	return 0.115 * loop_px()


func to_screen_all(points: Array[Vector2]) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for p in points:
		out.append(to_screen(p))
	return out
