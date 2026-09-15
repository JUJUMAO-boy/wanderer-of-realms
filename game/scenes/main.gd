func _ticks_per_day() -> int:
	return int(ContentLoader.get_balance_section("time").get("ticksPerDay", 24))


func _days_per_month() -> int:
	return int(ContentLoader.get_balance_section("time").get("daysPerMonth", 30))


func _months_per_year() -> int:
	return int(ContentLoader.get_balance_section("time").get("monthsPerYear", 12))


# --- 临时探针：跨世转生闭环（验证后删除）---

func _probe_press(key: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = key
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().process_frame


## 走一遍自由生成：属性点花光，落到确认段，再开始这一生。
func _probe_free_creation() -> void:
	var session: CreationSession = _creation_session
	session.go_to_section(CreationViewModel.SECTION_ATTRIBUTES)
	var guard: int = 0
	var index: int = 0
	var attrs: Array = PlayerAvatar.ALL_ATTRIBUTES
	while _creator.remaining_points(session.spec) > 0 and guard < 400:
		guard += 1
		session.allocate(index % attrs.size(), 1)
		index += 1
	session.go_to_section(CreationViewModel.SECTION_CONFIRM)
	_start_from_creation(session.confirm())
	await get_tree().process_frame


func _probe_life() -> void:
	print("[探针] === 跨世转生闭环 ===")
	_enter_creation()
	await _probe_free_creation()
	var avatar: PlayerAvatar = _world.avatar
	print("[探针] 第 1 世：%s（%s · %d 岁）在 %s，寿命上限 %d 岁，钱 %d 铜，avatarId=%s" % [
		avatar.display_name, avatar.race, avatar.age,
		_grid.get_city_id_at(avatar.pos_x, avatar.pos_y),
		_lifecycle.lifespan_of(avatar), avatar.money, avatar.avatar_id,
	])

	# 世代记录：在世时只有一行，底部给「结束这一生」
	await _probe_press(KEY_L)
	print("[探针] 世代记录（在世）：%d 行，抬头「%s」" % [
		int(_lives_view.get("rowCount", 0)), str(_lives_view.get("aliveLine", ""))
	])
	print("[探针] 按钮：%s" % _probe_buttons(_lives_view))

	# 主动结束这一生：第一次上膛，第二次才真的结束
	await _probe_press(KEY_ENTER)
	print("[探针] 上膛后按钮：%s ／ %s" % [_probe_buttons(_lives_view), _status.text])
	await _probe_press(KEY_ENTER)
	print("[探针] 结算：%s" % _status.text)
	var life1: Dictionary = _soul.life_archives[_soul.life_archives.size() - 1]
	var deeds1: Dictionary = life1.get("deeds", {})
	print("[探针] 档案：%s · 享年 %d · 死因 %s · 钱 %d 铜 · 走过 %d 座城 · 交付 %d 张单" % [
		str(life1.get("archiveId", "")), int(life1.get("age", 0)),
		str(Reincarnation.CAUSE_LABELS.get(str(life1.get("deathCause", "")), "")),
		int(deeds1.get("money", 0)), deeds1.get("visitedCities", []).size(),
		int(deeds1.get("counters", {}).get(PlayerAvatar.DEED_QUESTS_COMPLETED, 0)),
	])
	print("[探针] 世界上的化身：%s（应当是 null）" % str(_world.avatar))
	print("[探针] 死亡后按钮：%s" % _probe_buttons(_lives_view))

	# 转生：回到创建界面，抽一具宿主的躯壳
	await _probe_press(KEY_ENTER)
	var host: Dictionary = _creation_session.rebirth.get("legacy", {})
	print("[探针] 转生预览（模式 %d）：宿主 %s · 沉眠 %d 月 · 保留率 %d%%" % [
		int(_creation_session.mode), str(host.get("hostName", "")),
		int(_creation_session.rebirth.get("sleepMonths", 0)),
		int(round(float(_creation_session.rebirth.get("retention", 0.0)) * 100.0)),
	])
	await _probe_press(KEY_ENTER)
	var second: PlayerAvatar = _world.avatar
	print("[探针] 第 2 世：%s（%s · %d 岁）在第 %d 月，avatarId=%s，继承技能 %d 项" % [
		second.display_name, second.race, second.age, Clock.total_months(),
		second.avatar_id, second.skills.size(),
	])

	# 寿终：把这一世的起点挪近暮年，再快进十年
	second.age = 76
	second.life_start_age = 76
	second.life_start_month = Clock.total_months()
	await _probe_press(KEY_G)
	print("[探针] 快进十年：%s" % _status.text)
	var life2: Dictionary = _soul.life_archives[_soul.life_archives.size() - 1]
	print("[探针] 寿终的账记在第 %d 月（发现它时是第 %d 月），享年 %d，寿命上限 %d" % [
		int(life2.get("endedMonth", 0)), Clock.total_months(),
		int(life2.get("age", 0)), int(life2.get("lifespan", 0)),
	])

	# 再转生一次，确认化身编号往后走
	await _probe_press(KEY_ENTER)
	await _probe_press(KEY_ENTER)
	print("[探针] 第 3 世：%s，avatarId=%s，已转生 %d 次" % [
		_world.avatar.display_name, _world.avatar.avatar_id, _soul.reincarnation_count,
	])

	# 战死：正式遭遇打输会死。这里用训练战临时挂上"致命"标记来验证那条支路
	_set_all_dimensions(_world.get_city(_grid.get_city_id_at(
		_world.avatar.pos_x, _world.avatar.pos_y)) if false else _world.get_city("port_thorne"), 50)
	_world.avatar.pos_x = _world.get_city("port_thorne").coord_x
	_world.avatar.pos_y = _world.get_city("port_thorne").coord_y
	_start_combat()
	_combat_fatal = true
	var player: Dictionary = _combat.unit_by_id("unit-player")
	if not player.is_empty():
		player["hp"] = 1
	var turns: int = 0
	while _combat != null and not _combat.finished and turns < 60:
		turns += 1
		_submit_combat({"actionType": Combat.ACTION_END_TURN, "actorId": _actor_id()})
		await get_tree().process_frame
	print("[探针] 致命遭遇打输（走了 %d 手）：%s" % [turns, _status.text])
	var last: Dictionary = _soul.life_archives[_soul.life_archives.size() - 1]
	print("[探针] 最后一世的死因：%s · 世界上还有化身吗：%s" % [
		str(Reincarnation.CAUSE_LABELS.get(str(last.get("deathCause", "")), "")),
		str(_world.avatar != null),
	])
	print("[探针] 历代共 %d 世：%s" % [
		_soul.life_archives.size(), _probe_life_titles(),
	])
	print("[探针] 完成。")


func _probe_buttons(view: Dictionary) -> String:
	var labels: Array = []
	for button in LifePanel.buttons(view, PANEL_RECT):
		labels.append(str(button["label"]))
	return " / ".join(PackedStringArray(labels))


func _probe_life_titles() -> String:
	var titles: Array = []
	for row in _lives_view.get("rows", []):
		titles.append("%s（%s）" % [str(row.get("title", "")), str(row.get("meta", ""))])
	return " · ".join(PackedStringArray(titles))
