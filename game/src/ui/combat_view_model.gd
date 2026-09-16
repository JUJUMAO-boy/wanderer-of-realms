class_name CombatViewModel
extends RefCounted

## 战斗界面的视图模型（M6.2 与 M5 的呈现层）。
##
## 界面的交互是分层的：主菜单里选「攻击」/「技能：X」/「移动」，进入选目标或选格
## 子模式，选定后真正提交。菜单项直接携带**完整的动作字典**，主场景拿到就直接
## 交给 Combat.submit_action，中间不再做一次翻译——少一层翻译就少一处对不上的地方。

const MENU_MAIN: int = 0
const MENU_TARGET_UNIT: int = 1
const MENU_TARGET_TILE: int = 2
const MENU_DOWNED: int = 3

const MENU_HINTS: Dictionary = {
	MENU_MAIN: "↑↓ 选行动    回车 执行    ESC 取消",
	MENU_TARGET_UNIT: "↑↓ 选目标    回车 确认    ESC 返回",
	MENU_TARGET_TILE: "↑↓←→ 移光标    回车 确认移动    ESC 返回",
	MENU_DOWNED: "↑↓ 选处理方式    回车 执行    ESC 返回",
}

## 战场最多画出这么大，超出的单位不画（MVP 的遭遇战不会有更大的场面）
const BATTLE_WIDTH: int = 14
const BATTLE_HEIGHT: int = 9
const LOG_TAIL: int = 8


static func build(
	combat: Combat,
	skill_names: Dictionary,
	menu_mode: int,
	cursor: int,
	pending: Dictionary = {},
	cursor_tile: Vector2i = Vector2i.ZERO
) -> Dictionary:
	if combat == null:
		return {}
	var menu: Array = _menu(combat, skill_names, menu_mode, pending)
	return {
		"round": combat.round,
		"finished": combat.finished,
		"winner": combat.winner,
		"currentUnitId": combat.current_unit_id(),
		"menuMode": menu_mode,
		"menuHint": str(MENU_HINTS.get(menu_mode, "")),
		"menu": menu,
		"menuLabel": _menu_label(menu_mode, pending),
		"cursor": clampi(cursor, 0, maxi(0, menu.size() - 1)),
		"cursorTile": cursor_tile,
		"unitRows": _unit_rows(combat),
		"battlefield": _battlefield(combat),
		"logTail": _log_tail(combat),
		"loot": combat.loot.duplicate(true),
		"worldFlags": combat.world_flags.duplicate(),
	}


## 当前该动的是不是玩家（界面据此决定要不要弹菜单）。
static func is_player_turn(combat: Combat) -> bool:
	var unit_id: String = combat.current_unit_id()
	if unit_id.is_empty():
		return false
	var unit: Dictionary = combat.unit_by_id(unit_id)
	return not unit.is_empty() and str(unit.get("side", "")) == Combat.SIDE_PLAYER


static func _unit_rows(combat: Combat) -> Array:
	var out: Array = []
	for unit in combat.units:
		var max_hp: int = maxi(1, int(unit["maxHp"]))
		out.append({
			"unitId": str(unit["unitId"]),
			"name": str(unit["name"]),
			"side": str(unit["side"]),
			"hp": int(unit["hp"]),
			"maxHp": max_hp,
			"hpRatio": clampf(float(unit["hp"]) / float(max_hp), 0.0, 1.0),
			"ap": int(unit["ap"]),
			"tu": int(unit["tu"]),
			"downed": bool(unit["downed"]),
			"dead": bool(unit["dead"]),
			"statusLabel": status_label(unit),
			"isCurrent": str(unit["unitId"]) == combat.current_unit_id(),
		})
	return out


static func status_label(unit: Dictionary) -> String:
	if bool(unit.get("dead", false)):
		return "阵亡"
	if bool(unit.get("downed", false)):
		return "倒地"
	if int(unit.get("stunnedTurns", 0)) > 0:
		return "眩晕"
	var injured: int = 0
	var parts: Dictionary = unit.get("bodyParts", {})
	for part in DerivedStats.PARTS_LIMBS + DerivedStats.PARTS_HEAD:
		var state: Dictionary = parts.get(part, {})
		if bool(state.get("injured", false)):
			injured += 1
	if injured > 0:
		return "带伤 %d 处" % injured
	return "无恙"


