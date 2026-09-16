class_name HiddenAttributeSystem
extends RefCounted

## 隐藏属性事件规则层（M17，D-89~D-93）。
##
## 三种「看不见却算得出来」的属性——善恶（karma）、幸运（luck）、声誉（reputation）
## ——从被动累计变成完整闭环的裁决处。它只负责三件事：判定某个事件此刻能不能触发、
## 把一个分支的后果结清到玩家与城市上、以及算出该不该在两世之间留下一道「业」。
## 界面与状态行不直接读这里——它们读 HiddenEventViewModel 产出的期，落盘由
## PlayerAvatar / WorldState 的序列化负责。城市维度的增量不在此处终账：它产出
## StateChange 请求，由调用方（主场景 / 测试）提交给 WorldSim，与事件模块同一分工。

## 三种隐藏属性的流。
const ALL_KINDS: Array = ["karma", "luck", "reputation"]
## 触发时机：enter 是进城时查（声誉 / 善恶类），advance 是推进时间过夜时查（幸运类）。
const ALL_TIMINGS: Array = ["enter", "advance"]

## 隐藏属性的数值边界（《数值框架》3 节：全局善恶/幸运与按城的声誉都是 -100~+100，
## 越界即按档位封顶）。所有写入都过 clamp_attr，防止越界破坏档位判断。
const ATTR_MIN: int = -100
const ATTR_MAX: int = 100

## 事件标记前缀。种子与冷却都落在这里：
##   触发冷却：world_flags["fate.<templateId>"]        —— 触发过后不再重复
##   后果种子：world_flags["fate.<templateId>.<raw>"]  —— 如 fate.hl_unlucky_streak.curse_seed
const FLAG_PREFIX: String = "fate."

## 转世「业」标记（D-92/D-93）。写到哪里由转世模块接 soul 记录承担，此处只管判定。
const MARK_GOOD: String = "reincarnation.mark.saint"
const MARK_EVIL: String = "reincarnation.mark.sin"
const MARK_LUCK: String = "reincarnation.mark.fate"
## 判定「极端善恶 / 高价幸运」的档位阈值（《数值框架》3 节的档位描述只有定性，
## 这里取与委托/物价同一组 ±60）。
const GOOD_THRESHOLD: int = 60
const EVIL_THRESHOLD: int = -60
const LUCK_THRESHOLD: int = 60


## 钳到范围内的档位判断。所有写入隐藏属性的入口都应过这里。
static func clamp_attr(raw: int) -> int:
	return clampi(raw, ATTR_MIN, ATTR_MAX)


## 读一个隐藏属性当前值。善恶/幸运是全局的；声誉按城独立（_数值框架 3 节：每城一套）。
static func read_attr(avatar: PlayerAvatar, kind: String, city_id: String = "") -> int:
	match kind:
		"karma":
			return avatar.karma
		"luck":
			return avatar.luck
		"reputation":
			return avatar.get_reputation(city_id)
	return 0


## 结清一个隐藏属性的增量：当前值 + delta 后钳档。这是交付与界面预览共用的一条路：
## 预览读它算出的终点，落账也写它，没有「选项 +30、实际 +20」的缝隙。
## 返回结清后的值。
static func apply_attr(avatar: PlayerAvatar, kind: String, city_id: String, delta: int) -> int:
	var value: int = read_attr(avatar, kind, city_id) + delta
	match kind:
		"karma":
			avatar.karma = clamp_attr(value)
			return avatar.karma
		"luck":
			avatar.luck = clamp_attr(value)
			return avatar.luck
		"reputation":
			avatar.set_reputation(city_id, value)
			return avatar.get_reputation(city_id)
	return 0


