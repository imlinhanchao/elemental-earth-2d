# test_chemistry.gd
# 命令行无头测试脚本：测试数据加载与唯象化学反应计算
extends SceneTree

const DataDB = preload("res://src/core/data_db.gd")
const MixtureBuffer = preload("res://src/core/mixture_buffer.gd")
const ChemistrySolver = preload("res://src/core/chemistry_solver.gd")

func _init() -> void:
	print("\n========================================")
	print("🧪 [Elemental Earth 2D] 唯象化学求解器测试")
	print("========================================")

	# 1. 初始化数据
	DataDB.initialize()
	assert(DataDB.items.size() > 0, "Items 加载失败!")
	assert(DataDB.elements.size() > 0, "Elements 加载失败!")

	var solver = ChemistrySolver.new()

	# 2. 测试案例 A: 炭热还原炼铜 (常温不反应，升温至 950K 自动炼出金属铜)
	print("\n[测试 1] 炭热冶炼孔雀石制铜测试:")
	var crucible = MixtureBuffer.new()
	crucible.add_substance("malachite", 2.0)
	crucible.add_substance("charcoal", 2.0)
	crucible.temperature = 293.15 # 室温

	var res_room = solver.solve(crucible, 1.0)
	print(" -> 室温 (293K) 反应检测: ", "无反应发生 (符合预期)" if not res_room["occurred"] else "异常反应!")
	assert(not res_room["occurred"], "室温不应自发反应!")

	# 加热到 1150K (约 877℃，木炭火焰可达)
	crucible.temperature = 1150.0
	var res_hot = solver.solve(crucible, 1.0)
	print(" -> 高温 (1150K) 反应检测: ", res_hot["reactions"])
	print(" -> 当前坩埚内产物: ", crucible.components)
	
	assert(crucible.has_substance("copper"), "未能成功制备单质铜!")
	var elem_cu = DataDB.is_pure_element("copper")
	print(" -> 纯净元素识别: 铜单质元素序数 = #%d" % elem_cu)
	assert(elem_cu == 29, "铜元素序号匹配错误!")

	# 3. 测试案例 B: 直流电解水制氧测试
	print("\n[测试 2] 直流电解水制备纯氧与氢气测试:")
	var cell = MixtureBuffer.new()
	cell.add_substance("water", 5.0)
	cell.applied_voltage = 0.0 # 无电压

	var res_no_v = solver.solve(cell, 1.0)
	assert(not res_no_v["occurred"], "未通电不应发生电解!")

	# 施加 12V 直流电
	cell.applied_voltage = 12.0
	var res_v = solver.solve(cell, 1.0)
	print(" -> 通电 (12V) 反应检测: ", res_v["reactions"])
	print(" -> 电解槽内产物: ", cell.components)

	assert(cell.has_substance("oxygen"), "未能电解出纯氧!")
	assert(cell.has_substance("hydrogen"), "未能电解出氢气!")
	var elem_o = DataDB.is_pure_element("oxygen")
	print(" -> 纯净元素识别: 氧单质元素序数 = #%d" % elem_o)
	assert(elem_o == 8, "氧元素序号匹配错误!")

	# 4. 测试案例 C: 木材干馏制备木炭测试
	print("\n[测试 3] 木材热解干馏制备木炭测试:")
	var flask = MixtureBuffer.new()
	flask.container_type = "flask"
	flask.add_substance("wood", 2.0)
	flask.temperature = 293.15 # 室温
	var res_wood_cold = solver.solve(flask, 1.0)
	assert(not res_wood_cold["occurred"], "木材室温不应自发干馏炭化!")

	# 升温至 550K (约 277℃，木材热解温度)
	flask.temperature = 550.0
	var res_wood_hot = solver.solve(flask, 1.0)
	print(" -> 高温 (550K) 热解反应检测: ", res_wood_hot["reactions"])
	print(" -> 实验烧瓶内产物: ", flask.components)
	assert(flask.has_substance("charcoal"), "未能成功热解干馏出木炭!")
	assert(flask.get_moles("charcoal") >= 1.0, "木炭产出摩尔量错误!")

	print("\n========================================")
	print("🎉 所有唯象化学核心逻辑与数据加载测试 100% 通过!")
	print("========================================\n")
	
	quit(0)