static func _battlefield(combat: Combat) -> Dictionary:
	var units: Array = []
	for unit in combat.units:
		var position: Vector2i = unit["position"]
		if position.x < 0 or position.y < 0:
			continue
		if position.x >= BATTLE_WIDTH or position.y >= BATTLE_HEIGHT:
			continue
		units.append({
			"unitId": str(unit["unitId"]),
			"x": position.x,
			"y": position.y,
			"side": str(unit["side"]),
			"downed": bool(unit["downed"]),
			"dead": bool(unit["dead"]),
			"isCurrent": str(unit["unitId"]) == combat.current_unit_id(),
			"initial": str(unit["name"]).substr(0, 1),
		})
	var blocked: Array = []
	for key in combat.obstacles:
		var parts: PackedStringArray = str(key).split(",")
		if parts.size() == 2:
			blocked.append({"x": int(parts[0]), "y": int(parts[1])})
	return {
		"width": BATTLE_WIDTH,
		"height": BATTLE_HEIGHT,
		"units": units,
		"obstacles": blocked,
	}


static func _log_tail(combat: Combat) -> Array:
	var out: Array = []
	var start: int = maxi(0, combat.log.size() - LOG_TAIL)
	for i in range(start, combat.log.size()):
		out.append(str(combat.log[i]))
	return out


static func _menu_label(menu_mode: int, pending: Dictionary) -> String:
	match menu_mode:
		MENU_TARGET_UNIT:
			return "选择目标：%s" % str(pending.get("label", "攻击"))
		MENU_TARGET_TILE:
			return "选择落点（每格 %d AP）" % int(pending.get("moveCost", 1))
		MENU_DOWNED:
			return "处理倒地者"
	return "行动"


## 菜单项。每一项都带一个完整的动作字典，动作的 kind 决定主场景怎么处理：
##   end_turn / downed_choice / target_unit / target_tile 直接提交；
##   move / attack / skill / downed 进入下一层子菜单。
static func _menu(
	combat: Combat, skill_names: Dictionary, menu_mode: int, pending: Dictionary
) -> Array:
	if combat.finished:
		return []
	var actor_id: String = combat.current_unit_id()
	if actor_id.is_empty():
		return []
	var actor: Dictionary = combat.unit_by_id(actor_id)
	if actor.is_empty() or str(actor.get("side", "")) != Combat.SIDE_PLAYER:
		return []

	match menu_mode:
		MENU_TARGET_UNIT:
			return _target_unit_menu(combat, actor, pending)
		MENU_TARGET_TILE:
			return _target_tile_menu(actor, pending)
		MENU_DOWNED:
			return _downed_menu(combat)
	return _main_menu(combat, actor, skill_names)


static func _main_menu(combat: Combat, actor: Dictionary, skill_names: Dictionary) -> Array:
	var out: Array = [{
		"label": "移动（每格 %d AP）" % int(_move_cost(combat, actor)),
		"action": {"kind": "move"},
	}]
	var has_opponent: bool = false
	for unit in combat.units:
		if str(unit["side"]) != str(actor["side"]) and not bool(unit["downed"]) and not bool(unit["dead"]):
			has_opponent = true
			break
	if has_opponent:
		out.append({"label": "普通攻击（2 AP）", "action": {"kind": "attack"}})
		var skills: Array = actor["skills"].keys()
		skills.sort()
		for skill_id in skills:
			var skill: Dictionary = combat.skill_def(str(skill_id))
			if skill.is_empty():
				continue
			# 被动技能不是动作：它们没有 AP 消耗、不进战斗菜单（负重训练这类骨架技能
			# 挂在 avatar.skills 里提供熟练度，但战斗里不该多出一个"施放"项）
			if str(skill.get("category", "")) == "passive":
				continue
			var ap_cost: int = int(skill.get("apCost", 2))
			var skill_level: int = int(actor["skills"].get(str(skill_id), 0))
			var req: int = int(skill.get("requiredSkillLevel", 0))
			var mp_cost: int = int(skill.get("mpCost", 0))
			# 展示三层不可用原因（M13：熟练度门槛、魔力不足、AP/冷却）并置灰。
			var usable: bool = true
			var away: Array = []
			if skill_level < req:
				usable = false
				away.append("需 %d 熟练（现 %d）" % [req, skill_level])
			elif mp_cost > int(actor["mp"]):
				usable = false
				away.append("蓝不足（需 %d，现 %d）" % [mp_cost, int(actor["mp"])])
			if ap_cost > int(actor["ap"]) or int(actor["cooldowns"].get(str(skill_id), 0)) > 0:
				usable = false
				away.append("暂不可用")
			var suffix: String = "" if away.is_empty() else (" —— " + "、".join(PackedStringArray(away)))
			var mp_text: String = ("，%d MP" % mp_cost) if mp_cost > 0 else ""
			out.append({
				"label": "%s（%s%s，%d AP）%s" % [
					str(skill_names.get(str(skill_id), str(skill_id))),
					str(skill.get("effectText", "")), mp_text, ap_cost, suffix,
				],
				"enabled": usable,
				"action": {"kind": "skill", "skillId": str(skill_id),
					"label": str(skill_names.get(str(skill_id), str(skill_id))),
					"apCost": ap_cost},
			})
	if _has_pending_downed(combat):
		out.append({"label": "处理倒地者（1 AP）", "action": {"kind": "downed"}})
	out.append({"label": "结束回合", "action": {"kind": "end_turn"}})
	return out


