@abstract
class_name StitchType
extends RefCounted
## 针法（抽象）。规则层和画面层都只通过这里的接口区分针法，不写死 K/P。


## 图纸里的针法 id，例如 "K"。
@abstract func id() -> String

## 显示名，例如「下针」。
@abstract func display_name() -> String

## 图纸符号："V" 或 "-"，画图纸卡时据此选择画法。
@abstract func chart_symbol() -> String

## 钩出这种针时工作线需要处在的一侧。
@abstract func required_side() -> Yarn.Face

## 新线圈的腿是否压在旧线圈头的前面（下针 true，上针 false）。
@abstract func new_loop_in_front() -> bool
