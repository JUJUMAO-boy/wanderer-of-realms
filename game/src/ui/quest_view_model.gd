class_name QuestViewModel
extends RefCounted

## 委托界面的视图模型。
##
## 一屏两件事：左边是**委托板 + 手上还没办的委托**（一张单子一行），右边是选中那一张
## 的详情（谁贴的、为什么贴、剧本里的关键对白、办成了会怎样）。抉择是同一个面板的
## 另一种形态（mode = MODE_BRANCH）：把这张委托的选项与各自后果摊开。
##
## 后果预览与交付走的是同一个函数（QuestSystem.outcome_preview），所以"选项上写着
## +6、落账却是 +4"这种错误没有藏身处。

const ROW_KIND_ACTIVE: String = "active"
const ROW_KIND_OFFER: String = "offer"

const MODE_BOARD: int = 0
const MODE_BRANCH: int = 1


## world 只读。offers 来自 QuestBoard（本城可接），active 是玩家手上全部未办完的委托。
## here_city_id 是玩家当前站的城市——办理只能在委托所在城，这一条由界面显式说出来，
## 而不是让玩家按了回车才发现没反应。
static func build(
	world: WorldState,
	offers: Array,
	active: Array,
	city_id: String,
	here_city_id: String,
	city_names: Dictionary,
	cursor: int,
	rules: Dictionary,
	mode: int = MODE_BOARD
) -> Dictionary:
	var city: City = world.get_city(city_id)
	if city == null:
		return {}
	var city_label: String = _city_label(city_names, city_id)
	var rows: Array = []

	# 手上已经接下的排前面：那才是玩家来这一屏的事由
	for quest in active:
		rows.append(_active_row(quest, here_city_id, city_names))
	for offer in offers:
		rows.append(_offer_row(offer, city, city_label))

	var row_count: int = rows.size()
	var index: int = clampi(cursor, 0, maxi(0, row_count - 1))
	var selected: Dictionary = rows[index] if row_count > 0 else {}

	return {
		"cityId": city_id,
		"cityLabel": city_label,
		"hereCityId": here_city_id,
		"atCity": city_id == here_city_id,
		"rows": rows,
		"rowCount": row_count,
		"cursor": index,
		"selected": selected,
		"mode": mode,
		"branches": branch_rows(world, selected, rules),
		"activeCount": active.size(),
		"maxAccepted": int(rules.get("maxAccepted", 3)),
		"selectedIsActive": str(selected.get("kind", "")) == ROW_KIND_ACTIVE,
	}


# --- 行 ---

static func _offer_row(offer: Quest, city: City, city_label: String) -> Dictionary:
	var config: Dictionary = ContentLoader.get_quest_type(offer.quest_type)
	var dimension: String = offer.dimension()
	var value: int = city.get_dimension(dimension)
	var trigger: int = int(config.get("triggerBelow", 0))
	return {
		"kind": ROW_KIND_OFFER,
		"questId": offer.quest_id,
		"questType": offer.quest_type,
		"title": "%s · %s" % [str(config.get("displayName", offer.quest_type)), _tier_label(offer.tier_id)],
		"giverLabel": offer.giver_label,
		"cityLabel": city_label,
		"detail": "办成了：%s %s · %s" % [
			_dimension_label(dimension), _signed(offer.state_gain()),
			AvatarViewModel.money_label(offer.money_copper()),
		],
		# 触发原因。玩家在别的城看不到这张告示，得让他知道凭什么这里有人贴
		"reason": "%s %d ≤ %d（缺 %d）" % [
			_dimension_label(dimension), value, trigger, maxi(0, trigger - value)
		],
		"dialogue": config.get("dialogue", []),
		"summary": str(config.get("summary", "")),
		"deadlineLabel": "第 %d 月前交付" % offer.deadline_month,
		"dimension": dimension,
		"stateGain": offer.state_gain(),
		"money": offer.money_copper(),
		"reputation": offer.reputation_gain(),
		"karma": offer.karma_gain(),
		"scriptRef": offer.template_id,
		"enabled": true,
		"canAccept": true,
		"canDeliver": false,
	}