static func _target_unit_menu(combat: Combat, actor: Dictionary, pending: Dictionary) -> Array:
	var out: Array = []
	for unit in combat.units:
		if str(unit["side"]) == str(actor["side"]):
			continue
		if bool(unit["dead"]) or bool(unit["downed"]):
			continue
		var distance: int = absi(int(unit["position"].x) - int(actor["position"].x)) \
			+ absi(int(unit["position"].y) - int(actor["position"].y))
		var attack_range: int = int(pending.get("attackRange", 1))
		out.append({
			"label": "%s（距离 %d，射程 %d）%s" % [
				str(unit["name"]), distance, attack_range,
				"" if distance <= attack_range else " —— 够不着",
			],
			"enabled": distance <= attack_range,
			"action": {
				"kind": "target_unit",
				"targetId": str(unit["unitId"]),
				"pending": pending,
			},
		})
	return out


static func _target_tile_menu(actor: Dictionary, pending: Dictionary) -> Array:
	var out: Array = []
	var reach: int = int(pending.get("reach", 1))
	var cost_per_tile: int = maxi(1, int(pending.get("moveCost", 1)))
	var origin: Vector2i = actor["position"]
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			if dx == 0 and dy == 0:
				continue
			var tile := Vector2i(origin.x + dx, origin.y + dy)
			if tile.x < 0 or tile.y < 0:
				continue
			if tile.x >= BATTLE_WIDTH or tile.y >= BATTLE_HEIGHT:
				continue
			var distance: int = absi(dx) + absi(dy)
			out.append({
				"label": "移动到 (%d, %d)——%d AP" % [tile.x, tile.y, distance * cost_per_tile],
				"enabled": distance * cost_per_tile <= int(actor["ap"]),
				"action": {"kind": "target_tile", "x": tile.x, "y": tile.y},
			})
	return out


static func _downed_menu(combat: Combat) -> Array:
	var labels: Dictionary = {
		Combat.DOWNED_SEARCH: "搜身",
		Combat.DOWNED_CAPTURE: "俘虏",
		Combat.DOWNED_RELEASE: "放走",
		Combat.DOWNED_FINISH: "补刀",
	}
	var out: Array = []
	for unit in combat.units:
		if str(unit["side"]) == Combat.SIDE_PLAYER:
			continue
		if not bool(unit["downed"]) or bool(unit["dead"]):
			continue
		if bool(unit.get("handled", false)):
			continue
		for choice in Combat.ALL_DOWNED_CHOICES:
			out.append({
				"label": "%s %s" % [str(labels.get(choice, choice)), str(unit["name"])],
				"action": {
					"kind": "downed_choice",
					"targetId": str(unit["unitId"]),
					"downedChoice": choice,
				},
			})
	return out


static func _has_pending_downed(combat: Combat) -> bool:
	for unit in combat.units:
		if str(unit["side"]) == Combat.SIDE_PLAYER:
			continue
		if bool(unit["downed"]) and not bool(unit["dead"]) and not bool(unit.get("handled", false)):
			return true
	return false


static func _move_cost(combat: Combat, actor: Dictionary) -> int:
	# 腿伤让每格更贵（6.4 节）。这里调战斗里的同一处计算，
	# 避免界面显示的消耗与实际扣的对不上。
	return combat.unit_move_cost(actor)
