class_name FamilyGate
extends RefCounted

## 婚姻·家族规则层（A3，接口 D-179 ~ D-181）。
##
## 把 NPC 好感这条轴从"聊得来的熟人"接成"定了的人"：好感到亲密档、玩家未成家、
## 还在同一城，就可出彩礼求婚；成婚后配偶在城内落成常驻具名（position_id = spouse），
## 家族影响两件事——配偶所在城的买卖给玩家折扣（家族影响商业），配偶离世的丧偶
## 记进家族史（死亡不可逆、转世不挽留）。
##
## 三个守则：
## 1. **好感是前提、不是结果**。求婚只读 `NpcInteractionSystem` 填好的好感档位，
##    自己不改好感——A3 不在社交里再造一套加分。
## 2. **家族落盘、不靠派生**。`avatar.family`（现配偶）+ `world.family.histories`
##    （丧偶史）随世界落盘。配偶是谁、哪天成的、哪天走的，是"玩家签过的一条
##    关系"，不能靠种子反推（与好感同源：认得熟人靠落盘不靠算）。
## 3. **死亡不可逆**。配偶随世界死亡即丧偶——不复活、不换成另一个人顶替；丧偶
##    进史书，转世后不挽留（与转生口径一致，见企划边界 5.1）。
##
## 配偶的常驻化（`is_named` + `position_id = spouse`）在这里完成标记，但 NPC 个体
## 的创建/删除仍归 WorldSim——规则层只负责"这台戏要一个什么样的角色"。

const POSITION_ID_SPOUSE: String = "spouse"

## 丧偶原因类别（D-181）：配偶随世界离世 / 玩家死亡转世时这段婚姻被"带走"。
## 转世不挽留——死亡不可逆，两种都以丧偶收场，只是记录里注明是哪一种。
const WIDOW_CLASS_DEATH: String = "death"
const WIDOW_CLASS_REINCARNATION: String = "reincarnation"

## 家族史条目在 world.family.histories 里的字段。marriedAt/widowedAt 记月份，
## widowClass 记丧偶时的原因类别（reincarnation / death），见 D-181。
const HISTORY_KEYS: Array = ["npcId", "name", "cityId", "marriedAt", "widowedAt", "widowClass"]


static func _cfg() -> Dictionary:
	return ContentLoader.get_balance_section("family")


## 彩礼（铜币）。数值走 balance，规则层只读不写死。
static func bride_price() -> int:
	return int(_cfg().get("bridePriceCopper", 500))


## 配偶所在城的买卖折扣（百分点，0-100）。家族影响商业的唯一杠杆。
static func discount_pct() -> int:
	return int(_cfg().get("discountPct", 5))


## 当前配偶记录（从 avatar 读）。无配偶返回空 dict。
## 形如 {npcId, name, cityId, marriedAt, discountCityId}。
static func family(avatar: PlayerAvatar) -> Dictionary:
	if avatar == null:
		return {}
	var f: Dictionary = avatar.family
	if f.is_empty() or str(f.get("npcId", "")).is_empty():
		return {}
	return f


## 是否已婚（配偶尚在）。
static func is_married(avatar: PlayerAvatar) -> bool:
	return not family(avatar).is_empty()


## 求婚资格一次判明。返回 {ok, reason, cost, discount}：
##   - 玩家有化身、还没配偶
##   - NPC 不是具名职位角色（守卫队长/大祭司/店主等锚点不能娶——他们欠全体市民）
##   - NPC 与玩家同城（异地恋不成，得当面拿彩礼去求）
##   - 好感已达亲密档（NpcInteractionSystem.BAND_CLOSE）
## 该函数只读，不改任何状态——界面拿它判断要不要亮"求婚"按钮。
static func proposal_ctx(avatar: PlayerAvatar, world: WorldState, npc: SimNpc) -> Dictionary:
	if avatar == null or world == null or npc == null:
		return { "ok": false, "reason": "条件还不够。" }
	if is_married(avatar):
		return { "ok": false, "reason": "你已成了家，一颗心挪不开第二处。" }
	if str(npc.position_id).is_empty() == false:
		if npc.position_id != POSITION_ID_SPOUSE:
			return { "ok": false, "reason": "%s是整座城的人，求不得。" % npc.display_name() }
	if npc.city_id != avatar.city_id:
		return { "ok": false, "reason": "人不在身边，提亲也得当面提。" }
	if NpcInteractionSystem.band(NpcInteractionSystem.affinity(world, npc.npc_id)) != NpcInteractionSystem.BAND_CLOSE:
		return { "ok": false, "reason": "还不到谈婚论嫁的情分。" }
	return {
		"ok": true, "reason": "",
		"cost": bride_price(),
		"discount": discount_pct(),
	}