static func _active_row(
	quest: Quest, here_city_id: String, city_names: Dictionary
) -> Dictionary:
	var config: Dictionary = ContentLoader.get_quest_type(quest.quest_type)
	var here: bool = quest.city_id == here_city_id
	return {
		"kind": ROW_KIND_ACTIVE,
		"questId": quest.quest_id,
		"questType": quest.quest_type,
		"title": "%s · %s" % [str(config.get("displayName", quest.quest_type)), _tier_label(quest.tier_id)],
		"giverLabel": quest.giver_label,
		"cityLabel": _city_label(city_names, quest.city_id),
		"detail": "办成了：%s %s · %s" % [
			_dimension_label(quest.dimension()), _signed(quest.state_gain()),
			AvatarViewModel.money_label(quest.money_copper()),
		],
		"reason": "接手于第 %d 月" % quest.accepted_month,
		"dialogue": config.get("dialogue", []),
		"summary": str(config.get("summary", "")),
		"deadlineLabel": "第 %d 月前交付" % quest.deadline_month,
		"dimension": quest.dimension(),
		"stateGain": quest.state_gain(),
		"money": quest.money_copper(),
		"reputation": quest.reputation_gain(),
		"karma": quest.karma_gain(),
		"scriptRef": quest.template_id,
		"enabled": here,
		"canAccept": false,
		"canDeliver": here,
		# 不在委托所在城时不置灰也不静默：说清楚要回哪座城
		"blockedReason": "" if here else "要回到%s才能办理" % _city_label(city_names, quest.city_id),
	}


# --- 抉择 ---

## 交付这张委托可以怎么选，以及各选各的后果。
## 带战斗的委托多出一行「带人打一场」——它的后果要打完才知道（战场上怎么处置倒地者），
## 所以那一行只说明"打完再定"，不预告数值。
static func branch_rows(world: WorldState, selected: Dictionary, rules: Dictionary) -> Array:
	if str(selected.get("kind", "")) != ROW_KIND_ACTIVE:
		return []
	if not bool(selected.get("canDeliver", false)):
		return []
	var quest: Quest = world.find_quest(str(selected.get("questId", "")))
	if quest == null:
		return []
	var config: Dictionary = ContentLoader.get_quest_type(quest.quest_type)
	var amplify: float = QuestSystem.reputation_multiplier(world, quest.city_id, rules)
	var out: Array = []

	# 表里没有战斗段的类型写的是 "combat": null（见 quest_system.resolve_outcome）
	var raw_combat: Variant = config.get("combat", null)
	var combat: Dictionary = raw_combat if raw_combat is Dictionary else {}
	if not combat.is_empty():
		out.append({
			"branchId": "",
			"isCombat": true,
			"label": str(combat.get("label", "打一场")),
			"detail": str(combat.get("detail", "")),
			"effectLabel": "打完再看你怎么处置倒地的人",
			"enabled": true,
		})

	for branch in config.get("branches", []):
		var branch_id: String = str(branch.get("branchId", ""))
		var preview: Dictionary = QuestSystem.outcome_preview(quest, branch_id, amplify)
		out.append({
			"branchId": branch_id,
			"isCombat": false,
			"label": str(preview.get("label", branch_id)),
			"detail": str(preview.get("detail", "")),
			"effectLabel": effect_label(quest.dimension(), preview),
			"enabled": true,
		})
	return out


## 一行摆出这个选择的全部后果：城市六维、金钱、声誉、善恶。
## 数值与交付时算的是同一份（QuestSystem.outcome_preview），所以对得上。
static func effect_label(dimension: String, preview: Dictionary) -> String:
	var parts: Array = []
	var state_delta: int = int(preview.get("stateDelta", 0))
	if state_delta == 0:
		parts.append("城市无收益")
	else:
		parts.append("%s %s" % [_dimension_label(dimension), _signed(state_delta)])
	parts.append(AvatarViewModel.money_label(int(preview.get("money", 0))))
	var reputation: int = int(preview.get("reputation", 0))
	if reputation != 0:
		parts.append("声誉 %s" % _signed(reputation))
	var karma: int = int(preview.get("karma", 0))
	if karma != 0:
		parts.append("善恶 %s" % _signed(karma))
	return " · ".join(PackedStringArray(parts))


# --- 文案小工具 ---

static func _dimension_label(dimension: String) -> String:
	return str(City.DIMENSION_LABELS.get(dimension, dimension))


static func _tier_label(tier_id: String) -> String:
	var tier: Dictionary = ContentLoader.get_quest_tier(tier_id)
	return str(tier.get("displayName", tier_id))


static func _city_label(city_names: Dictionary, city_id: String) -> String:
	return str(city_names.get(city_id, city_id))


static func _signed(value: int) -> String:
	return "+%d" % value if value > 0 else str(value)
