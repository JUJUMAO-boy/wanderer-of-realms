class_name QuestBoard
extends RefCounted

## 委托板生成（M4.1）。纯函数：同样的城市六维、同样的月份、同样的世界种子，
## 给出同一板委托。所以板子不落盘——落盘反而要额外维护"任务随城市状态出现或
## 消失"这层同步，而按需推导天然就是对的。
##
## 「城市需求驱动任务供给」这条闭环（10.2 节）在这里落成两件事：
##   1. 出现与否：该维度高于触发阈值就根本不出现（城里有粮，没人贴运粮的告示）；
##   2. 出现多少：缺口越大权重越高，于是越缺什么，越多人在求。
## 档位同样由缺口深度决定，缺得狠的城贴的是大委托。
##
## M4.3 的后果链在这里被读回来：这一单在城里留下的标记会让同类委托更容易再来
## （上一单没把缺口真正补上）。这是"读取世界标记"的最小可验证形态。

## 后果标记的前缀。分支 flags 形如 quest.bandit_clearance.spared，
## 中间那段就是委托类型——生成时按这个前缀把标记归回各自类型。
const FLAG_PREFIX: String = "quest."


## 返回该城当前可接的委托（Quest 数组，state 为 STATE_ACTIVE 之前的"板上"态）。
## 调用方拿到的每个 Quest 都是全新的对象，改了不会污染下一次生成。
static func offers(
	world: WorldState, city_id: String, month: int, rules: Dictionary
) -> Array:
	var city: City = world.get_city(city_id)
	if city == null:
		return []
	var refresh: int = maxi(1, int(rules.get("boardRefreshMonths", 3)))
	@warning_ignore("integer_division")
	var bucket: int = month / refresh
	var rng := DeterministicRNG.new(world.world_seed ^ _city_salt(city_id) ^ (bucket * 2654435761))

	var taken: Dictionary = {}
	for quest in world.get_quests_of_city(city_id):
		if quest.is_active():
			taken[quest.quest_type] = true

	var gap_scale: float = maxf(1.0, float(rules.get("supplyGapScale", 40)))
	var pool: Array = []
	# A4（D-169）：城市专属职业委托。scope=="city" 的条目只在自己的城出现（外城
	# 不贴别家的职业告示）；它们同样走"缺口驱动供给"的规则——本城的职业维度低过
	# 阈值才冒出来，且作为"招牌活"权重自带加成，在同缺口段里更靠前。这样既让职业
	# 任务链跟着需求走，又不把通用委托挤下板。
	var specialty_boost: float = maxf(0.0, float(rules.get("citySpecialtyBoost", 2.0)))
	var specialty_city_id: String = _city_specialty_id(city_id)
	for entry in ContentLoader.get_quest_types():
		var quest_type: String = str(entry.get("questTypeId", ""))
		if taken.has(quest_type):
			continue
		if str(entry.get("scope", "")) == "city" \
				and str(entry.get("cityId", "")) != city_id:
			continue
		var dimension: String = str(entry.get("dimension", ""))
		var trigger: int = int(entry.get("triggerBelow", 0))
		var value: int = city.get_dimension(dimension)
		if value > trigger:
			continue
		var gap: float = float(trigger - value)
		var weight: float = 1.0 + gap / gap_scale + _repeat_boost(world, city_id, quest_type)
		if str(entry.get("scope", "")) == "city" \
				and str(entry.get("professionId", "")) == specialty_city_id:
			weight += specialty_boost
		pool.append({
			"entry": entry,
			"typeId": quest_type,
			"weight": weight,
			"gapRatio": gap / maxf(1.0, float(trigger)),
		})

	var out: Array = []
	var size: int = mini(maxi(0, int(rules.get("boardSizePerCity", 4))), pool.size())
	for i in range(size):
		var picked: int = _pick_weighted(pool, rng)
		if picked < 0:
			break
		var slot: Dictionary = pool[picked]
		pool.remove_at(picked)
		out.append(_build_offer(city, slot, bucket, month, rules, rng))
	# 板面固定顺序：按类型 id 排序，免得同一个城市两次打开看到的顺序不一样
	out.sort_custom(func(a: Quest, b: Quest) -> bool: return a.quest_type < b.quest_type)
	return out


## 按权重不放回地抽一个下标。权重全为正，抽完即移除，所以不会重复出同一类委托。
static func _pick_weighted(pool: Array, rng: DeterministicRNG) -> int:
	var total: float = 0.0
	for slot in pool:
		total += float(slot["weight"])
	if total <= 0.0:
		return -1
	var roll: float = rng.next_float() * total
	for i in range(pool.size()):
		roll -= float(pool[i]["weight"])
		if roll <= 0.0:
			return i
	return pool.size() - 1