## 触发判定：这套 trigger 此刻对这位玩家成立吗？三条件——属性挡位达标、时机属于
## 当前钩子、这场还没触发过（world_flags 里的冷却标记）。「已在事件流里」由调用方
## 会话管：触发钩子（进城/推进）是会话唯一的注入点，同钩子只推一个事件。
static func qualifies(config: Dictionary, avatar: PlayerAvatar, city_id: String, world: WorldState) -> bool:
	if avatar == null or world == null:
		return false
	var trigger: Dictionary = config.get("trigger", {})
	var kind: String = str(trigger.get("attr", ""))
	if not ALL_KINDS.has(kind):
		return false
	var value: int = read_attr(avatar, kind, city_id)
	if not _trigger_met(trigger, value, kind):
		return false
	return not _triggered(config, world)


## 一条 branch 的完整后果（交付与界面预览共用，与 EventSystem.branch_preview
## 同一条理由）。不假装决定玩家得失之外的世界因果，但把会结清的全部摆出来。
static func outcome_preview(branch: Dictionary) -> Dictionary:
	var deltas: Array = []
	var changes: Dictionary = _dict_of(branch.get("changes", null))
	var dimensions: Array = changes.keys()
	dimensions.sort()
	for dimension in dimensions:
		var delta: int = int(changes[dimension])
		if delta == 0:
			continue
		deltas.append({"dimension": str(dimension), "delta": delta})
	return {
		"branchId": str(branch.get("branchId", "")),
		"label": str(branch.get("label", "")),
		"detail": str(branch.get("detail", "")),
		"karma": int(branch.get("karma", 0)),
		"luck": int(branch.get("luck", 0)),
		"reputation": int(branch.get("reputation", 0)),
		"money": int(branch.get("money", 0)),
		"flags": branch.get("flags", []),
		"deltas": deltas,
		"resolved": bool(branch.get("resolved", true)),
	}


## 一行摆出这套后果的全部影响，供选项与结果行复用。
static func effect_label(preview: Dictionary) -> String:
	var parts: Array = []
	var karma: int = int(preview.get("karma", 0))
	if karma != 0:
		parts.append("善恶 %s" % _signed(karma))
	var luck: int = int(preview.get("luck", 0))
	if luck != 0:
		parts.append("幸运 %s" % _signed(luck))
	var reputation: int = int(preview.get("reputation", 0))
	if reputation != 0:
		parts.append("声誉 %s" % _signed(reputation))
	var money: int = int(preview.get("money", 0))
	if money != 0:
		parts.append("钱 %s" % _signed(money))
	for entry in preview.get("deltas", []):
		parts.append("%s %s" % [
			_dimension_label(str(entry.get("dimension", ""))), _signed(int(entry.get("delta", 0)))
		])
	if parts.is_empty():
		parts.append("没有直接影响")
	return " · ".join(PackedStringArray(parts))


## 结清一次抉择。当场落账玩家侧（善恶/幸运/声誉/金钱/种子），并产出城市维度的
## StateChange 请求交给调用方提交。转世「业」标记按落账后的善恶/幸运终点判定写入
## world_flags（跨世读取在转世模块，见 D-92/D-93）。
## returns { ok, label, detail, karma, luck, reputation, money, flags, changes, mark }
static func apply_branch(
	config: Dictionary,
	branch: Dictionary,
	avatar: PlayerAvatar,
	world: WorldState,
	city_id: String,
	month: int
) -> Dictionary:
	var template_id: String = str(config.get("templateId", ""))
	var preview: Dictionary = outcome_preview(branch)

	var avatar_karma: int = avatar.karma
	var avatar_luck: int = avatar.luck
	var changes: Array = []
	var changes_raw: Dictionary = _dict_of(branch.get("changes", null))
	var dimensions: Array = changes_raw.keys()
	dimensions.sort()
	for dimension in dimensions:
		var delta: int = int(changes_raw[dimension])
		if delta == 0:
			continue
		changes.append(StateChange.make(
			"hidden-%s-%s" % [template_id, str(dimension)],
			city_id,
			str(dimension),
			delta,
			StateChange.SOURCE_EVENT,
			template_id,
			month
		))

	if int(branch.get("karma", 0)) != 0:
		apply_attr(avatar, "karma", "", int(branch.get("karma", 0)))
	if int(branch.get("luck", 0)) != 0:
		apply_attr(avatar, "luck", "", int(branch.get("luck", 0)))
	if int(branch.get("reputation", 0)) != 0:
		apply_attr(avatar, "reputation", city_id, int(branch.get("reputation", 0)))
	if int(branch.get("money", 0)) != 0:
		avatar.money = maxi(0, avatar.money + int(branch.get("money", 0)))

	var flags: Array = _write_flags(config, world, branch)
	var mark: String = ""
	if avatar_karma != avatar.karma or avatar_luck != avatar.luck:
		mark = reincarnation_mark_for(avatar)

	return {
		"ok": true,
		"templateId": template_id,
		"cityId": city_id,
		"branchId": str(branch.get("branchId", "")),
		"label": str(preview.get("label", "")),
		"detail": str(preview.get("detail", "")),
		"karma": int(branch.get("karma", 0)),
		"luck": int(branch.get("luck", 0)),
		"reputation": int(branch.get("reputation", 0)),
		"money": int(branch.get("money", 0)),
		"flags": flags,
		"changes": changes,
		"mark": mark,
		"resolved": bool(preview.get("resolved", true)),
		"errorCode": "",
		"error": "",
	}


