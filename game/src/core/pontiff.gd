class_name Pontiff
extends RefCounted

## 代神规则层（M-A 深化，D-152~D-155）。
##
## M25 已经把神从背景板做成「可祈祷」：GodBlessing 给虔诚（善恶→0..100）与恩惠
## 门槛，回车结算出一段文案。但那几档恩惠与神的代价**都还是字**——"每次祈祷
## 烧掉一点运气"不真扣，"行的正就更少被摸走东西"也不生效。M35 把代神三件事里
## 的「恩惠」与「改信神罚」从文案变成真实机制，本类负责它们的纯函数部分。
##
## 与 M25 同口径的铁则：
##   1. **虔诚由善恶现算、不落盘**。恩惠门槛照旧由 `GodBlessing.devotion_of` 给出。
##   2. **恩惠是"身体这件皮"的事**——献祭换一段持续庇护，随化身落盘、每天 boundary
##      由 `sync` 剥掉到期的；跨世换体自然清零。这与 `DisguiseGate` 的"绝对自然日
##      到期"用的是同一种时钟通路（main 每日边界对照当天派生布尔）。
##   3. **规则层不读 Clock、不落存档**——只读传入的 avatar 与 rules，可无头钉测。

const KINDS: Array = [
	"theft_resist", "walk_ease", "bargain", "night_vision",
	"fire_resist", "reincarnation_keep", "sleep_ease", "warning",
]

## 神罚的阈值沿用 M25：善恶 ≤ 此值连最低档恩惠都够不着、反遭神罚（压住恩惠）。
const PUNISH_KARMA: int = -60


## 读 balance.deity 段。
static func _rules() -> Dictionary:
	return ContentLoader.get_balance_section("deity")


## 恩惠有效期（自然日）。兜底 3 天。
static func blessing_days(rules: Dictionary = {}) -> int:
	return maxi(1, int((rules if not rules.is_empty() else _rules()).get("blessingDays", 3)))


## 善恶太低连最低档都够不着——即会被神罚压住恩惠（沿用 M25 的 cursed 判定）。
static func behind_of(god: Dictionary, karma: int) -> bool:
	return GodBlessing.pray_result(god, karma, 0).get("cursed", false)


## 按当前虔诚取应得的恩惠档。返回该档 buff 机制字典 + 献祭代价，或空（够不着）。
## 读 gods.json 每档的 `buff:{kind,value,days,tierLabel}` 与每神的 `sacrifice`。
static func blessing_spec(god: Dictionary, karma: int, rules: Dictionary = {}) -> Dictionary:
	if god.is_empty():
		return {}
	var blessing: Dictionary = _reached_blessing(god, karma)
	if blessing.is_empty():
		return {}
	return {
		"godId": str(god.get("id", "")),
		"kind": str(blessing.get("kind", "")),
		"value": int(blessing.get("value", 0)),
		"days": maxi(1, int(blessing.get("days", blessing_days(rules)))),
		"tierLabel": str(blessing.get("tierLabel", "")),
		"displayEffect": str(blessing.get("displayEffect", str(blessing.get("effect", "")))),
		"tier": _tier_index(god, blessing),
		"sacrifice": god.get("sacrifice", {}).duplicate(),
	}


## 有没有够着一档恩惠、够着了是哪档。返回该档 dict 或空。
static func _reached_blessing(god: Dictionary, karma: int) -> Dictionary:
	if behind_of(god, karma):
		return {}
	var devotion: int = GodBlessing.devotion_of(god, karma)
	var best: Dictionary = {}
	var blessings: Array = god.get("blessings", [])
	for b in blessings:
		if not (b is Dictionary):
			continue
		var threshold: int = int((b as Dictionary).get("threshold", 1 << 30))
		if devotion >= threshold:
			best = b as Dictionary
	return best


## 该档在 blessings 数组里的下标（1..N），供面板显示"第几档恩惠"。
static func _tier_index(god: Dictionary, blessing: Dictionary) -> int:
	var idx: int = 0
	for b in god.get("blessings", []):
		idx += 1
		if b == blessing:
			return idx
	return 0


## 献祭这个代价付不付得起（不真正落账）。代价 `{kind, amount}`：
##   - karma / luck：善恶/幸运足够（有向，注意 amount 可负/正按神性）
##   - days：沉眠时间不是即时资产，恒可（由 main 负责沉眠推进）
##   - copper：钱够
static func can_pay(avatar: PlayerAvatar, sacrifice: Dictionary) -> bool:
	if avatar == null:
		return false
	var kind: String = str(sacrifice.get("kind", ""))
	var amount: int = int(sacrifice.get("amount", 0))
	match kind:
		"karma":
			# 扣善恶要留得住在下限内（-100）
			return avatar.karma - amount >= PlayerAvatar.HIDDEN_ATTR_MIN
		"luck":
			return avatar.luck - amount >= PlayerAvatar.HIDDEN_ATTR_MIN
		"copper":
			return avatar.money >= maxi(0, amount)
		"days":
			return true
	return false


## 真正付出献祭代价（就地落账）。付不起返回 false、不落任何账。
static func pay(avatar: PlayerAvatar, sacrifice: Dictionary) -> bool:
	if avatar == null:
		return false
	if not can_pay(avatar, sacrifice):
		return false
	var kind: String = str(sacrifice.get("kind", ""))
	var amount: int = int(sacrifice.get("amount", 0))
	match kind:
		"karma":
			avatar.set_karma(avatar.karma - amount)
		"luck":
			avatar.set_luck(avatar.luck - amount)
		"copper":
			avatar.money -= maxi(0, amount)
		"days":
			pass  # 沉眠时间由 main 的实际沉眠动作承担，这里只作为祈祷门槛存在
	return true


