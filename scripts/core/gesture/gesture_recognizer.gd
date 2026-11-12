@abstract
class_name GestureRecognizer
extends RefCounted
## 手势识别器（抽象）：输入织物坐标中的线头位置，识别到动作时由子类发信号。


## 线头移动到织物坐标 point。
@abstract func feed(point: Vector2) -> void

## 松手或重新抓取时清空状态。
@abstract func reset() -> void
