# hex_world_generator.gd
# 六边形柏林噪声多群系大世界生成器
class_name HexWorldGenerator
extends RefCounted

const ThemeStyler = preload("res://src/ui/theme_styler.gd")

# 生态群落类型定义
enum BiomeType {
	PLAINS,      # 平原草地 (常见孔雀石/树木)
	VOLCANO,     # 火山与地热地带 (伴生硫磺/黄铁矿)
	SALT_LAKE,   # 盐湖与卤水矿床 (伴生石盐/卤水)
	DEEP_FOREST  # 茂密原始森林 (高密度优质木材/煤炭)
}

# 六边形基础规格 (平顶六边形 Flat-topped 或 尖顶 Pointy-topped)
# 这里采用标准的尖顶六边形: 宽度 = sqrt(3) * 半径, 高度 = 2 * 半径
const HEX_RADIUS: float = 36.0
const HEX_WIDTH: float = 62.3538   # sqrt(3) * 36
const HEX_HEIGHT: float = 72.0     # 2 * 36

var noise_elevation: FastNoiseLite
var noise_moisture: FastNoiseLite

func _init(seed_val: int = 42) -> void:
	# 海拔噪声
	noise_elevation = FastNoiseLite.new()
	noise_elevation.seed = seed_val
	noise_elevation.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise_elevation.frequency = 0.04
	
	# 湿度噪声
	noise_moisture = FastNoiseLite.new()
	noise_moisture.seed = seed_val + 101
	noise_moisture.noise_type = FastNoiseLite.TYPE_PERLIN
	noise_moisture.frequency = 0.03

# 六边形轴向坐标 (q, r) 转换为世界像素坐标 (x, y)
static func hex_to_pixel(q: int, r: int) -> Vector2:
	var x = HEX_RADIUS * (sqrt(3.0) * q + sqrt(3.0) / 2.0 * r)
	var y = HEX_RADIUS * (3.0 / 2.0 * r)
	return Vector2(x, y)

# 世界像素坐标换算为最近的六边形轴向坐标 (q, r)
static func pixel_to_hex(point: Vector2) -> Vector2i:
	var q = (sqrt(3.0) / 3.0 * point.x - 1.0 / 3.0 * point.y) / HEX_RADIUS
	var r = (2.0 / 3.0 * point.y) / HEX_RADIUS
	return _hex_round(Vector2(q, r))

static func _hex_round(frac: Vector2) -> Vector2i:
	var q = round(frac.x)
	var r = round(frac.y)
	var s = round(-frac.x - frac.y)
	
	var q_diff = abs(q - frac.x)
	var r_diff = abs(r - frac.y)
	var s_diff = abs(s - (-frac.x - frac.y))
	
	if q_diff > r_diff and q_diff > s_diff:
		q = -r - s
	elif r_diff > s_diff:
		r = -q - s
	return Vector2i(int(q), int(r))

# 评估给定六边形地块的生态群落
func get_biome(q: int, r: int) -> BiomeType:
	var elev = noise_elevation.get_noise_2d(float(q), float(r))
	var moist = noise_moisture.get_noise_2d(float(q), float(r))
	
	if elev > 0.35:
		return BiomeType.VOLCANO
	elif elev < -0.2:
		return BiomeType.SALT_LAKE
	elif moist > 0.15:
		return BiomeType.DEEP_FOREST
	else:
		return BiomeType.PLAINS

# 获取群落代表色彩
static func get_biome_color(biome: BiomeType) -> Color:
	if ThemeStyler.is_dark:
		match biome:
			BiomeType.PLAINS: return Color(0.27, 0.30, 0.22)      # 原野 · 夜间灰绿
			BiomeType.VOLCANO: return Color(0.33, 0.21, 0.17)     # 火山 · 夜间赭红
			BiomeType.SALT_LAKE: return Color(0.18, 0.26, 0.30)   # 盐湖 · 夜间灰蓝
			BiomeType.DEEP_FOREST: return Color(0.17, 0.24, 0.17) # 深林 · 夜间墨绿
	match biome:
		BiomeType.PLAINS:
			return Color(0.74, 0.78, 0.62) # 原野 · 灰绿测绘色 #BDC79E
		BiomeType.VOLCANO:
			return Color(0.72, 0.52, 0.42) # 火山 · 赭红地质色 #B8856B
		BiomeType.SALT_LAKE:
			return Color(0.62, 0.74, 0.78) # 盐湖 · 灰蓝水域 #9EBDC7
		BiomeType.DEEP_FOREST:
			return Color(0.52, 0.64, 0.50) # 深林 · 墨绿 #85A380
	return Color.GRAY

# 根据群落与径向地貌决定伴生生成的资源类型 (覆盖各时代特色矿脉)
func determine_resource_spawn(q: int, r: int, biome: BiomeType) -> String:
	var dist = (abs(q) + abs(q + r) + abs(r)) / 2
	var rand_val = abs(sin(float(q * 374761393 + r * 668265263)))
	
	# 首先在所有群落中分布散落碎石、燧石与断枝 (供开局一穷二白拾取)
	if rand_val > 0.95:
		return "stone"        # 散落碎石 (大量分布，开局基础石材)
	elif rand_val > 0.91 and rand_val <= 0.95:
		return "flint"        # 伴生燧石 (尖锐矿石)
	elif rand_val < 0.06:
		return "stick"        # 地表断枝 (徒手可拾取)
		
	# 高阶外圈时代专属矿脉 (距离核心区越远，蕴藏矿石越具时代深度)
	if dist > 14: # 原子能与稀土外圈 (15-20)
		if rand_val > 0.88:
			return "pitchblende" if biome == BiomeType.VOLCANO else "monazite"
		elif rand_val < 0.12:
			return "bauxite"
	elif dist > 10: # 电化学圈 (11-14)
		if rand_val > 0.86:
			return "bauxite" if biome == BiomeType.PLAINS else "galena"
		elif rand_val < 0.14:
			return "sphalerite"
		elif rand_val > 0.80 and rand_val <= 0.86:
			return "cryolite"     # 冰晶石 (电解铝助熔剂)
		
	match biome:
		BiomeType.PLAINS:
			if rand_val > 0.88:
				return "malachite"    # 孔雀石
			elif rand_val > 0.82:
				return "clay"         # 粘土矿层
			elif rand_val > 0.78:
				return "limestone"    # 石灰岩露头 (水泥 / 生石灰原料)
			elif rand_val > 0.74 and dist > 7:
				return "niter"        # 硝石结壳 (火药与硝酸原料)
			elif rand_val < 0.14:
				return "wood"         # 散落橡树
		BiomeType.VOLCANO:
			if rand_val > 0.86:
				return "sulfur"       # 硫磺矿床
			elif rand_val > 0.12 and rand_val < 0.20:
				return "cassiterite"  # 锡石砂矿 (青铜冶炼原料)
			elif rand_val > 0.20 and rand_val < 0.26:
				return "pyrolusite"   # 软锰矿 (锰钢原料)
			elif rand_val < 0.12:
				return "hematite"     # 伴生赤铁矿
			elif rand_val > 0.78:
				return "pyrite"       # 黄铁矿
		BiomeType.SALT_LAKE:
			if rand_val > 0.85:
				return "rock_salt"       # 石盐矿床
		BiomeType.DEEP_FOREST:
			if rand_val > 0.80:
				return "wood"         # 原始大橡树
			elif rand_val < 0.10:
				return "coal"         # 浅层煤矿
			elif rand_val < 0.18:
				return "graphite"     # 石墨矿层 (电极与核反应堆慢化剂)
	return ""
