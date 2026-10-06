# tech_tree_layout.gd
# 科技树分层布局 (Sugiyama 方法)：
# 1. 按最长前置链分列，再把只服务于后方科技的节点右移，缩短连线；
# 2. 跨多列的连线插入占位点，让线从卡片之间的空隙穿过，不压在卡片上；
# 3. 用重心法多轮调整每列的上下顺序，减少连线交叉；
# 4. 每个节点向相邻节点的平均高度靠拢，连线尽量走直。
# 纯数据计算，不依赖场景节点，可在测试中直接调用。
extends RefCounted

const CARD_W := 190.0
const CARD_H := 74.0
const COL_GAP := 80.0     # 列与列之间留给连线的空隙
const CARD_GAP := 18.0    # 同列卡片之间的最小间距
const LANE_H := 10.0      # 穿过某一列的连线占用的高度
const LANE_GAP := 6.0
const MARGIN := Vector2(24, 20)

# 返回 {
#   "positions": {key: Vector2 卡片左上角},
#   "layers": {key: int 列号},
#   "routes": {"子|父": PackedVector2Array 连线途经点 (不含两端针脚)},
#   "size": Vector2 画布尺寸,
# }
static func compute(techs: Dictionary) -> Dictionary:
	var keys: Array = techs.keys()
	keys.sort()
	var parents := {}
	var children := {}
	for k in keys:
		parents[k] = []
		children[k] = []
	for k in keys:
		for p in techs[k].get("required_techs", []):
			if techs.has(p) and p != k:
				parents[k].append(p)
				children[p].append(k)

	var order := _topo_order(keys, parents)

	# 1. 分列：最长前置链，再把有后继的节点尽量右移到后继的前一列
	var layer := {}
	for k in order:
		var l := 0
		for p in parents[k]:
			l = max(l, int(layer[p]) + 1)
		layer[k] = l
	for i in range(order.size() - 1, -1, -1):
		var k = order[i]
		if children[k].is_empty():
			continue
		var m := 1 << 30
		for c in children[k]:
			m = min(m, int(layer[c]))
		layer[k] = max(int(layer[k]), m - 1)

	var n_layers := 0
	for k in keys:
		n_layers = max(n_layers, int(layer[k]) + 1)

	# 2. 构建分层图：跨列连线插入占位点
	var up := {}    # 节点 -> 上一列相邻节点
	var down := {}  # 节点 -> 下一列相邻节点
	var node_layer := {}
	var is_lane := {}
	var columns: Array = []
	for i in range(n_layers):
		columns.append([])
	for k in keys:
		up[k] = []
		down[k] = []
		node_layer[k] = layer[k]
		is_lane[k] = false
	var edge_chain := {} # "子|父" -> 占位点 id 列表
	for c in keys:
		for p in parents[c]:
			var prev: String = p
			var chain: Array = []
			for l in range(int(layer[p]) + 1, int(layer[c])):
				var d := "~%s|%s|%d" % [c, p, l]
				up[d] = []
				down[d] = []
				node_layer[d] = l
				is_lane[d] = true
				chain.append(d)
				down[prev].append(d)
				up[d].append(prev)
				prev = d
			down[prev].append(c)
			up[c].append(prev)
			edge_chain["%s|%s" % [c, p]] = chain

	# 初始顺序：按时代、再按键名，保证结果稳定
	var initial: Array = node_layer.keys()
	initial.sort_custom(func(a, b):
		var ea = int(techs.get(a, {}).get("era", 0))
		var eb = int(techs.get(b, {}).get("era", 0))
		return a < b if ea == eb else ea < eb
	)
	for n in initial:
		columns[int(node_layer[n])].append(n)

	# 3. 重心法减少交叉，保留交叉数最少的一轮
	var best := _copy_columns(columns)
	var best_cross := _count_crossings(columns, down)
	for it in range(24):
		if it % 2 == 0:
			for l in range(1, n_layers):
				_sort_by_barycenter(columns, l, up, l - 1)
		else:
			for l in range(n_layers - 2, -1, -1):
				_sort_by_barycenter(columns, l, down, l + 1)
		var cross := _count_crossings(columns, down)
		if cross < best_cross:
			best_cross = cross
			best = _copy_columns(columns)
	columns = best
	_transpose(columns, up, down)
	best_cross = _count_crossings(columns, down)

	# 4. 纵向坐标：按顺序紧排后，多轮向相邻节点平均高度靠拢
	var height := {}
	var y := {}
	for col in columns:
		var acc := 0.0
		for i in col.size():
			var n = col[i]
			height[n] = LANE_H if is_lane[n] else CARD_H
			if i > 0:
				acc += _sep(col[i - 1], n, height, is_lane)
			y[n] = acc
	for it in range(40):
		for l in range(n_layers):
			var col: Array = columns[l]
			var desired: Array = []
			for n in col:
				var nb: Array = up[n] + down[n]
				if nb.is_empty():
					desired.append(y[n])
				else:
					var s := 0.0
					for m in nb:
						s += y[m]
					desired.append(lerpf(y[n], s / nb.size(), 0.7))
			_place_column(col, desired, y, height, is_lane)

	var min_top := INF
	var max_bottom := -INF
	for n in y.keys():
		min_top = min(min_top, y[n] - height[n] * 0.5)
		max_bottom = max(max_bottom, y[n] + height[n] * 0.5)

	var positions := {}
	var layers := {}
	for k in keys:
		var x = MARGIN.x + int(layer[k]) * (CARD_W + COL_GAP)
		positions[k] = Vector2(x, MARGIN.y + y[k] - min_top - CARD_H * 0.5)
		layers[k] = int(layer[k])

	var routes := {}
	for ek in edge_chain.keys():
		var pts := PackedVector2Array()
		for d in edge_chain[ek]:
			var x = MARGIN.x + int(node_layer[d]) * (CARD_W + COL_GAP)
			var dy = MARGIN.y + y[d] - min_top
			pts.append(Vector2(x, dy))
			pts.append(Vector2(x + CARD_W, dy))
		routes[ek] = pts

	var size := Vector2(
		MARGIN.x * 2.0 + n_layers * CARD_W + max(0, n_layers - 1) * COL_GAP,
		MARGIN.y * 2.0 + (max_bottom - min_top))
	return {"positions": positions, "layers": layers, "routes": routes, "size": size, "crossings": best_cross}

