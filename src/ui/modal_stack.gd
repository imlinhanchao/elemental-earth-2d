# modal_stack.gd
# 弹窗层级栈：记录当前可见弹窗的打开顺序。ESC / 右键 / 切换热键只交给最上层弹窗处理，
# 避免多个弹窗同时可见时一次按键关掉好几层，或被下层弹窗抢先吞掉。
# 用法：弹窗在 _ready 中调用 ModalStack.track(self)，在 _input 开头判断 ModalStack.is_top(self)。
class_name ModalStack
extends RefCounted

static var _stack: Array[Control] = []

static func track(modal: Control) -> void:
	modal.visibility_changed.connect(func():
		_stack.erase(modal)
		if modal.visible:
			_stack.append(modal)
	)
	modal.tree_exiting.connect(func(): _stack.erase(modal))
	if modal.visible:
		_stack.append(modal)

static func is_top(modal: Control) -> bool:
	if _stack.is_empty():
		return true
	return _stack.back() == modal

static func top() -> Control:
	return null if _stack.is_empty() else _stack.back()

static func is_empty() -> bool:
	return _stack.is_empty()

# 关闭最上层弹窗；有 close() 的优先调用以执行收尾逻辑 (如暂停菜单恢复游戏)
static func close_top() -> bool:
	var m = top()
	if m == null:
		return false
	if m.has_method("close"):
		m.close()
	else:
		m.visible = false
	return true
