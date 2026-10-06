# test_modal_stack.gd
# 命令行无头测试：弹窗层级栈只让最上层弹窗处理 ESC / 右键
# 用法: Godot --headless --path . -s res://tests/test_modal_stack.gd
extends SceneTree

var _failed := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ✓ ", msg)
	else:
		_failed += 1
		printerr("  ✗ ", msg)

func _make_modal(n: String) -> Control:
	var c = Control.new()
	c.name = n
	c.visible = false
	root.add_child(c)
	ModalStack.track(c)
	return c

func _initialize() -> void:
	print("\n[弹窗层级栈测试]")
	var a = _make_modal("A")
	var b = _make_modal("B")
	_check(ModalStack.is_empty(), "初始无弹窗")
	a.visible = true
	b.visible = true
	_check(ModalStack.top() == b and ModalStack.is_top(b) and not ModalStack.is_top(a), "后打开的 B 位于最上层")
	ModalStack.close_top()
	_check(not b.visible and a.visible, "close_top 只关闭最上层 B")
	_check(ModalStack.is_top(a), "B 关闭后 A 成为最上层")
	b.visible = true
	a.visible = false
	a.visible = true
	_check(ModalStack.top() == a, "重新打开的弹窗回到最上层")
	ModalStack.close_top()
	ModalStack.close_top()
	_check(ModalStack.is_empty() and not ModalStack.close_top(), "全部关闭后栈为空，close_top 返回 false")
	a.queue_free()
	b.queue_free()
	if _failed == 0:
		print("🎉 弹窗层级栈测试全部通过")
		quit(0)
	else:
		printerr("❌ %d 项失败" % _failed)
		quit(1)