static func _topo_order(keys: Array, parents: Dictionary) -> Array:
	var result: Array = []
	var state := {}
	for k in keys:
		_visit(k, parents, state, result)
	return result

static func _visit(k: String, parents: Dictionary, state: Dictionary, result: Array) -> void:
	if state.has(k):
		return # 已访问；数据中若有环则在此截断
	state[k] = true
	for p in parents[k]:
		_visit(p, parents, state, result)
	result.append(k)

static func _copy_columns(columns: Array) -> Array:
	var out: Array = []
	for col in columns:
		out.append(col.duplicate())
	return out

# 按相邻节点在参照列 ref_l 中的平均序号重排第 l 列
static func _sort_by_barycenter(columns: Array, l: int, nbrs: Dictionary, ref_l: int) -> void:
	var ref_col: Array = columns[ref_l]
	var idx := {}
	for i in ref_col.size():
		idx[ref_col[i]] = i
	var col: Array = columns[l]
	var bary := {}
	for i in col.size():
		var n = col[i]
		var s := 0.0
		var c := 0
		for m in nbrs[n]:
			if idx.has(m):
				s += idx[m]
				c += 1
		# 没有相邻节点的保持原位置 (按比例换算到参照列)
		bary[n] = s / c if c > 0 else float(i) * ref_col.size() / max(1, col.size())
	var pos := {}
	for i in col.size():
		pos[col[i]] = i
	col.sort_custom(func(a, b):
		return pos[a] < pos[b] if is_equal_approx(bary[a], bary[b]) else bary[a] < bary[b]
	)

# 相邻两节点互换后与左右两列的交叉数减少就交换，直到没有可改进的交换
static func _transpose(columns: Array, up: Dictionary, down: Dictionary) -> void:
	var improved := true
	var guard := 0
	while improved and guard < 20:
		improved = false
		guard += 1
		for l in columns.size():
			var col: Array = columns[l]
			for i in range(col.size() - 1):
				var before := _local_crossings(columns, l, up, down)
				var tmp = col[i]
				col[i] = col[i + 1]
				col[i + 1] = tmp
				if _local_crossings(columns, l, up, down) < before:
					improved = true
				else:
					col[i + 1] = col[i]
					col[i] = tmp

static func _local_crossings(columns: Array, l: int, up: Dictionary, down: Dictionary) -> int:
	var total := 0
	if l > 0:
		total += _pair_crossings(columns[l - 1], columns[l], down)
	if l < columns.size() - 1:
		total += _pair_crossings(columns[l], columns[l + 1], down)
	return total

static func _pair_crossings(a: Array, b: Array, down: Dictionary) -> int:
	var idx_b := {}
	for i in b.size():
		idx_b[b[i]] = i
	var edges: Array = []
	for i in a.size():
		for m in down[a[i]]:
			if idx_b.has(m):
				edges.append(Vector2i(i, idx_b[m]))
	var total := 0
	for i in edges.size():
		for j in range(i + 1, edges.size()):
			if (edges[i].x - edges[j].x) * (edges[i].y - edges[j].y) < 0:
				total += 1
	return total

static func _count_crossings(columns: Array, down: Dictionary) -> int:
	var total := 0
	for l in range(columns.size() - 1):
		total += _pair_crossings(columns[l], columns[l + 1], down)
	return total

static func _sep(a: String, b: String, height: Dictionary, is_lane: Dictionary) -> float:
	var gap := LANE_GAP if (is_lane[a] and is_lane[b]) else CARD_GAP
	return (height[a] + height[b]) * 0.5 + gap

# 在保持顺序与最小间距的前提下，让每个节点尽量接近期望高度
static func _place_column(col: Array, desired: Array, y: Dictionary, height: Dictionary, is_lane: Dictionary) -> void:
	var n := col.size()
	if n == 0:
		return
	var fwd: Array = desired.duplicate()
	for i in range(1, n):
		fwd[i] = max(fwd[i], fwd[i - 1] + _sep(col[i - 1], col[i], height, is_lane))
	var bwd: Array = desired.duplicate()
	for i in range(n - 2, -1, -1):
		bwd[i] = min(bwd[i], bwd[i + 1] - _sep(col[i], col[i + 1], height, is_lane))
	var res: Array = []
	for i in n:
		res.append((fwd[i] + bwd[i]) * 0.5)
	for i in range(1, n):
		res[i] = max(res[i], res[i - 1] + _sep(col[i - 1], col[i], height, is_lane))
	for i in n:
		y[col[i]] = res[i]