## 在当前钩子（timing）上找一条此刻能触发的事件：数据表里逐条试 trigger.timing
## 是否一致 + qualifies 三条件，命中第一条即返回。一条钩子只推一件事（上下文已有
## 会话接管），避免快进十年贪心地把同档属性的三四个事件连环弹出来。
static func find_for_timing(
	timing: String, avatar: PlayerAvatar, city_id: String, world: WorldState
) -> Dictionary:
	for config in ContentLoader.get_hidden_events():
		var trigger: Dictionary = config.get("trigger", {})
		if str(trigger.get("timing", "")) != timing:
			continue
		if qualifies(config, avatar, city_id, world):
			return config
	return {}


## 触发冷却：这一场之后不再重复。
static func mark_triggered(config: Dictionary, world: WorldState) -> void:
	var template_id: String = str(config.get("templateId", ""))
	if template_id.is_empty():
		return
	world.world_flags[FLAG_PREFIX + template_id] = true


## 按眼下的善恶/幸运终点决定要不要在两世之间留一笔业。
## 极端善 / 极端恶取档位阈值；高价幸运单独一记。都不够就空（无事的世，无痕地走）。
static func reincarnation_mark_for(avatar: PlayerAvatar) -> String:
	if avatar.karma >= GOOD_THRESHOLD:
		return MARK_GOOD
	if avatar.karma <= EVIL_THRESHOLD:
		return MARK_EVIL
	if avatar.luck >= LUCK_THRESHOLD:
		return MARK_LUCK
	return ""


# --- 内部 ---

static func _trigger_met(trigger: Dictionary, value: int, kind: String) -> bool:
	if trigger.has("atLeast") and value < int(trigger.get("atLeast", 0)):
		return false
	if trigger.has("atMost") and value > int(trigger.get("atMost", 0)):
		return false
	# 至少得有一个门槛词，否则一个空 cursor 的事件会无条件触发
	return trigger.has("atLeast") or trigger.has("atMost")


static func _triggered(config: Dictionary, world: WorldState) -> bool:
	var template_id: String = str(config.get("templateId", ""))
	return world.world_flags.has(FLAG_PREFIX + template_id)


static func _write_flags(config: Dictionary, world: WorldState, branch: Dictionary) -> Array:
	var written: Array = []
	var template_id: String = str(config.get("templateId", ""))
	for raw in branch.get("flags", []):
		var flag: String = "%s%s.%s" % [FLAG_PREFIX, template_id, str(raw)]
		world.world_flags[flag] = true
		written.append(flag)
	return written


static func _dimension_label(dimension: String) -> String:
	return str(City.DIMENSION_LABELS.get(dimension, dimension))


static func _dict_of(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}


static func _signed(value: int) -> String:
	return "+%d" % value if value > 0 else str(value)