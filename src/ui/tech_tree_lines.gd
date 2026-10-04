# tech_tree_lines.gd
# 缺氧 (Oxygen Not Included) 风格科技树连线渲染层
# 渲染科技前置与后继节点之间的三次贝塞尔曲线及能量流转光晕
extends Control

var tech_modal: Control = null

func _draw() -> void:
	if not tech_modal:
		return
	tech_modal._draw_connecting_lines(self)