static func _build_offer(
	city: City, slot: Dictionary, bucket: int, month: int,
	rules: Dictionary, rng: DeterministicRNG
) -> Quest:
	var entry: Dictionary = slot["entry"]
	var quest_type: String = str(slot["typeId"])
	var tier_id: String = tier_for(float(slot["gapRatio"]), rules)
	var tier: Dictionary = ContentLoader.get_quest_tier(tier_id)
	var dimension: String = str(entry.get("dimension", ""))
	var money: int = int(tier.get("moneyCopper", 0))
	var jitter: int = int(rules.get("rewardMoneyJitterPermille", 0))
	if jitter > 0:
		@warning_ignore("integer_division")
		var span: int = money * jitter / 1000
		money = maxi(1, money + rng.range_int(-span, span))
	# 报价取整到 10 铜：报酬单上写「1237 铜」看着像随手填的
	@warning_ignore("integer_division")
	var rounded: int = (money + 5) / 10 * 10
	money = maxi(10, rounded)

	return Quest.make(
		quest_id_for(city.city_id, quest_type, bucket),
		str(entry.get("scriptRef", "")),
		quest_type,
		city.city_id,
		str(entry.get("giverLabel", "")),
		tier_id,
		{
			Quest.REWARD_MONEY: money,
			Quest.REWARD_REPUTATION: int(tier.get("reputationGain", 0)),
			Quest.REWARD_KARMA: int(tier.get("karmaGain", 0)),
			Quest.REWARD_STATE_GAIN: int(entry.get("stateGain", {}).get(tier_id, 0)),
			Quest.REWARD_DIMENSION: dimension,
		},
		month,
		month + int(tier.get("deadlineMonths", 0))
	)


## 缺口比例 → 档位。阈值取自 balance，不在代码里写死两个数字。
static func tier_for(gap_ratio: float, rules: Dictionary) -> String:
	var ratios: Array = rules.get("tierGapRatios", [0.25, 0.5])
	var tiers: Array = ContentLoader.get_quest_tiers()
	if tiers.is_empty():
		return ""
	var small: float = float(ratios[0]) if ratios.size() > 0 else 0.25
	var medium: float = float(ratios[1]) if ratios.size() > 1 else 0.5
	if gap_ratio < small:
		return str(tiers[0].get("tierId", ""))
	if gap_ratio < medium and tiers.size() > 1:
		return str(tiers[1].get("tierId", ""))
	return str(tiers[tiers.size() - 1].get("tierId", ""))


## 同一个（城、类型、板面周期）只会有一张委托：questId 由这三者决定，
## 所以"同一张告示接两次"在 id 上就不可能。
static func quest_id_for(city_id: String, quest_type: String, bucket: int) -> String:
	return "q-%s-%s-%d" % [city_id, quest_type, bucket]


## 该类型在这座城留下的后果标记，每个给权重 +1（M4.3 的读取侧）。
## 不限定具体标记名：写进 worldFlags 的键是 quest.<城市>.<类型>.<后果>
## （见 QuestSystem._write_flags），按前两段取前缀即可，将来往剧本里加标记
## 不必再改这里——这正是"任务结果写世界标记"要买到的东西。
static func _repeat_boost(world: WorldState, city_id: String, quest_type: String) -> float:
	var prefix: String = "%s%s.%s." % [FLAG_PREFIX, city_id, quest_type]
	var boost: float = 0.0
	for flag in world.world_flags:
		if str(flag).begins_with(prefix) and bool(world.world_flags[flag]):
			boost += 1.0
	return boost


## 城市 id → 32 位盐。生成用的随机源要按城市分开，否则同一板面上
## 各城的抽取会互相牵动：在这座城看过的板子会改变另一座城的板子。
static func _city_salt(city_id: String) -> int:
	var salt: int = 2166136261
	for i in range(city_id.length()):
		salt = ((salt ^ city_id.unicode_at(i)) * 16777619) & 0xFFFFFFFF
	return salt


## 该城市的专属职业 id（professions.json 的 citySpecialty），读不到返回 ""。
## A4（D-169）给本城的"职业招牌委托"加权，靠它把 Board 里那条被我们标成
## scope=="city" + professionId 的委托认出来。玩家的职业这一世没有——这是
## 「城市职能原型反哺职业」那一侧（每城建谁家职业的招牌），不下放到玩家身上。
static func _city_specialty_id(city_id: String) -> String:
	var prof_cfg: Dictionary = ContentLoader.get_profession_config()
	var mapping: Variant = prof_cfg.get("citySpecialty", {})
	if not (mapping is Dictionary):
		return ""
	return str((mapping as Dictionary).get(city_id, ""))
