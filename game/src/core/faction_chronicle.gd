class_name FactionChronicle
extends RefCounted

## 势力变更纪年（C4 / D-164）。
##
## 接 M16 Chronicle，把「一城势力维度跨档导致主导权易手」这件事沉淀成
## 跨代可查的纪年条目——玩家快进一百年后翻开史书能读到「艾德兰王冠倒了，
## 商人行会接了盘」这种大脉络，这就是 C4「势力兴衰纪年化」要做的事。
##
## 让势力真的会兴衰：city_evolution 明确 faction 维度不由时间自然演化（2.2 节），
## 但那是世界经济演化的事；这里给势力**一条独立的慢轴**——每年按
## (世界种子 ⊕ 城 ⊕ 年) 确定性派一个漂移量叠加到 faction 维度上（能派生就
## 不落盘：同世界种子下每一年读到的漂移完全相同）。势力维度跨过阈值档位就往
## 纪年写一条「谁兴谁衰」。
##
## 势力档位（三档，阈值含边界）：
##   0-33 落 / 34-66 持 / 67-100 兴
##
## 配置要求（cities.json 每个城市可选加）：
##   "factionCandidates": ["old_id", "middle_id", "high_id"]
##   索引 0 = 0~33，1 = 34~66，2 = 67~100。不配置 → 档位固定，势力永不换。
##   势力 id 只做纪年文案的标签（全部首字母大写拼接），不需要单独的势力表。

const THRESHOLD_LOW: int = 33
const THRESHOLD_MID: int = 66
const WEIGHT: int = 300  # 比默认 minWeight 高，保证能进史书

## 势力变更纪年的 kind（与 Chronicle 其它 kind 平级）。
const KIND_FACTION: String = "factionChange"

## 每年势力漂移的幅度上限（[-DRIFT_RANGE, +DRIFT_RANGE]）。
const DRIFT_RANGE: int = 2


## 当前城市该由哪个档位的势力接管（索引 = _tier_for_value）。
## 档位固定（未配 factionCandidates）时返回当前在任势力，表示永不换。
static func candidate_id(city: City) -> String:
	var cfg: Dictionary = ContentLoader.get_city_config(city.city_id)
	var candidates: Array = cfg.get("factionCandidates", [])
	if candidates.size() != 3:
		return city.dominant_faction_id
	return str(candidates[_tier_for_value(city.faction)])


## 该城此刻是否发生了主导权变更的分档（未改状态，纯判断）。
static func pending_change(city: City) -> bool:
	return candidate_id(city) != city.dominant_faction_id


## 把变更落到 city 上（改 dominant_faction_id）。返回旧的 id。
static func apply_change(city: City) -> String:
	var old_id: String = city.dominant_faction_id
	city.dominant_faction_id = candidate_id(city)
	return old_id


## 年度结算势力这条慢轴（调用方在年边界对每座城调一次）。返回本轮对
## faction 维度的漂移量（clamp 前的原始 delta）。已把 city.faction 落上漂移。
## base_seed 传世界种子：不同世界的势力走势不同，同世界同种子可复现。
static func drift(city: City, year_offset: int, base_seed: int) -> int:
	var delta: int = 0
	if FactionChronicle._has_candidates(city.city_id):
		var rng: DeterministicRNG = _rng_for(city.city_id, year_offset, base_seed)
		delta = rng.range_int(-DRIFT_RANGE, DRIFT_RANGE)
		city.faction = clampi(city.faction + delta, 0, 100)
	return delta


static func _has_candidates(city_id: String) -> bool:
	var cfg: Dictionary = ContentLoader.get_city_config(city_id)
	return cfg.get("factionCandidates", []).size() == 3


## 该城在任势力的档位标签（"落"/"持"/"兴"）。档位固定返回"持"。
static func tier_word(city: City) -> String:
	if not _has_candidates(city.city_id):
		return "持"
	var word: Array = ["落", "持", "兴"]
	return str(word[_tier_for_value(city.faction)])


## 生成势力变更的纪年条目（纯函数）。year 由调用方以 Chronicle.year_label 产出，
## 本类不碰 Chronicle 私有成员。
static func faction_change_entry(world: WorldState, city_id: String, old_label: String,
		new_label: String, month: int, year: String) -> Dictionary:
	var world_state: WorldState = world
	var city: City = null if world_state == null else world_state.get_city(city_id)
	var city_label: String = city.display_name if city != null else city_id

	var detail_mid: String = "这座经营了多年的城池，主导权悄悄换了手。城头变换大王旗，"
	# 荒诞细节锚，凑密度过 MenuStyle 筛（P8 每 N 字一处荒诞）
	var absurd_tail: String = ""
	match city_label:
		"艾德兰":
			absurd_tail = " 文书官抄了三遍错字，最后干脆把旧名刮掉重写。"
		"索恩港":
			absurd_tail = " 码头秤手把旧行会徽章扔进海里，第二天潮水又给送回来。"
		"铁锤堡":
			absurd_tail = " 熔炉旁的老矮人把新宪章铸进一块废铁，从此垫在酒桶底下。"
		"银月塔":
			absurd_tail = " 占星师划掉旧主的星位，笔尖落在一颗没人见过名字的彗星上。"
		"绿荫":
			absurd_tail = " 树图书馆的树人把新派系刻进树皮，刻痕里渗出带甜味的树汁。"
		"十字路":
			absurd_tail = " 竞技场的沙扫了三遍，还能扫出旧势力刻在地上的缩写。"
		"霜语堡":
			absurd_tail = " 冰川把旧主旗帜冻得结结实实，要等三百年的夏天才肯还。"
		_:
			absurd_tail = " 商队把旧铭牌埋进沙里，隔夜风一吹，铭牌又露出来见人。"

	return {
		"kind": KIND_FACTION,
		"title": "%s 的势力：%s 变为 %s" % [city_label, old_label, new_label],
		"cityId": city_id,
		"cityLabel": city_label,
		"detail": detail_mid + absurd_tail,
		"attribution": "势力变迁",
		"month": month,
		"year": year,
		"weight": WEIGHT,
	}


## 势力 id → 可读标签。蛇形转空格分词，词首大写；空串给「无主导势力」。
static func faction_label(faction_id: String) -> String:
	if faction_id.is_empty():
		return "无主导势力"
	var words: Array = faction_id.split("_")
	var out: Array = []
	for w in words:
		var word: String = str(w)
		if word.is_empty():
			continue
		out.append(word.left(1).to_upper() + word.substr(1))
	var result: String = ""
	for i in range(out.size()):
		if i > 0:
			result += " "
		result += str(out[i])
	return result


## 数值 → 档位索引（0/1/2）。阈值含边界。
static func _tier_for_value(value: int) -> int:
	if value <= THRESHOLD_LOW:
		return 0
	if value <= THRESHOLD_MID:
		return 1
	return 2


## 按 (城, 年, 世界种子) 派生该轮漂移用到的确定性 RNG。同世界同种子可复现。
static func _rng_for(city_id: String, year_offset: int, base_seed: int) -> DeterministicRNG:
	var seed: int = (base_seed) ^ (year_offset * 1013904223) ^ (city_id.hash() * 37) ^ 0x9E3779B9
	return DeterministicRNG.new(seed)