## 成婚。扣彩礼 → 写 avatar.family → 配偶在城内落成常驻具名 → 记家族史。
## 返回 {ok, error, ...}。任何前置不满足都拒绝（复用 proposal_ctx 的口径）。
static func marry(avatar: PlayerAvatar, world: WorldState, npc: SimNpc, month: int) -> Dictionary:
	var ctx: Dictionary = proposal_ctx(avatar, world, npc)
	if not bool(ctx.get("ok", false)):
		return { "ok": false, "error": str(ctx.get("reason", "求亲不成。")) }
	if avatar.money < int(ctx.get("cost", 0)):
		return { "ok": false, "error": "彩礼没备齐（还差 %s）。" % (
			AvatarViewModel.money_label(int(ctx.get("cost", 0)) - avatar.money)) }

	avatar.money -= int(ctx.get("cost", 0))
	avatar.family = {
		"npcId": npc.npc_id,
		"name": npc.display_name(),
		"cityId": npc.city_id,
		"marriedAt": month,
		"discountCityId": npc.city_id,
	}
	# 配偶转常驻具名：不再随开新位被普通流动顶掉，也不受衰老寿命走人。
	npc.is_named = true
	npc.position_id = POSITION_ID_SPOUSE
	_append_history(world, avatar.family)
	return { "ok": true, "npcId": npc.npc_id, "cost": int(ctx.get("cost", 0)),
		"discount": int(ctx.get("discount", 0)) }


## 配偶所在城给玩家的买卖折扣系数（1.0 = 无折扣）。
## 家族影响商业：在配偶落脚的城，玩家买卖便宜一点。别处不打折。
static func discount_for(avatar: PlayerAvatar, city_id: String) -> float:
	var f: Dictionary = family(avatar)
	if f.is_empty() or str(f.get("discountCityId", "")) != str(city_id):
		return 1.0
	return 1.0 - maxf(0.0, minf(100.0, float(discount_pct()))) / 100.0


## 丧偶（死亡不可逆）。玩家死亡转世或配偶随世界离世时调用：
## 清空现配偶、把这段婚姻沉淀进家族史（widowClass 记原因）。
## 转世后不挽留——新的化身从"未成家"开始，但读得到家族史。
static func on_spouse_gone(avatar: PlayerAvatar, world: WorldState, month: int, widow_class: String) -> Dictionary:
	var f: Dictionary = family(avatar)
	if f.is_empty():
		return { "ok": false, "error": "没有在世的配偶。" }
	var entry: Dictionary = _find_history(world, str(f.get("npcId", "")))
	if not entry.is_empty():
		entry["widowedAt"] = month
		entry["widowClass"] = widow_class
	avatar.family = {}
	avatar.bereaved_note = "你失了 %s。" % str(f.get("name", ""))
	return { "ok": true, "spouseName": str(f.get("name", "")), "widowClass": widow_class }


## 与丧偶同源的查询：这位 NPC 是不是玩家的（亡故或现任）配偶。
static func is_or_was_spouse(avatar: PlayerAvatar, npc_id: String) -> bool:
	var f: Dictionary = family(avatar)
	if not f.is_empty() and str(f.get("npcId", "")) == str(npc_id):
		return true
	return false


static func _append_history(world: WorldState, record: Dictionary) -> void:
	var fam: Dictionary = world.family
	var histories: Array = fam.get("histories", [])
	var head: Dictionary = _find_history(world, str(record.get("npcId", "")))
	if not head.is_empty():
		# 已是这段婚姻的进行时，不重复记一行
		return
	histories.append({
		"npcId": str(record.get("npcId", "")),
		"name": str(record.get("name", "")),
		"cityId": str(record.get("cityId", "")),
		"marriedAt": int(record.get("marriedAt", 0)),
		"widowedAt": -1,
		"widowClass": "",
	})
	fam["histories"] = histories
	world.family = fam


static func _find_history(world: WorldState, npc_id: String) -> Dictionary:
	if world == null:
		return {}
	for h in (world.family.get("histories", []) as Array):
		if str(h.get("npcId", "")) == str(npc_id):
			return h
	return {}