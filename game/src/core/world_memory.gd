class_name WorldMemory
extends RefCounted

## 世界记忆规则层（M-B 两件套，9.30 节 D-127/D-128）。
##
## 与神系/天候"能派生就不落盘"不同，世界记忆正因为要把"曾发生过什么"记下来，
## 所以落盘到 `WorldState.world_flags`——这是 P3 那句「世界不记恨，只记代价」的
## 落点。它只做两件事，全部静态函数、无 IO、可无头断言：
##   1. 守卫死后更强重生：本城每有一个守卫被击杀，该城之后的守备就会更强
##      （攻/命以档位递增并封顶）。只记"这城曾有人横死在守备身上"，不记谁杀的。
##   2. 店主倒下：本城的店主一旦被击杀，就在世界上留下"店门紧闭"的永久代价，
##      destination 供交易/事迹/后续功能读取。
## 界面与事件流不直接读这里——它们读 post_* 洞察函数产出的文案与叠层。

const FLAG_PREFIX: String = "memory."

## 守卫击杀计数标记前缀：memory.slaughter.<city_id> = 累计击杀数（int）
const GUARD_FLAG: String = FLAG_PREFIX + "slaughter."
## 店主倒下标记：memory.shopkeeper.<city_id> = true（bool）
const SHOP_FLAG: String = FLAG_PREFIX + "shopkeeper."

## 守卫增强随击杀数的档位曲线：每次击杀再生成时攻/命各上浮一档，封顶 3 档。
const BOOST_CAP: int = 3
## 每档攻/命加成系数（倍数）。1 次 → ×1.35 攻 ×1.5 命；3 次封顶 → ×2.05 攻 ×2.5 命。
const HP_PER_KILL: float = 0.5
const ATK_PER_KILL: float = 0.35

## 城内"会拦路"的职业类别（兵力与灰色：守卫/佣兵/盗贼/乞丐）。守卫增强只对这类人成立，
## 平民（农夫/面包师）被殃及时不会让全城守备升级——那会误伤"店里掌柜也会打架"的滤镜。
static func guard_categories() -> Array:
	return ContentLoader.get_balance_section("encounters").get("cityNpcCategories", ["military", "gray"])


# --- 守卫：死后更强重生 ---

## 本城累计被击杀的守卫数（世界记忆）。
static func guard_kills(world: WorldState, city_id: String) -> int:
	if world == null:
		return 0
	return int(world.world_flags.get(GUARD_FLAG + city_id, 0))


## 记一笔：本城有守卫被击杀。返回新的累计数。幂等累积——同一场死几个就+几。
static func record_guard_claimed(world: WorldState, city_id: String) -> int:
	if world == null:
		return 0
	var next: int = guard_kills(world, city_id) + 1
	world.world_flags[GUARD_FLAG + city_id] = next
	return next


## 本城守卫再生成时该有的增强叠层。依次击杀封顶到 BOOST_CAP 档。
## 返回 {count, hpMult, attackMult, label}；count=0 时 hpMult/attackMult=1.0、label 为空。
static func guard_boost(world: WorldState, city_id: String) -> Dictionary:
	var count: int = clampi(guard_kills(world, city_id), 0, BOOST_CAP)
	var hp_mult: float = 1.0 + HP_PER_KILL * float(count)
	var atk_mult: float = 1.0 + ATK_PER_KILL * float(count)
	var label: String = ""
	if count > 0:
		label = "此城的守备记得 %d 个人死在冲突里，新一任明显更狠。" % count
	return {
		"count": count,
		"hpMult": hp_mult,
		"attackMult": atk_mult,
		"label": label,
	}


## 把叠层套到一块守卫生成单位上（战斗 start 前调用）。改 hp/maxHp/attack，
## 其余字段不动——这样 boost 不引入第二个"强度真相"，只在现有规格上放大。
static func guard_boosted_unit(unit: Dictionary, boost: Dictionary) -> Dictionary:
	var hp_mult: float = float(boost.get("hpMult", 1.0))
	var atk_mult: float = float(boost.get("attackMult", 1.0))
	if hp_mult != 1.0:
		unit["hp"] = int(ceil(float(int(unit.get("hp", 0))) * hp_mult))
		if unit.has("maxHp"):
			unit["maxHp"] = int(ceil(float(int(unit["maxHp"])) * hp_mult))
	if atk_mult != 1.0:
		unit["attack"] = int(ceil(float(int(unit.get("attack", 0))) * atk_mult))
	return unit


## 批量：把这场遭遇里所有"本城守卫"套上增强。守卫以其 npcId 反查职业类别判定，
## 只有属 guard_categories() 的成年战斗 NPC 才套；店主（虽是 is_named）也属于拦路范畴
## 之外，不误触发守备升级。
static func boost_guard_units(units: Array, world: WorldState) -> Array:
	var boost_cache: Dictionary = {}
	for i in range(units.size()):
		var unit: Dictionary = units[i]
		if not bool(unit.get("isNpc", false)):
			continue
		var npc: SimNpc = world.get_npc(str(unit.get("npcId", "")))
		if npc == null or not _is_guard_npc(npc):
			continue
		if not boost_cache.has(npc.city_id):
			boost_cache[npc.city_id] = guard_boost(world, npc.city_id)
		var boost: Dictionary = boost_cache[npc.city_id]
		if int(boost.get("count", 0)) > 0:
			units[i] = guard_boosted_unit(unit, boost)
	return units


# --- 店主：倒下即永久留痕 ---

## 本城店主是否已经倒下（世界记忆）。
static func shopkeeper_fallen(world: WorldState, city_id: String) -> bool:
	if world == null:
		return false
	return bool(world.world_flags.get(SHOP_FLAG + city_id, false))


## 记一笔：本城店主已被击杀。只落一次，repeat 不改变状态。
static func record_shopkeeper_fallen(world: WorldState, city_id: String) -> void:
	if world == null:
		return
	world.world_flags[SHOP_FLAG + city_id] = true


## 一句"玩家能观察到的现象"（P8 筛）：店主倒下前后各一句。
static func shopkeeper_label(world: WorldState, city_id: String) -> String:
	if shopkeeper_fallen(world, city_id):
		return "这城的铺子关着门，店主不在了。"
	return "这城有家铺子，柜台后坐着东家。"


# --- 内部 ---

static func _is_guard_npc(npc: SimNpc) -> bool:
	if npc == null or npc.is_named:
		return false
	var profession: Dictionary = ContentLoader.get_profession(npc.profession_id)
	return guard_categories().has(str(profession.get("category", "")))