## 把一段恩惠登记到化身。today 是当前自然日（Clock.now().day）。
## 返回 {ok, kind, value, activeUntilDay}。
static func bestow(avatar: PlayerAvatar, spec: Dictionary, today: int) -> Dictionary:
	if avatar == null or spec.is_empty():
		return {"ok": false}
	var kind: String = str(spec.get("kind", ""))
	if kind.is_empty():
		return {"ok": false}
	var days: int = maxi(1, int(spec.get("days", blessing_days())))
	var active_until: int = today + days
	avatar.blessings[kind] = {"value": int(spec.get("value", 0)), "activeUntilDay": active_until}
	return {"ok": true, "kind": kind, "value": int(spec.get("value", 0)), "activeUntilDay": active_until}


## 此刻某类恩惠是否还在效（对照 today）。
static func blessing_active(avatar: PlayerAvatar, kind: String, today: int) -> bool:
	if avatar == null:
		return false
	var entry: Dictionary = avatar.blessings.get(kind, {})
	return int(entry.get("activeUntilDay", -1)) >= today


## 此刻某类恩惠的值（有效期内返回值，过期/没有返 0）。
static func blessing_value(avatar: PlayerAvatar, kind: String, today: int) -> int:
	if avatar == null:
		return 0
	var entry: Dictionary = avatar.blessings.get(kind, {})
	if int(entry.get("activeUntilDay", -1)) < today:
		return 0
	return int(entry.get("value", 0))


## 每日边界：剥掉到期的恩惠（与 DisguiseGate.sync 同一处调用）。
static func sync(avatar: PlayerAvatar, today: int) -> void:
	if avatar == null:
		return
	for kind in avatar.blessings.keys():
		var entry: Dictionary = avatar.blessings[kind]
		if int(entry.get("activeUntilDay", -1)) < today:
			avatar.blessings.erase(kind)


## —— 改信神罚（M-A 「背一柱投另一柱」，旧圣物逐件咬）——

## 背一柱投另一柱的代价：以「接过多少旧柱圣物」为基准逐件咬。
## 返回 {ok, karmaCost, relicCount, penaltyText, reversible, refundCost}。
static func convert_cost(god: Dictionary, avatar: PlayerAvatar, coup_target: Dictionary, rules: Dictionary = {}) -> Dictionary:
	if avatar == null:
		return {"ok": false, "reason": "还没有化身"}
	var rels: Array[String] = avatar.accepted_relics
	var count: int = rels.size()
	var per: int = maxi(0, int((rules if not rules.is_empty() else _rules()).get("perRelicPenalty", 10)))
	var cost: int = count * per
	return {
		"ok": true,
		"karmaCost": cost,
		"relicCount": count,
		"penaltyText": str(god.get("penalty", "")),
		"reversible": true,
		"refundCost": maxi(0, int((rules if not rules.is_empty() else _rules()).get("refundCost", 50))),
	}


## 执行改信：把 current_patron 换成 coup_target，按成本咬旧柱圣物（扣善恶）、
## 并剥掉旧柱可能正挂着的那段持久庇护。付费路径；同种可复现。
static func convert(avatar: PlayerAvatar, coup_target: Dictionary, rules: Dictionary = {}, rng: DeterministicRNG = null) -> Dictionary:
	if avatar == null:
		return {"ok": false, "reason": "还没有化身"}
	var target_id: String = str(coup_target.get("id", ""))
	if target_id.is_empty():
		return {"ok": false, "reason": "没有可投的柱"}
	var cost: Dictionary = convert_cost(coup_target, avatar, coup_target, rules)
	var karma_cost: int = int(cost.get("karmaCost", 0))
	if avatar.karma - karma_cost < PlayerAvatar.HIDDEN_ATTR_MIN:
		return {"ok": false, "reason": "改信的代价会把你推向无边的恶，它拒绝借这一步"}
	avatar.set_karma(avatar.karma - karma_cost)
	avatar.current_patron = target_id
	# 接新柱的圣物算"接过"——换柱也要能换回来（revert 付 refundCost）。
	if not avatar.accepted_relics.has(target_id):
		avatar.accepted_relics.append(target_id)
	# 剥掉旧柱的持久庇护（换柱后旧神的恩惠不再护你）
	_sweep_old_blessings(avatar, target_id)
	return {"ok": true, "targetGodId": target_id, "karmaCost": karma_cost}


## 换回旧柱（可逆但贵）。付 refundCost 铜币，把柱改回去。
static func revert(avatar: PlayerAvatar, back_to: String, rules: Dictionary = {}) -> Dictionary:
	if avatar == null:
		return {"ok": false, "reason": "还没有化身"}
	var rc: int = maxi(0, int((rules if not rules.is_empty() else _rules()).get("refundCost", 50)))
	if avatar.money < rc:
		return {"ok": false, "reason": "拆账的赎金不够：%d 铜" % rc}
	avatar.money -= rc
	avatar.current_patron = back_to
	return {"ok": true, "targetGodId": back_to, "copper": rc}


## 换柱后，把不属于目标柱的持久恩惠全部剥掉（恩惠绑柱）。
static func _sweep_old_blessings(avatar: PlayerAvatar, keep_god: String) -> void:
	# 恩惠 dict 键本身就是 kind，不存柱归属；改信就把整张恩惠表清掉——新柱从零开始护你。
	avatar.blessings.clear()