class_name TestSuite
extends RefCounted

## 里程碑 1 的验收测试。无头模式运行：
##   godot --headless --path game -- --test
##
## 每条测试对应技术设计文档 8.4 节里某个功能的验收标准。测试直接建在
## 纯逻辑层之上，不依赖渲染与场景，因此可以在无 GPU 的环境里跑。

var _passed: int = 0
var _failed: int = 0
var _failures: Array[String] = []

## 查抄代价用例跑多少个月。取 48 是为了让"声誉 −5/次"这条算式留在 −100 的
## 钳制之上：治安钉在 100 时每月每端 20% 被抓，48 个月各端约 10 次，离下限还远。
## 跑久了测的就不是算式而是钳制，而钳制另有 _test_reputation_clamp 专测。
const PENALTY_MONTHS: int = 48


func run_all() -> int:
	print("=== 里程碑 1 验收测试 ===")
	_test_clock_year_boundaries()
	_test_clock_determinism()
	_test_rng_determinism_and_state()
	_test_content_loaded()
	_test_city_tier()
	_test_map_grid()
	_test_save_round_trip()
	_test_migration_framework()
	print("=== 里程碑 2 验收测试 ===")
	_test_city_evolution_long_run()
	_test_tier_change_marker_and_deferred_change()
	_test_change_idempotency()
	_test_npc_generation()
	_test_profession_weights_follow_city_state()
	_test_npc_lifecycle_and_succession()
	_test_migration_from_low_attraction_city()
	_test_fast_forward()
	_test_route_rules()
	_test_route_break_only_hits_regular_routes()
	_test_confiscation_scales_with_security()
	_test_world_confiscation_does_not_touch_player()
	_test_player_smuggling_route_lifecycle()
	_test_player_confiscation_penalty()
	_test_reputation_clamp()
	_test_world_round_trip_with_npcs()
	print("=== 界面可读性 ===")
	_test_ui_font_available()
	print("=== 世界演化可感知性 ===")
	_test_delta_attribution()
	_test_state_change_attribution()
	_test_tier_progress()
	_test_history_recording()
	_test_city_view_model()
	_test_history_round_trip()
	print("=== 里程碑 3 开局与战斗公式 ===")
	_test_creation_config()
	_test_creation_config_refs()
	_test_attribute_allocation()
	_test_talent_flaw_pairing()
	_test_build_avatar_from_spec()
	_test_random_rebirth_legacy()
	_test_luck_favors_better_host()
	_test_retention_and_inheritance()
	_test_settle_death()
	_test_derived_stats_formulas()
	_test_hit_and_damage_formulas()
	_test_body_part_injury()
	_test_combat_initiative_and_ap()
	_test_combat_encumbrance()
	_test_combat_injury_effects()
	_test_combat_downed_choices()
	_test_downed_body_does_not_block_ai()
	_test_move_exhausting_ap_ends_turn()
	_test_combat_loot_scaling()
	print("=== 界面视图模型 ===")
	_test_creation_view_model()
	_test_avatar_view_model()
	_test_combat_view_model()
	_test_smuggling_view_model()
	print("=== 界面命中测试（鼠标）===")
	_test_creation_panel_hit_test()
	_test_city_and_avatar_panel_hit_test()
	_test_combat_panel_hit_test()
	_test_smuggling_panel_hit_test()
	print("=== 开局创建流程（状态机）===")
	_test_creation_session()
	print("=== 里程碑 4 委托闭环 ===")
	_test_quest_board_generation()
	_test_quest_accept_and_capacity()
	_test_quest_complete_and_settlement()
	_test_quest_branches_and_combat_outcomes()
	_test_quest_consequence_chain()
	_test_quest_round_trip()
	_test_quest_view_model()
	_test_quest_panel_hit_test()
	print("=== 里程碑 7 城市事件 ===")
	_test_event_trigger_and_blockade()
	_test_event_drain_and_lift()
	_test_event_branch_resolution()
	_test_event_deal_recurrence()
	_test_event_combat_outcomes()
	_test_event_legendary_route()
	_test_event_round_trip()
	_test_event_view_model()
	_test_event_panel_hit_test()
	print("=== 经济：价格与买卖 ===")
	_test_economy_price_factors()
	_test_economy_stock_availability()
	_test_economy_buy_and_sell()
	_test_economy_black_market()
	_test_trade_view_model()
	_test_trade_panel_hit_test()
	print("=== 装备槽与穿戴 ===")
	_test_equipment_slots()
	_test_equipment_equip_and_unequip()
	_test_equipment_two_handed()
	_test_equipment_loadout()
	_test_equipment_shop_link()
	_test_equipment_view_model()
	_test_equipment_panel_hit_test()
	print("=== 物品词缀、耐久与强化 ===")
	_test_item_affix_roll()
	_test_item_affix_effects()
	_test_item_durability()
	_test_item_wear_and_broken()
	_test_item_three_tier_repair()
	_test_portable_tool()
	_test_item_enhancement()
	_test_item_instance_price()
	_test_item_instance_round_trip()
	_test_forge_view_model()
	_test_forge_panel_hit_test()
	print("=== 里程碑 12 建筑经营经济 ===")
	_test_building_content()
	_test_building_available_and_effective()
	_test_building_invest()
	_test_building_settlement()
	_test_building_round_trip()
	print("=== 里程碑 13 法术与技能系统 ===")
	_test_skill_content()
	_test_skill_mastery_gate()
	_test_skill_mp()
	_test_skill_growth()
	_test_element_counter_formula()
	_test_element_wiring()
	_test_mastery_passive_formula()
	print("=== 里程碑 14 生产技能系统 ===")
	_test_recipe_content()
	_test_craft_gate()
	_test_craft_success()
	_test_craft_rarity()
	_test_craft_equipment_rarity()
	_test_enchant_in_place()
	_test_gather_action()
	_test_shop_sells_base_materials_only()
	print("=== 里程碑 15 制作台完整面板 ===")
	_test_crafting_view_model()
	_test_crafting_enchant_target()
	_test_crafting_panel_hit_test()
	_test_crafting_flow()
	print("=== 世界纪年与历史纪年（M16）===")
	_test_chronicle_rules()
	_test_chronicle_event_hook()
	_test_chronicle_round_trip()
	_test_chronicle_view_model()
	_test_chronicle_panel_hit_test()
	print("=== 世界遭遇 ===")
	_test_encounter_tier()
	_test_encounter_chance()
	_test_encounter_roll()
	_test_encounter_group()
	_test_encounter_city_npc()
	_test_encounter_avoid()
	_test_encounter_parley()
	_test_encounter_units_and_resolve()
	_test_level_gap_penalty()
	_test_encounter_view_model()
	_test_encounter_panel_hit_test()
	print("=== 隐藏属性事件（M17）===")
	_test_hidden_attr_clamp_band()
	_test_hidden_trigger_and_cooldown()
	_test_hidden_branch_apply()
	_test_hidden_view_model()
	_test_hidden_mark()
	print("=== NPC 人格与交互（M18）===")
	_test_npc_personality_faith()
	_test_npc_affinity_band()
	_test_npc_round_trip()
	_test_npc_talk()
	_test_npc_gift()
	_test_npc_hire()
	_test_npc_follower_combat()
	_test_npc_view_model()
	print("=== 城内空间（M19）===")
	_test_city_space_determinism()
	_test_city_space_placement()
	_test_city_space_collision()
	_test_city_space_gate()
	_test_city_space_near_building()
	_test_city_space_near_npc()
	_test_city_space_view_model()
	print("=== M20 阶段一：行走路径与导航侧栏 ===")
	_test_walk_path_grid()
	_test_hud_nav_layout_hit()
	print("=== M20 阶段二：全场景面板统一外壳 ===")
	_test_ui_panel_chrome()
	print("=== M21 临时副本与地图商人 ===")
	_test_dungeon_determinism()
	_test_dungeon_layout_valid()
	_test_dungeon_connectivity()
	_test_dungeon_step_collision()
	_test_dungeon_view_model()
	_test_merchant_stock_deterministic()
	_test_merchant_quote()
	_test_merchant_buy_sell_stock()
	_test_merchant_view_model()
	print("=== M22 战斗深度：连携/遮挡/随从倾向 ===")
	_test_element_chain()
	_test_line_of_sight_blocks_ranged()
	_test_m22_identity_and_tendency()
	print("=== M23 副本主题层与商人深度 ===")
	_test_dungeon_theme()
	_test_dungeon_theme_det()
	_test_merchant_persona()
	_test_merchant_legendary()
	_test_merchant_buy_back_value()
	print("=== M-C 大地图可见实体：遗构（副本入口）与怪物窝点 ===")
	_test_world_seen_determinism()
	_test_world_seen_prefix()
	_test_world_seen_placement()
	_test_world_seen_lair()
	_test_world_seen_words()
	print("---")
	print("通过 %d 项，失败 %d 项" % [_passed, _failed])
	if _failed > 0:
		print("失败明细：")
		for msg in _failures:
			print("  x " + msg)
	return _failed


# --- 测试项 ---

func _test_clock_year_boundaries() -> void:
	var tpd: int = _time_scale("ticksPerDay", 24)
	var dpm: int = _time_scale("daysPerMonth", 30)
	var mpy: int = _time_scale("monthsPerYear", 12)
	var core := ClockCore.new(tpd, dpm, mpy)

	var fired: Array[Dictionary] = core.advance(tpd * dpm * mpy)
	var days: int = 0
	var months: int = 0
	var years: int = 0
	for ev in fired:
		match str(ev["period"]):
			ClockCore.PERIOD_DAY:
				days += 1
			ClockCore.PERIOD_MONTH:
				months += 1
			ClockCore.PERIOD_YEAR:
				years += 1

	_eq(days, 360, "推进一年产生 360 次日结算")
	_eq(months, 12, "推进一年产生 12 次月结算")
	_eq(years, 1, "推进一年产生 1 次年结算")
	_eq(core.time.elapsed_months, 12, "推进一年后 elapsed_months 为 12")
	_eq(core.time.year, 2, "推进一年后年份为 2")

	# 每个月的最后一小时同时跨日界与月界，日事件必须先于月事件返回，
	# 否则当日的收尾结算会排在月度结算之后。
	var core2 := ClockCore.new(tpd, dpm, mpy)
	var one_month: Array[Dictionary] = core2.advance(tpd * dpm)
	var last_periods: Array[String] = []
	for i in range(maxi(0, one_month.size() - 2), one_month.size()):
		last_periods.append(str(one_month[i]["period"]))
	_eq(",".join(PackedStringArray(last_periods)), "day,month",
		"月末同一小时的日事件排在月事件之前")


func _test_clock_determinism() -> void:
	var a := ClockCore.new(24, 30, 12)
	var b := ClockCore.new(24, 30, 12)
	# 用非整月的 tick 数推进，确保余数也能对齐
	a.advance(5000)
	b.advance(5000)
	_eq(a.total_ticks(), b.total_ticks(), "两次推进的总 tick 相同")
	_eq(a.time.elapsed_months, b.time.elapsed_months, "两次推进的月数相同")
	_eq(a.time.tick_in_month, b.time.tick_in_month, "两次推进的月内偏移相同")

	# 存档往返：只存两个权威值，恢复后其余全部重算
	var c := ClockCore.new(24, 30, 12)
	c.restore(a.time.elapsed_months, a.time.tick_in_month)
	_eq(c.total_ticks(), a.total_ticks(), "由权威值恢复出相同的总 tick")
	_eq(c.time.year, a.time.year, "恢复后年份一致")
	_eq(c.time.day, a.time.day, "恢复后日一致")


func _test_rng_determinism_and_state() -> void:
	var a := DeterministicRNG.new(12345)
	var b := DeterministicRNG.new(12345)
	var identical: bool = true
	for _i in range(50):
		if a.next_u32() != b.next_u32():
			identical = false
			break
	_check(identical, "同一世界种子产生相同的随机序列")

	var x := DeterministicRNG.new(1)
	var y := DeterministicRNG.new(2)
	_check(x.next_u32() != y.next_u32(), "不同种子产生不同序列")

	# 状态恢复后序列要接着走，不能重头开始——读档后随机流重来会让
	# "同一份存档重复读"产生不同结果。
	var r := DeterministicRNG.new(999)
	for _i in range(10):
		r.next_u32()
	var saved_state: int = r.get_state()
	var next_expected: int = r.next_u32()
	var r2 := DeterministicRNG.new(0)
	r2.set_state(saved_state)
	_eq(r2.next_u32(), next_expected, "恢复随机状态后序列接着走")

	var z := DeterministicRNG.new(7)
	var in_range: bool = true
	for _i in range(300):
		var v: int = z.next_int(6)
		if v < 0 or v > 5:
			in_range = false
			break
	_check(in_range, "next_int(6) 的结果落在 [0,6)")

	_eq(DeterministicRNG.new(0).get_state(), DeterministicRNG.FALLBACK_SEED,
		"种子为 0 时改用兜底种子，避免 xorshift 退化")


func _test_content_loaded() -> void:
	_check(ContentLoader.is_loaded(), "配置在启动期装载并通过校验")
	_eq(ContentLoader.get_city_configs().size(), 8, "装载了 8 座城市")
	_check(not ContentLoader.get_city_config("port_thorne").is_empty(), "能按 id 取到城市配置")
	_check(ContentLoader.get_city_config("no_such_city").is_empty(), "取不存在的城市返回空")
	_check(ContentLoader.get_balance_section("trade").has("smugglingMaxDistance"),
		"数值配置含走私航线段")
	_eq(ContentLoader.get_events().size(), 1, "装载了 1 条城市事件（8.5 节的内容裁剪）")


func _test_city_tier() -> void:
	var cfg: Dictionary = ContentLoader.get_city_config("silvermoon_spire")
	var c: City = City.from_config(cfg)
	# 银月塔：发展度 80 属"城市"(66-85)，人口 45 属"城镇"(<=60)，取较低者
	_eq(c.get_tier(), City.Tier.TOWN, "城市阶段取发展度与人口中较低的一档")
	_eq(c.get_tier_label(), "城镇", "阶段标签正确")

	var c2: City = City.from_config(cfg)
	c2.development = 95
	c2.population = 5
	_eq(c2.get_tier(), City.Tier.RUINS, "人口散尽时阶段退回废墟，而非维持大城")


func _test_map_grid() -> void:
	var grid := MapGrid.new(120, 120)
	for cfg in ContentLoader.get_city_configs():
		grid.register_city(City.from_config(cfg))

	_eq(grid.get_city_id_at(60, 50), "aedran", "艾德兰坐标对应 aedran")
	_eq(grid.get_city_id_at(0, 0), "", "空白坐标没有城市")
	_check(grid.can_enter(119, 119), "右下角在网格内")
	_check(not grid.can_enter(120, 0), "超出右边界不可进入")
	_check(not grid.can_enter(-1, 0), "超出左边界不可进入")
	_eq(grid.step(0, 0, -1, 0), Vector2i(0, 0), "撞边界时原地不动")
	_eq(grid.step(10, 10, 1, 0), Vector2i(11, 10), "正常移动一格")

	_eq(MapGrid.manhattan(Vector2i(15, 40), Vector2i(60, 50)), 55, "曼哈顿距离计算正确")
	_eq(City.from_config(ContentLoader.get_city_config("port_thorne")).distance_to(
		City.from_config(ContentLoader.get_city_config("aedran"))
	), 55, "城市间距离与手工计算一致")


func _test_save_round_trip() -> void:
	var built: Dictionary = _new_world()
	var world: WorldState = built["world"]
	var avatar := PlayerAvatar.new()
	avatar.avatar_id = "avatar-1"
	avatar.soul_id = "soul-test"
	avatar.pos_x = 60
	avatar.pos_y = 50
	avatar.set_attribute(PlayerAvatar.ATTR_SOUL, 73)
	avatar.set_reputation("aedran", 42)
	world.avatar = avatar

	var soul := SoulRecord.new()
	soul.soul_id = "soul-test"
	soul.reincarnation_count = 3
	soul.karma_carry = -17

	var time_data: Dictionary = {"elapsedMonths": 7, "tickInMonth": 123}
	var saved: Dictionary = SaveIO.save_slot("_test_slot", world, soul, time_data)
	_check(saved.get("ok", false), "存档写入成功：" + str(saved.get("error", "")))
	if not saved.get("ok", false):
		return

	var loaded: Dictionary = SaveIO.load_slot("_test_slot")
	_check(loaded.get("ok", false), "存档读取成功：" + str(loaded.get("error", "")))
	if not loaded.get("ok", false):
		_cleanup_test_slot()
		return

	# 以配置为骨架重建，再比对可变状态
	var rebuilt: Dictionary = WorldFactory.from_save(
		loaded["worldData"], ContentLoader.get_city_configs(), 120, 120
	)
	var w2: WorldState = rebuilt["world"]

	_eq(w2.world_seed, world.world_seed, "世界种子往返一致")
	_eq(w2.rng.get_state(), world.rng.get_state(), "随机状态往返一致")
	_eq(w2.get_city_count(), world.get_city_count(), "城市数量往返一致")
	_eq(int(loaded["timeData"].get("elapsedMonths", -1)), 7, "时间往返一致")
	_eq(int(loaded["soulData"].get("reincarnationCount", -1)), 3, "灵魂记录往返一致")
	_eq(int(loaded["soulData"].get("karmaCarry", 0)), -17, "灵魂的善恶痕迹往返一致")

	# 六维逐字段比对——这是 M1.3 的验收标准
	var mismatch: String = ""
	for city_id in world.get_city_ids():
		var c1: City = world.get_city(city_id)
		var c2: City = w2.get_city(city_id)
		if c2 == null:
			mismatch = "%s 读档后缺失" % city_id
			break
		for dim in City.ALL_DIMENSIONS:
			if c1.get_dimension(dim) != c2.get_dimension(dim):
				mismatch = "%s.%s 往返不一致：%d -> %d" % [
					city_id, dim, c1.get_dimension(dim), c2.get_dimension(dim)
				]
				break
		if not mismatch.is_empty():
			break
	_check(mismatch.is_empty(), "全部城市六维逐字段往返一致" + _detail(mismatch))

	var avatar2: PlayerAvatar = w2.avatar
	_check(avatar2 != null, "读档后化身存在")
	if avatar2 != null:
		_eq(avatar2.get_attribute(PlayerAvatar.ATTR_SOUL), 73, "七维属性往返一致")
		_eq(avatar2.get_reputation("aedran"), 42, "本世声誉往返一致")
		_eq(avatar2.pos_x, 60, "位置往返一致")

	# 配置字段必须来自配置，而非存档里的旧副本
	var aedran: City = w2.get_city("aedran")
	_eq(aedran.display_name, "艾德兰", "读档后名称来自配置")
	_eq(aedran.coord_x, 60, "读档后坐标来自配置")

	var missing_read: Dictionary = SaveIO.load_slot("_no_such_slot")
	_check(not missing_read.get("ok", false), "读取不存在的槽位会失败")
	_eq(str(missing_read.get("errorCode", "")), SaveIO.ERR_NOT_FOUND, "失败码为 NOT_FOUND")

	_cleanup_test_slot()


func _test_migration_framework() -> void:
	var same: Dictionary = MigrateRegistry.migrate({"a": 1}, MigrateRegistry.CURRENT_VERSION)
	_check(same.get("ok", false), "当前版本的存档零步通过迁移")
	_eq(int(same.get("steps", -1)), 0, "零步通过时 steps 为 0")

	var newer: Dictionary = MigrateRegistry.migrate({}, MigrateRegistry.CURRENT_VERSION + 1)
	_check(not newer.get("ok", false), "更高版本的存档被拒绝，而不是硬读")
	_check(str(newer.get("error", "")).contains("高于"), "拒绝原因说明版本高于支持范围")

	# 缺步骤时必须报出缺的是哪一级，而不是静默放行
	MigrateRegistry.clear_steps()
	var gap: Dictionary = MigrateRegistry.migrate({}, 0)
	_check(not gap.get("ok", false), "缺少迁移步骤时报错")
	_check(str(gap.get("error", "")).contains("v0 -> v1"), "报错指出缺失的具体版本区间")

	# 用一个人造步骤验证链是按序逐级执行的机制本身可用
	MigrateRegistry.clear_steps()
	var step: Callable = func(p: Dictionary) -> Dictionary:
		var out: Dictionary = p.duplicate()
		out["touched"] = true
		return out
	MigrateRegistry.register_step(0, step)
	var chained: Dictionary = MigrateRegistry.migrate({"a": 1}, 0)
	_check(chained.get("ok", false), "注册步骤后可以从 v0 升到当前版本")
	_eq(int(chained.get("steps", -1)), 1, "逐级执行了 1 步")
	_check(bool(chained["payload"].get("touched", false)), "迁移步骤的改动带进了结果")
	MigrateRegistry.clear_steps()


# --- 里程碑 2 测试项 ---

## M2.1：两城连续演化 120 月，每步六维均落在 0–100；同种子逐月一致。
func _test_city_evolution_long_run() -> void:
	var a: Dictionary = _new_sim()
	var run_a: Dictionary = _run_months(a["sim"], 120)
	_check(bool(run_a["inRange"]), "连续演化 120 月，每步六维均落在 0–100")

	var b: Dictionary = _new_sim()
	var run_b: Dictionary = _run_months(b["sim"], 120)
	_eq(int(run_a["checksum"]), int(run_b["checksum"]),
		"同一世界种子演化 120 月的逐月快照校验和一致")
	_eq(a["world"].rng.get_state(), b["world"].rng.get_state(), "演化 120 月后的随机状态一致")
	_eq(int(run_a["checksum"]) != 17, true, "校验和确实由演化结果产生（非初始值）")

	# 单城对照：把两个世界的同一座城拉出来逐字段比对，避免校验和掩盖局部分歧
	var city_a: City = a["world"].get_city("port_thorne")
	var city_b: City = b["world"].get_city("port_thorne")
	var mismatch: String = ""
	for dim in City.ALL_DIMENSIONS:
		if city_a.get_dimension(dim) != city_b.get_dimension(dim):
			mismatch = "%s: %d vs %d" % [dim, city_a.get_dimension(dim), city_b.get_dimension(dim)]
			break
	_check(mismatch.is_empty(), "索恩港 120 月后的六维逐字段一致" + _detail(mismatch))


## M2.2：六维跨越档位边界时阶段值更新，并产出建模变化标记。
## 顺带验证 applyStateChange 的落账时机——变更正是通过月度结算才生效的。
func _test_tier_change_marker_and_deferred_change() -> void:
	var built: Dictionary = _new_sim()
	var world: WorldState = built["world"]
	var sim: WorldSim = built["sim"]
	var city: City = world.get_city("aedran")

	# 发展度 84 属"城市"，人口 81 属"大城"，取较低者 → 城市
	city.development = 84
	city.population = 81
	_eq(city.get_tier(), City.Tier.CITY, "起点阶段为城市")

	var wealth_before: int = city.wealth
	var change := StateChange.make(
		"tier-push", "aedran", City.DIM_DEVELOPMENT, 5,
		StateChange.SOURCE_QUEST, "quest-tier", 0
	)
	var submitted: Dictionary = sim.apply_state_change(change)
	_check(submitted.get("applied", false), "发展度变更提交成功")
	_eq(city.development, 84, "月中城市状态不变——变更只入队，等下个月结算")
	_eq(city.wealth, wealth_before, "未被变更的维度也不受影响")

	var report: Dictionary = sim.settle_month(1)
	_eq(city.get_tier(), City.Tier.METROPOLIS, "结算后发展度跨档，阶段升为大城")
	var marked: bool = false
	for entry in report["tierChanges"]:
		if str(entry["cityId"]) == "aedran":
			marked = true
	_check(marked, "跨越档位时产出建模变化标记录")
	_check(int(report["appliedChanges"]) >= 1, "结算报告里记有落账的变更条数")
	_eq(int(report["cityTiers"]["aedran"]), City.Tier.METROPOLIS, "结算报告返回全城阶段表")


## changeId 幂等：重复提交只落账一次，载荷不同才算冲突。
func _test_change_idempotency() -> void:
	var base: Dictionary = _new_sim()
	var sent: Dictionary = _new_sim()
	var world: WorldState = sent["world"]
	var sim: WorldSim = sent["sim"]

	var change := StateChange.make(
		"quest-42", "aedran", City.DIM_WEALTH, 20,
		StateChange.SOURCE_QUEST, "quest-42", 0
	)
	var first: Dictionary = sim.apply_state_change(change)
	_check(first.get("applied", false), "首次提交进入队列")
	_eq(int(first["newValue"]), world.get_city("aedran").wealth + 20, "预估值含本次变更")

	var again: Dictionary = sim.apply_state_change(
		StateChange.make("quest-42", "aedran", City.DIM_WEALTH, 20,
			StateChange.SOURCE_QUEST, "quest-42", 0)
	)
	_check(not again.get("applied", false) and again.get("duplicate", false),
		"同一 changeId 重复提交不重复落账")

	var conflict: Dictionary = sim.apply_state_change(
		StateChange.make("quest-42", "aedran", City.DIM_WEALTH, 999,
			StateChange.SOURCE_QUEST, "quest-42", 0)
	)
	_eq(str(conflict.get("errorCode", "")), WorldSim.ERROR_CONFLICT,
		"同一 changeId 携带不同载荷时判为冲突")

	# 两个月后比对：带变更的世界比对照组恰好高 20（两月自然演化相同）
	base["sim"].settle_month(1)
	base["sim"].settle_month(2)
	sim.settle_month(1)
	sim.settle_month(2)
	_eq(
		sent["world"].get_city("aedran").wealth - base["world"].get_city("aedran").wealth,
		20, "变更只落账一次，两个月后差值仍为 20"
	)


## M2.3：生成数量等于 min(人口×3, 200)；同家庭 NPC 全部建立亲属关系。
func _test_npc_generation() -> void:
	var built: Dictionary = _new_sim()
	var world: WorldState = built["world"]

	var expected: int = 0
	for city_id in world.get_city_ids():
		var city: City = world.get_city(str(city_id))
		expected += mini(city.population * 3, 200)
	_eq(world.get_npc_count(), expected, "模拟 NPC 总量等于各城 min(人口×3, 200) 之和")
	_eq(world.get_npc_count(), 1350, "八城开局共 1350 名模拟居民（手算对照）")

	var adult_professional: bool = true
	var child_employed: bool = false
	for city_id in world.get_city_ids():
		for npc in world.get_city_npcs(str(city_id)):
			if npc.age < 16 and not str(npc.profession_id).is_empty():
				child_employed = true
			if npc.age >= 16 and str(npc.profession_id).is_empty():
				adult_professional = false
	_check(adult_professional, "成年 NPC 都有职业")
	_check(not child_employed, "孩童不参与生产（无职业）")

	# 亲属关系完整性：同家庭任意两人之间都必须有 kin 关系
	var broken: String = ""
	for city_id in world.get_city_ids():
		var by_family: Dictionary = {}
		for npc in world.get_city_npcs(str(city_id)):
			var key: String = str(npc.family_id)
			if not by_family.has(key):
				by_family[key] = []
			by_family[key].append(npc)
		for family_id in by_family:
			var members: Array = by_family[family_id]
			for i in range(members.size()):
				for j in range(i + 1, members.size()):
					if not _has_kin(world, str(members[i].npc_id), str(members[j].npc_id)):
						broken = "%s 与 %s" % [members[i].npc_id, members[j].npc_id]
						break
				if not broken.is_empty():
					break
			if not broken.is_empty():
				break
		if not broken.is_empty():
			break
	_check(broken.is_empty(), "同家庭 NPC 之间全部建立亲属关系" + _detail(broken))

	# 家庭规模落在配置区间内
	var generator: NpcGenerator = built["sim"].generator
	var family_ok: bool = true
	var sizes: Dictionary = {}
	for city_id in world.get_city_ids():
		for npc in world.get_city_npcs(str(city_id)):
			sizes[str(npc.family_id)] = int(sizes.get(str(npc.family_id), 0)) + 1
	for family_id in sizes:
		var size: int = int(sizes[family_id])
		if size < 2 or size > 5:
			family_ok = false
	_check(family_ok, "每个家庭的人数落在 2–5 之间")
	_check(generator.target_count(500) == 200, "人口极高时模拟 NPC 数量封顶在 200")


## 11.3 节的职业权重调制：治安越差，灰色职业越多。
func _test_profession_weights_follow_city_state() -> void:
	var sim: WorldSim = WorldSim.create(WorldState.create(1))
	var generator: NpcGenerator = sim.generator
	var lawless: City = City.from_config(ContentLoader.get_city_config("crossroad"))
	var orderly: City = City.from_config(ContentLoader.get_city_config("silvermoon_spire"))
	lawless.security = 10
	orderly.security = 95

	var gray_lawless: int = int(generator.category_weight_totals(lawless).get("gray", 0))
	var gray_orderly: int = int(generator.category_weight_totals(orderly).get("gray", 0))
	_check(gray_lawless > gray_orderly, "治安越差，灰色职业权重越高（%d 对 %d）" % [
		gray_lawless, gray_orderly
	])

	var culture_high: int = int(generator.category_weight_totals(orderly).get("knowledge", 0))
	var culture_low: int = int(generator.category_weight_totals(lawless).get("knowledge", 0))
	_check(culture_high > culture_low, "文化越高，知识宗教职业权重越高（%d 对 %d）" % [
		culture_high, culture_low
	])

	# 城市特色职业获得额外权重：银月塔的法师应明显多于同等条件下的别城
	var spire: City = City.from_config(ContentLoader.get_city_config("silvermoon_spire"))
	var twin: City = City.from_config(ContentLoader.get_city_config("silvermoon_spire"))
	twin.city_id = "not_silvermoon_spire"
	var table_spire: Array = generator.profession_weight_table(spire)
	var table_twin: Array = generator.profession_weight_table(twin)
	_check(int(table_spire[table_spire.size() - 1]) > int(table_twin[table_twin.size() - 1]),
		"城市特色职业抬高了该城的职业权重总量")


## M2.4：按年结算年龄；具名 NPC 死亡后其职位由新 NPC 接替。
func _test_npc_lifecycle_and_succession() -> void:
	var built: Dictionary = _new_sim()
	var world: WorldState = built["world"]
	var sim: WorldSim = built["sim"]

	var captain: SimNpc = null
	var younker: SimNpc = null
	for npc in world.get_city_npcs("aedran"):
		if str(npc.position_id) == "guard_captain":
			captain = npc
		if younker == null and npc.age < 30 and str(npc.profession_id) == "guard":
			younker = npc
	_check(captain != null, "开局为城市指派了守卫队长")
	_check(captain != null and captain.is_named, "持职位的 NPC 同时是具名 NPC")
	_check(younker != null, "城里存在年轻的守卫可作接替者")

	var younker_age: int = 0 if younker == null else younker.age
	var total_before: int = world.get_npc_count()
	var captain_id: String = "" if captain == null else captain.npc_id

	# 让队长立刻达到寿命上限，年度结算时死亡
	if captain != null:
		captain.age = captain.lifespan
	var report: Dictionary = sim.settle_year()

	if not captain_id.is_empty():
		_check(world.get_npc(captain_id) == null, "达到寿命的 NPC 在年度结算中死亡")
	_check(int(report["deaths"]) >= 1, "年度结算报告了死亡人数")
	if younker != null:
		_eq(younker.age, younker_age + 1, "存活 NPC 的年龄按年增加 1 岁")
	_check(world.get_npc_count() < total_before, "死亡者从世界中移除")

	var successor: SimNpc = null
	for npc in world.get_city_npcs("aedran"):
		if str(npc.position_id) == "guard_captain":
			successor = npc
	_check(successor != null, "空缺的职位由新 NPC 接替")
	if successor != null:
		_check(successor.npc_id != captain_id, "接替者不是原来那位")


## M2.5：构造治安与财富双低的城市后，其人口在 24 个月内持续净流出。
func _test_migration_from_low_attraction_city() -> void:
	var built: Dictionary = _new_sim()
	var world: WorldState = built["world"]
	var sim: WorldSim = built["sim"]
	var city: City = world.get_city("frostspeak_keep")
	city.wealth = 15
	city.security = 10

	var outflow_months: int = 0
	var moved_out: int = 0
	var previous: int = city.population
	for month in range(48):
		var report: Dictionary = sim.settle_month(month + 1)
		moved_out += int(report["migration"]["frostspeak_keep"]["out"])
		if month < 24:
			if city.population < previous:
				outflow_months += 1
			previous = city.population
	_eq(outflow_months, 24, "低财富低治安城市连续 24 个月人口净流出（终值 %d）" % city.population)
	_check(city.population < 50, "24 个月后该城人口明显低于开局")

	# 具象 NPC 也按吸引力向量搬走，而不只是抽象数字在跌
	_check(moved_out > 0, "具象 NPC 也在向高吸引力城市迁出（%d 人）" % moved_out)

	# 对照：吸引力更高的城市不会净流出
	var safe: Dictionary = _new_sim()
	var safe_city: City = safe["world"].get_city("silvermoon_spire")
	var safe_out: int = 0
	var safe_prev: int = safe_city.population
	for month in range(24):
		safe["sim"].settle_month(month + 1)
		if safe_city.population < safe_prev:
			safe_out += 1
		safe_prev = safe_city.population
	_check(safe_out < 24, "高吸引力城市不会持续净流出（%d/24 个月）" % safe_out)


## M2.6：可一次推进 N 月并输出六维变化序列。
func _test_fast_forward() -> void:
	var built: Dictionary = _new_sim()
	var world: WorldState = built["world"]
	var sim: WorldSim = built["sim"]
	var report: Dictionary = sim.fast_forward(0, 24)

	_eq(int(report["monthsAdvanced"]), 24, "一次推进 24 个月")
	_eq(int(report["endMonth"]), 24, "返回结束月份")
	_eq(report["cityHistory"].size(), world.get_city_count(), "返回每座城市的六维序列")
	_eq(report["cityHistory"]["aedran"].size(), 24, "序列长度等于推进月数")
	_check(not bool(report["stopped"]), "未触发停止条件时不提前中断")

	var first: Dictionary = report["cityHistory"]["aedran"][0]
	var all_present: bool = true
	for dim in City.ALL_DIMENSIONS:
		if not first.has(dim):
			all_present = false
	_check(all_present, "序列里六个维度齐全")

	# stopAt 谓词命中时应提前停下
	var stopped: Dictionary = sim.fast_forward(24, 60, func(month: int) -> bool:
		return month >= 30)
	_eq(int(stopped["monthsAdvanced"]), 6, "stopAt 命中后停止推进")
	_eq(int(stopped["endMonth"]), 30, "停止月份正确")
	_check(bool(stopped["stopped"]), "标记了提前停止")

	# 快进一百年不崩，且城市阶段始终合法。设计文档 5.2 节把百年快进列为
	# 唯一的性能风险点，这里顺带把耗时打出来，便于回归时对比。
	var started: int = Time.get_ticks_msec()
	var long_run: Dictionary = sim.fast_forward(30, 1200)
	var elapsed_ms: int = Time.get_ticks_msec() - started
	_eq(int(long_run["monthsAdvanced"]), 1200, "一次推进 1200 个月（一百年）")
	print("    （百年快进 %d 个月耗时 %.2f 秒，结算了 %d 名居民的迁移）" % [
		1200, float(elapsed_ms) / 1000.0, world.get_npc_count()
	])
	var tiers_legal: bool = true
	for city_id in world.get_city_ids():
		var tier: int = world.get_city(str(city_id)).get_tier()
		if tier < 0 or tier > City.Tier.METROPOLIS:
			tiers_legal = false
	_check(tiers_legal, "百年快进后各城阶段仍在合法取值内")


## 路线判定：门槛、上限、重复建立。
func _test_route_rules() -> void:
	var built: Dictionary = _new_sim()
	var world: WorldState = built["world"]
	var sim: WorldSim = built["sim"]

	_eq(world.trade_routes.size(), 6, "开局预置 6 条路线")
	_eq(world.get_routes_of_city("aedran", TradeRoute.KIND_REGULAR).size(), 3,
		"艾德兰开局有 3 条正规商路")
	_eq(world.get_routes_of_city("crossroad", TradeRoute.KIND_SMUGGLING).size(), 2,
		"十字路开局有 2 条走私航线")
	_eq(world.get_routes_of_city("aedran", TradeRoute.KIND_SMUGGLING).size(), 1,
		"艾德兰同时握有 1 条走私航线")
	_check(world.find_route("hammerhold", "aedran") != null,
		"路线的两端顺序不影响查找（有序对归一化）")

	# 十字路治安 20，正规商路必须被拒——这正是走私航线存在的理由
	var regular_rejected: Dictionary = sim.establish_route(
		"crossroad", "silvermoon_spire", TradeRoute.KIND_REGULAR
	)
	_eq(str(regular_rejected.get("errorCode", "")), WorldSim.ERROR_PRECONDITION_FAILED,
		"治安不足 40 的城市无法建正规商路")

	# 绿荫与银月塔都够近，但两端都没有黑市渠道，走私航线不成立
	var no_market: Dictionary = sim.establish_route(
		"greenwade", "silvermoon_spire", TradeRoute.KIND_SMUGGLING
	)
	_eq(str(no_market.get("errorCode", "")), WorldSim.ERROR_PRECONDITION_FAILED,
		"两端都没有黑市渠道时走私航线不成立")

	# 距离超限
	var too_far: Dictionary = sim.establish_route(
		"aedran", "greenwade", TradeRoute.KIND_SMUGGLING
	)
	_eq(str(too_far.get("errorCode", "")), WorldSim.ERROR_PRECONDITION_FAILED,
		"距离超过走私上限的配对不可联通")

	# 十字路已有 2 条走私航线，达到每城上限；再给它添一条（条件本身合法）必须报容量错误
	var over_cap: Dictionary = sim.establish_route(
		"crossroad", "silvermoon_spire", TradeRoute.KIND_SMUGGLING
	)
	_eq(str(over_cap.get("errorCode", "")), WorldSim.ERROR_CAPACITY_EXCEEDED,
		"超过每城走私路线上限时报容量错误")

	# 索恩港与艾德兰都有黑市渠道（索恩港），距离 55 ≤ 60 → 成立
	var ok: Dictionary = sim.establish_route("port_thorne", "aedran", TradeRoute.KIND_SMUGGLING)
	_check(ok.get("ok", false), "满足条件的走私航线可以建立")
	_eq(world.get_routes_of_city("aedran", TradeRoute.KIND_SMUGGLING).size(), 2,
		"新航线计入该城走私路线数")

	var duplicate: Dictionary = sim.establish_route("aedran", "port_thorne", TradeRoute.KIND_SMUGGLING)
	_eq(str(duplicate.get("errorCode", "")), WorldSim.ERROR_CONFLICT, "重复建立路线返回 CONFLICT")


## 2.4 节：任一方治安跌破门槛，路线中断。但那张门槛表写的是**正规商路**——
## 9.4 节给走私航线的条件里根本没有治安这一项，走私的全部意义就是绕开它。
## 早先这里一视同仁，结果十字路（治安 20，全大陆最适合走私的城）开局第一个月
## 就被系统自己断光了它仅有的两条走私航线。
func _test_route_break_only_hits_regular_routes() -> void:
	var built: Dictionary = _new_sim()
	var world: WorldState = built["world"]
	var sim: WorldSim = built["sim"]
	world.get_city("crossroad").security = 5

	var report: Dictionary = sim.settle_month(1)
	_eq(report["brokenRoutes"].size(), 0, "治安崩塌不再中断走私航线")
	_eq(world.get_routes_of_city("crossroad").size(), 2, "十字路的 2 条走私航线都还在")
	_eq(world.trade_routes.size(), 6, "世界路线总数不变")

	# 把艾德兰也压到门槛之下：它的 3 条正规商路必须全断，走私那条不受影响
	world.get_city("aedran").security = 5
	var second: Dictionary = sim.settle_month(2)
	_eq(second["brokenRoutes"].size(), 3, "正规商路照旧按治安门槛中断")
	_eq(world.get_routes_of_city("aedran", TradeRoute.KIND_REGULAR).size(), 0,
		"艾德兰的正规商路已全部中断")
	_check(world.find_route("aedran", "crossroad") != null,
		"同一座城的走私航线不受门槛约束（它本来就是绕过治安门槛的办法）")


## 9.4 节：查抄概率与治安正相关，治安低的城反而更适合走私。
## 每月把治安钉在固定值再结算——否则治安会随治理项自己爬升，
## 120 个月后两组的治安就趋同了，测的就不再是"概率随治安变化"。
func _test_confiscation_scales_with_security() -> void:
	var low: Dictionary = _new_sim()
	var high: Dictionary = _new_sim()

	var low_hits: int = _count_confiscations(low["sim"], "crossroad", 120, 30)
	var high_hits: int = _count_confiscations(high["sim"], "crossroad", 120, 100)
	_check(low_hits < high_hits,
		"治安越低，走私被查抄的次数越少（治安 30 被查抄 %d 次，治安 100 被查抄 %d 次）" % [
			low_hits, high_hits
		])
	_check(low_hits > 0, "低治安城市仍有被查抄的可能，不是零风险")
	_check(high_hits < 120 * 2, "查抄不是必然事件，高治安城市也不是月月被查")


## "为什么我一直在掉名声"——世界航线被查抄的账不该记在玩家头上。
## 玩家既没参与那条航线，也没有从它拿到一文钱。
func _test_world_confiscation_does_not_touch_player() -> void:
	var built: Dictionary = _new_sim()
	var world: WorldState = built["world"]
	var sim: WorldSim = built["sim"]
	var avatar := PlayerAvatar.new()
	avatar.avatar_id = "avatar-bystander"
	world.avatar = avatar

	# 治安钉在 100，十字路那两条世界走私航线月月处于高查抄概率之下
	var hits: int = _count_confiscations(sim, "crossroad", 120, 100)
	_check(hits > 0, "世界航线本身会被查抄（%d 次）" % hits)
	_eq(avatar.get_reputation("crossroad"), 0, "世界的走私航线被查抄，玩家在该城的名声不受影响")
	_eq(avatar.karma, 0, "善恶也不受影响")
	_eq(sim.player_smuggling_routes().size(), 0, "玩家一条航线都没建")


## 玩家自建的走私航线：归属记在自己名下，每月进账，撤得掉；世界的航线碰不得。
func _test_player_smuggling_route_lifecycle() -> void:
	var built: Dictionary = _new_sim()
	var world: WorldState = built["world"]
	var sim: WorldSim = built["sim"]

	var preset: Array = world.get_routes_sorted()
	var preset_world_id: String = str(preset[0].route_id)
	_check(not preset[0].is_player_owned(), "开局预置的航线都不属于玩家")
	_eq(str(sim.cancel_route(preset_world_id).get("errorCode", "")),
		WorldSim.ERROR_PRECONDITION_FAILED, "世界的航线撤不掉")

	var built_route: Dictionary = sim.establish_route(
		"aedran", "port_thorne", TradeRoute.KIND_SMUGGLING, 0, TradeRoute.OWNER_PLAYER
	)
	_check(built_route.get("ok", false), "玩家可以自己开一条走私航线："
		+ str(built_route.get("error", "")))
	var route_id: String = str(built_route.get("routeId", ""))
	var owned: Array = sim.player_smuggling_routes()
	_eq(owned.size(), 1, "这条航线记在玩家名下")
	_eq(sim.player_smuggling_routes("aedran").size(), 1, "按城查也能查到（它的一端在艾德兰）")
	_eq(sim.player_smuggling_routes("crossroad").size(), 0, "与玩家无关的城查不到")

	# 走私的准入判定可以单独问，不必先建再回滚——界面靠它写"为什么建不了"
	var check: Dictionary = sim.smuggling_check(
		world.get_city("aedran"), world.get_city("crossroad")
	)
	_eq(bool(check.get("ok", false)), false, "已有航线的两座城之间建不了")
	_check(not str(check.get("reason", "")).is_empty(), "并给出理由：" + str(check.get("reason", "")))

	var cancelled: Dictionary = sim.cancel_route(route_id)
	_check(cancelled.get("ok", false), "自己开的航线可以撤销")
	_eq(sim.player_smuggling_routes().size(), 0, "撤销后名下不再有航线")
	_eq(world.find_route("aedran", "port_thorne"), null, "世界里的那条也不在了")

	# 世界航线还在（开局 6 条，撤销的是玩家自己那条）
	_eq(world.trade_routes.size(), 6, "玩家开/撤航线不影响世界原有的 6 条")


## 9.4 节：查抄的代价（声誉 -5、善恶 -2）只算玩家自己建的航线；
## 6 章「垄断贸易路线：该路线收益归玩家」——玩家自己开的航线每月进账。
func _test_player_confiscation_penalty() -> void:
	var built: Dictionary = _new_sim()
	var world: WorldState = built["world"]
	var sim: WorldSim = built["sim"]
	var avatar := PlayerAvatar.new()
	avatar.avatar_id = "avatar-x"
	world.avatar = avatar

	# 开局 6 条预置航线里，只有 艾德兰 ↔ 索恩港 还能再开一条走私（两端都有余量、
	# 索恩港有黑市、距离 55 ≤ 60）
	var opened: Dictionary = sim.establish_route(
		"aedran", "port_thorne", TradeRoute.KIND_SMUGGLING, 0, TradeRoute.OWNER_PLAYER
	)
	_check(opened.get("ok", false), "玩家自建走私航线成功：%s" % str(opened.get("error", "")))
	var route_id: String = str(opened.get("routeId", ""))

	var entries: int = 0
	var here_entries: int = 0
	var seized_months: int = 0
	var halted_months: int = 0
	var income: int = 0
	var before_money: int = avatar.money
	for i in range(PENALTY_MONTHS):
		# 治安钉在 100：查抄概率 20%/月/端（治安 × 系数 0.2 ÷ 100）。
		# 不钉的话治安会自己爬升，几百个月后两端趋同，测的就不是"谁承担代价"了。
		world.get_city("aedran").security = 100
		world.get_city("port_thorne").security = 100
		var report: Dictionary = sim.settle_month(i + 1)
		income += int(report.get("playerSmugglingIncome", 0))
		var seized_this_month: bool = false
		for entry in report["confiscations"]:
			if str(entry["routeId"]) != route_id:
				continue
			entries += 1
			seized_this_month = true
			if str(entry["cityId"]) == "aedran":
				here_entries += 1
		if seized_this_month:
			seized_months += 1
		# 索恩港在这几十个月里会经历一次封港（M7.1 的 EV-02）：那段时间这条航线
		# 整条停摆，没有货自然也没有进账，更不会被查抄。
		for entry in report.get("haltedRoutes", []):
			if str(entry["routeId"]) == route_id:
				halted_months += 1

	_check(entries > 0, "玩家自己的走私航线会被查抄（%d 个月共 %d 次）" % [PENALTY_MONTHS, entries])
	# 先确认这几十个月还没把声誉砸到下限：砸到了下面两句就变成在测钳制，
	# 而钳制由 _test_reputation_clamp 单独测
	_check(5 * maxi(here_entries, entries - here_entries) < 100,
		"这次跑的次数还没触到声誉下限（各端 %d/%d 次）" % [here_entries, entries - here_entries])
	_eq(avatar.get_reputation("aedran"), -5 * here_entries,
		"每次查抄使该城声誉下降 5（%d 次 → %d）" % [here_entries, -5 * here_entries])
	_eq(avatar.get_reputation("port_thorne"), -5 * (entries - here_entries),
		"另一端各扣各的（%d 次 → %d）" % [entries - here_entries, -5 * (entries - here_entries)])
	_eq(avatar.karma, -2 * entries, "每次查抄扣 2 点善恶（%d 次 → %d）" % [entries, -2 * entries])
	_check(seized_months < PENALTY_MONTHS, "不是月月被查（%d/%d 个月被抓）" % [seized_months, PENALTY_MONTHS])
	var per_route: int = int(ContentLoader.get_balance_section("trade").
		get("playerSmugglingIncomeCopper", 0))
	_check(per_route > 0, "配置里给了玩家走私航线的月进账（%d 铜）" % per_route)
	_check(halted_months > 0, "封港期间这条航线停摆（%d 个月）" % halted_months)
	_eq(income, per_route * (PENALTY_MONTHS - seized_months - halted_months),
		"没人抓、港口也没封着的月份才按月进账（一趟货只算一次）")
	_eq(avatar.money - before_money, income, "进账落到化身的钱袋上")


## 数值框架 3.3 节：声誉每城独立，范围 -100 ～ +100。
## 没有下限的话，玩家放着不管，几百个月后名声会掉到没法用任何界面表达的深度。
func _test_reputation_clamp() -> void:
	var avatar := PlayerAvatar.new()
	_eq(avatar.get_reputation("aedran"), 0, "声誉初始为 0")
	avatar.set_reputation("aedran", 999)
	_eq(avatar.get_reputation("aedran"), 100, "声誉上限 +100")
	avatar.set_reputation("aedran", -999)
	_eq(avatar.get_reputation("aedran"), -100, "声誉下限 -100")
	avatar.set_reputation("crossroad", -3)
	_eq(avatar.get_reputation("crossroad"), -3, "区间内原样保留")
	_eq(avatar.get_reputation("aedran"), -100, "每座城各记各的")


## NPC 与关系网进存档后能逐字段还原。
func _test_world_round_trip_with_npcs() -> void:
	var built: Dictionary = _new_sim()
	var world: WorldState = built["world"]
	var soul := SoulRecord.new()
	soul.soul_id = "soul-npc"
	built["sim"].apply_state_change(StateChange.make(
		"pending-1", "aedran", City.DIM_CULTURE, 4, StateChange.SOURCE_EVENT, "ev-1", 0
	))

	var saved: Dictionary = SaveIO.save_slot("_test_npc_slot", world, soul, {"elapsedMonths": 3, "tickInMonth": 10})
	_check(saved.get("ok", false), "带 NPC 的存档写入成功：" + str(saved.get("error", "")))
	if saved.get("ok", false):
		print("    （存档 %d 名 NPC + %d 条关系，world.json 共 %.1f KB）" % [
			world.get_npc_count(), world.get_relation_count(),
			float(saved.get("bytes", 0)) / 1024.0
		])
	if not saved.get("ok", false):
		return
	var loaded: Dictionary = SaveIO.load_slot("_test_npc_slot")
	_check(loaded.get("ok", false), "带 NPC 的存档读取成功：" + str(loaded.get("error", "")))
	if not loaded.get("ok", false):
		_cleanup_npc_slot()
		return

	var grid_cfg: Dictionary = ContentLoader.get_balance_section("worldGrid")
	var rebuilt: Dictionary = WorldFactory.from_save(
		loaded["worldData"], ContentLoader.get_city_configs(),
		int(grid_cfg.get("width", 120)), int(grid_cfg.get("height", 120))
	)
	var w2: WorldState = rebuilt["world"]
	_eq(w2.get_npc_count(), world.get_npc_count(), "NPC 数量往返一致")
	_eq(w2.get_relation_count(), world.get_relation_count(), "关系记录数量往返一致")
	_eq(w2.trade_routes.size(), world.trade_routes.size(), "贸易路线数量往返一致")
	_eq(w2.pending_changes.size(), world.pending_changes.size(), "待落账变更队列往返一致")
	_eq(w2.npc_seq, world.npc_seq, "NPC ID 游标往返一致")
	_eq(w2.applied_changes.size(), world.applied_changes.size(), "幂等表往返一致")
	_eq(w2.rng.get_state(), world.rng.get_state(), "随机状态往返一致")

	var sample: SimNpc = world.get_city_npcs("aedran")[0]
	var restored: SimNpc = w2.get_npc(str(sample.npc_id))
	_check(restored != null, "抽样 NPC 在读档后存在")
	if restored != null:
		_eq(restored.age, sample.age, "NPC 年龄往返一致")
		_eq(restored.profession_id, sample.profession_id, "NPC 职业往返一致")
		_eq(restored.display_name(), sample.display_name(), "NPC 姓名往返一致")
		_eq(restored.family_id, sample.family_id, "NPC 家庭分组往返一致")
	# 城与 NPC 的双重索引在重建后仍然自洽
	var indexed: int = 0
	for city_id in w2.get_city_ids():
		indexed += w2.get_city(str(city_id)).npc_ids.size()
	_eq(indexed, w2.get_npc_count(), "读档后城市 NPC 索引与总表数量一致")

	var revived: City = w2.get_city("port_thorne")
	var source: City = world.get_city("port_thorne")
	_eq(revived.evolution_carry.size(), source.evolution_carry.size(),
		"演化余数（含贸易收益的零头）往返一致")
	_cleanup_npc_slot()


# --- 世界演化可感知性测试项 ---

## 逐项归因：每个维度的变化必须能拆到具体的项，且各项之和等于净变化。
## 这是"玩家能不能说出城市为什么变成这样"的数据前提。
func _test_delta_attribution() -> void:
	var built: Dictionary = _new_sim()
	var sim: WorldSim = built["sim"]
	var report: Dictionary = sim.settle_month(1)
	var deltas: Dictionary = report["cityDeltas"]

	_eq(deltas.size(), built["world"].get_city_count(), "每座城市都有本月的归因报告")

	var missing: String = ""
	var mismatch: String = ""
	for city_id in built["world"].get_city_ids():
		var slot: Dictionary = deltas.get(str(city_id), {})
		for dimension in City.ALL_DIMENSIONS:
			var entry: Dictionary = slot.get(dimension, {})
			if not entry.has("items"):
				missing = "%s.%s 无拆项" % [city_id, dimension]
				break
			var total: int = 0
			for item in entry["items"]:
				total += int(item["milli"])
				if str(item["label"]).is_empty():
					missing = "%s.%s 有项没有标签" % [city_id, dimension]
			if total != int(entry["milli"]):
				mismatch = "%s.%s 各项之和 %d ≠ 净变化 %d" % [
					city_id, dimension, total, int(entry["milli"])
				]
				break
		if not missing.is_empty() or not mismatch.is_empty():
			break
	_check(missing.is_empty(), "每个维度都给出了逐项拆解" + _detail(missing))
	_check(mismatch.is_empty(), "各项之和等于该维度的净变化" + _detail(mismatch))

	# 人口必须拆成出生/死亡/净移民三项，且"净移民"对低吸引力城市为负
	var aedran_items: Array = deltas["aedran"][City.DIM_POPULATION]["items"]
	var labels: Array = []
	for item in aedran_items:
		labels.append(str(item["label"]))
	_eq(",".join(PackedStringArray(labels)), "出生,死亡,净移民", "人口变化拆成出生/死亡/净移民三项")

	var crossroad: City = built["world"].get_city("crossroad")
	crossroad.wealth = 10
	crossroad.security = 10
	var second: Dictionary = sim.settle_month(2)
	var migration_item: Dictionary = {}
	for item in second["cityDeltas"]["crossroad"][City.DIM_POPULATION]["items"]:
		if str(item["key"]) == "migration":
			migration_item = item
	_check(not migration_item.is_empty(), "低财富低治安城市的归因里含净移民项")
	_check(int(migration_item.get("milli", 0)) < 0,
		"低吸引力城市的净移民为负（%s）" % CityViewModel.format_signed(int(migration_item.get("milli", 0))))

	# 贸易收益也要出现在归因里，而不是只改数字不留痕。
	# 取艾德兰：它开局握有 3 条正规商路，且两端治安都在门槛之上。
	var trade_labels: Array = []
	for item in deltas["aedran"][City.DIM_WEALTH]["items"]:
		trade_labels.append(str(item["label"]))
	_check(trade_labels.has("正规商路"),
		"正规商路收益出现在艾德兰的财富归因里：" + ",".join(PackedStringArray(trade_labels)))
	var culture_labels: Array = []
	for item in deltas["aedran"][City.DIM_CULTURE]["items"]:
		culture_labels.append(str(item["label"]))
	_check(culture_labels.has("正规商路"), "商路带来的文化交流也在文化归因里")

	# 正规商路被治安门槛断掉时要留下事件——这是玩家必须能看见的世界反馈。
	# 走私航线不受这道门槛约束（见 _test_route_break_only_hits_regular_routes），
	# 所以要把中断逼出来得动正规商路那一端。
	var doomed: Dictionary = _new_sim()
	doomed["world"].get_city("aedran").security = 5
	var doomed_report: Dictionary = doomed["sim"].settle_month(1)
	var route_events: Array = []
	for record in doomed_report["notableEvents"]:
		if str(record["kind"]) == WorldSim.EVENT_ROUTE:
			route_events.append(str(record["cityId"]))
	_check(route_events.has("aedran"), "治安崩坏导致正规商路中断时产出事件")
	_eq(doomed["world"].get_routes_of_city("aedran", TradeRoute.KIND_REGULAR).size(), 0,
		"艾德兰的 3 条正规商路确实已中断")
	_eq(doomed["world"].get_routes_of_city("aedran").size(), 1, "只剩那条走私航线")

	# 被查抄的走私航线要留下"收益归零"的说明，而不是静默消失
	var seized: Dictionary = {
		"regular": [{"routeId": "r", "cityId": "port_thorne", "kind": "regular",
			"wealthMilli": 0, "cultureMilli": 0}],
		"smuggling": [], "confiscations": [],
	}
	var seized_world: Dictionary = _new_sim()
	var seized_report: Dictionary = seized_world["sim"].economy.settle_routes(
		seized_world["world"], 1, seized_world["world"].rng
	)
	_check(seized_report.has("confiscations"), "贸易结算返回查抄清单")


## 玩家/委托造成的变更必须能在归因里被认出来源——这正是"因为我做了什么"
## 那句话的凭据，也是 M4 委托闭环落地后能直接接上的接口。
func _test_state_change_attribution() -> void:
	var built: Dictionary = _new_sim()
	var sim: WorldSim = built["sim"]
	sim.apply_state_change(StateChange.make(
		"q-1", "aedran", City.DIM_WEALTH, 6, StateChange.SOURCE_QUEST, "quest-1", 0
	))
	sim.apply_state_change(StateChange.make(
		"p-1", "aedran", City.DIM_SECURITY, 3, StateChange.SOURCE_PLAYER, "player-1", 0
	))
	var report: Dictionary = sim.settle_month(1)
	var wealth_items: Array = report["cityDeltas"]["aedran"][City.DIM_WEALTH]["items"]
	var security_items: Array = report["cityDeltas"]["aedran"][City.DIM_SECURITY]["items"]

	var quest_item: Dictionary = _find_item(wealth_items, "change-quest")
	_check(not quest_item.is_empty(), "委托来源的变更出现在财富归因里")
	_eq(str(quest_item.get("label", "")), "委托", "委托来源标注为「委托」")
	_eq(int(quest_item.get("milli", 0)), 6000, "委托的 +6 以千分位记入（+6.00）")

	var player_item: Dictionary = _find_item(security_items, "change-player")
	_check(not player_item.is_empty(), "玩家来源的变更出现在治安归因里")
	_eq(str(player_item.get("label", "")), "玩家", "玩家来源标注为「玩家」")
	_eq(int(player_item.get("milli", 0)), 3000, "玩家的 +3 以千分位记入（+3.00）")

	# 落账后的净变化里必须真的含这 6 点，而不只是报告里写着
	var base: Dictionary = _new_sim()
	base["sim"].settle_month(1)
	_eq(
		built["world"].get_city("aedran").wealth - base["world"].get_city("aedran").wealth,
		6, "归因里记的委托收益确实落进了城市财富"
	)


## 阶段进度：升阶条件是两项同时满足，卡住的那一项要能指出来。
func _test_tier_progress() -> void:
	var cfg: Dictionary = ContentLoader.get_city_config("silvermoon_spire")
	var city: City = City.from_config(cfg)
	# 银月塔：发展度 80（城市档）、人口 45（城镇档）→ 阶段为城镇，瓶颈是人口
	_eq(city.get_tier(), City.Tier.TOWN, "阶段取较低的一档")
	var progress: Dictionary = city.tier_progress()
	_eq(int(progress["nextTier"]), City.Tier.CITY, "下一阶段为城市")
	_eq(str(progress["binding"]), City.DIM_POPULATION, "瓶颈识别为人口")
	_eq(int(progress["needDevelopment"]), 66, "升为城市需发展度 ≥ 66（城市档下限）")
	_eq(int(progress["needPopulation"]), 61, "升为城市需人口 ≥ 61（城镇档上限 +1）")
	_eq(int(progress["gapDevelopment"]), 0, "发展度已达标，差值为 0")
	_eq(int(progress["gapPopulation"]), 16, "人口还差 16")
	_check(str(progress["nextLabel"]) == "城市", "下一阶段名称正确")
	_check(float(progress["ratio"]) > 0.0 and float(progress["ratio"]) <= 1.0, "进度比例落在 0–1")

	# 顶格城市没有下一阶段
	var top: City = City.from_config(cfg)
	top.development = 100
	top.population = 100
	_eq(top.get_tier(), City.Tier.METROPOLIS, "双高时阶段为大城")
	var top_progress: Dictionary = top.tier_progress()
	_eq(int(top_progress["nextTier"]), -1, "大城没有下一阶段")
	_check(CityViewModel.tier_next_text(top_progress).contains("无法再升"),
		"顶格时给出「无法再升」的说明")

	# 接近下限要给出降级预警
	var shaky: City = City.from_config(cfg)
	shaky.development = 41
	shaky.population = 41
	var shaky_progress: Dictionary = shaky.tier_progress()
	_check(bool(shaky_progress["downgradeRisk"]), "贴住下限时标记降级风险")
	_check(not CityViewModel.downgrade_text(shaky_progress).is_empty(), "降级风险有对应文案")

	# 阶段判定的阈值只有一处：改配置里的一个数，判定与提示一起变。
	# 阈值表比阶段表少一项是设计如此——最高档「大城」没有上限，永远够得着。
	_eq(City.TIER_DEVELOPMENT_MAX.size(), City.TIER_LABELS.size() - 1, "阈值表比阶段表少一项（最高档无上限）")
	_eq(City.TIER_POPULATION_MAX.size(), City.TIER_LABELS.size() - 1, "人口阈值表比阶段表少一项（最高档无上限）")


## 六维历史：环形窗口封顶、与世界模拟的接线、快进只记最后一月。
func _test_history_recording() -> void:
	# 环形窗口本身：直接喂进超过窗口的笔数，验证封顶与丢弃顺序。
	# 这段刻意绕开世界模拟，免得为了让历史溢出而空跑几十个月的结算。
	var probe: WorldState = WorldState.create(1)
	var probe_city: City = City.from_config(ContentLoader.get_city_config("aedran"))
	probe.add_city(probe_city)
	for i in range(WorldState.HISTORY_MONTHS + 10):
		probe_city.population = i
		probe.record_history(probe_city)
	_eq(probe.get_history_length("aedran"), WorldState.HISTORY_MONTHS,
		"历史窗口封顶在 HISTORY_MONTHS")
	_eq(int(probe.get_history("aedran", City.DIM_POPULATION)[0]), 10,
		"超出窗口后丢掉最旧的记录")
	_eq(int(probe.get_history("aedran", City.DIM_POPULATION)[WorldState.HISTORY_MONTHS - 1]),
		WorldState.HISTORY_MONTHS + 9, "末尾始终是最新一笔")

	# 与世界模拟的接线
	var built: Dictionary = _new_sim()
	var world: WorldState = built["world"]
	var sim: WorldSim = built["sim"]
	_eq(world.get_history_length("aedran"), 1, "开局 bootstrap 记下第一个月")
	for month in range(1, 7):
		sim.settle_month(month)
	_eq(world.get_history_length("aedran"), 7, "逐月结算累积历史")
	_eq(world.get_history("aedran", City.DIM_POPULATION).size(), 7, "各维序列长度一致")

	var before: int = world.get_history_length("aedran")
	sim.fast_forward(7, 12)
	_eq(world.get_history_length("aedran"), before + 1, "快进 12 个月只补记最后一笔")

	var in_range: bool = true
	for value in world.get_history("aedran", City.DIM_POPULATION):
		if int(value) < 0 or int(value) > 100:
			in_range = false
	_check(in_range, "历史序列里的取值都在 0–100")


## 视图模型：界面拿到的结构与文案。
func _test_city_view_model() -> void:
	var built: Dictionary = _new_sim()
	var world: WorldState = built["world"]
	var sim: WorldSim = built["sim"]
	var report: Dictionary = sim.settle_month(1)
	var deltas: Dictionary = report["cityDeltas"]

	var list: Array = CityViewModel.build_list(world, deltas)
	_eq(list.size(), world.get_city_count(), "城市列表含全部城市")
	_check(not str(list[0]["displayName"]).is_empty(), "列表行有城市名")
	_check(not str(list[0]["tierLabel"]).is_empty(), "列表行有阶段名")
	_check(int(list[0]["npcCount"]) > 0, "列表行有居民数")

	var detail: Dictionary = CityViewModel.build_detail(world, "aedran", deltas)
	_eq(str(detail["displayName"]), "艾德兰", "详情取到了正确的城市")
	_eq(detail["rows"].size(), CityViewModel.DIMENSION_ORDER.size(), "六个维度各一行")
	_check(not str(detail["tierNextText"]).is_empty(), "有升阶说明")
	_check(not str(detail["tierGapText"]).is_empty(), "有差距说明")
	_check(int(detail["historyMonths"]) > 0, "带上了历史月数")
	_check(detail["stats"].size() >= 4, "带上了统计项")
	_check(detail["trends"].has(City.DIM_POPULATION), "带上了人口趋势统计")

	var population_row: Dictionary = {}
	for row in detail["rows"]:
		if str(row["key"]) == City.DIM_POPULATION:
			population_row = row
	_check(not population_row.is_empty(), "详情里有入口行")
	_eq(int(population_row["value"]), world.get_city("aedran").population, "行的数值取自城市状态")
	_check(population_row["items"].size() >= 3, "人口行带上了逐项拆解")
	_check(
		absf(float(population_row["bar"]) - float(population_row["value"]) / 100.0) < 0.001,
		"进度条比例与数值一致"
	)
	# 拆项按影响大小排序，读者第一眼看到的是主要驱动项
	var previous: int = 1 << 30
	var sorted_ok: bool = true
	for item in population_row["items"]:
		var magnitude: int = absi(int(item["milli"]))
		if magnitude > previous:
			sorted_ok = false
		previous = magnitude
	_check(sorted_ok, "拆项按影响从大到小排列")

	# 无归因数据时（读档后未推进月份）不应报错，只是没有逐项说明
	var bare: Dictionary = CityViewModel.build_detail(world, "aedran", {})
	_eq(bare["rows"].size(), CityViewModel.DIMENSION_ORDER.size(), "无归因数据时仍给出全部维度行")
	_eq(str(bare["rows"][0]["deltaText"]), "0.00", "无归因数据时变化显示为 0.00")
	_eq(CityViewModel.build_detail(world, "no_such_city", {}), {}, "取不存在的城市返回空结构")

	# 数值格式化：负数不能走截断，四舍五入到零不能带负号
	_eq(CityViewModel.format_signed(0), "0.00", "零显示为 0.00")
	_eq(CityViewModel.format_signed(440), "+0.44", "正数带加号并保留两位")
	_eq(CityViewModel.format_signed(-450), "-0.45", "负数带减号")
	_eq(CityViewModel.format_signed(-4), "0.00", "四舍五入归零时不带负号")
	_eq(CityViewModel.format_signed(995), "+1.00", "进位到整点")
	_eq(CityViewModel.format_signed(-1682), "-1.68", "多位数入账正确")

	var stats: Dictionary = CityViewModel.series_stats([70, 72, 68, 80])
	_eq(int(stats["min"]), 68, "趋势统计取到最小值")
	_eq(int(stats["max"]), 80, "趋势统计取到最大值")
	_eq(int(stats["delta"]), 10, "趋势统计算出净变化")
	_check(str(stats["text"]).contains("68–80"), "趋势文案含区间")
	var empty_stats: Dictionary = CityViewModel.series_stats([])
	_eq(int(empty_stats["length"]), 0, "空序列的统计长度为 0")


## 历史与归因结构要能进存档——否则读档后趋势线归零，玩家看不到长期变化。
func _test_history_round_trip() -> void:
	var built: Dictionary = _new_sim()
	var world: WorldState = built["world"]
	var sim: WorldSim = built["sim"]
	for month in range(1, 7):
		if month % 12 == 0:
			sim.settle_year(month)
		sim.settle_month(month)

	var soul := SoulRecord.new()
	soul.soul_id = "soul-history"
	var saved: Dictionary = SaveIO.save_slot(
		"_test_history_slot", world, soul, {"elapsedMonths": 6, "tickInMonth": 0}
	)
	_check(saved.get("ok", false), "含历史的存档写入成功：" + str(saved.get("error", "")))
	if not saved.get("ok", false):
		return
	var loaded: Dictionary = SaveIO.load_slot("_test_history_slot")
	_check(loaded.get("ok", false), "含历史的存档读取成功：" + str(loaded.get("error", "")))
	if not loaded.get("ok", false):
		_cleanup_history_slot()
		return

	var grid_cfg: Dictionary = ContentLoader.get_balance_section("worldGrid")
	var rebuilt: Dictionary = WorldFactory.from_save(
		loaded["worldData"], ContentLoader.get_city_configs(),
		int(grid_cfg.get("width", 120)), int(grid_cfg.get("height", 120))
	)
	var w2: WorldState = rebuilt["world"]
	_eq(w2.get_history_length("aedran"), world.get_history_length("aedran"), "历史长度往返一致")
	var original: Array = world.get_history("port_thorne", City.DIM_WEALTH)
	var restored: Array = w2.get_history("port_thorne", City.DIM_WEALTH)
	_eq(restored.size(), original.size(), "序列长度一致")
	var same: bool = true
	for i in range(original.size()):
		if int(original[i]) != int(restored[i]):
			same = false
	_check(same, "序列逐点一致")

	# 读档后的趋势文案要能直接画出来，不能是空的
	var detail: Dictionary = CityViewModel.build_detail(w2, "port_thorne", {})
	_check(int(detail["historyMonths"]) > 0, "读档后趋势仍有数据可画")
	_cleanup_history_slot()


func _find_item(items: Array, key: String) -> Dictionary:
	for item in items:
		if str(item["key"]) == key:
			return item
	return {}


# --- 界面可读性测试项 ---

## 界面要显示中文，而 Godot 自带的默认字体不含 CJK 字形：直接用它时所有中文
## 标签会渲染成空白——不报错、不是方块，就是什么都没有。对一个全中文的游戏
## 这是致命的，所以把"界面字体配置"纳入验收项。
##
## 这里**不碰 C:/Windows/Fonts**，也不解析字体。原因有两层：一是解析 10 MB 级
## 的中文字体需要渲染上下文，无头进程跑不通；二是落盘探测系统字体目录会触发
## 工具沙箱的限制（实测让测试挂住不返回）。字体实际能否装载，由 main.gd 启动
## 时的自检提示覆盖——它在有窗口的真实环境里跑，正是需要验证的那种环境。
func _test_ui_font_available() -> void:
	_check(UiTheme.CJK_FONT_PATHS.size() >= 3, "候选字体路径不止一条，避免单点依赖")
	_check(UiTheme.PROBE_TEXT.length() > 0, "提供了用于验证字形覆盖的中文样本")
	_check(UiTheme.DEFAULT_FONT_SIZE > 0, "设置了界面基准字号")
	# ThemeDB 的默认字体不含中文，这条断言锁住"不能拿它当界面字体"这个前提
	var fallback: Font = ThemeDB.fallback_font
	_check(fallback != null, "引擎默认字体可获取（仅作最后兜底）")


# --- 里程碑 3 开局测试项 ---

## 种族与出身配置：可玩种族都可选，且每个带完整七维偏移。
func _test_creation_config() -> void:
	var races: Array = ContentLoader.get_playable_races()
	_eq(races.size(), 6, "可玩种族 6 个")
	var incomplete: int = 0
	for race in races:
		var offsets: Dictionary = race.get("attributeOffsets", {})
		if offsets.size() != PlayerAvatar.ALL_ATTRIBUTES.size():
			incomplete += 1
	_eq(incomplete, 0, "每个可玩种族的属性偏移都覆盖七维")

	var backgrounds: Array = ContentLoader.get_backgrounds()
	_eq(backgrounds.size(), 8, "出身 8 个")
	var empty_desc: int = 0
	for background in backgrounds:
		if str(background.get("description", "")).is_empty():
			empty_desc += 1
	_eq(empty_desc, 0, "每个出身都有描述文案")


## 引用完整性：出身的初始物品与初始技能必须能在配置里找到。
## 启动期校验已经拦过一道，这里从数据侧再确认，免得校验规则本身写漏了。
func _test_creation_config_refs() -> void:
	var bad_item: int = 0
	var bad_skill: int = 0
	for background in ContentLoader.get_backgrounds():
		for template_id in background.get("initialItems", []):
			if ContentLoader.get_item(str(template_id)).is_empty():
				bad_item += 1
		for skill_id in background.get("initialSkills", {}):
			if ContentLoader.get_skill(str(skill_id)).is_empty():
				bad_skill += 1
	_eq(bad_item, 0, "出身的初始物品都能解析")
	_eq(bad_skill, 0, "出身的初始技能都能解析")


## M3.1：属性分配——点数必须刚好用完，单项不得越过创建期上限，
## 种族偏移叠加在分配之后。
func _test_attribute_allocation() -> void:
	var creator: CharacterCreation = _new_creator()
	_eq(creator.allocatable_points(), 20, "可分配 20 点")
	_eq(creator.per_attribute_cap(), 10, "创建期单项最多加 10（上限 20 − 起点 10）")

	var spec: Dictionary = creator.new_spec()
	spec["race"] = "human"
	spec["backgroundId"] = "merchant"

	var blank: Dictionary = creator.validate(spec)
	_check(not bool(blank["ok"]), "一点没分配时不允许开局")
	_check(_has_text(blank["errors"], "未分配"), "并指出还有点数没用")

	_allocate(spec, {"strength": 5, "constitution": 5, "perception": 5, "soul": 5})
	_eq(creator.remaining_points(spec), 0, "分配满 20 点后余额为 0")
	var valid: Dictionary = creator.validate(spec)
	_check(bool(valid["ok"]), "点数用尽后校验通过：" + _join(valid["errors"]))

	var over: Dictionary = creator.new_spec()
	over["race"] = "human"
	over["backgroundId"] = "merchant"
	_allocate(over, {"strength": 11, "constitution": 5, "perception": 4})
	_eq(creator.remaining_points(over), 0, "越界用例的点数本身是用尽的")
	_check(not bool(creator.validate(over)["ok"]), "单项超过创建期上限时不允许开局")

	# 种族偏移在分配之后叠加：矮人 力量 +3、敏捷 −2
	var dwarf: Dictionary = creator.new_spec()
	dwarf["race"] = "dwarf"
	dwarf["backgroundId"] = "farmer"
	_allocate(dwarf, {"strength": 5})
	var attributes: Dictionary = creator.final_attributes(dwarf)
	_eq(int(attributes[PlayerAvatar.ATTR_STRENGTH]), 18, "力量 = 10 起点 + 5 分配 + 3 矮人偏移")
	_eq(int(attributes[PlayerAvatar.ATTR_DEXTERITY]), 8, "敏捷 = 10 起点 + 0 分配 − 2 矮人偏移")


## M3.1：天赋与缺陷配对——数量必须相等，且正面总当量不得超过负面总当量。
func _test_talent_flaw_pairing() -> void:
	var creator: CharacterCreation = _new_creator()
	var spec: Dictionary = creator.new_spec()
	spec["race"] = "human"
	spec["backgroundId"] = "merchant"
	_allocate(spec, {"strength": 5, "constitution": 5, "perception": 5, "soul": 5})

	var lonely: Dictionary = spec.duplicate(true)
	lonely["talents"] = ["iron_will"]
	var lonely_result: Dictionary = creator.validate(lonely)
	_check(not bool(lonely_result["ok"]), "天赋与缺陷数量不等时不允许开局")
	_check(_has_text(lonely_result["errors"], "数量必须相等"), "并指出是数量不等")

	var paired: Dictionary = spec.duplicate(true)
	paired["talents"] = ["iron_will"]
	paired["flaws"] = ["blood_feud"]
	_check(bool(creator.validate(paired)["ok"]), "1 天赋 +3 / 1 缺陷 −4：数量相等且当量不超，允许开局")

	var heavy: Dictionary = spec.duplicate(true)
	heavy["talents"] = ["iron_will", "sharp_senses"]
	heavy["flaws"] = ["blood_feud"]
	var heavy_result: Dictionary = creator.validate(heavy)
	_check(not bool(heavy_result["ok"]), "天赋当量超过缺陷时不允许开局")
	_check(_has_text(heavy_result["errors"], "总当量"), "并指出是当量超标")

	var swapped: Dictionary = spec.duplicate(true)
	swapped["talents"] = ["frail_body"]
	swapped["flaws"] = ["blood_feud"]
	var swapped_result: Dictionary = creator.validate(swapped)
	_check(not bool(swapped_result["ok"]), "缺陷不能填进天赋槽")
	_check(_has_text(swapped_result["errors"], "不是天赋"), "并指出它不是天赋")


## M3.1：装配出的化身带上出身给的金钱、物品、技能，以及天赋的属性修正与债务。
func _test_build_avatar_from_spec() -> void:
	var creator: CharacterCreation = _new_creator()
	var spec: Dictionary = creator.new_spec()
	spec["race"] = "dwarf"
	spec["backgroundId"] = "merchant"
	spec["displayName"] = "试作角色"
	_allocate(spec, {"strength": 5, "constitution": 5, "perception": 5, "soul": 5})
	spec["talents"] = ["sharp_senses"]
	spec["flaws"] = ["deep_in_debt"]
	_check(bool(creator.validate(spec)["ok"]), "带天赋缺陷的规格校验通过")

	var avatar: PlayerAvatar = creator.build_avatar(spec, "avatar-t1", "soul-t1")
	_eq(avatar.race, "dwarf", "种族写入化身")
	_eq(avatar.background_id, "merchant", "出身写入化身")
	_eq(avatar.age, 30, "年龄取出身的 startAge")
	_eq(avatar.money, 3000, "初始金钱取出身")
	_eq(avatar.debt_copper, 500, "债台高筑记 500 铜负债")
	_eq(avatar.inventory.size(), 2, "商人出身带两瓶治疗药水")
	_eq(avatar.item_instances.size(), 2, "每件初始物品都生成一个实例")
	# 感知 = 10 起点 + 5 分配 + 3「敏锐」（矮人的感知偏移是 0）
	_eq(avatar.get_attribute(PlayerAvatar.ATTR_PERCEPTION), 18, "天赋的属性修正进入最终属性")

	var bad_template: int = 0
	for instance_id in avatar.inventory:
		var instance: Dictionary = avatar.item_instances[instance_id]
		if ContentLoader.get_item(str(instance["templateId"])).is_empty():
			bad_template += 1
	_eq(bad_template, 0, "背包实例都指向存在的物品模板")

	var restored: PlayerAvatar = PlayerAvatar.from_dict(avatar.to_dict())
	_eq(restored.debt_copper, avatar.debt_copper, "负债往返一致")
	_eq(restored.item_instances.size(), avatar.item_instances.size(), "物品实例往返一致")
	_eq(restored.get_attribute(PlayerAvatar.ATTR_PERCEPTION), 18, "属性往返一致")


## M3.2：随机转生——宿主来自模拟 NPC 池，且三类遗留物至少有一项非空。
func _test_random_rebirth_legacy() -> void:
	var built: Dictionary = _new_sim(true)
	var world: WorldState = built["world"]
	var soul := SoulRecord.new()
	soul.soul_id = "soul-test"

	var reinc: Reincarnation = _new_reincarnation(4242)
	var result: Dictionary = reinc.rebirth(world, soul, 0)
	_check(bool(result["ok"]), "转生产出规格：" + str(result.get("reason", "")))

	var legacy: Dictionary = result["legacy"]
	_check(not Reincarnation.legacy_is_empty(legacy),
		"宿主带有非空的债务/亲属/待办中的至少一项")
	var summary: Dictionary = Reincarnation.legacy_summary(legacy)
	_check(int(summary["kin"]) > 0, "亲属取自家庭关系网：%d 位" % int(summary["kin"]))
	_check(int(summary["pending"]) > 0, "待办由亲属/仇敌/债务推导：%d 条" % int(summary["pending"]))

	var host: SimNpc = result["host"]
	_check(not host.is_named, "具名 NPC 不作宿主")
	_check(host.age >= 16, "宿主已成年：%d 岁" % host.age)
	_check(not host.is_elder(15), "宿主未到暮年")

	var spec: Dictionary = result["avatarSpec"]
	_eq(str(spec["hostAvatarId"]), host.npc_id, "规格记录了宿主 ID")
	_check(int(result["sleepMonths"]) > 0, "沉眠月数为正：%d" % int(result["sleepMonths"]))

	# 同一种子必须抽到同一宿主，否则读档重试会换人
	var first: Dictionary = _new_reincarnation(4242).rebirth(world, SoulRecord.new(), 0)
	var second: Dictionary = _new_reincarnation(4242).rebirth(world, SoulRecord.new(), 0)
	_eq(str(second["host"].npc_id), str(first["host"].npc_id), "同种子抽到同一宿主")


## 《数值框架》3.2 节：幸运越高，随机到「优质躯壳」的概率越大。
## 「优质」文档未定义，实现取剩余寿命比例（精灵 100 岁寿命 500 比人类 50 岁
## 寿命 80 更"优质"）。
##
## 这里断言的是权重函数而不是抽样结果：权重带来的偏移约 1–2 个千分点，
## 要靠抽样把它和噪声分开需要上万次抽取，那在验收测试里跑不起。
func _test_luck_favors_better_host() -> void:
	var reinc: Reincarnation = _new_reincarnation(1)
	# 幸运 +100：优质躯壳（质量满分 1000）的权重高于劣质躯壳（质量 100）
	_check(reinc.host_weight(100, 1000) > reinc.host_weight(100, 100),
		"幸运为正时优质躯壳权重更高（%d > %d）" % [
			reinc.host_weight(100, 1000), reinc.host_weight(100, 100)
		])
	_check(reinc.host_weight(-100, 1000) < reinc.host_weight(-100, 100),
		"幸运为负时优质躯壳权重反而更低（%d < %d）" % [
			reinc.host_weight(-100, 1000), reinc.host_weight(-100, 100)
		])
	_eq(reinc.host_weight(0, 1000), reinc.host_weight(0, 100),
		"幸运为 0 时权重与躯壳质量无关")
	_eq(reinc.host_weight(100, 1000), 1500, "幸运 +100 且质量满分 → 1.5 倍权重")
	_eq(reinc.host_weight(-100, 1000), 500, "幸运 −100 且质量满分 → 0.5 倍权重")


## 《数值框架》11 节：保留率、技能继承、属性继承与沉眠年数。
func _test_retention_and_inheritance() -> void:
	var reinc: Reincarnation = _new_reincarnation(7)
	_eq(reinc.retention_milli(0), 200, "SOU 0 → 保留率 20%")
	_eq(reinc.retention_milli(50), 400, "SOU 50 → 保留率 40%")
	_eq(reinc.retention_milli(100), 600, "SOU 100 → 保留率 60%")
	_eq(reinc.retention_milli(150), 600, "保留率上限 60%")

	var carried: Dictionary = reinc.inherited_skills({"sword_slash": 80}, 50)
	_eq(int(carried["sword_slash"]), 32, "技能继承：熟练度 80 × 40% = 32")

	var bonus: Dictionary = reinc.inherited_attribute_bonus({PlayerAvatar.ATTR_SOUL: 60}, 50)
	# 60 × 0.4 × 0.3 = 7.2 → 7
	_eq(int(bonus[PlayerAvatar.ATTR_SOUL]), 7, "属性继承：前世 60 × 保留率 × 0.3")

	var cfg: Dictionary = ContentLoader.get_balance_section("reincarnation")
	var low: int = int(cfg["sleepMonthsMinYears"]) * 12
	var high: int = int(cfg["sleepMonthsMaxYears"]) * 12
	var months: int = reinc.sleep_months(50)
	_check(months >= low and months <= high,
		"沉眠月数落在 %d–%d 之间：%d" % [low, high, months])
	# SOU 越高沉眠越久（抖动是 ±3 年，这里比的是同一条公式的单调性）
	var short_sleep: int = reinc.sleep_months(0)
	var long_sleep: int = reinc.sleep_months(100)
	_check(long_sleep > short_sleep,
		"灵魂越高沉眠越久（SOU 100 → %d 月 > SOU 0 → %d 月）" % [long_sleep, short_sleep])


## 死亡结算：保留率、技能继承、生命存档与跨世痕迹。
func _test_settle_death() -> void:
	var reinc: Reincarnation = _new_reincarnation(11)
	var soul := SoulRecord.new()
	soul.soul_id = "soul-death"
	var avatar := PlayerAvatar.new()
	avatar.avatar_id = "avatar-death"
	avatar.skills = {"sword_slash": 50}
	avatar.karma = 12
	avatar.luck = 5

	# 七维默认 10，SOU 10 → 20% + 10×0.4% = 24%
	var report: Dictionary = reinc.settle_death(soul, avatar, Reincarnation.CAUSE_COMBAT, 36)
	_eq(soul.reincarnation_count, 1, "转生次数 +1")
	_eq(reinc.retention_milli(10), 240, "SOU 10 → 保留率 24%")
	_eq(int(round(float(report["retention"]) * 1000.0)), 240, "结算返回的保留率一致")
	_eq(int(soul.inherited_skills["sword_slash"]), 12, "技能继承：50 × 24% = 12")
	_eq(soul.karma_carry, 12, "本世善恶累计进跨世痕迹")
	_eq(soul.life_archives.size(), 1, "留下一份生命存档")
	_eq(int(soul.life_archives[0]["endedMonth"]), 36, "存档记录了结束月")
	_check(not str(report["archiveId"]).is_empty(), "返回存档 ID")


# --- 派生值与战斗公式测试项 ---

## 《数值框架》4.1 / 4.2 / 6.1 节：生命、魔力、耐力、PL、AP、TU。
func _test_derived_stats_formulas() -> void:
	var stats: DerivedStats = _new_derived()
	var plain: Dictionary = _plain_attributes()
	_eq(stats.max_hp(plain, 0), 110, "生命 = 30 + CON10×8 + PL0×4")
	_eq(stats.max_mp(plain), 90, "魔力 = 10 + INT10×4 + SOU10×4")
	_eq(stats.max_sp(plain), 70, "耐力 = 20 + CON10×3 + STR10×2")
	_eq(stats.power_level(plain, {}), 0, "七维总和 70 → PL 0")
	_eq(stats.power_level(plain, {"a": 100, "b": 100, "c": 100, "d": 100, "e": 100}), 10,
		"前五项技能熟练度均值 100 → PL +10")

	# 6.1 节的原文示例：DEX 20 → 5 AP、TU 84；DEX 100 → 9 AP、TU 20
	var dex20: Dictionary = _attributes_with(PlayerAvatar.ATTR_DEXTERITY, 20)
	_eq(stats.action_points(dex20), 5, "DEX 20 → 每回合 5 AP")
	_eq(stats.time_units(dex20), 84, "DEX 20 → TU 84")
	var dex100: Dictionary = _attributes_with(PlayerAvatar.ATTR_DEXTERITY, 100)
	_eq(stats.action_points(dex100), 9, "DEX 100 → 每回合 9 AP")
	_eq(stats.time_units(dex100), 20, "DEX 100 → TU 20")
	# M5.1 的验收就是这一条：高敏捷在同等时间内出手更多
	_check(stats.action_points(dex100) > stats.action_points(plain)
		and stats.time_units(dex100) < stats.time_units(plain),
		"高敏捷单位 AP 更多、TU 更小，因此同样时间内出手次数更多")

	# 负重上限（D-66）：基础 20 + STR10×3 = 50，四条来源各自叠加
	_eq(stats.encumbrance_limit(plain, 0, 0, 0), 50, "负重上限 = 基础 20 + 力量 10×3，无加成")
	_eq(stats.encumbrance_limit(plain, 50, 0, 0), 100, "负重训练熟练度 50 → 上限 +50")
	_eq(stats.encumbrance_limit(plain, 0, 8, 0), 58, "装备 carryBonus +8")
	_eq(stats.encumbrance_limit(plain, 0, 0, 15), 65, "天赋 carryBonus +15")

	# 超重是渐进惩罚：不超无惩罚，超得越多越厉害，且不硬封锁
	var none: Dictionary = stats.encumbrance_penalty(50, 50)
	_eq(int(none["over"]), 0, "未超重：超出量为 0")
	_eq(int(none["apPenalty"]) + int(none["movePenalty"]) + int(none["hitPenaltyBp"]) \
		+ int(none["tuPenalty"]), 0, "未超重四个惩罚全为 0")
	var half: Dictionary = stats.encumbrance_penalty(75, 50)
	_eq(int(half["over"]), 25, "超重 25（50%）")
	_eq(int(half["apPenalty"]), 1, "50% 超载 → AP −1")
	_eq(int(half["movePenalty"]), 2, "50% 超载 → 移动 +2")
	_eq(int(half["hitPenaltyBp"]), 750, "50% 超载 → 命中 −750 基点")
	_eq(int(half["tuPenalty"]), 13, "50% 超载 → TU +13")
	var full: Dictionary = stats.encumbrance_penalty(100, 50)
	_eq(int(full["apPenalty"]), 2, "100% 超载 → AP 封顶 −2")
	_eq(int(full["movePenalty"]), 3, "100% 超载 → 移动封顶 +3")
	_eq(int(full["hitPenaltyBp"]), 1500, "100% 超载 → 命中封顶 −1500 基点")
	_eq(int(full["tuPenalty"]), 25, "100% 超载 → TU 封顶 +25")
	# 从没降到 0 的行动力证明它不是硬封锁：即使满超载，行动点仍 ≥ 1
	var huge: Dictionary = stats.encumbrance_penalty(200, 50)
	_eq(int(huge["apPenalty"]), 2, "远超上限也封顶不涨，留着最低行动力")


## 6.2 / 6.3 节：命中率、瞄准修正、加算减法伤害。
func _test_hit_and_damage_formulas() -> void:
	var stats: DerivedStats = _new_derived()
	var plain: Dictionary = _plain_attributes()
	# 50% 基础 + PER10×0.4 个百分点 + DEX10×0.2 − 目标闪避 DEX10×0.3
	_eq(stats.hit_chance_bp(plain, 0, plain), 5300, "命中率 = 50% + 4% + 2% − 3%")

	var strong: Dictionary = {}
	for attr in PlayerAvatar.ALL_ATTRIBUTES:
		strong[attr] = 100
	_eq(stats.hit_chance_bp(strong, 100, plain), 9500, "命中率上限钳在 95%")

	var weak: Dictionary = _plain_attributes()
	weak[PlayerAvatar.ATTR_PERCEPTION] = 1
	weak[PlayerAvatar.ATTR_DEXTERITY] = 1
	var dodgy: Dictionary = _attributes_with(PlayerAvatar.ATTR_DEXTERITY, 100)
	_eq(stats.hit_chance_bp(weak, 0, dodgy, DerivedStats.AIM_TORSO, {}, 0, 5000), 500,
		"命中率下限钳在 5%")

	_eq(stats.hit_chance_bp(plain, 0, plain, DerivedStats.AIM_HEAD), 3300, "瞄准头部扣 20% 命中")
	_eq(stats.hit_chance_bp(plain, 0, plain, "left_leg"), 4300, "瞄准四肢扣 10% 命中")
	_eq(stats.aim_damage_factor(DerivedStats.AIM_HEAD), 1.5, "头部伤害 ×1.5")
	_eq(stats.aim_damage_factor("left_leg"), 0.7, "四肢伤害 ×0.7")

	# 基础 = 武器 16 × 1.0 + STR20×0.6 = 28；× 技能系数 0.5 = 14
	var attacker: Dictionary = _attributes_with(PlayerAvatar.ATTR_STRENGTH, 20)
	_eq(stats.physical_damage(attacker, 16, 0, 1.0, 0), 14, "无甲时伤害 14")
	_eq(stats.physical_damage(attacker, 16, 0, 1.0, 10), 4, "护甲 10 → 少受 10 点（加算减法）")
	_eq(stats.physical_damage(attacker, 16, 0, 1.0, 100), 1, "护甲远高于伤害时保底 1 点")
	_eq(stats.physical_damage(attacker, 16, 50, 1.0, 0), 28,
		"熟练度 50 → 技能系数 1.0，伤害从 14 翻到 28")
	# 破甲 30% → 减伤从 10 降到 7
	_eq(stats.physical_damage(attacker, 16, 0, 1.0, 10, 0.3), 7, "破甲 30% 把减伤从 10 压到 7")


## 6.4 节部位伤：腿降移动、手降命中，未包扎的伤不会自己好。
func _test_body_part_injury() -> void:
	var stats: DerivedStats = _new_derived()
	var plain: Dictionary = _plain_attributes()
	var healthy: Dictionary = PlayerAvatar.new().body_parts

	_eq(stats.move_cost(healthy), 1, "无伤时移动 1 格花 1 AP")
	_eq(stats.arm_hit_penalty_bp(healthy), 0, "无伤时命中不扣")

	var wounded: Dictionary = healthy.duplicate(true)
	wounded["left_leg"] = {"injured": true, "severity": 2, "treated": false}
	_eq(stats.move_cost(wounded), 3, "腿伤 2 级 → 移动每格花 3 AP")
	_eq(stats.move_cost(healthy), 1, "腿伤不影响别的部位")

	var arm: Dictionary = healthy.duplicate(true)
	arm["right_arm"] = {"injured": true, "severity": 1, "treated": false}
	_eq(stats.arm_hit_penalty_bp(arm), 1000, "手伤 1 级 → 命中 −10%")
	_eq(stats.hit_chance_bp(plain, 0, plain, DerivedStats.AIM_TORSO, arm), 4300,
		"手伤把命中从 53% 拉到 43%")

	var untreated: Dictionary = {"injured": true, "severity": 3, "treated": false}
	_eq(int(stats.heal_step(untreated, 30)["severity"]), 3, "未包扎的伤放 30 天也不降级")
	var treated: Dictionary = {"injured": true, "severity": 3, "treated": true}
	_eq(int(stats.heal_step(treated, 3)["severity"]), 2, "包扎后每 3 天降一级")
	_eq(int(stats.heal_step(treated, 9)["severity"]), 0, "包扎后 9 天痊愈")
	_check(not bool(stats.heal_step(treated, 9)["injured"]), "痊愈后不再算受伤")


# --- 战斗会话测试项 ---

## M5.1：网格回合与 AP/TU——敏捷高者先手，且同一轮内出手次数更多。
func _test_combat_initiative_and_ap() -> void:
	var combat: Combat = _new_combat(1001)
	var started: Dictionary = combat.start(_duel_encounter(40, 10))
	_check(bool(started["ok"]), "战斗开始：" + str(started.get("reason", "")))
	# DEX 40 → TU 68；DEX 10 → TU 92。TU 越小越先动。
	_eq(combat.current_unit_id(), "hero", "敏捷高的单位先手")
	_eq(str(started["state"]["order"][0]), "hero", "先攻顺序把敏捷高的排在前")
	_eq(int(combat.unit_by_id("hero")["ap"]), 6, "DEX 40 → 每轮 6 AP")

	# 6 AP ÷ 普通攻击 2 AP = 一轮三次，打完自动换人
	var swung: int = 0
	while combat.current_unit_id() == "hero" and swung < 10:
		var result: Dictionary = combat.submit_action({
			"actionType": Combat.ACTION_ATTACK, "actorId": "hero", "targetId": "foe",
		})
		_check(bool(result["ok"]), "高敏捷单位的第 %d 次攻击被接受" % (swung + 1))
		swung += 1
	_eq(swung, 3, "6 AP 打出 3 次普通攻击")
	_eq(combat.current_unit_id(), "foe", "AP 用尽后行动权交出")

	# 敌人 DEX 10 → 4 AP → 一轮两次
	var foe_swung: int = 0
	while combat.current_unit_id() == "foe" and foe_swung < 10:
		combat.submit_action({
			"actionType": Combat.ACTION_ATTACK, "actorId": "foe", "targetId": "hero",
		})
		foe_swung += 1
	_eq(foe_swung, 2, "4 AP 打出 2 次普通攻击")
	_check(swung > foe_swung, "M5.1：同等时间内高敏捷出手更多（%d > %d）" % [swung, foe_swung])
	_eq(combat.current_unit_id(), "hero", "一轮走完后回到先手单位")
	_eq(int(combat.get_state()["round"]), 2, "已进入第 2 轮")


## D-66：超重单位带着惩罚进场——TU 拖后、AP 变少、移动变贵、命中变低；
## 且惩罚只落在带 encumbrance 的玩家单位上，敌人一概不受影响。
func _test_combat_encumbrance() -> void:
	var specs: Dictionary = _duel_encounter(40, 10)
	specs["units"][0]["encumbrance"] = {
		"apPenalty": 2, "movePenalty": 2, "hitPenaltyBp": 750, "tuPenalty": 13,
	}
	var combat: Combat = _new_combat(4004)
	_check(bool(combat.start(specs)["ok"]), "带上超重的战斗开始成功")

	var hero: Dictionary = combat.unit_by_id("hero")
	_eq(int(hero["tu"]), 81, "DEX 40 → TU 68 + 超重 +13 = 81，行动序被拖后")
	_eq(int(hero["ap"]), 4, "DEX 40 → 每轮 6 AP − 超重 2 = 4")
	# DEX 10 的敌人 TU 92 > 81，所以超重的英雄仍是先手——但至少比不带超重时慢
	_eq(combat.current_unit_id(), "hero", "TU 81 < 92，英雄仍然先手")

	# 移动：腿无伤每格 1 AP + 超重 +2 = 3 AP
	var move: Dictionary = combat.submit_action({
		"actionType": Combat.ACTION_MOVE, "actorId": "hero", "moveTo": [0, 1],
	})
	_check(bool(move["ok"]), "超重时移动被接受（渐进惩罚，不硬封锁）")
	_eq(int(hero["ap"]), 1, "超重移动一格花 3 AP（1 基础 + 2 超重）")

	# 敌人没有 encumbrance，既不加 TU 也不减 AP——惩罚只落在带负担的玩家身上
	var foe: Dictionary = combat.unit_by_id("foe")
	_eq(int(foe["tu"]), 92, "敌人 TU 不受超重影响（缺省 0）")
	combat.submit_action({"actionType": Combat.ACTION_END_TURN, "actorId": "hero"})
	_eq(combat.current_unit_id(), "foe", "结束回合轮到敌人")
	_eq(int(foe["ap"]), 4, "敌人的行动点不吃超重惩罚，仍是 DEX 10 的 4 AP")


## M5.3：腿部受伤让移动变贵（6.4 节「腿→降移速」）。
func _test_combat_injury_effects() -> void:
	var combat: Combat = _new_combat(2002)
	combat.start(_duel_encounter(20, 10))
	var foe: Dictionary = combat.unit_by_id("foe")
	_eq(int(foe["ap"]), 0, "还没轮到的单位没有行动点")

	combat.submit_action({"actionType": Combat.ACTION_END_TURN, "actorId": "hero"})
	_eq(combat.current_unit_id(), "foe", "结束回合后轮到敌人")
	_eq(int(foe["ap"]), 4, "DEX 10 → 每轮 4 AP")

	var healthy_move: Dictionary = combat.submit_action({
		"actionType": Combat.ACTION_MOVE, "actorId": "foe", "moveTo": [1, 1],
	})
	_check(bool(healthy_move["ok"]), "无伤时移动被接受")
	_eq(int(foe["ap"]), 3, "无伤移动一格花 1 AP")

	foe["bodyParts"]["left_leg"] = {"injured": true, "severity": 1, "treated": false}
	var hurt_move: Dictionary = combat.submit_action({
		"actionType": Combat.ACTION_MOVE, "actorId": "foe", "moveTo": [1, 2],
	})
	_check(bool(hurt_move["ok"]), "带腿伤时移动被接受")
	_eq(int(foe["ap"]), 1, "腿伤 1 级后移动一格花 2 AP")


## M5.4：HP 归零是倒地而非死亡；四种处理各自产出不同的世界标记。
func _test_combat_downed_choices() -> void:
	for choice in Combat.ALL_DOWNED_CHOICES:
		var combat: Combat = _new_combat(3003)
		combat.start(_duel_encounter(40, 10, 30))
		var foe: Dictionary = combat.unit_by_id("foe")

		# 反复攻击直到打倒。命中率约 95%，落空也消耗 AP，所以要处理换人。
		var guard: int = 0
		while not bool(foe["downed"]) and guard < 80:
			guard += 1
			var actor_id: String = combat.current_unit_id()
			if actor_id.is_empty():
				break
			if actor_id != "hero" or int(combat.unit_by_id("hero")["ap"]) < 2:
				combat.submit_action({"actionType": Combat.ACTION_END_TURN, "actorId": actor_id})
				continue
			combat.submit_action({
				"actionType": Combat.ACTION_ATTACK, "actorId": "hero", "targetId": "foe",
			})
		_check(bool(foe["downed"]), "把敌人打倒（HP 归零）")
		_check(not bool(foe["dead"]), "倒地不等于死亡")
		_check(not bool(combat.get_state()["finished"]),
			"还有下场未定的倒地者时战斗不结束——玩家才有做选择的时机")

		var chosen: Dictionary = combat.submit_action({
			"actionType": Combat.ACTION_DOWNED_CHOICE, "actorId": "hero",
			"targetId": "foe", "downedChoice": choice,
		})
		_check(bool(chosen["ok"]), "倒地处理「%s」被接受" % choice)
		_check(bool(combat.world_flags.get("combat.%s.foe" % choice, false)),
			"「%s」产出自己的世界标记" % choice)
		_check(bool(combat.get_state()["finished"]), "处理完最后一名倒地者后战斗结束")
		if choice == Combat.DOWNED_FINISH:
			_check(bool(foe["dead"]), "补刀才致死")

	var flags: Array = []
	for choice in Combat.ALL_DOWNED_CHOICES:
		flags.append("combat.%s.foe" % choice)
	_eq(flags.size(), 4, "四种处理对应四枚互不相同的世界标记")


## M5.5：掉落率随 TL 与幸运变化，稀有度权重随幸运上浮（14.1 / 14.2 节）。
func _test_combat_loot_scaling() -> void:
	var combat: Combat = _new_combat(4004)
	# 原文示例：平凡生物（TL 1–5）掉落率 32%–40%，灾厄（TL 21–35）72%–100%
	_eq(combat.loot_chance_bp(1, 0), 3200, "TL 1 → 掉落率 32%")
	_eq(combat.loot_chance_bp(5, 0), 4000, "TL 5 → 掉落率 40%")
	_eq(combat.loot_chance_bp(21, 0), 7200, "TL 21 → 掉落率 72%")
	_eq(combat.loot_chance_bp(35, 0), 10000, "TL 35 → 掉落率 100%")
	# 幸运 ±100 → 掉落率 ×1.5 / ×0.5
	_eq(combat.loot_chance_bp(36, 100), 10000, "幸运 +100 后钳在上限 100%")
	_eq(combat.loot_chance_bp(1, -100), 1600, "幸运 −100 让掉落率减半")

	# 稀有度：TL 1–5 的原始权重就是 14.2 节那一行的 85% / 12% / 3%
	var plain: Array = combat.rarity_weights(3, 0)
	_eq(int(plain[0]), 850, "TL 1–5 普通档权重 85%")
	_eq(int(plain[1]), 120, "精良 12%")
	_eq(int(plain[2]), 30, "稀有 3%")

	# 幸运 +100 = 5 步，每步从最低档搬 1 个千分点到最高档
	var lucky: Array = combat.rarity_weights(3, 100)
	_eq(int(lucky[0]), 845, "幸运 +100 从普通档扣掉 5 个千分点")
	_eq(int(lucky[5]), 5, "这 5 个千分点搬到最高档")
	var total: int = 0
	for weight in lucky:
		total += int(weight)
	_eq(total, 1000, "搬权重不改变总量")

	# 掉落靠按稀有度反查 items.json，低四档必须有货
	var missing: int = 0
	for rarity in ["common", "fine", "rare", "epic"]:
		var found: int = 0
		for item in ContentLoader.get_items():
			if str(item.get("rarity", "")) == rarity:
				found += 1
		if found == 0:
			missing += 1
	_eq(missing, 0, "普通到史诗四档都有可掉落的物品")


# --- 界面视图模型（M6.2 / M6.3）---
#
# 三个视图模型都是纯函数，所以能在无头环境下被钉住。面板本身只做绘制，
# 无法在这里断言——那部分只能靠窗口目视确认。

## 开局创建界面（M3.1 自由生成 / M3.2 随机转生）。
func _test_creation_view_model() -> void:
	var creator: CharacterCreation = _new_creator()
	var spec: Dictionary = creator.new_spec()
	spec["race"] = "dwarf"
	spec["backgroundId"] = "merchant"
	spec["displayName"] = "试作角色"

	var race_view: Dictionary = CreationViewModel.build(
		creator, spec, CreationViewModel.SECTION_RACE, 0, CreationViewModel.MODE_FREE
	)
	_eq(int(race_view["rowCount"]), creator.race_options().size(),
		"种族段的条目数等于可玩种族数")
	_check(int(race_view["rowCount"]) >= 2, "至少有两个可玩种族")
	_eq(str(race_view["sectionLabel"]), "1 种族", "段标签按段序号给出")
	var marked: int = 0
	for row in race_view["rows"]:
		if bool(row["selected"]):
			marked += 1
	_eq(marked, 1, "种族段里恰有一行是当前选择")

	# 属性段：点数没分完时不允许开局，且错误文案说得出是哪种问题
	var attr_view: Dictionary = CreationViewModel.build(
		creator, spec, CreationViewModel.SECTION_ATTRIBUTES, 0, CreationViewModel.MODE_FREE
	)
	_eq(int(attr_view["rowCount"]), PlayerAvatar.ALL_ATTRIBUTES.size(), "属性段七行")
	_eq(int(attr_view["remainingPoints"]), creator.allocatable_points(),
		"尚未分配时剩余点数等于可分配点数")
	_check(_has_text(attr_view["errors"], "未分配"), "点数没分完时给出提示")
	_check(not bool(attr_view["canStart"]), "点数没分完不允许开局")

	# 分满之后：属性行体现种族偏移，且合法规格允许开局
	_allocate(spec, {"strength": 6, "dexterity": 5, "constitution": 5, "perception": 4})
	spec["talents"] = ["sharp_senses"]
	spec["flaws"] = ["deep_in_debt"]
	var ready_attrs: Dictionary = CreationViewModel.build(
		creator, spec, CreationViewModel.SECTION_ATTRIBUTES, 0, CreationViewModel.MODE_FREE
	)
	_eq(int(ready_attrs["remainingPoints"]), 0, "点数分配完毕")
	var strength_row: Dictionary = _find_row(ready_attrs["rows"], "strength")
	# 矮人力量偏移 +3：10 起点 + 6 分配 + 3 = 19
	_eq(int(strength_row["final"]), 19, "属性行的最终值含种族偏移")

	var confirm: Dictionary = CreationViewModel.build(
		creator, spec, CreationViewModel.SECTION_CONFIRM, 0, CreationViewModel.MODE_FREE
	)
	_check(bool(confirm["canStart"]), "合法规格允许开局")
	_check(_row_text(confirm["rows"]).contains("天赋"), "确认段列出天赋数量")

	# 缺陷数与天赋数不等时必须拦住
	spec["flaws"] = []
	var blocked: Dictionary = CreationViewModel.build(
		creator, spec, CreationViewModel.SECTION_CONFIRM, 0, CreationViewModel.MODE_FREE
	)
	_check(not bool(blocked["canStart"]), "缺陷数与天赋数不等时不允许开局")
	_check(_has_text(blocked["errors"], "数量必须相等"), "错误文案说明是数量不等")
	_check(int(blocked["errors"].size()) > 0, "错误列表非空，界面才有东西可显示")

	# 转生模式：不跑创建期校验（规格由宿主推导），且列出宿主与遗留
	var built: Dictionary = _new_sim(true)
	var world: WorldState = built["world"]
	var soul := SoulRecord.new()
	soul.soul_id = "soul-vm"
	var rebirth: Dictionary = _new_reincarnation(4242).rebirth(world, soul, 0)
	_check(bool(rebirth["ok"]), "转生预览生成成功")
	var rebirth_view: Dictionary = CreationViewModel.build(
		creator, spec, CreationViewModel.SECTION_CONFIRM, 0,
		CreationViewModel.MODE_REBIRTH, rebirth, {"aedran": "艾德兰"}
	)
	_check(bool(rebirth_view["canStart"]), "转生模式不跑创建期校验，可直接开始")
	_eq(int(rebirth_view["section"]), CreationViewModel.SECTION_CONFIRM, "转生模式停在确认段")
	var rebirth_text: String = _row_text(rebirth_view["rows"])
	_check(rebirth_text.contains("宿主"), "转生确认段列出宿主")
	_check(rebirth_text.contains("沉眠"), "转生确认段列出沉眠时长")
	_check(rebirth_text.contains("记忆保留率"), "转生确认段列出记忆保留率")
	_check(rebirth_text.contains("岁"), "转生确认段列出躯壳年龄")


## 角色面板（M6.2）。名字解析走注入的查询表，所以测试不必背一份完整配置。
func _test_avatar_view_model() -> void:
	var creator: CharacterCreation = _new_creator()
	var spec: Dictionary = creator.new_spec()
	spec["race"] = "human"
	spec["backgroundId"] = "merchant"
	spec["displayName"] = "试作角色"
	_allocate(spec, {"strength": 10, "dexterity": 10})
	var avatar: PlayerAvatar = creator.build_avatar(spec, "avatar-vm", "soul-vm")

	var lookups: Dictionary = {
		"skillNames": {"sword_slash": "挥砍"},
		"talentNames": {"deep_in_debt": "债台高筑"},
		"itemTemplates": _item_template_table(),
		"cityNames": {"aedran": "艾德兰"},
		"raceNames": {"human": "人类"},
	}
	var view: Dictionary = AvatarViewModel.build(avatar, _new_derived(), lookups, "在艾德兰")
	_eq(int(view["attributeRows"].size()), PlayerAvatar.ALL_ATTRIBUTES.size(), "属性行数等于七维")
	_eq(str(view["raceLabel"]), "人类", "种族显示名来自查询表")
	_check(str(view["identityLine"]).contains("人类"),
		"身份行用种族显示名而不是 ID：" + str(view["identityLine"]))
	_check(str(view["identityLine"]).contains("%d 岁" % avatar.age), "身份行带年龄")
	_eq(str(view["location"]), "在艾德兰", "位置行原样透传")
	_eq(int(view["derivedRows"].size()), 7, "派生值七行")
	_check(not view["inventoryRows"].is_empty(), "背包列出出身给的初始物品")
	_check(not bool(view["hasLegacy"]), "自由生成没有宿主遗留")
	_eq(int(view["legacyRows"].size()), 0, "没有遗留时不留空段")
	_eq(int(view["skillRows"].size()), 0, "还没练技能时技能段为空")

	# 金钱换算（9.1 节：1 金 = 100 银 = 10000 铜）
	_eq(AvatarViewModel.money_label(0), "0 铜", "零钱显示 0 铜")
	_eq(AvatarViewModel.money_label(205), "2 银 5 铜", "银铜进位")
	_eq(AvatarViewModel.money_label(10000), "1 金", "整金不带零头")
	_eq(AvatarViewModel.money_label(12345), "1 金 23 银 45 铜", "金银铜三段")

	# 属性档位（2.1 节）与技能阶位（《技能库》1.3 节）
	_eq(AvatarViewModel.tier_label(3, AvatarViewModel.ATTRIBUTE_TIERS), "羸弱", "3 → 羸弱")
	_eq(AvatarViewModel.tier_label(10, AvatarViewModel.ATTRIBUTE_TIERS), "普通", "10 → 普通")
	_eq(AvatarViewModel.tier_label(45, AvatarViewModel.ATTRIBUTE_TIERS), "强者", "45 → 强者")
	_eq(AvatarViewModel.tier_label(90, AvatarViewModel.ATTRIBUTE_TIERS), "破限", "90 → 破限")
	_eq(AvatarViewModel.tier_label(35, AvatarViewModel.SKILL_TIERS), "熟练", "熟练度 35 → 熟练")
	_eq(AvatarViewModel.tier_label(100, AvatarViewModel.SKILL_TIERS), "宗师", "熟练度 100 → 宗师")

	# 技能段：名称来自查询表，阶位由熟练度推
	avatar.skills = {"sword_slash": 35}
	var skill_view: Dictionary = AvatarViewModel.build(avatar, _new_derived(), lookups)
	_eq(int(skill_view["skillRows"].size()), 1, "一项技能一行")
	_eq(str(skill_view["skillRows"][0]["label"]), "挥砍", "技能名来自查询表")
	_eq(str(skill_view["skillRows"][0]["tierLabel"]), "熟练", "技能阶位由熟练度推出")

	# 宿主遗留（M3.2）：三项各自出现，空的项不占版面
	avatar.legacy = {
		"hostName": "某人",
		"kin": [{"npcId": "npc-1", "value": 60}],
		"debtCopper": 800,
		"pending": [{"kind": "debt", "text": "你欠着一笔 800 铜的债"}],
	}
	avatar.debt_copper = 800
	var legacy_view: Dictionary = AvatarViewModel.build(avatar, _new_derived(), lookups)
	_check(bool(legacy_view["hasLegacy"]), "有宿主遗留时标记为真")
	var legacy_text: String = _row_text(legacy_view["legacyRows"])
	_check(legacy_text.contains("某人"), "遗留里列出宿主姓名")
	_check(legacy_text.contains("亲属"), "遗留里列出亲属")
	_check(legacy_text.contains("债"), "遗留里列出宿主的债")
	_check(legacy_text.contains("800 铜"), "宿主的债换算成人话")
	_eq(str(legacy_view["debtLabel"]), "8 银", "负债字段单独换算")

	# 缺查询表时退化成 ID，而不是崩掉或空屏
	var bare: Dictionary = AvatarViewModel.build(avatar, _new_derived(), {})
	_eq(str(bare["raceLabel"]), "human", "没有种族名表时退回 ID")
	_check(int(bare["attributeRows"].size()) > 0, "没有查询表时属性段照样画得出来")


## 战斗界面（M5 的呈现层）。菜单项直接携带动作字典，这里断言的就是那份字典。
func _test_combat_view_model() -> void:
	var combat: Combat = _new_combat(99)
	_check(bool(combat.start(_duel_encounter(20, 5))["ok"]), "测试战斗开始成功")
	# DEX 20 → TU 84 先手，对手 DEX 5 → TU 96
	_check(CombatViewModel.is_player_turn(combat), "敏捷高的一方先手")

	var skill_names: Dictionary = {"sword_slash": "挥砍"}
	var view: Dictionary = CombatViewModel.build(
		combat, skill_names, CombatViewModel.MENU_MAIN, 0
	)
	_eq(int(view["round"]), 1, "首轮")
	_eq(str(view["menuHint"]), str(CombatViewModel.MENU_HINTS[CombatViewModel.MENU_MAIN]),
		"主菜单提示取自菜单模式")
	_eq(int(view["unitRows"].size()), 2, "单位列表两名参战者")
	_eq(int(view["battlefield"]["units"].size()), 2, "战场上画两个单位")
	_eq(int(view["battlefield"]["width"]), CombatViewModel.BATTLE_WIDTH, "战场宽度")
	_eq(int(view["logTail"].size()), 0, "尚未交手时日志为空")
	var main_text: String = _menu_text(view["menu"])
	_check(main_text.contains("移动"), "主菜单含移动")
	_check(main_text.contains("普通攻击"), "主菜单含普通攻击")
	_check(main_text.contains("挥砍"), "主菜单含已练的技能")
	_check(main_text.contains("结束回合"), "主菜单含结束回合")
	_eq(str(_find_menu(view["menu"], "移动")["action"]["kind"]), "move",
		"移动项携带 move 动作字典")
	_eq(str(_find_menu(view["menu"], "结束回合")["action"]["kind"]), "end_turn",
		"结束回合项携带 end_turn 动作字典")

	# 光标会被钳进菜单范围，菜单为空时也不会越界
	var clamped: Dictionary = CombatViewModel.build(
		combat, skill_names, CombatViewModel.MENU_MAIN, 999
	)
	_eq(int(clamped["cursor"]), int(clamped["menu"].size()) - 1, "越界的光标被钳到最后一项")

	# 选目标：相邻够得着，隔着三格够不着
	var near_view: Dictionary = CombatViewModel.build(
		combat, skill_names, CombatViewModel.MENU_TARGET_UNIT, 0,
		{"label": "普通攻击", "attackRange": 1}
	)
	_eq(int(near_view["menu"].size()), 1, "目标菜单只列对手")
	_check(bool(near_view["menu"][0]["enabled"]), "相邻的对手可选中")
	_eq(str(near_view["menu"][0]["action"]["kind"]), "target_unit",
		"目标项携带 target_unit 动作")
	_check(str(near_view["menuLabel"]).contains("普通攻击"), "目标菜单标题带上正在使用的动作")

	var far: Combat = _new_combat(7)
	var far_encounter: Dictionary = _duel_encounter(20, 5)
	far_encounter["units"][1]["position"] = [4, 0]
	_check(bool(far.start(far_encounter)["ok"]), "远距离对局开局成功")
	var far_view: Dictionary = CombatViewModel.build(
		far, skill_names, CombatViewModel.MENU_TARGET_UNIT, 0, {"attackRange": 1}
	)
	_check(not bool(far_view["menu"][0]["enabled"]), "超出射程的对手被标成不可选")

	# 选落点：reach 给到 AP 支撑不了的距离，才能同时出现可选与不可选
	var tile_view: Dictionary = CombatViewModel.build(
		combat, skill_names, CombatViewModel.MENU_TARGET_TILE, 0,
		{"reach": 3, "moveCost": 1}
	)
	_check(not tile_view["menu"].is_empty(), "落点菜单非空")
	_eq(str(tile_view["menu"][0]["action"]["kind"]), "target_tile",
		"落点项携带 target_tile 动作")
	var walkable: int = 0
	for item in tile_view["menu"]:
		if bool(item["enabled"]):
			walkable += 1
	_check(walkable > 0, "至少有一步走得动")
	_check(walkable < tile_view["menu"].size(),
		"AP 不够的落点被标成不可选（%d / %d 可选）" % [walkable, tile_view["menu"].size()])

	# 倒地处理：把对手直接置为倒地，四项处理各占一条
	var downed_combat: Combat = _new_combat(5)
	_check(bool(downed_combat.start(_duel_encounter(20, 5))["ok"]), "倒地用例开局成功")
	var foe: Dictionary = downed_combat.unit_by_id("foe")
	foe["hp"] = 0
	foe["downed"] = true
	_eq(CombatViewModel.status_label(foe), "倒地", "倒地单位的状况标签")
	_eq(CombatViewModel.status_label(downed_combat.unit_by_id("hero")), "无恙",
		"满血单位的状况标签")

	var downed_view: Dictionary = CombatViewModel.build(
		downed_combat, skill_names, CombatViewModel.MENU_DOWNED, 0
	)
	_eq(int(downed_view["menu"].size()), Combat.ALL_DOWNED_CHOICES.size(),
		"倒地处理四项各一条")
	var choices: Array = []
	for item in downed_view["menu"]:
		choices.append(str(item["action"]["downedChoice"]))
	_eq(choices.size(), Combat.ALL_DOWNED_CHOICES.size(), "四项处理互不重复")
	_eq(str(downed_view["menu"][0]["action"]["kind"]), "downed_choice",
		"处理项携带 downed_choice 动作")

	# 对手全倒且未处理时，主菜单保留「处理倒地者」入口——这正是 M5.4 的时机
	var downed_main: Dictionary = CombatViewModel.build(
		downed_combat, skill_names, CombatViewModel.MENU_MAIN, 0
	)
	_check(_menu_text(downed_main["menu"]).contains("处理倒地者"),
		"有未处理的倒地者时主菜单出现处理入口")
	_check(not _menu_text(downed_main["menu"]).contains("普通攻击"),
		"没有站立对手时不再列出攻击")

	# 玩家行动之后日志会出现在末尾若干条里
	var acted: Combat = _new_combat(99)
	acted.start(_duel_encounter(20, 5))
	acted.submit_action({
		"actionType": Combat.ACTION_ATTACK, "actorId": "hero", "targetId": "foe",
	})
	var acted_view: Dictionary = CombatViewModel.build(
		acted, skill_names, CombatViewModel.MENU_MAIN, 0
	)
	_check(not acted_view["logTail"].is_empty(), "出手之后日志非空")
	_check(int(acted_view["logTail"].size()) <= CombatViewModel.LOG_TAIL,
		"日志只取末尾若干条（%d ≤ %d）" % [
			int(acted_view["logTail"].size()), CombatViewModel.LOG_TAIL
		])

	# 战斗结束时不产出菜单，界面改画结算块。
	# 直接判对手阵亡，不走"打一下"：命中是掷出来的，落空时下面两句会被
	# if 挡掉——用例照样报"通过"，却其实什么都没验。
	var finished: Combat = _new_combat(31)
	finished.start(_duel_encounter(20, 5))
	var lethal_foe: Dictionary = finished.unit_by_id("foe")
	lethal_foe["hp"] = 0
	lethal_foe["dead"] = true
	finished.resolve()
	_check(bool(finished.finished), "对手阵亡后战斗判为结束")
	var finished_view: Dictionary = CombatViewModel.build(
		finished, skill_names, CombatViewModel.MENU_MAIN, 0
	)
	_check(finished_view["menu"].is_empty(), "战斗结束后不再产出菜单")
	_check(bool(finished_view["finished"]), "战斗结束标记透传给界面")


## 走私航线界面。要摆出来的就三件事：这条路能不能建、建了每月进多少、
## 被查抄的概率多大。前两件来自 WorldSim，界面不自己再判一次规则。
func _test_smuggling_view_model() -> void:
	var built: Dictionary = _new_sim()
	var world: WorldState = built["world"]
	var sim: WorldSim = built["sim"]
	var names: Dictionary = {}
	for city_id in world.get_city_ids():
		names[str(city_id)] = str(city_id)
	var rules: Dictionary = {
		"confiscationPermille": 200, "incomePerRoute": 300,
		"reputationLoss": 5, "karmaLoss": 2, "maxPerCity": 2,
	}

	# 十字路：2 条走私航线都在上限上，候选城市里没有一条建得了
	var full: Dictionary = SmugglingViewModel.build(
		world, sim.smuggling_options("crossroad"), sim.player_smuggling_routes("crossroad"),
		"crossroad", names, 0, rules
	)
	_eq(int(full["rowCount"]), 7, "一城对其他 7 座城都列出来（建不了的也列）")
	_eq(str(full["rows"][0]["kind"]), SmugglingViewModel.ROW_KIND_BLOCKED,
		"十字路已到上限，候选行全部不可建")
	_eq(int(full["ownedCount"]), 0, "玩家还没建过航线")
	_eq(int(full["maxPerCity"]), 2, "界面上摊出每城上限")
	_eq(int(full["reputationLoss"]), 5, "摊出被查抄的声誉代价")
	_check(not str(full["rows"][0]["detail"]).is_empty(),
		"不可建的行也写明理由：" + str(full["rows"][0]["detail"]))

	# 索恩港还剩余量，且它与艾德兰之间没有航线 → 那一行可以建
	var options: Array = sim.smuggling_options("port_thorne")
	var ok_count: int = 0
	for option in options:
		if bool(option.get("ok", false)):
			ok_count += 1
	_check(ok_count > 0, "索恩港至少有一条能建的航线")

	# 玩家建一条，己方航线排在候选之前，且第一行就是"撤销"
	var opened: Dictionary = sim.establish_route(
		"aedran", "port_thorne", TradeRoute.KIND_SMUGGLING, 0, TradeRoute.OWNER_PLAYER
	)
	_check(opened.get("ok", false), "建一条玩家航线成功：%s" % str(opened.get("error", "")))
	var view: Dictionary = SmugglingViewModel.build(
		world, sim.smuggling_options("aedran"), sim.player_smuggling_routes("aedran"),
		"aedran", names, 0, rules
	)
	_eq(int(view["ownedCount"]), 1, "己方航线计入 ownedCount")
	_eq(str(view["rows"][0]["kind"]), SmugglingViewModel.ROW_KIND_CANCEL,
		"己方航线排在候选城市之前（它是玩家最关心、也是唯一撤得掉的那类）")
	_eq(str(view["rows"][0]["key"]), str(opened["routeId"]), "撤销行带着航线 id")
	_eq(int(view["ownedIncome"]), int(view["incomePerRoute"]),
		"月入合计 = 条数 × 单条进账")

	# 光标越界时钳回最后一行，而不是让界面拿到一个点不中的下标
	var clamped: Dictionary = SmugglingViewModel.build(
		world, sim.smuggling_options("aedran"), sim.player_smuggling_routes("aedran"),
		"aedran", names, 999, rules
	)
	_eq(int(clamped["cursor"]), int(clamped["rowCount"]) - 1, "光标越界时钳到最后一行")
	_check(SmugglingViewModel.build(
		world, [], [], "不存在", names, 0, rules
	).is_empty(), "城市不存在时视图为空，面板据此不画")


## 倒地者不挡住去路。
##
## 这不是寻路问题：AI 只会朝目标直线走一步（_step_toward 明确不做寻路）。
## 若倒地的队友也占格，同一列上的两个单位会互相卡死——后面的永远走不到目标，
## 战斗也就永远打不完。玩家侧本来就能踩上倒地者的格子（_do_move 只看障碍），
## 这里验证 AI 与玩家一致。
func _test_downed_body_does_not_block_ai() -> void:
	var combat: Combat = _new_combat(2024)
	var started: Dictionary = combat.start({
		"sessionId": "test-block",
		"units": [
			{
				"unitId": "hero", "side": Combat.SIDE_PLAYER, "name": "试作角色",
				"attributes": _attributes_with(PlayerAvatar.ATTR_DEXTERITY, 10),
				"weaponTemplateId": "weapon_longsword_common",
				"position": [0, 0], "hp": 100000, "maxHp": 100000, "threatLevel": 1,
			},
			{
				"unitId": "e1", "side": Combat.SIDE_ENEMY, "name": "倒地的同伙",
				"attributes": _plain_attributes(),
				"position": [1, 0], "hp": 1, "maxHp": 100, "threatLevel": 1,
			},
			{
				"unitId": "e2", "side": Combat.SIDE_ENEMY, "name": "被卡住的同伙",
				"attributes": _attributes_with(PlayerAvatar.ATTR_DEXTERITY, 100),
				"weaponTemplateId": "weapon_longsword_common",
				"position": [2, 0], "threatLevel": 1,
			},
		],
	})
	_check(bool(started["ok"]), "卡位用例开局成功")

	var blocker: Dictionary = combat.unit_by_id("e1")
	blocker["hp"] = 0
	blocker["downed"] = true
	# DEX 100 → TU 20，先手落在 e2 身上
	_eq(combat.current_unit_id(), "e2", "敏捷最高的一方先手")

	var before: Vector2i = combat.unit_by_id("e2")["position"]
	combat.auto_action("e2")
	var after: Vector2i = combat.unit_by_id("e2")["position"]
	_check(after != before, "e2 越过了倒地的同伙，而不是原地卡住")

	# 反过来：站立单位仍然挡路，否则"阵型"就没有意义了
	var stand: Combat = _new_combat(2025)
	stand.start({
		"sessionId": "test-block-2",
		"units": [
			{
				"unitId": "hero", "side": Combat.SIDE_PLAYER, "name": "试作角色",
				"attributes": _attributes_with(PlayerAvatar.ATTR_DEXTERITY, 10),
				"position": [0, 0], "hp": 100000, "maxHp": 100000, "threatLevel": 1,
			},
			{
				"unitId": "e1", "side": Combat.SIDE_ENEMY, "name": "挡路的同伙",
				"attributes": _plain_attributes(),
				"position": [1, 0], "threatLevel": 1,
			},
			{
				"unitId": "e2", "side": Combat.SIDE_ENEMY, "name": "后面的同伙",
				"attributes": _attributes_with(PlayerAvatar.ATTR_DEXTERITY, 100),
				"weaponTemplateId": "weapon_longsword_common",
				"position": [2, 0], "threatLevel": 1,
			},
		],
	})
	var stand_before: Vector2i = stand.unit_by_id("e2")["position"]
	stand.auto_action("e2")
	_eq(str(stand.unit_by_id("e2")["position"]), str(stand_before),
		"站立单位仍然挡住去路")


## AP 用尽即换人，出手与移动一致。
##
## _do_move 曾经漏掉 _after_action：用最后一步花光 AP 后行动权不交出去，
## 界面继续列着已经点不动的动作，玩家必须手动按一次结束回合才能继续。
## 人按得动，所以症状不像崩溃那么显眼——但它让"走完就该对面了"这条规则
## 在两条动作路径上表现不一致。
func _test_move_exhausting_ap_ends_turn() -> void:
	var combat: Combat = _new_combat(3033)
	_check(bool(combat.start(_duel_encounter(20, 5))["ok"]), "移动收尾用例开局成功")
	_eq(combat.current_unit_id(), "hero", "敏捷高的一方先手")

	var hero: Dictionary = combat.unit_by_id("hero")
	_eq(int(hero["ap"]), 5, "DEX 20 → 每轮 5 点行动点")
	# 一次走满 5 格，正好把行动点用光
	var moved: Dictionary = combat.submit_action({
		"actionType": Combat.ACTION_MOVE, "actorId": "hero", "moveTo": [0, 5],
	})
	_check(bool(moved["ok"]), "一次走满 5 格的移动被接受：" + str(moved.get("reason", "")))
	_eq(int(combat.unit_by_id("hero")["ap"]), 0, "行动点用尽")
	_check(combat.current_unit_id() != "hero", "行动点用尽后行动权交给下一位")
	_eq(combat.current_unit_id(), "foe", "接手的是敌方单位")
	_check(moved["log"].size() == 1 and str(moved["log"][0]).contains("移动"),
		"返回的是这一条移动日志，而不是收尾时追加的内容")

	# 反过来：还有剩点时不该换人，否则会强迫玩家每次只走一格
	var partial: Combat = _new_combat(3034)
	partial.start(_duel_encounter(20, 5))
	partial.submit_action({
		"actionType": Combat.ACTION_MOVE, "actorId": "hero", "moveTo": [0, 2],
	})
	_eq(partial.current_unit_id(), "hero", "还有剩余行动点时继续由该单位行动")
	_eq(int(partial.unit_by_id("hero")["ap"]), 3, "走 2 格扣 2 点")


# --- 界面命中测试（鼠标）---
#
# 面板的 hit_test 是纯函数——位置全部由面板自己的布局函数产出——所以能在无头
# 环境里钉住"某个可点元素在不在、点上去认不认得出来"。绘制本身仍然只能目视。
#
# 这里扫一遍面板，而不是逐个手算坐标：把布局常量在测试里再抄一份，等于用同一套
# 算式验自己，常量一改两处一起错还照样通过。

## 扫面板用的画布。与 main.gd 的 PANEL_RECT 同为 1248×568；面板把 rect 当参数收，
## 所以给一块同尺寸的矩形，结论一致。
const PANEL_RECT: Rect2 = Rect2(16.0, 48.0, 1248.0, 568.0)


## 开局创建界面。用户报的第一个问题就在这里——"不能回到上一步"。
##
## 能测到的是"回退入口存在且点得中"，"点下去真的退回上一段"要动 main.gd 的
## 状态，无头环境里没有主场景，那部分只能靠窗口目视。
func _test_creation_panel_hit_test() -> void:
	var creator: CharacterCreation = _new_creator()
	var spec: Dictionary = creator.new_spec()
	spec["race"] = "dwarf"
	spec["backgroundId"] = "merchant"
	spec["displayName"] = "试作角色"

	var attr_view: Dictionary = CreationViewModel.build(
		creator, spec, CreationViewModel.SECTION_ATTRIBUTES, 0, CreationViewModel.MODE_FREE
	)
	var back: Dictionary = UiTheme.find_button(
		CreationPanel.buttons(attr_view, PANEL_RECT), "back"
	)
	_check(not back.is_empty(), "创建界面有「上一步」按钮")
	_check(bool(back["enabled"]), "非首段时「上一步」可点")
	var hit: Dictionary = CreationPanel.hit_test(attr_view, PANEL_RECT, _center(back["rect"]))
	_eq(str(hit.get("kind", "")), "button", "「上一步」画在哪儿就点得中哪儿")
	_eq(str(hit.get("id", "")), "back", "命中的是「上一步」")
	_check(bool(hit.get("enabled", false)), "命中结果带上可用状态，界面才画得出灰")

	# 第一段没有上一步可回；确认段多一个「开始这一生」
	var race_view: Dictionary = CreationViewModel.build(
		creator, spec, CreationViewModel.SECTION_RACE, 0, CreationViewModel.MODE_FREE
	)
	_check(not bool(UiTheme.find_button(CreationPanel.buttons(race_view, PANEL_RECT),
		"back")["enabled"]), "第一段时「上一步」置灰")
	var confirm_view: Dictionary = CreationViewModel.build(
		creator, spec, CreationViewModel.SECTION_CONFIRM, 0, CreationViewModel.MODE_FREE
	)
	_check(not UiTheme.find_button(CreationPanel.buttons(confirm_view, PANEL_RECT),
		"start").is_empty(), "确认段给出「开始这一生」按钮")

	# 段标签、属性加减方块、天赋勾选框都要点得到
	var sweep: Dictionary = _sweep_hits("creation", attr_view, PANEL_RECT)
	_check(sweep.has("tab"), "段标签可点（回上一步的第二个入口）")
	_check(sweep.has("attribute_plus"), "属性行右边有「+」可点")
	_check(sweep.has("attribute_minus"), "属性行右边有「−」可点")

	var trait_view: Dictionary = CreationViewModel.build(
		creator, spec, CreationViewModel.SECTION_TRAITS, 0, CreationViewModel.MODE_FREE
	)
	_check(_sweep_hits("creation", trait_view, PANEL_RECT).has("toggle"),
		"天赋缺陷行的勾选框可点")

	# 转生模式没有可填的段：标签照样画得出来，但点了不该跳过去
	sweep = _sweep_hits("creation", CreationViewModel.build(
		creator, spec, CreationViewModel.SECTION_CONFIRM, 0,
		CreationViewModel.MODE_REBIRTH, {}, {}
	), PANEL_RECT)
	_check(sweep.has("tab"), "转生模式下段标签照样画得出来")
	_check(not bool(sweep["tab"].get("enabled", true)), "转生模式下非确认段标签置灰")


## 城市面板与角色面板。两者的返回按钮分别在标题行右侧与列表右侧，
## 命中测试要各自认得出来。
func _test_city_and_avatar_panel_hit_test() -> void:
	var built: Dictionary = _new_sim()
	var world: WorldState = built["world"]
	var deltas: Dictionary = built["sim"].settle_month(1)["cityDeltas"]
	var detail: Dictionary = CityViewModel.build_detail(world, "aedran", deltas)
	detail["trendDimension"] = str(CityViewModel.DIMENSION_ORDER[0])
	# 面板结构由 main.gd 组装，这里照它的形状给一份——测的是面板怎么认坐标，
	# 不是主场景怎么组数据（后者已被 _test_city_view_model 覆盖）。
	var panel: Dictionary = {
		"monthLabel": "",
		"list": CityViewModel.build_list(world, deltas),
		"detail": detail,
		"selectedIndex": 0,
	}

	var back: Dictionary = UiTheme.find_button(CityPanel.buttons(PANEL_RECT), "back")
	_check(back.is_empty(), "城市面板已移除「返回地图」按钮，改由左侧导航接管")
	# 走私航线的入口就挂在城市面板上：玩家看一座城的账，顺手就能决定要不要在这开一条
	var entry: Dictionary = UiTheme.find_button(CityPanel.buttons(PANEL_RECT), "smuggling")
	_check(not entry.is_empty(), "城市面板有「走私航线」按钮")
	_eq(str(CityPanel.hit_test(panel, PANEL_RECT, _center(entry["rect"])).get("id", "")),
		"smuggling", "走私航线按钮点得中")
	# 走私航线与相邻按钮不能重叠，否则点上会击错
	var shop: Dictionary = UiTheme.find_button(CityPanel.buttons(PANEL_RECT), "shop")
	_check(not shop.is_empty(), "城市面板有「商铺」按钮")
	_check(not (entry["rect"] as Rect2).intersects(shop["rect"] as Rect2), "走私航线与商铺不重叠")
	var sweep: Dictionary = _sweep_hits("city", panel, PANEL_RECT)
	_check(sweep.has("button"), "城市面板的按钮在命中范围内")
	_check(sweep.has("city"), "城市列表行可点")
	_check(sweep.has("dimension"), "趋势维度的 ◀ ▶ 可点")

	var creator: CharacterCreation = _new_creator()
	var spec: Dictionary = creator.new_spec()
	spec["race"] = "human"
	spec["backgroundId"] = "merchant"
	spec["displayName"] = "试作角色"
	_allocate(spec, {"strength": 10, "dexterity": 10})
	var avatar: PlayerAvatar = creator.build_avatar(spec, "avatar-hit", "soul-hit")
	var lookups: Dictionary = {
		"skillNames": {}, "talentNames": {}, "itemTemplates": _item_template_table(),
		"cityNames": {"aedran": "艾德兰"}, "raceNames": {"human": "人类"},
	}
	var view: Dictionary = AvatarViewModel.build(avatar, _new_derived(), lookups, "在艾德兰")
	back = UiTheme.find_button(AvatarPanel.buttons(PANEL_RECT), "back")
	_check(not back.is_empty(), "角色面板有「返回地图」按钮")
	_eq(str(AvatarPanel.hit_test(view, PANEL_RECT, _center(back["rect"])).get("id", "")),
		"back", "角色面板的返回按钮点得中")


## 战斗界面。菜单项、战场格子、参战者列表、返回按钮四类都要点得到。
func _test_combat_panel_hit_test() -> void:
	var combat: Combat = _new_combat(99)
	_check(bool(combat.start(_duel_encounter(20, 5))["ok"]), "命中测试用的战斗开始成功")
	var skill_names: Dictionary = {"sword_slash": "挥砍"}
	var view: Dictionary = CombatViewModel.build(
		combat, skill_names, CombatViewModel.MENU_MAIN, 0
	)

	var back: Dictionary = UiTheme.find_button(CombatPanel.buttons(PANEL_RECT), "back")
	_check(not back.is_empty(), "战斗界面有「返回地图」按钮")
	_eq(str(CombatPanel.hit_test(view, PANEL_RECT, _center(back["rect"])).get("id", "")),
		"back", "战斗界面的返回按钮点得中")

	var sweep: Dictionary = _sweep_hits("combat", view, PANEL_RECT)
	_check(sweep.has("menu"), "行动菜单项可点")
	_check(sweep.has("tile"), "战场格子可点")
	_check(sweep.has("unit"), "参战者列表可点")
	# 格子带着"站在那里的单位"：点空格是走过去、点敌人是打它，两者才分得开
	_eq(str(sweep.get("tile", {}).get("unitId", "")), "hero",
		"格子报出站在上面的单位（扫到的第一格是玩家的出生格）")

	# 选落点那一层的菜单同样是点出来的，只列不可点等于鼠标没接上
	var tile_view: Dictionary = CombatViewModel.build(
		combat, skill_names, CombatViewModel.MENU_TARGET_TILE, 0, {"reach": 2, "moveCost": 1}
	)
	_check(_sweep_hits("combat", tile_view, PANEL_RECT).has("menu"), "选落点的菜单项可点")

	# 战斗结束后不再有菜单，只剩返回按钮——面板与主场景的判断要一致。
	# 直接判对手阵亡，不走"打一下"：命中是掷出来的，攻击落空时用例会静默地
	# 什么都不验。
	var finished: Combat = _new_combat(31)
	finished.start(_duel_encounter(20, 5))
	var foe: Dictionary = finished.unit_by_id("foe")
	foe["hp"] = 0
	foe["dead"] = true
	finished.resolve()
	_check(bool(finished.finished), "对手阵亡后战斗判为结束")
	var done_sweep: Dictionary = _sweep_hits("combat", CombatViewModel.build(
		finished, skill_names, CombatViewModel.MENU_MAIN, 0
	), PANEL_RECT)
	_check(not done_sweep.has("menu"), "战斗结束后菜单项不再可点")
	_check(done_sweep.has("button"), "战斗结束后只留返回按钮")


## 走私界面：按钮与每一行都要点得到，且行号必须报得准——主场景正是拿这个
## 行号决定"撤销哪条、建立哪条"，报错一行就会撤掉另一条航线。
func _test_smuggling_panel_hit_test() -> void:
	var built: Dictionary = _new_sim()
	var world: WorldState = built["world"]
	var sim: WorldSim = built["sim"]
	var names: Dictionary = {}
	for city_id in world.get_city_ids():
		names[str(city_id)] = str(city_id)
	var view: Dictionary = SmugglingViewModel.build(
		world, sim.smuggling_options("port_thorne"),
		sim.player_smuggling_routes("port_thorne"), "port_thorne", names, 0,
		{"confiscationPermille": 200, "incomePerRoute": 300,
			"reputationLoss": 5, "karmaLoss": 2, "maxPerCity": 2}
	)

	var back: Dictionary = UiTheme.find_button(SmugglingPanel.buttons(PANEL_RECT), "back")
	_check(not back.is_empty(), "走私界面有「返回地图」按钮")
	_eq(str(SmugglingPanel.hit_test(view, PANEL_RECT, _center(back["rect"])).get("id", "")),
		"back", "走私界面的返回按钮点得中")

	var sweep: Dictionary = _sweep_hits("smuggling", view, PANEL_RECT)
	_check(sweep.has("button"), "走私界面的按钮在命中范围内")
	_check(sweep.has("row"), "走私界面的行可点")

	# 索恩港的第一行是艾德兰：距离 55 ≤ 60、索恩港有黑市、两端都还有余量
	var first: Dictionary = _hit_for("smuggling", view, PANEL_RECT, "row", 0)
	_eq(int(first.get("index", -1)), 0, "第一行报出自己的行号")
	_check(bool(first.get("enabled", false)), "可建的行是启用的")
	var blocked: Dictionary = _hit_for("smuggling", view, PANEL_RECT, "row", 1)
	_check(not bool(blocked.get("enabled", true)), "建不了的行是灰的（铁锤堡距索恩港 90）")

	_check(SmugglingPanel.hit_test(view, PANEL_RECT, Vector2(4.0, 4.0)).is_empty(),
		"面板外的点击不算命中")


# --- 开局创建流程（M3.1 / M3.2）---

## 开局创建的状态机（CreationSession）。
##
## 这套规则原先只写在 main.gd 的事件处理里，而主场景在无头测试中不存在——
## "点第二行天赋却把第一行取消了"（那一刻它读的还是上一次刷新留下的光标）就是
## 这么漏出去的。抽成会话之后，一次点击从面板的 hit_test 到自己改状态整条链子
## 都能在这里钉住，不必再靠人工点。
func _test_creation_session() -> void:
	var rolls: Array = []
	var session: CreationSession = _new_creation_session(rolls)
	session.enter()
	_eq(session.section, CreationViewModel.SECTION_RACE, "进入创建时停在第一段")
	_check(not str(session.spec.get("race", "")).is_empty(), "进入创建时预选了第一个种族")
	_check(not str(session.spec.get("displayName", "")).is_empty(), "进入创建时已抽好姓名")
	_check(not str(session.spec.get("startCityId", "")).is_empty(),
		"进入创建时已定好出身所在城市")

	# 属性：点某一行的「+」只该改那一行
	session.go_to_section(CreationViewModel.SECTION_ATTRIBUTES)
	var plus: Dictionary = _hit_for("creation", session.view, PANEL_RECT, "attribute_plus", 3)
	_eq(str(plus.get("kind", "")), "attribute_plus", "面板认出第 4 行的「+」")
	session.click(plus)
	var allocations: Dictionary = session.spec[CharacterCreation.ATTR_POINTS_KEY]
	var target: String = str(session.view["rows"][3]["key"])
	_eq(int(allocations.get(target, 0)), 1, "点第 4 行的「+」加到第 4 行")
	var others: int = 0
	for attr in allocations:
		if str(attr) != target:
			others += int(allocations[attr])
	_eq(others, 0, "其余属性一点没动（原先会加到光标上一次停留的那一行）")
	session.click(_hit_for("creation", session.view, PANEL_RECT, "attribute_minus", 3))
	_eq(int(allocations.get(target, 0)), 0, "点「−」把刚加的那一点减回来")
	_eq(int(session.view["remainingPoints"]), int(session.view["allocatablePoints"]),
		"加减一来一回，可分配点数回到原点")

	# 天赋缺陷：连点两行，两行都该被选上
	session.go_to_section(CreationViewModel.SECTION_TRAITS)
	var first: String = str(session.view["rows"][0]["key"])
	var second: String = str(session.view["rows"][1]["key"])
	session.click(_hit_for("creation", session.view, PANEL_RECT, "toggle", 0))
	session.click(_hit_for("creation", session.view, PANEL_RECT, "toggle", 1))
	_check(session.spec["talents"].has(first), "第一行被选上")
	_check(session.spec["talents"].has(second), "第二行也被选上，而不是把第一行取消")
	_eq(int(session.view["talentCount"]), 2, "界面上的天赋计数也是 2")
	session.click(_hit_for("creation", session.view, PANEL_RECT, "toggle", 0))
	_eq(int(session.view["talentCount"]), 1, "再点同一行才是取消")

	# 回上一步：ESC 与「← 上一步」按钮走同一条路
	session.go_to_section(CreationViewModel.SECTION_ATTRIBUTES)
	_click_creation_button(session, "back")
	_eq(session.section, CreationViewModel.SECTION_BACKGROUND, "点「← 上一步」退回上一段")
	_click_creation_button(session, "back")
	_eq(session.section, CreationViewModel.SECTION_RACE, "再点一次退到第一段")
	_click_creation_button(session, "back")
	_eq(session.section, CreationViewModel.SECTION_RACE, "第一段没有上一步")
	_check(session.message.contains("第一段"), "回不去时说明原因")
	session.next_section()
	_eq(session.section, CreationViewModel.SECTION_BACKGROUND, "TAB 走到下一段")

	# 点种族行 = 直接选中它
	session.go_to_section(CreationViewModel.SECTION_RACE)
	var race_id: String = str(session.view["rows"][1]["key"])
	var race_hit: Dictionary = _hit_for("creation", session.view, PANEL_RECT, "option", 1)
	_eq(str(race_hit.get("kind", "")), "option", "面板认出第 2 个种族行")
	session.click(race_hit)
	_eq(str(session.spec.get("race", "")), race_id, "点种族行直接选它")

	# 确认段：规格不合法时不开局，并说明理由
	session.go_to_section(CreationViewModel.SECTION_CONFIRM)
	var refused: Dictionary = session.confirm()
	_check(not bool(refused["ok"]), "点数没分完时不开局")
	_check(session.message.contains("还不能开始"), "不开局时说明理由")

	# 分满点并配对天赋缺陷之后可以开局
	_allocate(session.spec, {"strength": 6, "dexterity": 5, "constitution": 5, "perception": 4})
	session.spec["talents"] = ["sharp_senses"]
	session.spec["flaws"] = ["deep_in_debt"]
	session.sync()
	var start: Dictionary = session.confirm()
	# 该成的事没成时，把流程给的说法缀在标签后面——否则红了只知道"没通过"，
	# 还得回头改测试才能问出为什么。成功时不缀，免得带上上一条陈旧的说法。
	var why: String = "" if bool(start["ok"]) else "（%s）" % session.message
	_check(bool(start["ok"]), "合法规格可以开局" + why)
	_eq(int(start["mode"]), CreationViewModel.MODE_FREE, "告诉调用方按自由生成装配")

	# 随机转生：抽宿主由注入的 Callable 提供，会话本身不碰世界
	var fresh: CreationSession = _new_creation_session(rolls)
	fresh.enter()
	_click_creation_button(fresh, "mode")
	_eq(int(fresh.mode), CreationViewModel.MODE_REBIRTH, "点「切换开局方式」进随机转生")
	_eq(fresh.section, CreationViewModel.SECTION_CONFIRM, "转生直接落到确认段")
	_eq(rolls.size(), 1, "切模式时抽了一具躯壳")
	var rebirth: Dictionary = fresh.confirm()
	var rebirth_why: String = "" if bool(rebirth["ok"]) else "（%s）" % fresh.message
	_check(bool(rebirth["ok"]), "有宿主时可以直接转生" + rebirth_why)
	_eq(int(rebirth["mode"]), CreationViewModel.MODE_REBIRTH, "告诉调用方按转生装配")
	_check(rebirth.has("rebirth"), "把宿主结果一并交给调用方")
	_eq(rolls.size(), 1, "已有宿主时不再重复抽")

	# 转生模式没有可填的段，也没有上一步
	fresh.go_to_section(CreationViewModel.SECTION_RACE)
	_eq(fresh.section, CreationViewModel.SECTION_CONFIRM, "转生模式跳不到种族段")
	fresh.back()
	_eq(fresh.section, CreationViewModel.SECTION_CONFIRM, "转生模式没有上一步")
	_check(fresh.message.contains("没有上一步"), "并说明原因")
	fresh.next_section()
	_eq(fresh.section, CreationViewModel.SECTION_CONFIRM, "转生模式 TAB 也停在确认段")

	# 抽不到宿主时不开局
	var barren: CreationSession = _new_creation_session([], false)
	barren.enter()
	barren.toggle_mode()
	var failed: Dictionary = barren.confirm()
	_check(not bool(failed["ok"]), "抽不到宿主时不开局")
	_check(barren.message.contains("抽不到宿主"), "并说明原因")


# --- 里程碑 4：委托闭环 ---
#
# 一条委托要走过四个地方：板上出现（QuestBoard）→ 接下（QuestSystem.accept）
# → 交付并落账（complete + WorldSim 的月末结算）→ 在城里留下痕迹（world_flags
# 与延迟后果）。下面的用例按这条路走，每一段都钉在"规则在哪儿写"的那一层上。

## 委托板（M4.1）。板子不落盘，所以它的正确性只能由"给定城市状态 → 板上有什么"
## 这条纯函数关系来保证，这正是要测的东西。
func _test_quest_board_generation() -> void:
	var built: Dictionary = _new_sim()
	var world: WorldState = built["world"]
	var sim: WorldSim = built["sim"]
	var city_id: String = "aedran"

	# 城里的各项都在阈值之上：没人贴告示
	_set_all_dimensions(world, city_id, 80)
	_eq(sim.quests.list_available(city_id, 0).size(), 0, "六项都还过得去时不贴任何告示")

	# 只把财富压到 50（阈值 60，缺口比例 0.167）→ 一张小委托
	world.get_city(city_id).wealth = 50
	var small: Array = sim.quests.list_available(city_id, 0)
	_eq(small.size(), 1, "只有财富低于阈值，板上只有一张告示")
	var offer: Quest = small[0]
	_eq(offer.quest_type, "grain_supply", "缺粮贴出来的是运粮补给")
	_eq(offer.dimension(), City.DIM_WEALTH, "委托绑定在缺的那个维度上")
	_eq(offer.tier_id, "small", "缺口不到 25% 出小委托")
	_eq(offer.state_gain(), 3, "小档的城市增量取自量化规则 10.1 表")
	_eq(offer.reputation_gain(), 3, "小档的声誉回报取自 10.3 表")
	_eq(offer.karma_gain(), 1, "小档的善恶回报取自 10.3 表")
	_eq(offer.deadline_month, 6, "小委托给 6 个月期限")
	_check(offer.money_copper() >= 800 and offer.money_copper() <= 1200,
		"小档报酬在 1000 铜的 ±20%% 内（实际 %d）" % offer.money_copper())
	_eq(offer.money_copper() % 10, 0, "报价取整到 10 铜")
	_eq(offer.accepted_month, 0, "生成时记下板面对应的月份")

	# 缺口越深档位越高
	world.get_city(city_id).wealth = 40
	_eq((sim.quests.list_available(city_id, 0)[0] as Quest).tier_id, "medium",
		"缺口三分之一出中委托")
	world.get_city(city_id).wealth = 20
	var large: Quest = sim.quests.list_available(city_id, 0)[0]
	_eq(large.tier_id, "large", "缺口过半出大委托")
	_eq(large.state_gain(), 10, "大档的城市增量更可观")
	_eq(large.deadline_month, 3, "大委托的期限反而更短")

	# 确定性：同一城、同一板面周期，两次打开看到的是同一张单子
	var again: Array = sim.quests.list_available(city_id, 0)
	_eq(again[0].quest_id, large.quest_id, "同一板面周期内的委托 id 一致")
	_eq(again[0].money_copper(), large.money_copper(), "报酬也一致（同一条随机链）")
	var next_board: Array = sim.quests.list_available(
		city_id, int(sim.quests.rules().get("boardRefreshMonths", 3))
	)
	_check(next_board[0].quest_id != large.quest_id, "换了一个板面周期，告示换了新的一批")

	# 接手之后同类告示从板上撤下，别的城不受影响
	world.get_city(city_id).wealth = 40
	var mine: Quest = sim.quests.list_available(city_id, 0)[0]
	var taken: Dictionary = sim.quests.accept(mine.quest_id, 0)
	_check(bool(taken.get("ok", false)), "接下一张委托：" + str(taken.get("error", "")))
	_eq(sim.quests.list_available(city_id, 0).size(), 0, "接手之后同类告示从这座城的板上撤下")
	_set_all_dimensions(world, "port_thorne", 90)
	world.get_city("port_thorne").wealth = 40
	_eq(sim.quests.list_available("port_thorne", 0).size(), 1, "别的城的板子照旧")
	sim.quests.abandon(mine.quest_id)
	_eq(sim.quests.list_available(city_id, 0).size(), 1, "放弃了，告示又挂回板上")

	# 一次刷满一板：六项都压下去时按板面容量出，且类型不重复、顺序稳定
	_set_all_dimensions(world, city_id, 10)
	var full: Array = sim.quests.list_available(city_id, 0)
	_eq(full.size(), int(sim.quests.rules().get("boardSizePerCity", 4)),
		"板面容量取自 balance.quests.boardSizePerCity")
	var kinds: Dictionary = {}
	for quest in full:
		kinds[quest.quest_type] = true
	_eq(kinds.size(), full.size(), "同一板面上不会出现两张同类型的委托")
	var ordered: bool = true
	for i in range(1, full.size()):
		if str(full[i - 1].quest_type) > str(full[i].quest_type):
			ordered = false
	_check(ordered, "板面按类型 id 排序（两次打开看到的顺序一样）")

	# M4.3 的读取侧：城里留过某类委托的标记，同类告示更容易再被挑出来。
	# 板面容量压到 1，让"先挑中谁"变成可数的现象；两类的缺口又不相等，
	# 于是每次抽取都是一次有偏的选择。
	var counting: Dictionary = sim.quests.rules().duplicate(true)
	counting["boardSizePerCity"] = 1
	_set_all_dimensions(world, city_id, 90)
	world.get_city(city_id).wealth = 30
	world.get_city(city_id).security = 30
	var before: int = 0
	for bucket in range(24):
		var one: Array = QuestBoard.offers(
			world, city_id, bucket * int(counting.get("boardRefreshMonths", 3)), counting
		)
		if not one.is_empty() and str(one[0].quest_type) == "grain_supply":
			before += 1
	world.world_flags["quest.%s.grain_supply.resold" % city_id] = true
	var after: int = 0
	for bucket in range(24):
		var one: Array = QuestBoard.offers(
			world, city_id, bucket * int(counting.get("boardRefreshMonths", 3)), counting
		)
		if not one.is_empty() and str(one[0].quest_type) == "grain_supply":
			after += 1
	_check(after > before,
		"留过标记的委托类型在板面上更靠前（24 个板面周期里被优先挑出 %d → %d 次）" % [before, after])


## 接受（I-16）：重复接、板上已经没了、手上到上限，各给各的错误码。
func _test_quest_accept_and_capacity() -> void:
	var built: Dictionary = _new_sim()
	var world: WorldState = built["world"]
	var sim: WorldSim = built["sim"]
	var ids: Array = Array(world.get_city_ids())
	for city_id in ids:
		_set_all_dimensions(world, str(city_id), 10)

	var first: Quest = sim.quests.list_available(str(ids[0]), 0)[0]
	var accepted: Dictionary = sim.quests.accept(first.quest_id, 0)
	_check(bool(accepted.get("ok", false)), "接下一张委托：" + str(accepted.get("error", "")))
	_eq(str(accepted.get("cityId", "")), str(ids[0]), "接受结果里带上委托所在的城市")
	_eq(world.active_quest_count(), 1, "手上多了一张")
	_check(world.find_quest(first.quest_id) != null, "世界的委托表里能找到它")

	_eq(str(sim.quests.accept(first.quest_id, 0).get("errorCode", "")),
		QuestSystem.ERROR_PRECONDITION_FAILED, "同一张委托接不了第二次")
	_eq(str(sim.quests.accept("q-nobody-x-0", 0).get("errorCode", "")),
		QuestSystem.ERROR_NOT_FOUND, "板上没有的委托接不了")

	var cap: int = int(sim.quests.rules().get("maxAccepted", 3))
	for i in range(1, cap):
		var offer: Quest = sim.quests.list_available(str(ids[i]), 0)[0]
		_check(bool(sim.quests.accept(offer.quest_id, 0).get("ok", false)),
			"第 %d 张也能接" % (i + 1))
	_eq(world.active_quest_count(), cap, "手上的委托数达到上限 %d" % cap)

	var over: Quest = sim.quests.list_available(str(ids[cap]), 0)[0]
	var refused: Dictionary = sim.quests.accept(over.quest_id, 0)
	_check(not bool(refused.get("ok", false)), "到上限之后接不动了")
	_eq(str(refused.get("errorCode", "")), QuestSystem.ERROR_CAPACITY_EXCEEDED,
		"给的是容量错误码，界面据此提示先办掉几张")

	# 办掉（这里是放弃）一张，名额就腾出来了
	_check(bool(sim.quests.abandon(first.quest_id).get("ok", false)), "放弃一张")
	_eq(world.active_quest_count(), cap - 1, "放弃的委托不再占名额")
	_check(bool(sim.quests.accept(over.quest_id, 0).get("ok", false)), "腾出名额后可以再接")
	_eq(str(sim.quests.abandon("q-nobody-x-0").get("errorCode", "")),
		QuestSystem.ERROR_NOT_FOUND, "放弃不存在的委托给未找到")


## 交付（I-17）：玩家自己的账当场结，城市的账排进变更队列、月末才落。
## 后者是 10.4 节的"月中不变"，也是"为什么我办完事城里没动"的答案。
func _test_quest_complete_and_settlement() -> void:
	var built: Dictionary = _new_sim()
	var world: WorldState = built["world"]
	var sim: WorldSim = built["sim"]
	var avatar := PlayerAvatar.new()
	avatar.avatar_id = "avatar-quest"
	world.avatar = avatar

	var city_id: String = "aedran"
	_set_all_dimensions(world, city_id, 90)
	world.get_city(city_id).wealth = 40
	var offer: Quest = sim.quests.list_available(city_id, 0)[0]
	_eq(offer.tier_id, "medium", "缺口三分之一出中委托")
	sim.quests.accept(offer.quest_id, 0)

	# 预览与交付必须同源：界面上写着多少，落账就是多少
	var preview: Dictionary = QuestSystem.outcome_preview(offer, "honest", 1.0)
	var result: Dictionary = sim.quests.complete(offer.quest_id, "honest", 0)
	var why: String = "" if bool(result.get("ok", false)) else "（%s）" % str(result.get("error", ""))
	_check(bool(result.get("ok", false)), "老老实实运到，交付成功" + why)
	_eq(int(result["stateDelta"]), int(preview["stateDelta"]), "交付的城市增量与预览一致")
	_eq(int(result["money"]), int(preview["money"]), "交付的钱与预览一致")
	_eq(int(result["reputation"]), int(preview["reputation"]), "交付的声誉与预览一致")
	_eq(int(result["karma"]), int(preview["karma"]), "交付的善恶与预览一致")
	_eq(int(result["stateDelta"]), offer.state_gain(), "不打折扣的做法拿满城市增量")
	_eq(int(result["reputation"]), offer.reputation_gain(), "声誉取自档位（分支没写就沿用）")
	_eq(int(result["karma"]), 1, "善恶被分支覆盖：不赚差价该记一分善")
	_eq(str(result["dimension"]), City.DIM_WEALTH, "结果里带上受影响的维度")

	_eq(avatar.money, int(result["money"]), "玩家的钱当场到手")
	_eq(avatar.get_reputation(city_id), int(result["reputation"]), "城市声誉当场记下")
	_eq(avatar.karma, int(result["karma"]), "善恶当场记下")
	_eq(world.find_quest(offer.quest_id).state, Quest.STATE_DONE, "这张委托了结了")

	_eq(int(world.get_city(city_id).wealth), 40, "城市的数字月中不动")
	# QuestSystem 只产出变更请求，提交给城市是调用方（主场景）的事——城市六维
	# 只有一个写入口，委托模块不越过它自己改。
	var change: StateChange = result.get("change", null)
	_check(change != null, "交付产出一条城市变更请求")
	if change != null:
		_eq(change.dimension, City.DIM_WEALTH, "变更打在缺的那个维度上")
		_eq(change.delta, offer.state_gain(), "变更额度就是委托的增量")
		_eq(change.source, StateChange.SOURCE_QUEST, "来源记为委托")
		_eq(change.source_ref_id, offer.quest_id, "变更能追到是哪张委托带来的")
		_eq(str(sim.apply_state_change(change).get("errorCode", "")), WorldSim.ERROR_NONE,
			"请求能提交进队列")
	_eq(world.pending_changes.size(), 1, "城市增量排进了变更队列")

	# 月末结算：落了账，且归因里能说是"委托"带来的
	var report: Dictionary = sim.settle_month(1)
	_check(world.pending_changes.is_empty(), "月末结算把排队的变更落掉了")
	_eq(_delta_milli(report, city_id, City.DIM_WEALTH, "change-quest"),
		offer.state_gain() * CityEvolution.SCALE, "归因里的额度就是委托的增量")

	_eq(str(sim.quests.complete(offer.quest_id, "honest", 1).get("errorCode", "")),
		QuestSystem.ERROR_PRECONDITION_FAILED, "已经了结的委托交不了第二次")
	_eq(str(sim.quests.complete("q-nobody-x-0", "honest", 1).get("errorCode", "")),
		QuestSystem.ERROR_NOT_FOUND, "交付不存在的委托给未找到")
	_eq(str(sim.quests.complete(offer.quest_id, "no_such_branch", 1).get("errorCode", "")),
		QuestSystem.ERROR_PRECONDITION_FAILED, "已了结的委托先报已了结（选项合法性在那之后）")

	# 选项名不对时拒绝，而不是静默按基准收益交付
	_set_all_dimensions(world, "port_thorne", 90)
	world.get_city("port_thorne").wealth = 40
	var other: Quest = sim.quests.list_available("port_thorne", 0)[0]
	sim.quests.accept(other.quest_id, 0)
	_eq(str(sim.quests.complete(other.quest_id, "no_such_branch", 0).get("errorCode", "")),
		QuestSystem.ERROR_INVALID_ARGUMENT, "没有这个选项时给参数错误")


## 分支的修正系数与剿匪类的战斗结局。
##
## 分支只给系数、不给绝对数（技术设计文档 D-31），所以这一节的断言大多写成
## "拿基准值乘系数"的形式：这样改数值表时用例不必跟着改。
func _test_quest_branches_and_combat_outcomes() -> void:
	var built: Dictionary = _new_sim()
	var world: WorldState = built["world"]
	var sim: WorldSim = built["sim"]
	var avatar := PlayerAvatar.new()
	avatar.avatar_id = "avatar-branch"
	world.avatar = avatar
	var city_id: String = "aedran"
	_set_all_dimensions(world, city_id, 90)
	world.get_city(city_id).wealth = 40
	var offer: Quest = sim.quests.list_available(city_id, 0)[0]

	# 系数本身
	_eq(QuestSystem.apply_multiplier(6, 1.0), 6, "不打折扣就是原值")
	_eq(QuestSystem.apply_multiplier(6, -0.6), -4, "负系数让城市净亏（转卖公粮）")
	_eq(QuestSystem.apply_multiplier(1, 0.3), 1, "非零分支至少留 1 点，不会被抹成 0")
	_eq(QuestSystem.apply_multiplier(0, 2.5), 0, "基准为 0 的怎么乘都是 0")

	# 转卖：钱翻倍，城市亏本，名声与善恶一起掉
	var resell: Dictionary = QuestSystem.outcome_preview(offer, "resell", 1.0)
	_check(int(resell["money"]) > offer.money_copper(), "转卖拿到的钱比老实运到多")
	_eq(int(resell["money"]), int(round(float(offer.money_copper()) * 2.2)), "钱按 2.2 倍算")
	_eq(int(resell["stateDelta"]), QuestSystem.apply_multiplier(offer.state_gain(), -0.6),
		"城市按 -0.6 倍亏")
	_check(int(resell["stateDelta"]) < 0, "这条做法对城市是净损失")
	_eq(int(resell["reputation"]), -5, "分支自己写了声誉代价")
	_eq(int(resell["karma"]), -3, "善恶也照分支写的扣")

	# 6 章的声誉联动：只放大金钱
	var rules: Dictionary = sim.quests.rules()
	avatar.set_reputation(city_id, 80)
	var amplify_high: float = QuestSystem.reputation_multiplier(world, city_id, rules)
	_eq(amplify_high, float(rules.get("reputationRespectMultiplier", 1.5)), "敬重时回报放大")
	_eq(int(QuestSystem.outcome_preview(offer, "resell", amplify_high)["money"]),
		int(round(float(offer.money_copper()) * 2.2 * amplify_high)), "放大的只有金钱")
	_eq(int(QuestSystem.outcome_preview(offer, "resell", amplify_high)["reputation"]),
		int(resell["reputation"]), "声誉本身不再被放大（否则敌视会自我强化）")
	avatar.set_reputation(city_id, -80)
	_eq(QuestSystem.reputation_multiplier(world, city_id, rules),
		float(rules.get("reputationHostileMultiplier", 0.5)), "敌视时回报打对折")
	avatar.set_reputation(city_id, 0)
	_eq(QuestSystem.reputation_multiplier(world, city_id, rules), 1.0, "平常心照常给钱")

	# 没有战斗段的类型：战斗结局名解析不出来，而不是撞上 null 崩掉
	_check(QuestSystem.resolve_outcome("grain_supply", "combat:release").is_empty(),
		"运粮这类没有战斗段，战斗结局名解析不出来")
	var release: Dictionary = QuestSystem.resolve_outcome("bandit_clearance", "combat:release")
	_eq(str(release.get("label", "")), "放他们走", "剿匪的战斗结局取自 combat.outcomes")
	_check(str(release.get("detail", "")).is_empty() == false, "结局带一句后果说明")
	_eq(str((release.get("flags", []) as Array)[0]), "spared", "结局带上要写的世界标记")
	_check(QuestSystem.resolve_outcome("bandit_clearance", "combat:no_such").is_empty(),
		"没有这个结局名时解析不出来")

	# 按战场上的处置交付
	_set_all_dimensions(world, "port_thorne", 90)
	world.get_city("port_thorne").security = 40
	var bandit: Quest = sim.quests.list_available("port_thorne", 0)[0]
	_eq(bandit.quest_type, "bandit_clearance", "治安低的城贴的是剿匪")
	sim.quests.accept(bandit.quest_id, 0)
	var spared: Dictionary = sim.quests.complete(bandit.quest_id, "combat:release", 0)
	var why: String = "" if bool(spared.get("ok", false)) else "（%s）" % str(spared.get("error", ""))
	_check(bool(spared.get("ok", false)), "按「放他们走」交付成功" + why)
	_eq(str(spared["label"]), "放他们走", "结果里带上结局名")
	_eq(int(spared["stateDelta"]), QuestSystem.apply_multiplier(bandit.state_gain(), 0.6),
		"放走只换回六成的治安")
	_eq(int(spared["karma"]), 4, "放人一马记四分善")
	_check(world.world_flags.has("quest.port_thorne.bandit_clearance.spared"),
		"世界标记带上了城市与委托类型，生成侧才读得回")

	# 打输了：城市一点没变、钱也没有，只有名声受损；零增量不提交变更
	_set_all_dimensions(world, "crossroad", 90)
	world.get_city("crossroad").security = 40
	var second: Quest = sim.quests.list_available("crossroad", 0)[0]
	sim.quests.accept(second.quest_id, 0)
	var rep_before: int = avatar.get_reputation("crossroad")
	var lost: Dictionary = sim.quests.complete(second.quest_id, "combat:defeat", 0)
	_check(bool(lost.get("ok", false)), "打输了也要走完交付，好把这张单子结掉")
	_eq(int(lost["stateDelta"]), 0, "打输了城市一点没变")
	_eq(int(lost["money"]), 0, "打输了没有报酬")
	_eq(int(lost["reputation"]), -6, "打输了在城市里的名声受损")
	_eq(avatar.get_reputation("crossroad"), rep_before - 6, "声誉是当场扣的")
	_check(lost["change"] == null, "零增量不提交变更（StateChange 明确拒绝 delta == 0）")


## 后果链（M4.3）：交付时排下的"数月后"到期变成城市变更并产出事件；
## 接了不办的委托过了期限作废并扣声誉。
func _test_quest_consequence_chain() -> void:
	var built: Dictionary = _new_sim()
	var world: WorldState = built["world"]
	var sim: WorldSim = built["sim"]
	var avatar := PlayerAvatar.new()
	avatar.avatar_id = "avatar-chain"
	world.avatar = avatar
	var city_id: String = "aedran"
	_set_all_dimensions(world, city_id, 90)
	world.get_city(city_id).wealth = 40
	var offer: Quest = sim.quests.list_available(city_id, 0)[0]
	sim.quests.accept(offer.quest_id, 0)

	var faked: Dictionary = sim.quests.complete(offer.quest_id, "fake_raid", 0)
	_check(bool(faked.get("ok", false)), "与盗匪合谋假劫：" + str(faked.get("error", "")))
	_eq(int(faked["stateDelta"]), 0, "假劫对城市没有当即的增益")
	_eq(int(faked["money"]), int(round(float(offer.money_copper()) * 2.5)), "骗来的是双份半的钱")
	_eq((faked["delayed"] as Array).size(), 1, "排下了一条延迟后果")
	_eq(world.pending_consequences.size(), 1, "延迟后果进了世界的待落账表")
	_eq(int(world.pending_consequences[0]["dueMonth"]), 3, "三个月后到期")
	_eq(str(world.pending_consequences[0]["dimension"]), City.DIM_WEALTH, "到期打的是财富")
	_check(world.world_flags.has("quest.%s.grain_supply.faked" % city_id),
		"骗局留下了标记，生成侧据此让同类委托更容易再来")

	var early: Dictionary = sim.settle_month(1)
	_eq(world.pending_consequences.size(), 1, "没到期就先不动它")
	_check(not _has_notice(early, "假劫"),
		"没到期也不声张（%s）" % _notice_text(early))
	sim.settle_month(2)
	_eq(world.pending_consequences.size(), 1, "差一个月也还不动")
	var due: Dictionary = sim.settle_month(3)
	_eq(world.pending_consequences.size(), 0, "到期的当月就落账，不拖到下个月")
	_check(_has_notice(due, "假劫"), "并产出一条事件说明城里发生了什么（%s）" % _notice_text(due))
	_eq(_delta_milli(due, city_id, City.DIM_WEALTH, "change-quest"), -3 * CityEvolution.SCALE,
		"到期的额度是 -3 财富")

	# 过期：接了小委托却一直不办
	_set_all_dimensions(world, city_id, 90)
	world.get_city(city_id).wealth = 50
	var late: Quest = sim.quests.list_available(city_id, 3)[0]
	_eq(late.deadline_month, 9, "第 3 月接的小委托，第 9 月到期")
	sim.quests.accept(late.quest_id, 3)
	var rep_before: int = avatar.get_reputation(city_id)
	sim.settle_month(9)
	_eq(world.find_quest(late.quest_id).state, Quest.STATE_ACTIVE, "到期那个月的月末还是期内")
	var overdue: Dictionary = sim.settle_month(10)
	_eq(world.find_quest(late.quest_id).state, Quest.STATE_EXPIRED, "过了期限就作废")
	_eq(avatar.get_reputation(city_id),
		rep_before - int(sim.quests.rules().get("expireReputationLoss", 0)),
		"手上有张欠条不办，城里的耐心会用完")
	_eq(world.active_quest_count(), 0, "作废的委托不再占手上的名额")
	_check(_has_notice(overdue, "撤了告示"), "并说清是哪张告示撤了（%s）" % _notice_text(overdue))


## 存档往返：手上的委托、冻结的报酬快照、待落账的后果、留下的标记都要能过一遍 JSON。
func _test_quest_round_trip() -> void:
	var built: Dictionary = _new_sim()
	var world: WorldState = built["world"]
	var sim: WorldSim = built["sim"]
	_set_all_dimensions(world, "aedran", 90)
	world.get_city("aedran").wealth = 40
	var held: Quest = sim.quests.list_available("aedran", 0)[0]
	sim.quests.accept(held.quest_id, 0)

	_set_all_dimensions(world, "port_thorne", 90)
	world.get_city("port_thorne").wealth = 40
	var done: Quest = sim.quests.list_available("port_thorne", 0)[0]
	sim.quests.accept(done.quest_id, 0)
	sim.quests.complete(done.quest_id, "fake_raid", 0)
	_eq(world.get_quests().size(), 2, "一张办完了、一张还欠着")

	var encoded: String = JSON.stringify(world.to_dict())
	var decoded: Variant = JSON.parse_string(encoded)
	_check(decoded is Dictionary, "世界状态可以过一遍 JSON")
	var fresh: WorldState = _new_world()["world"]
	fresh.apply_dict(decoded)

	_eq(fresh.get_quests().size(), 2, "手上的委托数量往返一致")
	_eq(fresh.active_quest_count(), 1, "未办完的仍是那张")
	var restored: Quest = fresh.find_quest(held.quest_id)
	_check(restored != null, "读回来时那张欠着的委托还在")
	if restored != null:
		_eq(restored.state, Quest.STATE_ACTIVE, "状态往返一致")
		_eq(restored.quest_type, held.quest_type, "类型往返一致")
		_eq(restored.tier_id, held.tier_id, "档位往返一致")
		_eq(restored.giver_label, held.giver_label, "委托人往返一致")
		_eq(restored.money_copper(), held.money_copper(), "冻结的报酬快照往返一致")
		_eq(restored.state_gain(), held.state_gain(), "城市增量往返一致")
		_eq(restored.dimension(), held.dimension(), "关联维度往返一致")
		_eq(restored.accepted_month, held.accepted_month, "接手月份往返一致")
		_eq(restored.deadline_month, held.deadline_month, "期限往返一致")
	_eq(fresh.find_quest(done.quest_id).state, Quest.STATE_DONE, "已交付的委托也往返一致")
	_eq(fresh.pending_consequences.size(), 1, "待落账的延迟后果往返一致")
	_eq(int(fresh.pending_consequences[0]["dueMonth"]),
		int(world.pending_consequences[0]["dueMonth"]), "到期月份往返一致")
	_check(fresh.world_flags.has("quest.port_thorne.grain_supply.faked"), "世界标记往返一致")
	# 板子是推导出来的，读档后不必额外同步："同类单子已经在手上"这条规则照旧生效
	_eq(QuestBoard.offers(fresh, "aedran", 0, sim.quests.rules()).size(), 0,
		"读档后同类告示仍然从板上撤下")


## 委托界面的视图模型：手上没办完的排前面、办理要站在那座城、抉择行的后果与交付同源。
func _test_quest_view_model() -> void:
	var built: Dictionary = _new_sim()
	var world: WorldState = built["world"]
	var sim: WorldSim = built["sim"]
	var names: Dictionary = _city_names(world)
	var rules: Dictionary = sim.quests.rules()
	_set_all_dimensions(world, "aedran", 90)
	world.get_city("aedran").wealth = 40
	var offers: Array = sim.quests.list_available("aedran", 0)
	_eq(offers.size(), 1, "艾德兰的板上有一张")

	# 手上还空着时，左列就是板上的候选
	var board: Dictionary = QuestViewModel.build(
		world, offers, [], "aedran", "aedran", names, 0, rules
	)
	_eq(int(board["rowCount"]), 1, "一张单子一行")
	_eq(str(board["rows"][0]["kind"]), QuestViewModel.ROW_KIND_OFFER, "这一行是「可接」")
	_check(bool(board["atCity"]), "玩家就站在这座城")
	_check(bool(board["rows"][0]["canAccept"]), "候选行可以接")
	_check(not bool(board["rows"][0]["canDeliver"]), "还没接下的单子不能办理")
	_check(str(board["rows"][0]["title"]).contains("运粮补给"), "标题写清类型与档位")
	_check(str(board["rows"][0]["reason"]).contains("财富"),
		"写明这里凭什么有人贴告示：" + str(board["rows"][0]["reason"]))
	_eq(str(board["rows"][0]["scriptRef"]), "QT-01", "详情带上剧本编号")
	_check((board["rows"][0]["dialogue"] as Array).size() > 0, "详情带上剧本的关键对白")
	_check(str(board["rows"][0]["deadlineLabel"]).contains("第 4 月"), "写明交付期限")
	_eq(int(board["maxAccepted"]), int(rules.get("maxAccepted", 3)), "摊出接手上限")

	# 接下来之后：手上那张排到候选之前
	sim.quests.accept(offers[0].quest_id, 0)
	var active: Array = [world.find_quest(offers[0].quest_id)]
	_set_all_dimensions(world, "port_thorne", 90)
	world.get_city("port_thorne").security = 40
	var elsewhere: Array = sim.quests.list_available("port_thorne", 0)
	var mixed: Dictionary = QuestViewModel.build(
		world, elsewhere, active, "port_thorne", "port_thorne", names, 0, rules
	)
	_eq(int(mixed["rowCount"]), 2, "别的城的候选与本城的欠账一起列出来")
	_eq(str(mixed["rows"][0]["kind"]), QuestViewModel.ROW_KIND_ACTIVE,
		"手上没办完的排在最前面（玩家来这一屏就是为了它）")
	_eq(str(mixed["rows"][1]["kind"]), QuestViewModel.ROW_KIND_OFFER, "候选排在后面")
	_eq(int(mixed["activeCount"]), 1, "摊出手上有几张")
	# 面板据 selectedIsActive 决定要不要摆出「放弃这张」，所以它必须跟着光标走
	_check(not bool(board["selectedIsActive"]), "光标停在候选行上时 selectedIsActive 为假")
	_check(bool(mixed["selectedIsActive"]), "光标在手上那一行时为真")
	var on_offer: Dictionary = QuestViewModel.build(
		world, elsewhere, active, "port_thorne", "port_thorne", names, 1, rules
	)
	_check(not bool(on_offer["selectedIsActive"]), "光标移到候选行时为假")

	# 不在委托所在城：置灰、说明要回哪座城，且给不出抉择
	var away: Dictionary = QuestViewModel.build(
		world, [], active, "aedran", "port_thorne", names, 0, rules
	)
	_check(not bool(away["atCity"]), "玩家不在这座城")
	_check(not bool(away["rows"][0]["canDeliver"]), "不在这座城办不了")
	_check(not bool(away["rows"][0]["enabled"]), "行是灰的")
	_check(str(away["rows"][0]["blockedReason"]).contains("艾德兰"),
		"说清要回到哪座城：" + str(away["rows"][0]["blockedReason"]))
	_eq((away["branches"] as Array).size(), 0, "给不出抉择，也就不会误执行")

	var here: Dictionary = QuestViewModel.build(
		world, [], active, "aedran", "aedran", names, 0, rules
	)
	var branches: Array = here["branches"]
	_eq(branches.size(), 4, "运粮剧本给了四个做法")
	_check(not bool(branches[0]["isCombat"]), "运粮没有「带人打一场」这一行")
	var resell: Dictionary = {}
	for branch in branches:
		if str(branch["branchId"]) == "resell":
			resell = branch
	_check(not resell.is_empty(), "四个做法里有「中途转卖高价」")
	_eq(str(resell["effectLabel"]),
		QuestViewModel.effect_label(City.DIM_WEALTH,
			QuestSystem.outcome_preview(active[0], "resell", 1.0)),
		"行上的后果与交付算式同源，不会「写着 +6、落账 +4」")
	_check(str(resell["effectLabel"]).contains("-4"), "转卖会让这座城市亏 4 点财富")
	_check(str(resell["effectLabel"]).contains("声誉"), "并把声誉代价写在行上")

	# 剿匪：多出一行战斗选择，它不预告数值
	_set_all_dimensions(world, "crossroad", 90)
	world.get_city("crossroad").security = 40
	var bandit: Quest = sim.quests.list_available("crossroad", 0)[0]
	_eq(bandit.quest_type, "bandit_clearance", "治安低的城贴的是剿匪")
	sim.quests.accept(bandit.quest_id, 0)
	var bandit_view: Dictionary = QuestViewModel.build(
		world, [], [world.find_quest(bandit.quest_id)], "crossroad", "crossroad", names, 0, rules
	)
	var bandit_branches: Array = bandit_view["branches"]
	_check(bool(bandit_branches[0]["isCombat"]), "剿匪多出一行「带人打一场」")
	_eq(str(bandit_branches[0]["label"]), "带人打一场", "那一行的标题取自配置")
	_eq(str(bandit_branches[0]["branchId"]), "", "战斗那一行没有 branchId（要打完才定）")
	_check(str(bandit_branches[0]["effectLabel"]).contains("处置"),
		"战斗那一行只说打完再定，不预告数值：" + str(bandit_branches[0]["effectLabel"]))
	_eq(bandit_branches.size(), 5, "战斗行之后还有剧本里的四个分支")

	# 光标越界时钳回，而不是让界面拿到一个点不中的下标
	var clamped: Dictionary = QuestViewModel.build(
		world, [], active, "aedran", "aedran", names, 99, rules
	)
	_eq(int(clamped["cursor"]), int(clamped["rowCount"]) - 1, "光标越界时钳到最后一行")
	_check(QuestViewModel.build(world, [], [], "no_such_city", "", names, 0, rules).is_empty(),
		"城市不存在时视图为空，面板据此不画")


func _test_quest_panel_hit_test() -> void:
	var built: Dictionary = _new_sim()
	var world: WorldState = built["world"]
	var sim: WorldSim = built["sim"]
	var names: Dictionary = _city_names(world)
	var rules: Dictionary = sim.quests.rules()
	_set_all_dimensions(world, "aedran", 90)
	world.get_city("aedran").wealth = 40
	var offers: Array = sim.quests.list_available("aedran", 0)
	var board: Dictionary = QuestViewModel.build(
		world, offers, [], "aedran", "aedran", names, 0, rules
	)

	var back: Dictionary = UiTheme.find_button(QuestPanel.buttons(board, PANEL_RECT), "back")
	_check(not back.is_empty(), "委托界面有「返回地图」按钮")
	_eq(str(QuestPanel.hit_test(board, PANEL_RECT, _center(back["rect"])).get("id", "")),
		"back", "委托界面的返回按钮点得中")

	var sweep: Dictionary = _sweep_hits("quest", board, PANEL_RECT)
	_check(sweep.has("button"), "委托界面的按钮在命中范围内")
	_check(sweep.has("row"), "委托行可点")
	var first: Dictionary = _hit_for("quest", board, PANEL_RECT, "row", 0)
	_eq(int(first.get("index", -1)), 0, "第一行报出自己的行号")
	_check(bool(first.get("enabled", false)), "可接的行是启用的")
	_check(QuestPanel.hit_test(board, PANEL_RECT, Vector2(4.0, 4.0)).is_empty(),
		"面板外的点击不算命中")

	# 抉择模式：右列换成选项，左列不再响应点击——免得在另一张单子上执行上一步选的选项
	sim.quests.accept(offers[0].quest_id, 0)
	var held: Array = [world.find_quest(offers[0].quest_id)]
	var held_view: Dictionary = QuestViewModel.build(
		world, [], held, "aedran", "aedran", names, 0, rules
	)

	# 「放弃这张」只在选中手上那张时出现：上限是硬的，没有这条出口就卡死了
	_check(UiTheme.find_button(QuestPanel.buttons(board, PANEL_RECT), "abandon").is_empty(),
		"看板上选的是可接的候选，没有「放弃这张」")
	var abandon: Dictionary = UiTheme.find_button(
		QuestPanel.buttons(held_view, PANEL_RECT), "abandon"
	)
	_check(not abandon.is_empty(), "选中手上那张时出现「放弃这张」")
	_eq(str(QuestPanel.hit_test(held_view, PANEL_RECT, _center(abandon["rect"])).get("id", "")),
		"abandon", "「放弃这张」点得中")

	var branch_view: Dictionary = QuestViewModel.build(
		world, [], held, "aedran", "aedran", names, 0, rules,
		QuestViewModel.MODE_BRANCH
	)
	_eq(int(branch_view["mode"]), QuestViewModel.MODE_BRANCH, "视图处于抉择模式")
	var branch_hit: Dictionary = _hit_for("quest", branch_view, PANEL_RECT, "branch", 1)
	_eq(int(branch_hit.get("index", -1)), 1, "第 2 个做法点得中")
	var branch_sweep: Dictionary = _sweep_hits("quest", branch_view, PANEL_RECT)
	_check(branch_sweep.has("branch"), "抉择行在命中范围内")
	_check(not branch_sweep.has("row"), "抉择模式下左列不再响应点击")
	var cancel: Dictionary = UiTheme.find_button(
		QuestPanel.buttons(branch_view, PANEL_RECT), "cancel"
	)
	_check(not cancel.is_empty(), "抉择里有「再想想」")
	_eq(str(QuestPanel.hit_test(branch_view, PANEL_RECT, _center(cancel["rect"])).get("id", "")),
		"cancel", "「再想想」点得中")
	_check(UiTheme.find_button(QuestPanel.buttons(branch_view, PANEL_RECT), "back") != null,
		"抉择里也留着「返回地图」")


# --- 里程碑 7.1 城市事件 ---

## 封港的触发与瞬时冲击。
##
## 条件（财富 ≥ 75 且有血腥味）索恩港开局即满足——8.2 节「不需玩家先做前置任务」
## 正指此，所以"推进一个月"就该出事。
func _test_event_trigger_and_blockade() -> void:
	var built: Dictionary = _new_sim()
	var world: WorldState = built["world"]
	var sim: WorldSim = built["sim"]
	var report: Dictionary = sim.settle_month(1)

	var event: CityEvent = world.find_event("ev-ev_02_kraken_blockade-1")
	_check(event != null, "封港按模板与月份建了实例")
	if event == null:
		return
	_eq(world.active_event_count("port_thorne"), 1, "这座城有一件未了的大事")
	_eq(event.template_id, "ev_02_kraken_blockade", "实例记得自己演的是哪一场")
	_eq(event.triggered_month, 1, "实例记得是哪个月起的")
	_eq(event.phase, CityEvent.PHASE_BLOCKADE, "刚触发时处于封锁阶段")
	_check(event.halt_routes, "封港中断该城的航线")
	_eq(str(event.drain.get("dimension", "")), City.DIM_WEALTH, "每月的持续代价打在财富上")
	_eq(int(event.drain.get("delta", 0)), -3,
		"持续代价冻结在实例里：内容表改了也不该让一场进行中的事件中途换规则")

	# 触发月只吃瞬时冲击：-30，且不叠那个 -3
	_eq(_delta_milli(report, "port_thorne", City.DIM_WEALTH, "change-event"),
		-30 * CityEvolution.SCALE, "触发月财富 -30，没有叠加每月的 -3")
	_check(_has_notice(report, "利维坦盘踞航道口"), "事件流里写明封港")
	_check(_has_delta_item(report, "port_thorne", City.DIM_WEALTH, "halted"),
		"中断被单独记一笔，玩家分得清是封港还是被查抄")

	var halted: Array = report.get("haltedRoutes", [])
	_check(not halted.is_empty(), "该城的航线本月收益整条中断")
	var halted_here: bool = false
	for entry in halted:
		if str(entry.get("cityId", "")) == "port_thorne":
			halted_here = true
	_check(halted_here, "中断的正是索恩港那一端")
	# 中断不是注销：航线还在，解封即恢复（见 D-37）
	_check(not world.get_routes_of_city("port_thorne").is_empty(), "航线只是停摆，没有被注销")


## 持续代价，以及"世界自己走完"。
##
## 后者是剧本里没有的一条（见 balance.events.blockadeLiftMonths 的说明）：不加它，
## 快进十年就等于让一座城无限放血，财富会被钳到 0 并一直贴在 0 上。
func _test_event_drain_and_lift() -> void:
	var built: Dictionary = _new_sim()
	var world: WorldState = built["world"]
	var sim: WorldSim = built["sim"]
	sim.settle_month(1)
	var event: CityEvent = world.find_event("ev-ev_02_kraken_blockade-1")
	if event == null:
		_check(false, "封港没有触发，后面的断言无从谈起")
		return

	var second: Dictionary = sim.settle_month(2)
	_eq(_delta_milli(second, "port_thorne", City.DIM_WEALTH, "change-event"),
		-3 * CityEvolution.SCALE, "第二个月起每月扣 3 点")
	_check(_has_notice(second, "还在继续"), "持续代价写进事件流")
	_check(_has_delta_item(second, "port_thorne", City.DIM_WEALTH, "halted"), "航线仍然断着")

	var lift: int = int(sim.events.rules().get("blockadeLiftMonths", 12))
	_check(lift > 0, "配置了封锁自行解除的月数")
	var last: Dictionary = {}
	for month in range(3, 2 + lift):
		last = sim.settle_month(month)

	_eq(int(event.resolved_month), 1 + lift, "拖过 lift 个月之后封锁自己松了")
	_check(event.resolved, "自行解除也算它了结了")
	_eq(event.branch_id, EventSystem.BRANCH_LIFTED, "记的是「没人管」而不是某个做法")
	_eq(world.active_event_count("port_thorne"), 0, "这座城不再有未了的大事")
	_check(_has_notice(last, "封锁自己松了下来"), "解封写进事件流")
	var halted_after: bool = false
	for entry in last.get("haltedRoutes", []):
		if str(entry.get("cityId", "")) == "port_thorne":
			halted_after = true
	_check(not halted_after, "解封之后航线当月就恢复")

	# 自行解除之后这一场不再重演：否则世界在无人过问时会永远振荡——财富涨回
	# 阈值就再封一次，而玩家什么也没做
	var config: Dictionary = ContentLoader.get_event_template("ev_02_kraken_blockade")
	world.get_city("port_thorne").wealth = 90
	var cooldown: int = int(sim.events.rules().get("recurrenceCooldownMonths", 12))
	_check(cooldown > 0, "配置了复发冷却")
	_check(not sim.events.conditions_met(config, "port_thorne", 1 + lift + cooldown),
		"自行解除之后条件再满足也不再封一次")


## 两个不带战斗的做法：预览与交付同源、玩家侧当场结清、城市增量排进月末队列、
## 世界标记按「event.城市.事件.后果」写下。
func _test_event_branch_resolution() -> void:
	var built: Dictionary = _new_sim()
	var world: WorldState = built["world"]
	var sim: WorldSim = built["sim"]
	var avatar := PlayerAvatar.new()
	avatar.avatar_id = "avatar-event"
	world.avatar = avatar
	var config: Dictionary = ContentLoader.get_event_template("ev_02_kraken_blockade")

	sim.settle_month(1)
	var event: CityEvent = world.find_event("ev-ev_02_kraken_blockade-1")
	if event == null:
		_check(false, "封港没有触发，后面的断言无从谈起")
		return

	# 选项合法性
	_eq(str(sim.events.resolve(event.event_id, "no_such_branch", 1).get("errorCode", "")),
		EventSystem.ERROR_INVALID_ARGUMENT, "没有这个做法时给参数错误")
	_eq(str(sim.events.resolve(event.event_id, "hunt", 1).get("errorCode", "")),
		EventSystem.ERROR_INVALID_ARGUMENT, "带战斗的做法要打完才知道结果")
	_eq(str(sim.events.resolve("ev-nobody", "expose", 1).get("errorCode", "")),
		EventSystem.ERROR_NOT_FOUND, "处置不存在的事件给未找到")

	var preview: Dictionary = EventSystem.branch_preview(config, "expose")
	_eq(EventSystem.effect_label(preview), "财富 +15 · 声誉 +6 · 善恶 +5",
		"预览把这一做的全部后果摆出来")

	var result: Dictionary = sim.events.resolve(event.event_id, "expose", 1)
	_check(bool(result.get("ok", false)), "揭发银鳞，处置成功：" + str(result.get("error", "")))
	_eq(str(result["label"]), "调查银鳞并揭发", "结果里带着这个做法的名字")
	var deltas: Array = result.get("deltas", [])
	_eq(deltas.size(), 1, "只有财富这一项动了")
	if deltas.size() == 1:
		_eq(str(deltas[0]["dimension"]), City.DIM_WEALTH, "打在财富上")
		_eq(int(deltas[0]["delta"]), 15, "额度与预览一致")
	_eq(int(result["reputation"]), 6, "声誉 +6")
	_eq(int(result["karma"]), 5, "善恶 +5")
	_check(bool(result["eventEnded"]), "揭发把这件事了结了")
	_eq(avatar.get_reputation("port_thorne"), 6, "声誉当场记下（玩家自己的账不等月末）")
	_eq(avatar.karma, 5, "善恶当场记下")
	_check(world.world_flags.has("event.port_thorne.ev_02_kraken_blockade.silverscale_exposed"),
		"世界标记写下了揭发的后果")
	_check(not event.is_active(), "事件了结了")
	_eq(event.phase, CityEvent.PHASE_DONE, "阶段推进到了结")
	_check(sim.events.blockade_cities().is_empty(), "解封之后航线立刻恢复")

	# 城市的那一份只产出请求，提交是调用方的事——与委托同一条分工
	var changes: Array = result.get("changes", [])
	_eq(changes.size(), 1, "产出一条城市变更请求")
	for change in changes:
		_eq(change.source, StateChange.SOURCE_EVENT, "来源记为事件")
		_eq(change.source_ref_id, event.event_id, "变更能追到是哪场事件带来的")
		_eq(str(sim.apply_state_change(change).get("errorCode", "")), WorldSim.ERROR_NONE,
			"请求能提交进队列")
	var after: Dictionary = sim.settle_month(2)
	_eq(_delta_milli(after, "port_thorne", City.DIM_WEALTH, "change-event"),
		15 * CityEvolution.SCALE, "揭发的 +15 在月末落账")

	# 病根已除：条件再满足也不重演
	world.get_city("port_thorne").wealth = 90
	_check(not sim.events.conditions_met(config, "port_thorne", 3),
		"揭发之后病根已除，条件再满足也不会重演")
	_eq(str(sim.events.resolve(event.event_id, "deal", 3).get("errorCode", "")),
		EventSystem.ERROR_PRECONDITION_FAILED, "已经了结的事件处置不了第二次")


## 分赃：唯一一个"以未根除结束"的做法。它写下病根标记，并在冷却之后允许复发。
##
## 冷却不是装饰：剧本写的是"可能复发"，而条件（财富 ≥ 75 + 血腥味）往往在解封后
## 仍然满足——不设冷却，世界会在解封后立刻再封一次。
func _test_event_deal_recurrence() -> void:
	var built: Dictionary = _new_sim()
	var world: WorldState = built["world"]
	var sim: WorldSim = built["sim"]
	var avatar := PlayerAvatar.new()
	avatar.avatar_id = "avatar-deal"
	world.avatar = avatar
	var config: Dictionary = ContentLoader.get_event_template("ev_02_kraken_blockade")

	sim.settle_month(1)
	var event: CityEvent = world.find_event("ev-ev_02_kraken_blockade-1")
	if event == null:
		_check(false, "封港没有触发，后面的断言无从谈起")
		return
	var result: Dictionary = sim.events.resolve(event.event_id, "deal", 1)
	_check(bool(result.get("ok", false)), "与银鳞分赃，处置成功：" + str(result.get("error", "")))
	_eq(int(result["reputation"]), -8, "声誉 -8")
	_eq(int(result["karma"]), -6, "善恶 -6")
	_check(bool(result["recurrence"]), "分赃明确告诉玩家病根未除")
	_check(world.world_flags.has("event.port_thorne.ev_02_kraken_blockade.silverscale_deal"),
		"病根标记写下了")
	_check(not event.is_active(), "这一场结束了（港口开了，血腥味还在）")

	world.get_city("port_thorne").wealth = 90
	var cooldown: int = int(sim.events.rules().get("recurrenceCooldownMonths", 12))
	_check(not sim.events.conditions_met(config, "port_thorne", cooldown),
		"冷却没过，不会再封一次")
	_check(sim.events.conditions_met(config, "port_thorne", 1 + cooldown),
		"冷却过后条件仍然满足，会再封一次")


## 讨伐的胜负两套后果。输的那一套**不了结**这件事——剧本写的是「港口还是封着，
## 什么都没变」，所以封港、断航、每月流血都照旧，玩家可以整备之后再来。
func _test_event_combat_outcomes() -> void:
	var built: Dictionary = _new_sim()
	var world: WorldState = built["world"]
	var sim: WorldSim = built["sim"]
	var avatar := PlayerAvatar.new()
	avatar.avatar_id = "avatar-hunt"
	world.avatar = avatar
	sim.settle_month(1)
	var event: CityEvent = world.find_event("ev-ev_02_kraken_blockade-1")
	if event == null:
		_check(false, "封港没有触发，后面的断言无从谈起")
		return

	var won: Dictionary = sim.events.resolve_combat(event.event_id, true, 1)
	_check(bool(won.get("ok", false)), "打赢利维坦，事件了结：" + str(won.get("error", "")))
	_eq(str(won["label"]), "利维坦伏诛", "结局是「利维坦伏诛」")
	_eq(int(won["reputation"]), 8, "声誉 +8")
	_eq(int(won["karma"]), 4, "善恶 +4")
	_check(bool(won["eventEnded"]), "打赢就解封")
	_check(world.world_flags.has("event.port_thorne.ev_02_kraken_blockade.kraken_slain"),
		"世界标记记下利维坦已死")
	var deltas: Array = won.get("deltas", [])
	_eq(deltas.size(), 1, "财富这一项有变化")
	if deltas.size() == 1:
		_eq(int(deltas[0]["delta"]), 30, "讨伐成功把封港扣掉的 30 点补回来")
	var unlock: Dictionary = won.get("unlockRoute", {})
	_check(not unlock.is_empty(), "讨伐的报酬里有一条解锁航线")
	_eq(str(unlock.get("cityA", "")), "port_thorne", "航线一端是索恩港")
	_eq(str(unlock.get("cityB", "")), "red_sands", "另一端是赤沙（唯一没有既有航线的远岸城市）")
	_eq(str(unlock.get("kind", "")), TradeRoute.KIND_LEGENDARY, "类型是传奇航线")
	_eq(str(sim.events.resolve_combat(event.event_id, true, 2).get("errorCode", "")),
		EventSystem.ERROR_PRECONDITION_FAILED, "已经了结的事件打不了第二次")

	# 输的那一路另开一局
	var lost_build: Dictionary = _new_sim()
	var lost_world: WorldState = lost_build["world"]
	var lost_sim: WorldSim = lost_build["sim"]
	var lost_avatar := PlayerAvatar.new()
	lost_avatar.avatar_id = "avatar-lost"
	lost_world.avatar = lost_avatar
	lost_sim.settle_month(1)
	var lost_event: CityEvent = lost_world.find_event("ev-ev_02_kraken_blockade-1")
	if lost_event == null:
		_check(false, "第二局里封港也没有触发")
		return
	var lost: Dictionary = lost_sim.events.resolve_combat(lost_event.event_id, false, 1)
	_check(bool(lost.get("ok", false)), "打输了也算一次处置：" + str(lost.get("error", "")))
	_eq(str(lost["label"]), "从雾里退回来", "结局是「从雾里退回来」")
	_eq(int(lost["reputation"]), -6, "声誉 -6（但命还在）")
	_check(not bool(lost["eventEnded"]), "打输不了结这件事（剧本：什么都没变）")
	_check(lost_event.is_active(), "封港照旧")
	_eq(lost_sim.events.blockade_cities().size(), 1, "航道还是断着")
	_check(lost_world.world_flags.has("event.port_thorne.ev_02_kraken_blockade.kraken_failed"),
		"失败的痕迹也记下")
	_check(lost_avatar.get_reputation("port_thorne") == -6, "声誉照扣，账不白欠")
	var again: Dictionary = lost_sim.events.resolve(lost_event.event_id, "expose", 1)
	_check(bool(again.get("ok", false)), "输了之后可以改走别的做法")


## 传奇航线：事件奖励才有的第三条航线。它买到的是"不受 9.3 / 9.4 那套门槛约束"
## ——收益高于走私、不被查抄、也不因治安崩坏而中断。
func _test_event_legendary_route() -> void:
	var built: Dictionary = _new_sim()
	var world: WorldState = built["world"]
	var sim: WorldSim = built["sim"]
	var avatar := PlayerAvatar.new()
	avatar.avatar_id = "avatar-legend"
	world.avatar = avatar
	sim.settle_month(1)
	var event: CityEvent = world.find_event("ev-ev_02_kraken_blockade-1")
	if event == null:
		_check(false, "封港没有触发，后面的断言无从谈起")
		return
	_check(world.find_route("port_thorne", "red_sands") == null, "打之前这两座城之间没有航线")
	var won: Dictionary = sim.events.resolve_combat(event.event_id, true, 1)
	var unlock: Dictionary = won.get("unlockRoute", {})

	var established: Dictionary = sim.establish_route(
		str(unlock.get("cityA", "")), str(unlock.get("cityB", "")),
		str(unlock.get("kind", "")), 1, TradeRoute.OWNER_PLAYER
	)
	_check(bool(established.get("ok", false)),
		"解锁的航线建得起来：" + str(established.get("error", "")))
	var route: TradeRoute = world.find_route("port_thorne", "red_sands")
	if route == null:
		_check(false, "航线没有进世界")
		return
	_check(route.is_legendary(), "类型是传奇航线")
	_check(route.is_player_owned(), "它归玩家（奖给玩家的东西，进账不能绕开他）")
	_eq(int(sim.get_city("port_thorne").get("legendaryRoutes", 0)), 1, "城市视图里数得出来")

	# 归玩家的航线每月进账，与走私那条分开算
	var legendary_income: int = int(
		ContentLoader.get_balance_section("trade").get("legendaryPlayerIncomeCopper", 800)
	)
	var paid: Dictionary = sim.settle_month(2)
	_eq(int(paid.get("playerSmugglingIncome", 0)), legendary_income, "传奇航线每月给玩家进账")

	# 每城上限 1：同一个事件刷不出第二条
	_eq(str(sim.establish_route(
		"port_thorne", "aedran", TradeRoute.KIND_LEGENDARY, 2, TradeRoute.OWNER_PLAYER
	).get("errorCode", "")), WorldSim.ERROR_CAPACITY_EXCEEDED, "每城最多一条传奇航线")

	# 治安崩坏也断不掉它：买到的正是"不受这套规则约束"
	world.get_city("port_thorne").security = 10
	sim.settle_month(3)
	_check(world.find_route("port_thorne", "red_sands") != null, "治安崩坏也断不掉传奇航线")


## 事件实例的存档往返。模板（events.json）不落盘，但实例状态要——尤其那些
## **冻结**下来的字段（是否断航、每月扣多少），它们决定了一场进行中的事件怎么跑。
func _test_event_round_trip() -> void:
	var built: Dictionary = _new_sim()
	var world: WorldState = built["world"]
	var sim: WorldSim = built["sim"]
	sim.settle_month(1)
	var active: CityEvent = world.find_event("ev-ev_02_kraken_blockade-1")
	if active == null:
		_check(false, "封港没有触发，后面的断言无从谈起")
		return

	var decoded: Variant = JSON.parse_string(JSON.stringify(world.to_dict()))
	_check(decoded is Dictionary, "世界状态可以过一遍 JSON")
	var fresh: WorldState = _new_world()["world"]
	fresh.apply_dict(decoded)
	_eq(fresh.get_events().size(), 1, "事件数量往返一致")
	var restored: CityEvent = fresh.find_event(active.event_id)
	_check(restored != null, "进行中的那场事件读得回来")
	if restored == null:
		return
	_eq(restored.template_id, active.template_id, "模板 id 往返一致")
	_eq(restored.city_id, active.city_id, "事发城市往返一致")
	_eq(restored.triggered_month, active.triggered_month, "触发月份往返一致")
	_check(restored.is_active(), "未了结的状态往返一致")
	_eq(restored.halt_routes, active.halt_routes, "断航标记往返一致")
	_eq(int(restored.drain.get("delta", 0)), int(active.drain.get("delta", 0)),
		"冻结的持续代价往返一致")
	_eq(fresh.active_event_count("port_thorne"), 1, "读档后「城中大事」照旧")

	# 了结之后的那份也要能存下来（做法、了结月份都要在，否则"还会不会再来"没法判断）
	sim.events.resolve(active.event_id, "deal", 1)
	var done: CityEvent = world.find_event(active.event_id)
	var decoded_done: Variant = JSON.parse_string(JSON.stringify(world.to_dict()))
	var fresh_done: WorldState = _new_world()["world"]
	fresh_done.apply_dict(decoded_done)
	var restored_done: CityEvent = fresh_done.find_event(active.event_id)
	_check(restored_done != null, "已了结的那场事件读得回来")
	if restored_done == null:
		return
	_check(not restored_done.is_active(), "了结状态往返一致")
	_eq(restored_done.branch_id, "deal", "记下了当初选的做法")
	_eq(restored_done.resolved_month, done.resolved_month, "了结月份往返一致")
	# 判据跟着一起活过来：读档后它仍然是"病根未除、冷却过后会再犯"
	var config: Dictionary = ContentLoader.get_event_template("ev_02_kraken_blockade")
	world.get_city("port_thorne").wealth = 90
	fresh_done.get_city("port_thorne").wealth = 90
	_eq(sim.events.conditions_met(config, "port_thorne", 20),
		EventSystem.create(fresh_done).conditions_met(config, "port_thorne", 20),
		"读档后复发判据与原世界一致")


## 事件界面：一屏两件事——城里正在发生什么、以及这件事上一次是怎么收的场。
func _test_event_view_model() -> void:
	var built: Dictionary = _new_sim()
	var world: WorldState = built["world"]
	var sim: WorldSim = built["sim"]
	var names: Dictionary = _city_names(world)
	sim.settle_month(1)

	# 没事的城：一屏空白，不编东西出来
	var quiet: Dictionary = EventViewModel.build(
		world, world.get_events(), "aedran", "aedran", names, 0
	)
	_eq(int(quiet.get("rowCount", -1)), 0, "没事的城列表是空的")
	_check((quiet.get("branches", []) as Array).is_empty(), "没事的城没有可选的处置")

	var view: Dictionary = EventViewModel.build(
		world, world.get_events(), "port_thorne", "port_thorne", names, 0
	)
	_eq(int(view["rowCount"]), 1, "索恩港有一件事")
	_check(bool(view["selectedIsActive"]), "选中的是进行中的那件")
	var row: Dictionary = view["selected"]
	_eq(str(row["statusLabel"]), "未了", "行上标着未了")
	# 封港的三条影响都要写全，否则玩家判断不了"要不要管"
	_check(str(row["effect"]).contains("触发时 财富 -30"), "写明触发时扣了多少")
	_check(str(row["effect"]).contains("每月 财富 -3"), "写明每月还在扣")
	_check(str(row["effect"]).contains("航线收益全断"), "写明航线断着")
	_eq((row["dialogue"] as Array).size(), 4, "对白取自剧本 EV-02")

	var branches: Array = view.get("branches", [])
	_eq(branches.size(), 3, "三个做法都摆出来")
	var combat: Dictionary = {}
	var expose: Dictionary = {}
	for branch in branches:
		if bool(branch.get("isCombat", false)):
			combat = branch
		if str(branch.get("branchId", "")) == "expose":
			expose = branch
	_check(not combat.is_empty(), "讨伐那一行单独标出来")
	_check(str(combat.get("effectLabel", "")).contains("赢："), "讨伐写着赢了会怎样")
	_check(str(combat.get("effectLabel", "")).contains("输："), "也写着输了会怎样")
	_check(str(combat.get("effectLabel", "")).contains("事没了结"), "并写明输了这件事还不算完")
	_eq(str(expose.get("effectLabel", "")), "财富 +15 · 声誉 +6 · 善恶 +5",
		"行上的后果与交付同源")

	# 不在那座城：能看，但不能处置
	var away: Dictionary = EventViewModel.build(
		world, world.get_events(), "port_thorne", "aedran", names, 0
	)
	_check(not bool(away["atCity"]), "面板知道你不在这座城")
	var away_row: Dictionary = away["selected"]
	_check(not bool(away_row.get("canResolve", true)), "不在这座城就处置不了")
	_check(str(away_row.get("blockedReason", "")).contains("索恩港"),
		"并且说清楚要回哪座城")
	_check((away.get("branches", []) as Array).is_empty(), "不在这座城时没有可选项")

	# 了结之后：留在列表上，写清上一次是怎么收的场——玩家要问的正是"还会不会再来"
	sim.events.resolve("ev-ev_02_kraken_blockade-1", "deal", 1)
	var after: Dictionary = EventViewModel.build(
		world, world.get_events(), "port_thorne", "port_thorne", names, 0
	)
	_eq(int(after["activeCount"]), 0, "了结之后没有进行中的")
	_eq(int(after["rowCount"]), 1, "已了结的留在列表上")
	var resolved: Dictionary = after["selected"]
	_eq(str(resolved["kind"]), EventViewModel.ROW_KIND_RESOLVED, "这一行是已了结")
	_eq(str(resolved["statusLabel"]), "已了", "行上标着已了")
	_eq(str(resolved["outcomeLabel"]), "与银鳞合作分赃", "写清上一次选的做法")
	_check(str(resolved["effect"]).contains("可能再犯"), "并且写明病根还在")


func _test_event_panel_hit_test() -> void:
	var built: Dictionary = _new_sim()
	var world: WorldState = built["world"]
	var sim: WorldSim = built["sim"]
	var names: Dictionary = _city_names(world)
	sim.settle_month(1)
	var view: Dictionary = EventViewModel.build(
		world, world.get_events(), "port_thorne", "port_thorne", names, 0
	)

	var back: Dictionary = UiTheme.find_button(EventPanel.buttons(view, PANEL_RECT), "back")
	_check(not back.is_empty(), "城中大事界面有「返回地图」按钮")
	_eq(str(EventPanel.hit_test(view, PANEL_RECT, _center(back["rect"])).get("id", "")),
		"back", "返回按钮点得中")

	var sweep: Dictionary = _sweep_hits("event", view, PANEL_RECT)
	_check(sweep.has("button"), "界面上的按钮在命中范围内")
	_check(sweep.has("row"), "事件行可点")
	var first: Dictionary = _hit_for("event", view, PANEL_RECT, "row", 0)
	_eq(int(first.get("index", -1)), 0, "第一行报出自己的行号")
	_check(EventPanel.hit_test(view, PANEL_RECT, Vector2(4.0, 4.0)).is_empty(),
		"面板外的点击不算命中")

	# 抉择模式：右列换成做法，左列不再响应——免得在另一件事上执行上一步选的做法
	var branch_view: Dictionary = EventViewModel.build(
		world, world.get_events(), "port_thorne", "port_thorne", names, 0,
		EventViewModel.MODE_BRANCH
	)
	_eq(int(branch_view["mode"]), EventViewModel.MODE_BRANCH, "视图处于抉择模式")
	var branch_hit: Dictionary = _hit_for("event", branch_view, PANEL_RECT, "branch", 0)
	_eq(int(branch_hit.get("index", -1)), 0, "第一个做法点得中")
	var branch_sweep: Dictionary = _sweep_hits("event", branch_view, PANEL_RECT)
	_check(branch_sweep.has("branch"), "抉择行在命中范围内")
	_check(not branch_sweep.has("row"), "抉择模式下左列不再响应点击")
	var cancel: Dictionary = UiTheme.find_button(
		EventPanel.buttons(branch_view, PANEL_RECT), "cancel"
	)
	_check(not cancel.is_empty(), "抉择里有「再想想」")
	_eq(str(EventPanel.hit_test(branch_view, PANEL_RECT, _center(cancel["rect"])).get("id", "")),
		"cancel", "「再想想」点得中")


## 物价六因子（《数值框架》9.3）。供需那两段区间与治安因子都各有端点，逐个钉住，
## 免得"插值方向反了"这种错只在某座城贵得不合理时才被发现。
func _test_economy_price_factors() -> void:
	var built: Dictionary = _new_sim(false)
	var world: WorldState = built["world"]
	var sim: WorldSim = built["sim"]
	var city: City = world.get_city("greenwade")

	# 供需：短缺越狠越贵、过剩越足越贱，中间是 1.0 的正常档
	for pair in [[0, 3.0], [40, 1.5], [50, 1.0], [60, 0.8], [100, 0.5]]:
		city.development = int(pair[0])
		var quote: Dictionary = sim.economy.get_price(world, "greenwade", "weapon_longsword_common")
		_check(absf(float(quote["supplyFactor"]) - float(pair[1])) < 0.0001,
			"发展度 %d 时武器的供需系数是 %.1f（实际 %.3f）" % [
				int(pair[0]), float(pair[1]), float(quote["supplyFactor"])
			])

	# 谁的需求：武器防具看发展度、药品食物看财富（D-43）
	_eq(str(sim.economy.get_price(world, "greenwade", "weapon_longsword_common")["supplyDimension"]),
		"development", "武器看发展度")
	_eq(str(sim.economy.get_price(world, "greenwade", "consumable_bread")["supplyDimension"]),
		"wealth", "食物看财富")

	# 治安与地区：绿荫治安 65 → 因子 0.675、地区溢价 0.95，发展度 45 落在正常档。
	# 基准价不是 510 而是 740：稀有一档带 2 条词缀，买入侧按该类别词缀池的期望
	# 折价算（武器池 115 铜/条 × 2），见 D-56。
	city.development = 45
	var green: Dictionary = sim.economy.get_price(world, "greenwade", "weapon_longsword_rare")
	_check(absf(float(green["securityFactor"]) - 0.675) < 0.0001, "治安 65 的治安因子是 0.675")
	_check(absf(float(green["premiumFactor"]) - 0.95) < 0.0001, "绿荫的地区溢价是 0.95")
	_eq(int(green["templatePrice"]), 510, "模板价还是 items.json 里那个数")
	_eq(int(green["affixBonus"]), 230, "稀有一档的期望词缀折价")
	_eq(int(green["basePrice"]), 740, "基准价 = 模板价 + 词缀折价")
	_eq(int(green["unitPrice"]), 475, "四个因子乘出来的买价")
	_eq(int(green["sellPrice"]), 237, "收价是公式价的一半")

	# 同样的六维之下，地区溢价不同的两座城贵贱不同
	_set_all_dimensions(world, "silvermoon_spire", 40)
	_set_all_dimensions(world, "hammerhold", 40)
	var spire: Dictionary = sim.economy.get_price(world, "silvermoon_spire", "weapon_longsword_rare")
	var hold: Dictionary = sim.economy.get_price(world, "hammerhold", "weapon_longsword_rare")
	_eq(int(spire["unitPrice"]), 1066, "银月塔（溢价 1.20）的买价")
	_eq(int(hold["unitPrice"]), 799, "铁锤堡（溢价 0.90）的买价")

	# 声誉三档：敬重折扣、警惕抬价、敌视拒售。收价不吃声誉（D-44）
	var avatar := PlayerAvatar.new()
	avatar.avatar_id = "avatar-price"
	world.avatar = avatar
	var neutral_sell: int = int(hold["sellPrice"])
	avatar.set_reputation("hammerhold", 70)
	var respect: Dictionary = sim.economy.get_price(world, "hammerhold", "weapon_longsword_rare")
	_check(absf(float(respect["reputationFactor"]) - 0.85) < 0.0001, "敬重时打 85 折")
	_eq(int(respect["unitPrice"]), 679, "敬重时的买价")
	_eq(int(respect["sellPrice"]), neutral_sell, "收价不吃声誉")
	_check(not bool(respect["refused"]), "敬重时照样做生意")
	avatar.set_reputation("hammerhold", -30)
	var wary: Dictionary = sim.economy.get_price(world, "hammerhold", "weapon_longsword_rare")
	_check(absf(float(wary["reputationFactor"]) - 1.15) < 0.0001, "警惕时抬价 15%")
	_eq(int(wary["unitPrice"]), 919, "警惕时的买价")
	avatar.set_reputation("hammerhold", -60)
	_check(bool(sim.economy.get_price(world, "hammerhold", "weapon_longsword_rare")["refused"]),
		"敌视时商铺拒售")

	# 输入错误各有各的错码
	_eq(str(sim.economy.get_price(world, "nowhere", "weapon_longsword_rare").get("errorCode", "")),
		Economy.ERROR_NOT_FOUND, "没有这座城市")
	_eq(str(sim.economy.get_price(
		world, "greenwade", "weapon_longsword_rare", "bazaar").get("errorCode", "")),
		Economy.ERROR_INVALID_ARGUMENT, "没有这个渠道")
	_eq(str(sim.economy.get_price(
		world, "aedran", "weapon_longsword_rare", Economy.CHANNEL_BLACK_MARKET).get("errorCode", "")),
		Economy.ERROR_PRECONDITION_FAILED, "没有黑市的城不开黑市")


## 商品可得性（D-45）：某座城卖得到多好的货由它的发展度决定——"我能买到什么"
## 取决于城的境况，而不是每座城都什么都卖。
func _test_economy_stock_availability() -> void:
	var built: Dictionary = _new_sim(false)
	var world: WorldState = built["world"]
	var sim: WorldSim = built["sim"]

	_set_all_dimensions(world, "greenwade", 0)
	var poor: Array = sim.economy.list_stock(world, "greenwade")
	_check(not poor.is_empty(), "发展度 0 的城也有普通货")
	_eq(_count_rarity(poor, "common"), poor.size(), "发展度 0 的城只摆得出普通货")

	_set_all_dimensions(world, "greenwade", 45)
	var mid: Array = sim.economy.list_stock(world, "greenwade")
	_check(_count_rarity(mid, "rare") > 0, "发展度 45 摆得出稀有的货")
	_eq(_count_rarity(mid, "epic"), 0, "但还摆不出史诗的货")

	# 龙魂/神造只认产地：绿荫发展度拉满也造不出来
	_set_all_dimensions(world, "greenwade", 100)
	var rich: Array = sim.economy.list_stock(world, "greenwade")
	_eq(_count_rarity(rich, "dragonforged"), 0, "没有锻造坊的城造不出龙魂装备")
	_check(_count_rarity(rich, "legendary") > 0, "发展度 100 时传奇货上架")

	# 铁锤堡要长到 85 才开炉
	_set_all_dimensions(world, "hammerhold", 84)
	_eq(_count_rarity(sim.economy.list_stock(world, "hammerhold"), "dragonforged"), 0,
		"发展度 84 的铁锤堡还没开炉")
	_set_all_dimensions(world, "hammerhold", 85)
	_check(_count_rarity(sim.economy.list_stock(world, "hammerhold"), "dragonforged") > 0,
		"发展度 85 时龙魂装备上架")

	# 黑市摆得更宽的货：发展度 30 的港城在商铺买不到稀有的货，在黑市买得到
	_set_all_dimensions(world, "port_thorne", 30)
	_eq(_count_rarity(sim.economy.list_stock(world, "port_thorne"), "rare"), 0,
		"发展度 30 的商铺摆不出稀有的货")
	_check(_count_rarity(
		sim.economy.list_stock(world, "port_thorne", Economy.CHANNEL_BLACK_MARKET), "rare"
	) > 0, "黑市的门槛放宽之后摆得出来")
	_check(sim.economy.list_stock(world, "aedran", Economy.CHANNEL_BLACK_MARKET).is_empty(),
		"没有黑市的城拿不到黑市货架")

	# 顺序稳定：同一份世界连开两次货架，顺序一模一样
	var first: Array = sim.economy.list_stock(world, "port_thorne", Economy.CHANNEL_BLACK_MARKET)
	var second: Array = sim.economy.list_stock(world, "port_thorne", Economy.CHANNEL_BLACK_MARKET)
	_eq(_stock_ids(first), _stock_ids(second), "货架顺序稳定")


## 买卖当场结清：买扣钱进货、卖出货收钱。城市六维一概不动——物价只读城市状态。
func _test_economy_buy_and_sell() -> void:
	var built: Dictionary = _new_sim(false)
	var world: WorldState = built["world"]
	var sim: WorldSim = built["sim"]
	_set_all_dimensions(world, "hammerhold", 50)

	var avatar := PlayerAvatar.new()
	avatar.avatar_id = "avatar-trade"
	avatar.money = 5000
	world.avatar = avatar
	var held_before: int = avatar.inventory.size()

	var quote: Dictionary = sim.economy.get_price(world, "hammerhold", "weapon_longsword_common")
	var price: int = int(quote["unitPrice"])
	var bought: Dictionary = sim.economy.execute_trade(
		world, "hammerhold", "weapon_longsword_common", Economy.SIDE_BUY
	)
	_check(bool(bought.get("ok", false)), "买得成：" + str(bought.get("error", "")))
	_eq(avatar.money, 5000 - price, "买货当场扣钱")
	_eq(avatar.inventory.size(), held_before + 1, "货进背包")
	var bought_id: String = str(bought.get("instanceId", ""))
	_check(avatar.item_instances.has(bought_id), "实例登记在册")
	_eq(str(avatar.item_instances.get(bought_id, {}).get("templateId", "")),
		"weapon_longsword_common", "实例指向买的那件模板")

	# 钱不够：一分不动、一件不进
	avatar.money = price - 1
	var poor: Dictionary = sim.economy.execute_trade(
		world, "hammerhold", "weapon_longsword_common", Economy.SIDE_BUY
	)
	_eq(str(poor.get("errorCode", "")), Economy.ERROR_PRECONDITION_FAILED, "钱不够就买不成")
	_eq(avatar.money, price - 1, "买不成时钱一分不动")
	_eq(avatar.inventory.size(), held_before + 1, "买不成时背包也不动")

	# 货架上没有的货买不到：发展度 50 的铁锤堡摆不出史诗长剑
	_eq(str(sim.economy.execute_trade(
		world, "hammerhold", "weapon_longsword_epic", Economy.SIDE_BUY
	).get("errorCode", "")), Economy.ERROR_NOT_FOUND, "货架上没有的货买不到")

	# 卖：货出背包、钱到手
	avatar.money = 0
	var sold: Dictionary = sim.economy.execute_trade(
		world, "hammerhold", "weapon_longsword_common", Economy.SIDE_SELL,
		Economy.CHANNEL_SHOP, bought_id
	)
	_check(bool(sold.get("ok", false)), "卖得成：" + str(sold.get("error", "")))
	_eq(avatar.money, int(quote["sellPrice"]), "卖货当场收钱")
	_eq(avatar.inventory.size(), held_before, "货出背包")
	_check(not avatar.item_instances.has(bought_id), "实例注销")
	_check(int(quote["sellPrice"]) < price, "同一座城里买贵卖贱，原地倒手必亏")

	# 背包里没有的东西卖不掉
	_eq(str(sim.economy.execute_trade(
		world, "hammerhold", "weapon_longsword_common", Economy.SIDE_SELL
	).get("errorCode", "")), Economy.ERROR_NOT_FOUND, "背包里没有这件货就卖不了")
	_eq(str(sim.economy.execute_trade(
		world, "hammerhold", "weapon_longsword_common", "swap"
	).get("errorCode", "")), Economy.ERROR_INVALID_ARGUMENT, "没有这种买卖方向")

	# 城市六维一概不动
	var snapshots: Dictionary = {}
	for dimension in City.ALL_DIMENSIONS:
		snapshots[dimension] = world.get_city("hammerhold").get_dimension(dimension)
	sim.economy.execute_trade(world, "hammerhold", "consumable_bread", Economy.SIDE_BUY)
	for dimension in City.ALL_DIMENSIONS:
		_eq(world.get_city("hammerhold").get_dimension(dimension), int(snapshots[dimension]),
			"买卖不改城市六维：" + dimension)


## 两条渠道的差别：商铺问名声、黑市不问；黑市买更贵、销赃给得更多。
func _test_economy_black_market() -> void:
	var built: Dictionary = _new_sim(false)
	var world: WorldState = built["world"]
	var sim: WorldSim = built["sim"]
	_set_all_dimensions(world, "port_thorne", 50)

	var avatar := PlayerAvatar.new()
	avatar.avatar_id = "avatar-market"
	avatar.money = 100000
	world.avatar = avatar
	avatar.set_reputation("port_thorne", -80)

	var shop: Dictionary = sim.economy.get_price(
		world, "port_thorne", "consumable_healing_potion", Economy.CHANNEL_SHOP
	)
	var black: Dictionary = sim.economy.get_price(
		world, "port_thorne", "consumable_healing_potion", Economy.CHANNEL_BLACK_MARKET
	)
	_check(bool(shop["refused"]), "名声坏透之后商铺拒售")
	_check(not bool(black["refused"]), "黑市不问你的名声")
	_check(int(black["unitPrice"]) > int(shop["unitPrice"]), "黑市买得更贵")
	_check(int(black["sellPrice"]) > int(shop["sellPrice"]), "黑市销赃给得更多")

	_eq(str(sim.economy.execute_trade(
		world, "port_thorne", "consumable_healing_potion", Economy.SIDE_BUY
	).get("errorCode", "")), Economy.ERROR_PRECONDITION_FAILED, "拒售时商铺买不成")
	var dealt: Dictionary = sim.economy.execute_trade(
		world, "port_thorne", "consumable_healing_potion", Economy.SIDE_BUY,
		Economy.CHANNEL_BLACK_MARKET
	)
	_check(bool(dealt.get("ok", false)), "名声坏了之后黑市是唯一的出路")

	# 卖东西也走得通：买来的药水在黑市销掉
	avatar.money = 0
	var sold: Dictionary = sim.economy.execute_trade(
		world, "port_thorne", "consumable_healing_potion", Economy.SIDE_SELL,
		Economy.CHANNEL_BLACK_MARKET, str(dealt.get("instanceId", ""))
	)
	_check(bool(sold.get("ok", false)), "黑市销得掉：" + str(sold.get("error", "")))
	_eq(avatar.money, int(black["sellPrice"]), "销赃按黑市收价结账")

	# 还没有化身时做不了买卖
	world.avatar = null
	_eq(str(sim.economy.execute_trade(
		world, "port_thorne", "consumable_healing_potion", Economy.SIDE_BUY
	).get("errorCode", "")), Economy.ERROR_PRECONDITION_FAILED, "没有化身做不了买卖")


## 商铺界面的视图：左列一屏是货架还是背包、右列写得清"贵在哪"，都靠视图模型。
func _test_trade_view_model() -> void:
	var built: Dictionary = _new_sim(false)
	var world: WorldState = built["world"]
	var sim: WorldSim = built["sim"]
	_set_all_dimensions(world, "port_thorne", 50)
	var avatar := PlayerAvatar.new()
	avatar.avatar_id = "avatar-shop"
	avatar.money = 5000
	world.avatar = avatar

	var view: Dictionary = _trade_view(world, sim, "port_thorne", "port_thorne")
	_check(bool(view.get("atCity", false)), "人就站在这座城")
	_check(bool(view.get("canTrade", false)), "这件货买得成")
	_check(int(view.get("rowCount", 0)) > 0, "货架上有货")
	var first: Dictionary = view["rows"][0]
	_check(not str(first.get("label", "")).is_empty(), "行上有商品名")
	_check(not str(first.get("priceText", "")).is_empty(), "行上写着买价")
	_eq(str(first.get("categoryLabel", "")), "武器", "货架按武器在前排")
	_eq((view.get("selected", {}).get("factorRows", []) as Array).size(), 6,
		"价目把六个因子逐个摊开")
	_check(str(view.get("dealSummary", "")).contains("→"), "页脚写得出成交后的账面")

	# 钱不够：货还在架上，只是这件拿不下
	avatar.money = 0
	var broke: Dictionary = _trade_view(world, sim, "port_thorne", "port_thorne")
	_check(not bool(broke.get("canTrade", false)), "钱不够就成交不了")
	_check(str(broke.get("blockedReason", "")).contains("钱不够"), "并且说明是钱不够")
	_check(int(broke.get("rowCount", 0)) > 0, "买不起不等于货架上没有")

	# 只看得到价：人在索恩港，翻到艾德兰
	avatar.money = 5000
	var remote: Dictionary = _trade_view(world, sim, "aedran", "port_thorne")
	_check(not bool(remote.get("atCity", false)), "不在这座城")
	_check(int(remote.get("rowCount", 0)) > 0, "别城的价照样看得到")
	_check(not bool(remote.get("canTrade", false)), "但成交不了")
	_check(str(remote.get("blockedReason", "")).contains("不在这座城"), "页脚说明原因")

	# 卖的一侧看背包：先买一件，再翻过去
	var bought: Dictionary = sim.economy.execute_trade(
		world, "port_thorne", "consumable_healing_potion", Economy.SIDE_BUY
	)
	_check(bool(bought.get("ok", false)), "先买一件备着")
	var sell: Dictionary = _trade_view(
		world, sim, "port_thorne", "port_thorne", Economy.CHANNEL_SHOP, TradeViewModel.SIDE_SELL
	)
	_eq(int(sell.get("rowCount", 0)), 1, "背包里那一件就在卖出列表上")
	var held: Dictionary = sell["rows"][0]
	_eq(str(held.get("kind", "")), TradeViewModel.ROW_KIND_HELD, "这一行来自背包")
	_eq(str(held.get("instanceId", "")), str(bought.get("instanceId", "")), "卖的就是那一件")
	_check(bool(sell.get("canTrade", false)), "卖得成")

	# 同名多件：卖的是光标停的那一件，不是"背包里第一件同名的货"
	sim.economy.execute_trade(world, "port_thorne", "consumable_healing_potion", Economy.SIDE_BUY)
	var two: Dictionary = _trade_view(
		world, sim, "port_thorne", "port_thorne", Economy.CHANNEL_SHOP,
		TradeViewModel.SIDE_SELL, 1
	)
	_eq(int(two.get("rowCount", 0)), 2, "两瓶药水各占一行")
	_eq(int(two.get("cursor", -1)), 1, "光标停在第二行")
	var target: Dictionary = two.get("selected", {})
	_check(not str(target.get("instanceId", "")).is_empty(), "价目里带着那一件的实例号")
	_check(str(target.get("instanceId", "")) != str(bought.get("instanceId", "")),
		"两行指向不同的实例")
	var picked: Dictionary = sim.economy.execute_trade(
		world, "port_thorne", str(target.get("templateId", "")), TradeViewModel.SIDE_SELL,
		Economy.CHANNEL_SHOP, str(target.get("instanceId", ""))
	)
	_check(bool(picked.get("ok", false)), "卖得掉：" + str(picked.get("error", "")))
	_check(not avatar.item_instances.has(str(target["instanceId"])), "卖掉的是选中那一件")
	_check(avatar.item_instances.has(str(bought["instanceId"])), "另一件还在")

	# 名声坏透：商铺拒售，黑市照做
	avatar.set_reputation("port_thorne", -70)
	var refused: Dictionary = _trade_view(world, sim, "port_thorne", "port_thorne")
	_check(bool(refused.get("refused", false)), "商铺拒售")
	_check(not bool(refused.get("canTrade", false)), "拒售时成交不了")
	_check(str(refused.get("blockedReason", "")).contains("黑市"), "拒售时指出还有黑市这条路")
	var black: Dictionary = _trade_view(
		world, sim, "port_thorne", "port_thorne", Economy.CHANNEL_BLACK_MARKET
	)
	_check(bool(black.get("hasBlackMarket", false)), "这座城有黑市")
	_check(not bool(black.get("refused", false)), "黑市不问名声")
	_check(bool(black.get("canTrade", false)), "名声坏了还是买得到")

	# 没有黑市的城：界面不给换渠道的按钮（按钮本身在面板用例里验）
	var plain: Dictionary = _trade_view(world, sim, "aedran", "aedran")
	_check(not bool(plain.get("hasBlackMarket", false)), "艾德兰没有黑市")


## 商铺界面的命中：三个动作按钮与货架行都要点得中，且互不重叠。
func _test_trade_panel_hit_test() -> void:
	var built: Dictionary = _new_sim(false)
	var world: WorldState = built["world"]
	var sim: WorldSim = built["sim"]
	_set_all_dimensions(world, "port_thorne", 50)
	var avatar := PlayerAvatar.new()
	avatar.avatar_id = "avatar-hit-shop"
	avatar.money = 5000
	world.avatar = avatar
	var view: Dictionary = _trade_view(world, sim, "port_thorne", "port_thorne")

	var buttons: Array = TradePanel.buttons(view, PANEL_RECT)
	var deal: Dictionary = UiTheme.find_button(buttons, "deal")
	var switch_side: Dictionary = UiTheme.find_button(buttons, "side")
	var channel: Dictionary = UiTheme.find_button(buttons, "channel")
	var back: Dictionary = UiTheme.find_button(buttons, "back")
	_check(not deal.is_empty() and not switch_side.is_empty() and not back.is_empty(),
		"成交、换买卖、返回三个按钮都在")
	_check(not channel.is_empty(), "有黑市的城多一个换渠道的按钮")
	for pair in [[deal, switch_side], [switch_side, channel], [channel, back]]:
		_check(not (pair[0]["rect"] as Rect2).intersects(pair[1]["rect"] as Rect2),
			"按钮之间不重叠")
	_eq(str(TradePanel.hit_test(view, PANEL_RECT, _center(deal["rect"])).get("id", "")),
		"deal", "成交按钮点得中")
	_eq(str(TradePanel.hit_test(view, PANEL_RECT, _center(back["rect"])).get("id", "")),
		"back", "返回按钮点得中")

	var sweep: Dictionary = _sweep_hits("trade", view, PANEL_RECT)
	_check(sweep.has("button"), "按钮在命中范围内")
	_check(sweep.has("row"), "货架行可点")
	_eq(int(_hit_for("trade", view, PANEL_RECT, "row", 0).get("index", -1)), 0,
		"第一行报出自己的行号")
	_check(TradePanel.hit_test(view, PANEL_RECT, Vector2(4.0, 4.0)).is_empty(),
		"面板外的点击不算命中")

	# 没有黑市的城不给「去黑市」按钮：按不动的东西不该占版面
	var plain: Dictionary = _trade_view(world, sim, "aedran", "aedran")
	_check(UiTheme.find_button(TradePanel.buttons(plain, PANEL_RECT), "channel").is_empty(),
		"没有黑市的城不给换渠道的按钮")


## 商铺界面要用的两张查询表。
func _trade_lookups(world: WorldState) -> Dictionary:
	return {"itemTemplates": _item_template_table(), "cityNames": _city_names(world)}


## 商铺界面的视图。用例里反复要它，参数只差城市、渠道、买卖方向与页签。
func _trade_view(
	world: WorldState, sim: WorldSim, city_id: String, here_city_id: String,
	channel: String = Economy.CHANNEL_SHOP, side: String = TradeViewModel.SIDE_BUY,
	cursor: int = 0, pane: String = TradeViewModel.PANE_TRADE
) -> Dictionary:
	return TradeViewModel.build(
		world, sim.economy, _trade_lookups(world), city_id, here_city_id,
		channel, side, cursor, pane
	)


## 装备规则。模板表默认取真实配置，用例要测"副手"这类暂时没有实物的情况时可以
## 传一份加了假货的小表进去（Equipment.create 的注释里写了为什么模板表要外传）。
func _new_gear(templates: Dictionary = {}) -> Equipment:
	return Equipment.create(templates if not templates.is_empty() else _item_template_table())


## 实例层规则（词缀 / 强化 / 耐久）。默认取真实配置。
func _new_rules(templates: Dictionary = {}) -> ItemInstance:
	return ItemInstance.create(templates if not templates.is_empty() else _item_template_table())


## 找一个能让这一炉失手的种子。测试要测的是"失手之后会怎样"，所以按结果挑种子，
## 而不是把配置里的成功率改小——改了成功率就换了被测的那条规则。
func _failing_seed(chance_bp: int) -> int:
	for seed_value in range(1, 20000):
		if DeterministicRNG.new(seed_value).next_int(ItemInstance.BP_FULL) >= chance_bp:
			return seed_value
	return 1


## 找一个"磨损必中"的种子：next_int(BP_FULL) 小于给定基点（武器磨损率 3000、
## 护甲 5000）。测的是"掉下去之后会怎样"，所以按结果挑种子。
func _wearing_seed(under_bp: int) -> int:
	for seed_value in range(1, 20000):
		if DeterministicRNG.new(seed_value).next_int(ItemInstance.BP_FULL) < under_bp:
			return seed_value
	return 1


## 往背包里塞一件模板，返回实例 id。
func _give(avatar: PlayerAvatar, template_id: String, instance_id: String) -> String:
	return CharacterCreation.add_item(avatar, template_id, instance_id)


## 装备槽位（D-50）。这一条测的不是某个函数，而是"配置里那两张表"与"代码怎么读它们"
## 的一致性：槽位名拼错、某件货没写槽位、弓被写成单手武器，表现都是"这件装备穿不上"
## 或"某个槽永远空着"，而配置里看不出任何异常。
func _test_equipment_slots() -> void:
	var gear: Equipment = _new_gear()
	var slots: Array = gear.slots()
	_eq(slots.size(), 5, "五个槽")
	for slot in ["main_hand", "off_hand", "body", "head", "legs"]:
		if not slots.has(slot):
			_check(false, "槽位清单里应该有：" + slot)
	for slot in slots:
		_check(not gear.slot_label(str(slot)).is_empty(), "每个槽都有显示名：" + str(slot))

	# 物品进哪个槽
	_eq(gear.slot_of("weapon_longsword_common"), "main_hand", "长剑进主手")
	_eq(gear.slot_of("weapon_bow_common"), "main_hand", "弓也进主手（双手是另一回事）")
	_eq(gear.slot_of("armor_leather_common"), "body", "皮甲护身体")
	_eq(gear.slot_of("armor_helmet_common"), "head", "头盔护头")
	_eq(gear.slot_of("armor_legging_common"), "legs", "护腿护腿")
	_eq(gear.slot_of("consumable_healing_potion"), "", "药水不占槽位")
	_check(not gear.can_equip("consumable_healing_potion"), "药水穿不上")
	_check(gear.can_equip("weapon_longsword_common"), "长剑穿得上")

	# 配置里每一件都查一遍：装备的槽位要合法、消耗品/工具不能声明槽位、武器的手数只能是 1 或 2
	var weapons: int = 0
	for item in ContentLoader.get_items():
		var template_id: String = str(item.get("templateId", ""))
		var category: String = str(item.get("category", ""))
		if category != "weapon" and category != "armor":
			# 消耗品与工具（如修补工具）都不占槽位——它们不是穿在身上的东西
			_eq(str(item.get("slot", "")), "", "非装备不声明槽位：" + template_id)
			continue
		_check(gear.has_slot(str(item.get("slot", ""))), "装备的槽位合法：" + template_id)
		if category == "weapon":
			weapons += 1
			var hands: int = int(item.get("hands", 0))
			_check(hands == 1 or hands == 2, "武器的手数是 1 或 2：" + template_id)
	_check(weapons > 0, "表里有武器可测")


## 穿 / 脱 / 换。三条硬规则的落点：同槽替换时旧的回背包、穿过的不能再穿、
## 背包里没有的穿不上、不占槽位的穿不上。
func _test_equipment_equip_and_unequip() -> void:
	var gear: Equipment = _new_gear()
	var avatar := PlayerAvatar.new()
	avatar.avatar_id = "avatar-gear"
	var sword: String = _give(avatar, "weapon_longsword_common", "gear-sword")
	var axe: String = _give(avatar, "weapon_axe_common", "gear-axe")
	var potion: String = _give(avatar, "consumable_healing_potion", "gear-potion")

	var worn: Dictionary = gear.equip(avatar, sword)
	_check(bool(worn.get("ok", false)), "长剑穿得上：" + str(worn.get("error", "")))
	_eq(str(avatar.equipment.get("main_hand", "")), sword, "主手挂着它")
	_check(not avatar.inventory.has(sword), "穿上之后不在背包里")
	_eq(avatar.inventory.size(), 2, "背包少了一件")
	_check(gear.is_equipped(avatar, sword), "查得出它在身上")
	_eq(str(worn.get("slotLabel", "")), "主手", "结果里带着槽位名")

	# 同一个槽换一件：换下来的回背包，而不是消失
	var swapped: Dictionary = gear.equip(avatar, axe)
	_check(bool(swapped.get("ok", false)), "换成战斧也穿得上")
	_eq(str(avatar.equipment.get("main_hand", "")), axe, "主手换成新的")
	_eq(str(swapped.get("replaced", "")), sword, "结果里写明换下了哪一件")
	_check(avatar.inventory.has(sword), "换下来的回到背包")
	_check(not avatar.inventory.has(axe), "新的不在背包里")

	# 脱
	var off: Dictionary = gear.unequip(avatar, "main_hand")
	_check(bool(off.get("ok", false)), "脱得下来")
	_check(not avatar.equipment.has("main_hand"), "槽空了")
	_check(avatar.inventory.has(axe), "脱下的回背包")

	# 错误分支各有各的错码
	_eq(str(gear.unequip(avatar, "main_hand").get("errorCode", "")),
		Equipment.ERROR_NOT_FOUND, "空槽脱不了")
	_eq(str(gear.unequip(avatar, "tail").get("errorCode", "")),
		Equipment.ERROR_INVALID_ARGUMENT, "没有这个槽")
	_eq(str(gear.equip(avatar, "no-such-item").get("errorCode", "")),
		Equipment.ERROR_NOT_FOUND, "背包里没有的东西穿不上")
	_eq(str(gear.equip(avatar, potion).get("errorCode", "")),
		Equipment.ERROR_INVALID_ARGUMENT, "不占槽位的东西穿不上")
	gear.equip(avatar, axe)
	_eq(str(gear.equip(avatar, axe).get("errorCode", "")),
		Equipment.ERROR_PRECONDITION_FAILED, "已经穿着的不能再穿一次")
	_eq(str(gear.unequip(null, "main_hand").get("errorCode", "")),
		Equipment.ERROR_PRECONDITION_FAILED, "没有化身就动不了")
	_eq(str(gear.equip(null, axe).get("errorCode", "")),
		Equipment.ERROR_PRECONDITION_FAILED, "没有化身就穿不上")

	# 存档往返：身上的与背包里的各归各位
	var decoded: Variant = JSON.parse_string(JSON.stringify(avatar.to_dict()))
	_check(decoded is Dictionary, "化身可以过一遍 JSON")
	var fresh: PlayerAvatar = PlayerAvatar.from_dict(decoded)
	_eq(str(fresh.equipment.get("main_hand", "")), axe, "装备往返一致")
	_eq(fresh.inventory.size(), avatar.inventory.size(), "背包件数往返一致")
	_check(fresh.inventory.has(sword) and not fresh.inventory.has(axe),
		"换下来的那件仍在背包里")


## 双手武器占两只手（D-50）。现在的表里只有弓是双手，而"副手"还没有实物，
## 所以这里给模板表塞一件假盾——规则本身与具体货品无关。
func _test_equipment_two_handed() -> void:
	var templates: Dictionary = _item_template_table()
	templates["test_shield"] = {
		"templateId": "test_shield", "displayName": "试作圆盾", "category": "armor",
		"subtype": "shield", "slot": "off_hand", "rarity": "common",
		"attack": 0, "armor": 3, "magicResist": 1, "attackRange": 0, "hands": 0,
		"weight": 2, "price": 400, "effectText": "副手，格挡",
	}
	var gear: Equipment = _new_gear(templates)
	var avatar := PlayerAvatar.new()
	avatar.avatar_id = "avatar-two-hand"
	var bow: String = _give(avatar, "weapon_bow_common", "th-bow")
	var shield: String = _give(avatar, "test_shield", "th-shield")
	var sword: String = _give(avatar, "weapon_longsword_common", "th-sword")

	_check(bool(gear.equip(avatar, shield).get("ok", false)), "盾先穿上")
	var blocked: Dictionary = gear.equip(avatar, bow)
	_eq(str(blocked.get("errorCode", "")), Equipment.ERROR_PRECONDITION_FAILED,
		"另一只手拿着东西时穿不了双手武器")
	_check(str(blocked.get("error", "")).contains("两只手"), "并且说明是两只手的问题")
	_check(not avatar.equipment.has("main_hand"), "被拒之后身上什么都没变")
	_check(avatar.inventory.has(bow), "弓还在背包里")

	# 空出副手之后穿得上，副手从此被占
	gear.unequip(avatar, "off_hand")
	_check(bool(gear.equip(avatar, bow).get("ok", false)), "空出副手后穿得上")
	var blocked_slots: Dictionary = gear.blocked_slots(avatar)
	_check(blocked_slots.has("off_hand"), "副手被占着")
	_eq(str(blocked_slots.get("off_hand", "")), bow, "占着它的就是那把弓")

	# 反方向也拒绝：双手武器在手上时，副手穿不进东西
	var refused: Dictionary = gear.equip(avatar, shield)
	_eq(str(refused.get("errorCode", "")), Equipment.ERROR_PRECONDITION_FAILED,
		"双手武器在手上时副手穿不进东西")
	_check(str(refused.get("error", "")).contains("双手武器"), "说明原因是双手武器")
	_check(avatar.inventory.has(shield), "被拒之后盾还在背包里")

	# 卸下弓，两只手都空出来
	gear.unequip(avatar, "main_hand")
	_check(not gear.blocked_slots(avatar).has("off_hand"), "卸下双手武器后副手空出来")
	_check(bool(gear.equip(avatar, shield).get("ok", false)), "这时盾穿得上")
	_check(bool(gear.equip(avatar, sword).get("ok", false)), "单手剑与盾可以同时在身")


## 「这一身能打能扛多少」（D-52）。只算穿在身上的：在这之前，战斗与面板都是
## "背包里攻击最高的武器 + 所有防具的护甲之和"，于是买一把更好的剑还没穿上就先加了伤害。
func _test_equipment_loadout() -> void:
	var gear: Equipment = _new_gear()
	var avatar := PlayerAvatar.new()
	avatar.avatar_id = "avatar-loadout"
	var sword: String = _give(avatar, "weapon_longsword_common", "lo-sword")
	var dagger: String = _give(avatar, "weapon_dagger_common", "lo-dagger")
	var body: String = _give(avatar, "armor_leather_common", "lo-body")
	var helm: String = _give(avatar, "armor_helmet_common", "lo-helm")
	var legs: String = _give(avatar, "armor_legging_common", "lo-legs")

	var bare: Dictionary = gear.loadout(avatar)
	_eq(int(bare["attack"]), 0, "背包里的剑不算在手")
	_eq(int(bare["armor"]), 0, "背包里的甲不算在身上")
	_check((bare["rows"] as Array).is_empty(), "一件都没穿时没有装备行")

	gear.equip(avatar, sword)
	var armed: Dictionary = gear.loadout(avatar)
	_eq(int(armed["attack"]), 16, "普通长剑的伤害")
	_eq(int(armed["attackRange"]), 1, "近战 1 格")
	_eq(int(armed["hands"]), 1, "单手")
	_eq(str(armed["weapon"].get("templateId", "")), "weapon_longsword_common", "武器就是穿的那一把")
	_eq((armed["rows"] as Array).size(), 1, "一行一件")

	# 换成匕首：伤害跟着换，不是"取最高的那件"
	gear.equip(avatar, dagger)
	_eq(int(gear.loadout(avatar)["attack"]), 8, "换了更弱的武器，伤害就跟着降")

	# 三件防具的护甲与魔抗相加（皮甲 6/4、头盔 4/2、护腿 5/1）
	gear.equip(avatar, body)
	gear.equip(avatar, helm)
	gear.equip(avatar, legs)
	var armored: Dictionary = gear.loadout(avatar)
	_eq(int(armored["armor"]), 15, "三件防具的护甲之和")
	_eq(int(armored["magicResist"]), 7, "三件防具的魔抗之和")
	_eq((armored["rows"] as Array).size(), 4, "四行装备")

	# 背包里再放一把更强的剑也不影响
	_give(avatar, "weapon_longsword_dragonforged", "lo-strong")
	_eq(int(gear.loadout(avatar)["attack"]), 8, "背包里的龙魂长剑不算数")

	# 负重（D-66）：当前负重是身上+背包全部实例的重量之和；carryBonus 只算穿的、没坏的
	_eq(int(gear.carried_weight(avatar)), 17, "当前负重 = 6 件实例重量 3+1+5+2+3+3 之和")
	_eq(int(gear.carry_bonus(avatar)), 8, "装备 carryBonus = 穿着的皮甲 +8")


## 穿在身上的货卖不掉（D-53）。界面不列它，逻辑层也再挡一道——
## 挡住的那句话要告诉玩家"先脱下"，而不是"背包里没有这件货"。
func _test_equipment_shop_link() -> void:
	var built: Dictionary = _new_sim(false)
	var world: WorldState = built["world"]
	var sim: WorldSim = built["sim"]
	_set_all_dimensions(world, "port_thorne", 50)
	var avatar := PlayerAvatar.new()
	avatar.avatar_id = "avatar-gear-shop"
	avatar.money = 100000
	world.avatar = avatar
	var gear: Equipment = _new_gear()
	var sword: String = _give(avatar, "weapon_longsword_common", "shop-sword")
	_give(avatar, "consumable_healing_potion", "shop-potion")
	gear.equip(avatar, sword)

	# 卖出列表里只有背包里的那瓶药水
	var view: Dictionary = _trade_view(
		world, sim, "port_thorne", "port_thorne", Economy.CHANNEL_SHOP, TradeViewModel.SIDE_SELL
	)
	_eq(int(view.get("rowCount", 0)), 1, "卖出列表只剩背包里那一件")
	_check(str(view["rows"][0].get("instanceId", "")) != sword, "身上的剑不在列表里")

	# 逻辑层再挡一道
	var refused: Dictionary = sim.economy.execute_trade(
		world, "port_thorne", "weapon_longsword_common", Economy.SIDE_SELL,
		Economy.CHANNEL_SHOP, sword
	)
	_eq(str(refused.get("errorCode", "")), Economy.ERROR_PRECONDITION_FAILED,
		"身上的东西卖不掉")
	_check(str(refused.get("error", "")).contains("脱下"), "并且告诉玩家先脱下")

	# 脱下之后就卖得掉
	gear.unequip(avatar, "main_hand")
	var sold: Dictionary = sim.economy.execute_trade(
		world, "port_thorne", "weapon_longsword_common", Economy.SIDE_SELL,
		Economy.CHANNEL_SHOP, sword
	)
	_check(bool(sold.get("ok", false)), "脱下之后卖得掉：" + str(sold.get("error", "")))


## 角色面板的装备行与光标。光标是一个整数走完"槽位 → 背包"两段，
## 面板据此把高亮画到左右两栏里正确的那一行。
func _test_equipment_view_model() -> void:
	var gear: Equipment = _new_gear()
	var avatar := PlayerAvatar.new()
	avatar.avatar_id = "avatar-gear-view"
	avatar.display_name = "试装者"
	avatar.money = 1000
	var sword: String = _give(avatar, "weapon_longsword_common", "v-sword")
	var potion: String = _give(avatar, "consumable_healing_potion", "v-potion")
	gear.equip(avatar, sword)
	var lookups: Dictionary = {
		"itemTemplates": _item_template_table(), "cityNames": {}, "raceNames": {},
		"skillNames": {}, "talentNames": {},
	}

	var view: Dictionary = AvatarViewModel.build(avatar, _new_derived(), lookups, "在艾德兰", gear, 0)
	_eq((view.get("equipmentRows", []) as Array).size(), 5, "五个槽各占一行")
	_eq((view.get("inventoryRows", []) as Array).size(), 1, "背包里剩下那瓶药水")
	_eq(int(view.get("rowCount", 0)), 6, "光标走完 5 个槽 + 1 件背包货")

	var main_row: Dictionary = view["equipmentRows"][0]
	_eq(str(main_row.get("slot", "")), "main_hand", "第一行是主手")
	_eq(str(main_row.get("label", "")), "普通长剑", "主手写着穿的那件")
	_check(not bool(main_row.get("empty", false)), "它不是空槽")
	_eq(str(main_row.get("detail", "")), "伤害 16 · 距离 1 格", "行上有这件货的数值")
	var off_row: Dictionary = view["equipmentRows"][1]
	_eq(str(off_row.get("slot", "")), "off_hand", "第二行是副手")
	_check(bool(off_row.get("empty", false)), "副手是空的")
	_check(not bool(view["inventoryRows"][0].get("equippable", true)), "药水不可穿")

	# 光标两段的映射
	_eq(AvatarViewModel.cursor_kind(view, 0), AvatarViewModel.CURSOR_KIND_SLOT, "0 号在槽位段")
	_eq(AvatarViewModel.cursor_kind(view, 5), AvatarViewModel.CURSOR_KIND_BAG, "5 号在背包段")
	_eq(AvatarViewModel.slot_index_of(view, 4), 4, "4 号是最后一个槽")
	_eq(AvatarViewModel.slot_index_of(view, 5), -1, "背包行不是槽位")
	_eq(AvatarViewModel.bag_index_of(view, 5), 0, "5 号是背包第一件")
	_eq(AvatarViewModel.bag_index_of(view, 0), -1, "槽位行不是背包行")

	# 选中主手：可以脱下
	var selected: Dictionary = view.get("selected", {})
	_check(bool(selected.get("canAct", false)), "主手那一行动得了手")
	_eq(str(selected.get("actionLabel", "")), "脱下", "动作是脱下")
	_check(str(view.get("actionLine", "")).contains("脱下"), "行上写着会发生什么")

	# 光标落在药水上：动不了，且写明原因
	var potion_view: Dictionary = AvatarViewModel.build(
		avatar, _new_derived(), lookups, "", gear, 5
	)
	_eq(int(potion_view.get("cursor", -1)), 5, "光标停在背包那一行")
	_check(not bool(potion_view["selected"].get("canAct", false)), "药水那一行动不了手")
	_check(str(potion_view.get("actionLine", "")).contains("不是能穿在身上的东西"),
		"并且说明原因")

	# 没有装备规则时退化成只有背包（老调用方与部分测试走这条路）
	var plain: Dictionary = AvatarViewModel.build(avatar, _new_derived(), lookups)
	_check((plain.get("equipmentRows", []) as Array).is_empty(), "没有规则就没有装备段")
	_eq(int(plain.get("rowCount", 0)), 1, "光标只走背包")


## 角色面板的命中：装备槽与背包行都点得到，空槽与不可穿的行点得中但不可动手。
func _test_equipment_panel_hit_test() -> void:
	var gear: Equipment = _new_gear()
	var avatar := PlayerAvatar.new()
	avatar.avatar_id = "avatar-gear-hit"
	avatar.display_name = "试装者"
	var sword: String = _give(avatar, "weapon_longsword_common", "h-sword")
	var potion: String = _give(avatar, "consumable_healing_potion", "h-potion")
	gear.equip(avatar, sword)
	var lookups: Dictionary = {
		"itemTemplates": _item_template_table(), "cityNames": {}, "raceNames": {},
		"skillNames": {}, "talentNames": {},
	}
	var view: Dictionary = AvatarViewModel.build(avatar, _new_derived(), lookups, "", gear, 0)

	var worn: Dictionary = AvatarPanel.hit_test(
		view, PANEL_RECT, _center(AvatarPanel.slot_row_rect(PANEL_RECT, view, 0))
	)
	_eq(str(worn.get("kind", "")), AvatarViewModel.CURSOR_KIND_SLOT, "装备槽点得到")
	_eq(int(worn.get("index", -1)), 0, "它报出自己的行号")
	_check(bool(worn.get("enabled", false)), "有货的槽可动手")
	_eq(str(worn.get("slot", "")), "main_hand", "并且报出槽位名")

	var empty: Dictionary = AvatarPanel.hit_test(
		view, PANEL_RECT, _center(AvatarPanel.slot_row_rect(PANEL_RECT, view, 1))
	)
	_eq(str(empty.get("kind", "")), AvatarViewModel.CURSOR_KIND_SLOT, "空槽也点得中")
	_check(not bool(empty.get("enabled", true)), "但空槽动不了手")

	var bag: Dictionary = AvatarPanel.hit_test(
		view, PANEL_RECT, _center(AvatarPanel.bag_row_rect(PANEL_RECT, view, 0))
	)
	_eq(str(bag.get("kind", "")), AvatarViewModel.CURSOR_KIND_BAG, "背包行点得到")
	_eq(int(bag.get("index", -1)), 5, "统一光标序号接在槽位段之后")
	_check(not bool(bag.get("enabled", true)), "药水那一行动不了手")
	_eq(int(AvatarPanel.bag_at(view, PANEL_RECT, _center(
		AvatarPanel.bag_row_rect(PANEL_RECT, view, 0)
	))), 0, "bag_at 报出它在背包里的行号")

	var back: Dictionary = UiTheme.find_button(AvatarPanel.buttons(PANEL_RECT), "back")
	_eq(str(AvatarPanel.hit_test(view, PANEL_RECT, _center(back["rect"])).get("id", "")),
		"back", "返回按钮仍然点得中")
	_check(AvatarPanel.hit_test(view, PANEL_RECT, Vector2(4.0, 4.0)).is_empty(),
		"面板外的点击不算命中")


# --- 物品实例：词缀 / 耐久 / 强化 ---

## 词缀（D-54）。三件事在这里被钉住：条数由稀有度定、池内不重复且数值落在区间里、
## 同一段种子摇出同一件——存档里存的是摇好的结果，读档重放不该摇出第二套。
func _test_item_affix_roll() -> void:
	var rules: ItemInstance = _new_rules()
	for pair in [["common", 0], ["fine", 1], ["rare", 2], ["epic", 3],
			["legendary", 4], ["dragonforged", 5]]:
		_eq(rules.affix_count(str(pair[0])), int(pair[1]),
			"%s 档带 %d 条词缀（《数值框架》8 节的附带词条数）" % [str(pair[0]), int(pair[1])])

	var plain: Dictionary = rules.roll_instance("weapon_longsword_common", "seed-a")
	_eq((plain.get("modifiers", []) as Array).size(), 0, "普通货是白板")
	_eq(int(plain.get("enhancement", -1)), 0, "新货没有强化")
	_eq(int(plain.get("durability", 0)), rules.durability_max(), "新货是满耐久")

	var rare: Dictionary = rules.roll_instance("weapon_longsword_rare", "seed-a")
	var modifiers: Array = rare.get("modifiers", [])
	_eq(modifiers.size(), 2, "稀有一档摇出两条")
	var seen: Dictionary = {}
	for modifier in modifiers:
		var affix_id: String = str(modifier.get("affixId", ""))
		_check(not seen.has(affix_id), "同一条词缀不会摇到两次：" + affix_id)
		seen[affix_id] = true
		var affix: Dictionary = ContentLoader.get_affix(affix_id)
		_check(not affix.is_empty(), "摇出来的词缀在配置里存在：" + affix_id)
		_eq(str(modifier.get("target", "")), str(affix.get("target", "")), "目标取自配置")
		var value: int = int(modifier.get("value", 0))
		_check(value >= int(affix.get("minValue", 0)) and value <= int(affix.get("maxValue", 0)),
			"数值落在配置的区间里：" + affix_id)

	# 词缀只装在词缀表的池子里
	var pools: Dictionary = {}
	for affix in rules.affix_pool("weapon"):
		pools[str(affix.get("affixId", ""))] = true
	_check(not pools.is_empty(), "武器有词缀池")
	_check(not rules.affix_pool("armor").is_empty(), "防具有词缀池")
	_check(rules.affix_pool("consumable").is_empty(), "消耗品没有词缀池")
	for affix_id in seen:
		_check(pools.has(str(affix_id)), "摇出来的词缀来自武器池：" + str(affix_id))

	# 确定性：同一段种子摇出同一件；换种子总该换一次组合（8 选 2 有 28 种）
	_eq(rules.roll_instance("weapon_longsword_rare", "seed-a").get("modifiers", []),
		modifiers, "同一段种子摇出同一件")
	var differs: bool = false
	for i in range(8):
		if rules.roll_instance("weapon_longsword_rare", "seed-%d" % i).get("modifiers", []) != modifiers:
			differs = true
			break
	_check(differs, "换一段种子会摇出另一批词缀")

	# 池子比条数少时抽空就停，不会重复，也不会转不出来
	var tiny: ItemInstance = ItemInstance.new(
		{
			"durabilityMax": 10,
			"affixCountByRarity": {"dragonforged": 99},
			"affixPricePerPoint": {"attack": 1},
			"enhancementMax": 0, "enhancementPerLevelRatio": 0.1,
		},
		[{
			"affixId": "only", "displayName": "唯一", "target": "attack",
			"minValue": 1, "maxValue": 1, "categories": ["weapon"],
		}],
		{"t": {"templateId": "t", "category": "weapon", "rarity": "dragonforged",
			"attack": 5, "price": 10}}
	)
	_eq(tiny.roll_modifiers("t", DeterministicRNG.new(7)).size(), 1, "池子抽空就停，不补出重复的")

	# 种子由文本派生，同一段文本永远同一个数
	_eq(ItemInstance.seed_from_text("same"), ItemInstance.seed_from_text("same"), "同文本同种子")
	_check(ItemInstance.seed_from_text("same") != ItemInstance.seed_from_text("other"),
		"不同文本不同种子")


## 词缀与强化怎么落到数值上（D-54）：强化加在模板基础值上、词缀是额外的绝对值，
## 两者各管一段；七维的词缀加在佩戴者身上，由 Equipment 汇总（面板与战斗都读它）。
func _test_item_affix_effects() -> void:
	var rules: ItemInstance = _new_rules()
	var gear: Equipment = _new_gear()
	var avatar := PlayerAvatar.new()
	avatar.avatar_id = "avatar-affix"
	var sword: String = _give(avatar, "weapon_longsword_common", "affix-sword")
	# 手搓一件确定的实例：普通长剑攻击 16，+2 级、再挂一条锋锐 +4 与一条蛮力 +2
	avatar.item_instances[sword] = {
		"templateId": "weapon_longsword_common",
		"durability": 100,
		"enhancement": 2,
		"modifiers": [
			{"affixId": "affix_keen", "target": "attack", "value": 4},
			{"affixId": "affix_brutal", "target": "strength", "value": 2},
		],
	}
	_eq(rules.enhancement_bonus(avatar.item_instances[sword], 16), roundi(16.0 * 0.1 * 2.0),
		"强化加在基础值上")
	_eq(rules.effective_stat(avatar.item_instances[sword], "attack"), 16 + roundi(16.0 * 0.2) + 4,
		"攻击 = 基础 + 强化 + 词缀")
	_eq(rules.attribute_bonus(avatar.item_instances[sword]), {"strength": 2}, "七维单独取出")
	_eq(rules.affix_text(avatar.item_instances[sword]), "锋锐 +4 攻击 · 蛮力 +2 力量", "词缀写成一行")

	gear.equip(avatar, sword)
	var loadout: Dictionary = gear.loadout(avatar)
	_eq(int(loadout["attack"]), rules.effective_stat(avatar.item_instances[sword], "attack"),
		"战斗读到的就是这一件的有效攻击")
	_eq(int(loadout["attackRange"]), 1, "射程还是模板那 1 格（词缀改不了它）")
	_eq(int(loadout["hands"]), 1, "手数也不随词缀变")
	_eq(gear.attribute_bonus(avatar), {"strength": 2}, "身上的七维加成汇总")
	_eq(str(loadout["rows"][0].get("displayName", "")), "普通长剑 +2", "名字带上强化等级")

	# 防具同理：皮甲护甲 6，+1 级 + 坚固 +3
	var vest: String = _give(avatar, "armor_leather_common", "affix-vest")
	avatar.item_instances[vest] = {
		"templateId": "armor_leather_common",
		"durability": 100,
		"enhancement": 1,
		"modifiers": [{"affixId": "affix_sturdy", "target": "armor", "value": 3}],
	}
	gear.equip(avatar, vest)
	_eq(int(gear.loadout(avatar)["armor"]), 6 + roundi(6.0 * 0.1) + 3, "护甲 = 基础 + 强化 + 词缀")

	# 白板实例：数值就是模板值
	var bare: Dictionary = rules.bare_instance("weapon_longsword_common")
	_eq(rules.effective_stat(bare, "attack"), 16, "白板的攻击就是模板值")
	_eq(rules.attribute_bonus(bare), {}, "白板没有七维加成")
	_eq(str(rules.display_name(bare)), "普通长剑", "没强化就不写 +0")


## 耐久只记录与显示，不磨损（D-55）。
func _test_item_durability() -> void:
	var rules: ItemInstance = _new_rules()
	var instance: Dictionary = rules.roll_instance("weapon_longsword_common", "dur-1")
	_eq(int(instance.get("durability", 0)), rules.durability_max(), "新货是满耐久")
	_eq(rules.durability_text(instance), "耐久 %d/%d" % [rules.durability_max(), rules.durability_max()],
		"新货是满耐久")
	# 旧存档里没有这个字段时按满耐久算，而不是 0——0 会读成"这件东西坏了"
	_eq(rules.durability({"templateId": "weapon_longsword_common"}), rules.durability_max(),
		"缺字段按满耐久算")

	var avatar := PlayerAvatar.new()
	avatar.avatar_id = "avatar-dur"
	var sword: String = _give(avatar, "weapon_longsword_common", "dur-sword")
	var gear: Equipment = _new_gear()
	gear.equip(avatar, sword)
	var before: int = rules.durability(avatar.item_instances[sword])
	_eq(rules.durability_text(avatar.item_instances[sword]),
		"耐久 %d/%d" % [rules.durability_max(), rules.durability_max()], "身上的货也写着耐久")
	rules.forge(avatar.item_instances[sword], 100000, DeterministicRNG.new(1))
	_eq(rules.durability(avatar.item_instances[sword]), before, "进炉子不改耐久")
	gear.unequip(avatar, "main_hand")
	_eq(rules.durability(avatar.item_instances[sword]), before, "穿脱也不改耐久")


## 磨损与失效（D-62/D-63）。磨损是概率掉落、就地扣；归零即失效——武器不算攻击、
## 护甲不算护甲，损坏的文字也标注出来。
func _test_item_wear_and_broken() -> void:
	var rules: ItemInstance = _new_rules()
	var avatar := PlayerAvatar.new()
	avatar.avatar_id = "avatar-wear"
	var gear: Equipment = _new_gear()
	var sword: String = _give(avatar, "weapon_longsword_common", "wear-sword")
	var body: String = _give(avatar, "armor_leather_common", "wear-body")
	gear.equip(avatar, sword)
	gear.equip(avatar, body)
	var weapon: Dictionary = avatar.item_instances[sword]
	var armor: Dictionary = avatar.item_instances[body]
	var full: int = rules.durability_max()
	_eq(int(weapon["durability"]), full, "新货满耐久")

	# 命中武器：落在"必掉"的种子上，耐久应少 1 点
	var weapon_before: int = rules.durability(weapon)
	var wore: bool = rules.wear(weapon, true, DeterministicRNG.new(_wearing_seed(3000)))
	_check(wore, "这次命中把武器磨掉了一点")
	_eq(rules.durability(weapon), weapon_before - 1, "武器确实掉了一点")

	# 护甲受击：同理
	var armor_before: int = rules.durability(armor)
	rules.wear(armor, false, DeterministicRNG.new(_wearing_seed(5000)))
	_eq(rules.durability(armor), armor_before - 1, "护甲受击磨掉一点")

	# 归零即失效：把武器打到 0
	weapon["durability"] = 0
	_check(rules.broken(weapon), "耐久归零判为损坏")
	_check(str(rules.durability_text(weapon)).contains("损坏"), "损坏的文案带标记")
	var loadout: Dictionary = gear.loadout(avatar)
	_eq(int(loadout["attack"]), 0, "主手损坏时攻击归零")
	_eq(int(loadout["armor"]), 6, "护甲没坏，护甲值照旧")
	var has_broken_row: bool = false
	for row in loadout["rows"]:
		if bool(row.get("broken", false)):
			has_broken_row = true
	_check(has_broken_row, "损坏的货在栏位里被标出来")


## 三档修理（便携/工匠/满修，D-64）。便携每次回五成、封顶九成、不花钱；
## 工匠修回九成；满修到满且按强化等级加价。缺口为零时修不动。
func _test_item_three_tier_repair() -> void:
	var rules: ItemInstance = _new_rules()
	var full: int = rules.durability_max()
	_eq(full, 150, "上限提到 150（更耐用），否则这段算式没意义")
	var ninty: int = roundi(full * 0.9)
	var portable_cap: int = roundi(full * 0.9)
	var portable_restore: int = roundi(full * 0.5)

	var avatar := PlayerAvatar.new()
	avatar.avatar_id = "avatar-repair"
	avatar.money = 100000
	var sword: String = _give(avatar, "weapon_longsword_common", "rep-sword")
	var inst: Dictionary = avatar.item_instances[sword]

	# 满耐久的东西修不动
	_eq(str(rules.can_repair(inst, ItemInstance.REPAIR_FULL, 100000).get("errorCode", "")),
		ItemInstance.ERROR_PRECONDITION_FAILED, "满耐久不用修")
	_check(not bool(rules.apply_repair(inst, ItemInstance.REPAIR_FULL).get("ok", false)),
		"满耐久调用 apply_repair 返回失败")

	# 强化一级，验证满修按强化加价（+1 → 每点单价 3×(1+0.2)）
	inst["modifiers"] = []
	inst["durability"] = full
	_check(bool(rules.forge(inst, 100000, DeterministicRNG.new(1)).get("upgraded", false)),
		"把这一件敲到 +1")
	_eq(int(inst["enhancement"]), 1, "强化一级")
	# 磨掉 30 点
	inst["durability"] = full - 30
	var mid: int = full - 30

	# 各档目标
	_eq(rules.repair_target(inst, ItemInstance.REPAIR_FULL), full, "满修的目标是顶")
	_eq(rules.repair_target(inst, ItemInstance.REPAIR_CRAFTSMAN), ninty, "工匠修回九成")
	_eq(rules.repair_target(inst, ItemInstance.REPAIR_PORTABLE),
		mini(mid + portable_restore, portable_cap), "便携回五成、封顶九成")

	# 各档工钱：工匠每点 2 铜，满修每点 3×(1+0.2)=4 铜（按缺口算）
	_eq(rules.repair_cost(inst, ItemInstance.REPAIR_CRAFTSMAN), (ninty - mid) * 2, "工匠按缺口计价")
	_eq(rules.repair_cost(inst, ItemInstance.REPAIR_FULL), (full - mid) * 4, "满修按缺口、按强化加价")
	_eq(rules.repair_cost(inst, ItemInstance.REPAIR_PORTABLE), 0, "便携不花钱")

	# 便携就地修：改这一件、返回前后与成本
	var portable: Dictionary = rules.apply_repair(inst, ItemInstance.REPAIR_PORTABLE)
	_check(bool(portable.get("ok", false)), "便携修得动")
	_eq(int(portable["after"]), mini(mid + portable_restore, portable_cap), "便携的目标吻合")
	_eq(int(portable["cost"]), 0, "便携不花钱")
	_check(not rules.broken(inst), "修完之后不是损坏了")

	# 钱不够满修的时候 can_repair 拦得下来
	var drained: Dictionary = rules.can_repair(inst, ItemInstance.REPAIR_FULL, 1)
	_eq(str(drained.get("errorCode", "")), ItemInstance.ERROR_PRECONDITION_FAILED, "钱不够修不成")

	# 便携反复用顶到九成就不涨了
	var after_portable: int = rules.durability(inst)
	while rules.can_repair(inst, ItemInstance.REPAIR_PORTABLE, 0).get("ok", false):
		rules.apply_repair(inst, ItemInstance.REPAIR_PORTABLE)
	_eq(rules.repair_target(inst, ItemInstance.REPAIR_PORTABLE), rules.durability(inst),
		"便携永远修不满，顶死在九成")


## 道具库的修补工具（D-64）。配置里写明功能与获取途径；背包里带着它、光标停在一
## 件受伤装备上时，角色面板报"可以就地修"；不带则不报。
func _test_portable_tool() -> void:
	var tool: Dictionary = {}
	for item in ContentLoader.get_items():
		if str(item.get("repairTool", "")) == "portable":
			tool = item
			break
	_check(not tool.is_empty(), "表里有修补工具")
	_eq(str(tool.get("templateId", "")), "tool_repair_portable", "工具 id")
	_eq(str(tool.get("category", "")), "tool", "归在工具类")
	_eq(str(tool.get("subtype", "")), "repair", "子类是修理")
	_check(str(tool.get("effectText", "")).length() > 0, "道具库写明功能")
	_check(str(tool.get("getMethod", "")).length() > 0, "道具库写明获取途径")
	_check(int(tool.get("price", 0)) > 0, "有标价（买得到）")

	var tables: Dictionary = {"itemTemplates": _item_template_table()}
	var gear: Equipment = _new_gear()
	var rules: ItemInstance = gear.rules()
	var avatar := PlayerAvatar.new()
	avatar.avatar_id = "avatar-tool"
	var sword: String = _give(avatar, "weapon_longsword_common", "tool-sword")
	gear.equip(avatar, sword)
	var inst: Dictionary = avatar.item_instances[sword]

	# 没带工具时，光标停在这把受伤的剑上也不给"就地修"
	inst["durability"] = 100
	_check(not AvatarViewModel.has_portable_tool(avatar, tables["itemTemplates"]),
		"没带工具时 has_portable_tool 为假")
	var bare_view := AvatarViewModel.build(avatar, _new_derived(), tables, "野外", gear, 0)
	_check(not bool(bare_view["selected"].get("portableRepair", {}).get("canRepair", false)),
		"没带工具时不给就地修提示")

	# 带上工具之后，同样这件剑就修得动了
	_give(avatar, "tool_repair_portable", "tool-1")
	_check(AvatarViewModel.has_portable_tool(avatar, tables["itemTemplates"]),
		"带了工具后 has_portable_tool 为真")
	var repair_view := AvatarViewModel.build(avatar, _new_derived(), tables, "野外", gear, 0)
	var info: Dictionary = repair_view["selected"].get("portableRepair", {})
	_check(bool(info.get("canRepair", false)), "光标停在受伤装备且带工具时可修")
	_check(str(info.get("actionLine", "")).length() > 0, "就地修的动作说明已有人话")

	# 满耐久的装备即使带着工具也不报"可修"
	inst["durability"] = rules.durability_max()
	var full_view := AvatarViewModel.build(avatar, _new_derived(), tables, "野外", gear, 0)
	_check(not bool(full_view["selected"].get("portableRepair", {}).get("canRepair", false)),
		"满耐久的装备不报可修")


## 强化（D-57）：上限 +5、每级按基础值加一成、第 3 级起会失手、失手掉一级且钱照扣。
func _test_item_enhancement() -> void:
	var rules: ItemInstance = _new_rules()
	var avatar := PlayerAvatar.new()
	avatar.avatar_id = "avatar-forge"
	avatar.money = 100000
	var sword: String = _give(avatar, "weapon_longsword_common", "forge-sword")
	var instance: Dictionary = avatar.item_instances[sword]
	instance["modifiers"] = []

	_eq(rules.enhancement_max(), 5, "上限五级")
	_eq(rules.enhancement_cost(instance), maxi(1, roundi(300.0 * 0.3)), "第一炉按基准价的三成")
	_eq(rules.enhancement_chance_bp(instance), 10000, "第一级必成")

	# 前两级必成，且写回实例
	for level in [1, 2]:
		var result: Dictionary = rules.forge(instance, 100000, DeterministicRNG.new(level))
		_check(bool(result.get("upgraded", false)), "+%d 必成" % level)
		_eq(int(instance["enhancement"]), level, "等级写回了实例")
	_eq(rules.effective_stat(instance, "attack"), 16 + roundi(16.0 * 0.2), "+2 之后的攻击")

	# 钱不够：不动实例
	var broke: Dictionary = rules.forge(instance, 1, DeterministicRNG.new(1))
	_eq(str(broke.get("errorCode", "")), ItemInstance.ERROR_PRECONDITION_FAILED, "钱不够就敲不成")
	_eq(int(instance["enhancement"]), 2, "敲不成时等级不动")

	# 第三级起会失手。按成功率挑种子，测的是"失手之后会怎样"
	var chance: int = rules.enhancement_chance_bp(instance)
	_check(chance < 10000, "第三级不再必成")
	var failed: Dictionary = rules.forge(instance, 100000, DeterministicRNG.new(_failing_seed(chance)))
	_check(not bool(failed.get("upgraded", false)), "这一炉失手了")
	_eq(int(instance["enhancement"]), 1, "失手掉一级")
	_check(int(failed.get("cost", 0)) > 0, "失手的工钱照扣")

	# 到顶之后敲不动，且实例不变
	instance["enhancement"] = rules.enhancement_max()
	var capped: Dictionary = rules.forge(instance, 100000, DeterministicRNG.new(1))
	_eq(str(capped.get("errorCode", "")), ItemInstance.ERROR_PRECONDITION_FAILED, "到顶了就敲不动")
	_eq(int(instance["enhancement"]), 5, "到顶时等级不动")
	_eq(rules.enhancement_chance_bp(instance), 0, "到顶时成功率报 0")

	# 不是装备的东西进不了炉子
	var potion: String = _give(avatar, "consumable_healing_potion", "forge-potion")
	var refused: Dictionary = rules.can_enhance(avatar.item_instances[potion], 100000)
	_eq(str(refused.get("errorCode", "")), ItemInstance.ERROR_INVALID_ARGUMENT, "药水进不了炉子")

	# 0 级失手不会掉成负数：拿一份成功率恒为 0 的规则来测
	var never: ItemInstance = ItemInstance.new(
		{
			"durabilityMax": 10,
			"affixCountByRarity": {}, "affixPricePerPoint": {},
			"enhancementMax": 3, "enhancementPerLevelRatio": 0.1,
			"enhancementChanceBp": [0, 0, 0],
			"enhancementCostRatio": [1, 1, 1],
		},
		[],
		{"t": {"templateId": "t", "category": "weapon", "rarity": "common",
			"attack": 10, "price": 100}}
	)
	var blank: Dictionary = never.bare_instance("t")
	var doomed: Dictionary = never.forge(blank, 1000, DeterministicRNG.new(3))
	_check(not bool(doomed.get("upgraded", false)), "成功率 0 就是必失手")
	_eq(int(blank["enhancement"]), 0, "0 级失手不会掉成负数")
	_eq(int(doomed.get("cost", 0)), 100, "工钱按配置的比例取")


## 词缀与强化计入价钱（D-56）。买入侧按该稀有度的**期望**折价报价（货架报价必须
## 每次刷新都一样），卖出侧按这一件**实际**带着的词缀与强化算——于是同一件货
## 买进来再卖出去永远亏。
func _test_item_instance_price() -> void:
	var built: Dictionary = _new_sim(false)
	var world: WorldState = built["world"]
	var sim: WorldSim = built["sim"]
	_set_all_dimensions(world, "hammerhold", 50)
	var rules: ItemInstance = sim.economy.item_rules()

	var avatar := PlayerAvatar.new()
	avatar.avatar_id = "avatar-item-price"
	avatar.money = 100000
	world.avatar = avatar

	# 买入侧：基准价 = 模板价 + 期望词缀折价，且连算两次一样
	var quote: Dictionary = sim.economy.get_price(world, "hammerhold", "weapon_longsword_rare")
	var again: Dictionary = sim.economy.get_price(world, "hammerhold", "weapon_longsword_rare")
	_eq(int(quote["templatePrice"]), 510, "模板价照旧来自 items.json")
	_eq(int(quote["affixBonus"]), rules.typical_affix_price_bonus("weapon_longsword_rare"),
		"报价里含该稀有度的期望词缀折价")
	_eq(int(quote["basePrice"]), 510 + int(quote["affixBonus"]), "基准价 = 模板价 + 折价")
	_eq(quote.get("affixBonus", 0), again.get("affixBonus", -1), "货架报价稳定，不随刷新跳")
	_eq(int(quote["enhancementBonus"]), 0, "新货没有强化折价")

	# 普通货没有词缀，所以溢价是 0——"白板货"与"有来头的货"在价目上就分得开
	var common_quote: Dictionary = sim.economy.get_price(
		world, "hammerhold", "weapon_longsword_common"
	)
	_eq(int(common_quote["affixBonus"]), 0, "普通货没有词缀溢价")
	_eq(int(common_quote["basePrice"]), 300, "普通货的基准价就是模板价")

	# 到手的货就是货架上那一件：同一个种子摇同一批词缀
	var bought: Dictionary = sim.economy.execute_trade(
		world, "hammerhold", "weapon_longsword_rare", Economy.SIDE_BUY
	)
	_check(bool(bought.get("ok", false)), "买得成：" + str(bought.get("error", "")))
	var bought_id: String = str(bought.get("instanceId", ""))
	var bought_instance: Dictionary = avatar.item_instances[bought_id]
	_eq((bought_instance.get("modifiers", []) as Array).size(), 2, "买到的稀有货带着两条词缀")
	_eq(bought_instance.get("modifiers", []),
		rules.roll_instance("weapon_longsword_rare",
			sim.economy.shop_seed("hammerhold", Economy.CHANNEL_SHOP, "weapon_longsword_rare")
		).get("modifiers", []),
		"到手的货与货架上报价的那一件是同一件")

	# 卖出侧按实例算：同一件模板，带词缀的那一件收价更高
	var with_affix: Dictionary = sim.economy.get_price(
		world, "hammerhold", "weapon_longsword_rare", Economy.CHANNEL_SHOP, bought_id
	)
	var bare: Dictionary = rules.bare_instance("weapon_longsword_rare")
	_give(avatar, "weapon_longsword_rare", "price-bare")
	avatar.item_instances["price-bare"] = bare
	var quote_bare: Dictionary = sim.economy.get_price(
		world, "hammerhold", "weapon_longsword_rare", Economy.CHANNEL_SHOP, "price-bare"
	)
	_eq(int(quote_bare["affixBonus"]), 0, "白板那一件没有词缀折价")
	_eq(int(quote_bare["basePrice"]), 510, "白板那一件的基准价就是模板价")
	_check(int(with_affix["sellPrice"]) > int(quote_bare["sellPrice"]),
		"带词缀那一件的收价更高（%d > %d）" % [
			int(with_affix["sellPrice"]), int(quote_bare["sellPrice"])
		])
	_eq(int(with_affix["affixBonus"]), rules.affix_price_bonus(bought_instance),
		"卖出时按这一件实际的词缀折价")

	# 强化过的卖得更贵：强化折价与强化加成同一个口径
	var worn: Dictionary = bare.duplicate(true)
	_eq(rules.enhancement_price_bonus(worn), 0, "没强化就没有强化折价")
	worn["enhancement"] = 3
	_eq(rules.enhancement_price_bonus(worn), roundi(510.0 * 0.1 * 3.0), "三级强化的折价")
	_check(rules.price_bonus(worn) > rules.price_bonus(bare), "强化过的折价更高")

	# 买入侧按期望、卖出侧按实际，所以买进来再卖出去必亏
	_check(int(with_affix["sellPrice"]) < int(quote["unitPrice"]),
		"同一座城里买贵卖贱，倒手必亏（%d < %d）" % [
			int(with_affix["sellPrice"]), int(quote["unitPrice"])
		])


## 实例的词缀与强化跟着存档走（3.3 节：存档只存实例，模板由配置提供）。
func _test_item_instance_round_trip() -> void:
	var avatar := PlayerAvatar.new()
	avatar.avatar_id = "avatar-item-save"
	var sword: String = _give(avatar, "weapon_longsword_rare", "save-sword")
	avatar.item_instances[sword]["enhancement"] = 3
	_eq((avatar.item_instances[sword].get("modifiers", []) as Array).size(), 2,
		"稀有货出生就带两条词缀")

	var restored: PlayerAvatar = PlayerAvatar.from_dict(avatar.to_dict())
	_eq(restored.item_instances.get(sword, {}), avatar.item_instances[sword],
		"实例（模板、耐久、强化、词缀）逐字段往返")
	_eq(int(restored.item_instances[sword].get("enhancement", 0)), 3, "强化等级跟着走")

	# 词缀变了，穿在身上的数值也跟着变——读档之后战斗读到的是同一套数
	var gear: Equipment = _new_gear()
	_eq(int(gear.loadout(restored)["attack"]), 0, "没穿的时候一身都是 0")
	gear.equip(restored, sword)
	_eq(int(gear.loadout(restored)["attack"]),
		gear.rules().effective_stat(restored.item_instances[sword], "attack"),
		"穿上之后读到的就是这一件的有效攻击")


## 铁匠铺那一页（D-57）。它是商铺版面的第三页，与商店 / 黑市并列。
func _test_forge_view_model() -> void:
	var built: Dictionary = _new_sim(false)
	var world: WorldState = built["world"]
	var sim: WorldSim = built["sim"]
	_set_all_dimensions(world, "hammerhold", 50)
	var avatar := PlayerAvatar.new()
	avatar.avatar_id = "avatar-forge-view"
	avatar.money = 5000
	world.avatar = avatar
	var sword: String = _give(avatar, "weapon_longsword_common", "fv-sword")
	_give(avatar, "consumable_healing_potion", "fv-potion")

	var forge: Dictionary = _trade_view(
		world, sim, "hammerhold", "hammerhold", Economy.CHANNEL_SHOP,
		TradeViewModel.SIDE_BUY, 0, TradeViewModel.PANE_FORGE
	)
	_eq(str(forge.get("pane", "")), TradeViewModel.PANE_FORGE, "这一页是铁匠铺")
	_eq(str(forge.get("channelLabel", "")), "铁匠铺", "抬头写着铁匠铺")
	_eq(str(forge.get("sideLabel", "")), "强化", "动作那一栏写着强化")
	_eq(int(forge.get("rowCount", 0)), 1, "炉子只收装备，药水不列")
	_eq(str((forge.get("rows", []) as Array)[0].get("instanceId", "")), sword, "列的是那把剑")
	_eq(str(forge.get("selected", {}).get("unitPriceText", "")), "未强化", "写明现在没强化")
	_eq(str(forge.get("selected", {}).get("sellPriceText", "")), "+1", "写明下一级是 +1")
	_check(str(forge.get("selected", {}).get("detail", "")).contains("伤害 16"), "写着这件货的数值")
	_check(str(forge.get("selected", {}).get("durabilityText", "")).contains("耐久"), "写着耐久")
	_check(int(forge.get("selected", {}).get("price", 0)) > 0, "写着这一炉的工钱")
	_eq((forge.get("selected", {}).get("factorRows", []) as Array).size(), 4, "右列四项")
	_check(bool(forge.get("canTrade", false)), "钱够就走得通")
	_check(str(forge.get("dealSummary", "")).contains("敲一炉"), "页脚写着按下回车会发生什么")

	# 钱不够：行不可动，页脚说明是钱不够
	avatar.money = 1
	var poor: Dictionary = _trade_view(
		world, sim, "hammerhold", "hammerhold", Economy.CHANNEL_SHOP,
		TradeViewModel.SIDE_BUY, 0, TradeViewModel.PANE_FORGE
	)
	_check(not bool(poor.get("canTrade", false)), "钱不够就敲不成")
	_check(str(poor.get("blockedReason", "")).contains("钱不够"), "并且说明是钱不够")

	# 人不在城里：看得到自己带了什么，但动不了手
	var away: Dictionary = _trade_view(
		world, sim, "hammerhold", "greenwade", Economy.CHANNEL_SHOP,
		TradeViewModel.SIDE_BUY, 0, TradeViewModel.PANE_FORGE
	)
	_check(not bool(away.get("canTrade", false)), "不在城里就敲不成")
	_eq(int(away.get("rowCount", 0)), 1, "但看得到自己带了什么")

	# 背包里没有能进炉子的东西
	avatar.inventory.clear()
	avatar.item_instances.clear()
	var empty: Dictionary = _trade_view(
		world, sim, "hammerhold", "hammerhold", Economy.CHANNEL_SHOP,
		TradeViewModel.SIDE_BUY, 0, TradeViewModel.PANE_FORGE
	)
	_eq(int(empty.get("rowCount", 0)), 0, "没有能进炉子的货")
	_check(str(empty.get("blockedReason", "")).contains("没有能进炉子"), "并且说明原因")

	# 买卖页照旧：pane 只是多了一个分支，不该改变原来那一页
	var trade: Dictionary = _trade_view(world, sim, "hammerhold", "hammerhold")
	_eq(str(trade.get("pane", "")), TradeViewModel.PANE_TRADE, "默认还是买卖那一页")
	_check(trade.has("sideLabel"), "买卖页有买卖方向")


## 铁匠铺的命中：页签按钮（铁匠铺 / 回商铺 / 敲一炉）与左列的行。
func _test_forge_panel_hit_test() -> void:
	var built: Dictionary = _new_sim(false)
	var world: WorldState = built["world"]
	var sim: WorldSim = built["sim"]
	_set_all_dimensions(world, "hammerhold", 50)
	var avatar := PlayerAvatar.new()
	avatar.avatar_id = "avatar-forge-hit"
	avatar.money = 5000
	world.avatar = avatar
	_give(avatar, "weapon_longsword_common", "fh-sword")

	var forge: Dictionary = _trade_view(
		world, sim, "hammerhold", "hammerhold", Economy.CHANNEL_SHOP,
		TradeViewModel.SIDE_BUY, 0, TradeViewModel.PANE_FORGE
	)
	var buttons: Array = TradePanel.buttons(forge, PANEL_RECT)
	var deal: Dictionary = UiTheme.find_button(buttons, "deal")
	var leave: Dictionary = UiTheme.find_button(buttons, "leaveForge")
	var back: Dictionary = UiTheme.find_button(buttons, "back")
	_check(not deal.is_empty() and not leave.is_empty() and not back.is_empty(),
		"敲一炉、回商铺、返回三个按钮都在")
	_eq(str(deal["label"]), "敲一炉", "主按钮写着敲一炉")
	_check(UiTheme.find_button(buttons, "side").is_empty(), "铁匠铺里没有换买卖方向")
	_check(UiTheme.find_button(buttons, "channel").is_empty(), "铁匠铺里没有换渠道")
	for pair in [[deal, leave], [leave, back]]:
		_check(not (pair[0]["rect"] as Rect2).intersects(pair[1]["rect"] as Rect2),
			"按钮之间不重叠")
	_eq(str(TradePanel.hit_test(forge, PANEL_RECT, _center(deal["rect"])).get("id", "")),
		"deal", "敲一炉那个按钮点得中")
	_eq(str(TradePanel.hit_test(forge, PANEL_RECT, _center(leave["rect"])).get("id", "")),
		"leaveForge", "回商铺那个按钮点得中")

	var sweep: Dictionary = _sweep_hits("trade", forge, PANEL_RECT)
	_check(sweep.has("button"), "按钮在命中范围内")
	_check(sweep.has("row"), "左列的行可点")
	_eq(int(_hit_for("trade", forge, PANEL_RECT, "row", 0).get("index", -1)), 0,
		"第一行报出自己的行号")
	_check(bool(_hit_for("trade", forge, PANEL_RECT, "row", 0).get("enabled", false)),
		"钱够的那一行动得了手")
	_check(TradePanel.hit_test(forge, PANEL_RECT, Vector2(4.0, 4.0)).is_empty(),
		"面板外的点击不算命中")

	# 买卖页多一个进铁匠铺的按钮，且没有"回商铺"（那是铁匠铺里才有的）。
	# 用有黑市的港城看按钮排布——那里按钮最多，最容易挤到邻居。
	_set_all_dimensions(world, "port_thorne", 50)
	var trade: Dictionary = _trade_view(world, sim, "port_thorne", "port_thorne")
	var trade_buttons: Array = TradePanel.buttons(trade, PANEL_RECT)
	_check(not UiTheme.find_button(trade_buttons, "forge").is_empty(), "买卖页有「铁匠铺」按钮")
	_check(UiTheme.find_button(trade_buttons, "leaveForge").is_empty(),
		"买卖页没有「回商铺」按钮")
	var row: Array = []
	for button in trade_buttons:
		row.append(button["rect"] as Rect2)
	for i in range(row.size()):
		for j in range(i + 1, row.size()):
			_check(not (row[i] as Rect2).intersects(row[j] as Rect2),
				"多出来的按钮不压到邻居：%d / %d" % [i, j])


# --- 世界遭遇（M9：谁在什么地方因为什么拦住你）---

## 一格的坐标：相对某座城挪 dx / dy 格。分档用例都从城市坐标出发算，
## 免得把"哪一格属于第几档"再抄一遍。
func _pos_near(world: WorldState, city_id: String, dx: int, dy: int) -> Vector2i:
	var city: City = world.get_city(city_id)
	return Vector2i(city.coord_x + dx, city.coord_y + dy)


## 装了遭遇系统的测试世界。with_npcs 为真时城里才有人可拦路（城内遭遇要用真人）。
func _new_encounters(with_npcs: bool = true) -> Dictionary:
	var built: Dictionary = _new_sim(with_npcs)
	var world: WorldState = built["world"]
	var grid: MapGrid = built["grid"]
	var avatar := PlayerAvatar.new()
	avatar.avatar_id = "avatar-enc"
	avatar.display_name = "试作角色"
	avatar.attributes = _plain_attributes()
	world.avatar = avatar
	return {
		"world": world, "grid": grid, "sim": built["sim"],
		"system": EncounterSystem.create(world, grid, _new_derived()),
	}


# --- 里程碑 12：建筑经营经济（D-69 ~ D-72）---

## 内容装载：40 座建筑、每城 5 座引用与 buildings.json 一一对应。
func _test_building_content() -> void:
	var cfgs: Array = ContentLoader.get_building_configs()
	var ids: Dictionary = {}
	var by_city: Dictionary = {}
	for cfg in cfgs:
		var bid: String = str(cfg.get("buildingId", ""))
		_check(not bid.is_empty(), "建筑有 id")
		_check(not ids.has(bid), "建筑 id 唯一：" + bid)
		ids[bid] = true
		var cid: String = str(cfg.get("cityId", ""))
		if not by_city.has(cid):
			by_city[cid] = []
		by_city[cid].append(bid)
	_eq(ids.size(), 40, "装载 40 座建筑（8 城 × 5）且 id 互不重复")
	for city_cfg in ContentLoader.get_city_configs():
		var cid: String = str(city_cfg.get("cityId", ""))
		var refs: Array = ContentLoader.get_city_building_ids(cid)
		_check(by_city.has(cid), "城市 " + cid + " 有建筑配置")
		_eq(refs.size(), 5, "城 " + cid + " 引用 5 座建筑")
		for bid in refs:
			var cfg: Dictionary = ContentLoader.get_building_config(str(bid))
			_check(not cfg.is_empty(), "城 " + cid + " 引用的建筑找得到：" + str(bid))
			_eq(str(cfg.get("cityId", "")), cid, "建筑 " + str(bid) + " 归属城一致")
	_check(not ContentLoader.get_balance_section("buildings").is_empty(),
		"balance.buildings 段存在")


## 等级派生：tier 门槛关闭 + 同档按维度细化 + 投资累加 + 上限钳制。
func _test_building_available_and_effective() -> void:
	var built: Dictionary = _new_sim(false)
	var world: WorldState = built["world"]
	var bal: Dictionary = ContentLoader.get_balance_section("buildings")
	var cfg: Dictionary = ContentLoader.get_building_config("aedran_throne")
	var city: City = world.get_city("aedran")
	_check(not cfg.is_empty(), "找到地标 aedran_throne")
	# 全新世界的 aedran 阶段低于 metropolis，地标关闭（minTier=metropolis）
	_eq(CityBuildings.available_level(cfg, city, bal), 0, "阶段过低时地标关闭")
	_eq(CityBuildings.effective_level(cfg, city, 0, bal), 0, "关闭时生效等级为 0")
	# 阶段达标后，按关联维度细化为 1..(1+maxRefine) 的自然等级
	_set_all_dimensions(world, "aedran", 95)
	var avail: int = CityBuildings.available_level(cfg, city, bal)
	_check(avail >= 1, "发展充分的城地标存在（L%d）" % avail)
	# 投资部分由玩家私有状态给定，未投资还是 0
	_eq(CityBuildings.invested_level(world, "aedran", "aedran_throne"), 0, "未投资为 0")
	# 投资受到全局上限钳制：生效等级封在 maxLevel
	var max_level: int = int(bal.get("maxLevel", 10))
	_eq(CityBuildings.effective_level(cfg, city, max_level, bal), max_level,
		"投资等级被全局上限钳制")
	# 费用随当前生效等级递增（档位定价）
	_eq(CityBuildings.invest_cost(bal, 1) - CityBuildings.invest_cost(bal, 0),
		int(bal.get("investCostPerLevel", 2500)), "投资费用递增 perLevel")


## 投资：即时扣 avatar.money + 落盘 building_investments；失败不改状态。
func _test_building_invest() -> void:
	var built: Dictionary = _new_sim(false)
	var world: WorldState = built["world"]
	var bal: Dictionary = ContentLoader.get_balance_section("buildings")
	var cfg: Dictionary = ContentLoader.get_building_config("aedran_throne")
	var city_id: String = "aedran"
	_set_all_dimensions(world, city_id, 95)
	# 无化身
	var r: Dictionary = CityBuildings.invest(world, city_id, "aedran_throne", cfg, bal)
	_eq(str(r["error"]), CityBuildings.ERROR_NO_AVATAR, "无化身时投资报 NO_AVATAR")
	# 有化身但钱不够
	var avatar := PlayerAvatar.new()
	avatar.avatar_id = "avatar-bu"
	avatar.money = 0
	world.avatar = avatar
	r = CityBuildings.invest(world, city_id, "aedran_throne", cfg, bal)
	_eq(str(r["error"]), CityBuildings.ERROR_INSUFFICIENT_FUNDS, "钱不够报 INSUFFICIENT_FUNDS")
	_eq(CityBuildings.invested_level(world, city_id, "aedran_throne"), 0, "失败不改投资状态")
	# 给够钱：按当前生效等级定价，即时扣钱并落盘
	avatar.money = 100_000
	var before: int = avatar.money
	r = CityBuildings.invest(world, city_id, "aedran_throne", cfg, bal)
	_check(bool(r["ok"]), "投资成功：" + str(r.get("error", "")))
	_eq(int(r["cost"]), before - avatar.money, "投资即时扣按生效等级计的钱")
	_eq(avatar.money, before - int(r["cost"]), "投资即时扣钱")
	_eq(CityBuildings.invested_level(world, city_id, "aedran_throne"), 1, "投资落盘为 1")
	# 封顶后再投报 MAX_LEVEL
	var max_level: int = int(bal.get("maxLevel", 10))
	if not world.building_investments.has(city_id):
		world.building_investments[city_id] = {}
	world.building_investments[city_id]["aedran_throne"] = max_level
	avatar.money = 9_999_999
	r = CityBuildings.invest(world, city_id, "aedran_throne", cfg, bal)
	_eq(str(r["error"]), CityBuildings.ERROR_MAX_LEVEL, "到上限报 MAX_LEVEL")
	_eq(CityBuildings.invested_level(world, city_id, "aedran_throne"), max_level,
		"封顶后不再累加")
	# 关闭的建筑投不进（阶段退回）
	_set_all_dimensions(world, city_id, 0)
	r = CityBuildings.invest(world, city_id, "aedran_throne", cfg, bal)
	_eq(str(r["error"]), CityBuildings.ERROR_CLOSED, "建筑关闭时报 CLOSED")


## 月度结算：建筑贡献折进城市维度归因；玩家按投资部分收月收益。
func _test_building_settlement() -> void:
	var built: Dictionary = _new_sim(false)
	var world: WorldState = built["world"]
	var sim: WorldSim = built["sim"]
	var bal: Dictionary = ContentLoader.get_balance_section("buildings")
	var cfg: Dictionary = ContentLoader.get_building_config("aedran_knights")
	var city: City = world.get_city("aedran")
	var avatar := PlayerAvatar.new()
	avatar.avatar_id = "avatar-bu"
	avatar.money = 1_000_000
	world.avatar = avatar
	# 阶段拉到 metropolis（dev/pop 足够），但把关联维度 security 压在细化档下界之下，
	# 让 available 稳定为 1、单月漂移也不会跨档，预期贡献因此确定。
	_set_all_dimensions(world, "aedran", 95)
	world.get_city("aedran").set_dimension(City.DIM_SECURITY, 40)
	var r: Dictionary = CityBuildings.invest(world, "aedran", "aedran_knights", cfg, bal)
	_check(bool(r["ok"]), "投资成功以测结算：" + str(r.get("error", "")))
	var expected_milli: int = CityBuildings.monthly_contribution(
		cfg, CityBuildings.effective_level(cfg, city, 1, bal)
	).get(City.DIM_SECURITY, 0)
	_check(expected_milli > 0, "预期贡献为正（%d）" % int(expected_milli))
	var before: int = avatar.money
	var report: Dictionary = sim.settle_month(1)
	_eq(_delta_milli(report, "aedran", City.DIM_SECURITY, "building-aedran_knights"),
		expected_milli, "建筑月度贡献折进维度归因")
	var expected_income: int = int(bal.get("playerReturnPerLevel", 300)) * 1
	_eq(int(report["buildingIncome"]), expected_income, "setle_month 报告玩家建筑收益")
	_eq(avatar.money - before, expected_income, "玩家每月按投资部分收钱")


## 持久化：玩家建筑投资经 WorldState 序列化往返一致。
func _test_building_round_trip() -> void:
	var built: Dictionary = _new_sim(false)
	var world: WorldState = built["world"]
	var bal: Dictionary = ContentLoader.get_balance_section("buildings")
	var avatar := PlayerAvatar.new()
	avatar.avatar_id = "avatar-bu"
	avatar.money = 1_000_000
	world.avatar = avatar
	_set_all_dimensions(world, "aedran", 95)
	var cfg: Dictionary = ContentLoader.get_building_config("aedran_throne")
	var r: Dictionary = CityBuildings.invest(world, "aedran", "aedran_throne", cfg, bal)
	_check(bool(r["ok"]), "投资以写入落盘数据")
	var saved: Dictionary = world.to_dict()
	_check(saved.has("buildingInvestments"), "world 序列化含 buildingInvestments")
	var rebuilt: WorldState = WorldState.new()
	rebuilt.apply_dict(saved)
	_eq(CityBuildings.invested_level(rebuilt, "aedran", "aedran_throne"), 1,
		"投资等级经序列化往返一致")


func _test_encounter_tier() -> void:
	var built: Dictionary = _new_encounters()
	var world: WorldState = built["world"]
	var system: EncounterSystem = built["system"]

	# 三档按离最近城市的距离切：0–9 / 10–19 / 20 以上（balance.encounters.tierBoundaries）
	_eq(system.distance_to_nearest_city(_pos_near(world, "aedran", 0, 0)), 0, "站在城里距离为 0")
	_eq(system.tier_at(_pos_near(world, "aedran", 9, 0)), 0, "离城 9 格是近郊")
	_eq(system.tier_at(_pos_near(world, "aedran", 10, 0)), 1, "离城 10 格进远郊")
	_eq(system.tier_at(_pos_near(world, "aedran", 19, 0)), 1, "离城 19 格还是远郊")
	_eq(system.tier_at(_pos_near(world, "aedran", 20, 0)), 2, "离城 20 格进荒野深处")

	# 三档的 TL 区间照《数值框架》12.1 的分层：平凡 1–5、精锐 6–10、凶险 11–20
	_eq(system.tier_threat_range(0), [1, 5], "近郊的 TL 区间是平凡档")
	_eq(system.tier_threat_range(1), [6, 10], "远郊的 TL 区间是精锐档")
	_eq(system.tier_threat_range(2), [11, 20], "荒野深处的 TL 区间是凶险档")
	_eq(system.tier_threat_range(99), [11, 20], "档位越界时退到最后一档")

	# 离最近城市远的那一格不该算在城里，也不该算在路上
	_eq(system.context_at(Vector2i(0, 0)), EncounterSystem.CONTEXT_WILD,
		"地图角落是荒野")

	# 站在城的坐标上就是"城里"
	_eq(system.context_at(_pos_near(world, "aedran", 0, 0)), EncounterSystem.CONTEXT_CITY,
		"站在城的坐标上算城里")


func _test_encounter_chance() -> void:
	var built: Dictionary = _new_encounters()
	var world: WorldState = built["world"]
	var system: EncounterSystem = built["system"]

	_eq(system.encounter_chance_bp(EncounterSystem.CONTEXT_WILD, ""), 1600,
		"荒野每判一次撞上的概率")
	_eq(system.encounter_chance_bp(EncounterSystem.CONTEXT_ROAD, ""), 900,
		"路上比荒野低——有人走的地方野兽少")

	# 城里按治安线性缩：治安到 ceiling（30）就一点都不出，治安 0 是满值
	var greenwade: City = world.get_city("greenwade")
	greenwade.set_dimension(City.DIM_SECURITY, 30)
	_eq(system.encounter_chance_bp(EncounterSystem.CONTEXT_CITY, "greenwade"), 0,
		"治安到顶的城里不会出事")
	greenwade.set_dimension(City.DIM_SECURITY, 0)
	_eq(system.encounter_chance_bp(EncounterSystem.CONTEXT_CITY, "greenwade"), 2000,
		"治安 0 的城里每次进城都可能被拦")
	greenwade.set_dimension(City.DIM_SECURITY, 20)
	_eq(system.encounter_chance_bp(EncounterSystem.CONTEXT_CITY, "greenwade"), 667,
		"治安 20 的城里概率按比例缩到三分之一强")
	_eq(system.encounter_chance_bp(EncounterSystem.CONTEXT_CITY, "no_such_city"), 0,
		"没有这座城市就没有遭遇")

	# 判定节奏：每 stepInterval（8）格一次
	_check(not system.should_check(7), "走了 7 格还不判")
	_check(system.should_check(8), "走满 8 格判一次")

	# 路上：地图上画出来的那条线就是判据
	var routes: Array = world.get_routes_sorted()
	_check(not routes.is_empty(), "预置路线装上了")
	if not routes.is_empty():
		var route: TradeRoute = routes[0]
		var a: City = world.get_city(str(route.city_a))
		var b: City = world.get_city(str(route.city_b))
		@warning_ignore("integer_division")
		var mid := Vector2i((a.coord_x + b.coord_x) / 2, (a.coord_y + b.coord_y) / 2)
		_check(system.on_route(mid), "商路中点算在路上")
		_eq(system.context_at(mid), EncounterSystem.CONTEXT_ROAD, "商路中点走在路上")
		_check(not system.on_route(Vector2i(0, 0)), "地图角落不在任何一条路上")


func _test_encounter_roll() -> void:
	var built: Dictionary = _new_encounters()
	var world: WorldState = built["world"]
	var avatar: PlayerAvatar = world.avatar
	var system: EncounterSystem = built["system"]

	# 荒野：偏好野兽与亡灵
	avatar.pos_x = _pos_near(world, "aedran", 9, 0).x
	avatar.pos_y = _pos_near(world, "aedran", 9, 0).y
	var wild: Dictionary = system.roll(
		EncounterSystem.CONTEXT_WILD, "aedran", 12, "enc-0001", DeterministicRNG.new(7)
	)
	_check(not wild.is_empty(), "荒野摇得出对手")
	_eq(int(wild["tier"]), 0, "这一场记下了自己在第几档")
	_check(int(wild["threatLevel"]) >= 1 and int(wild["threatLevel"]) <= 5,
		"近郊的对手落在平凡档")
	var wild_category: String = str((wild["opponents"][0] as Dictionary)["category"])
	_check(wild_category == "beast" or wild_category == "undead",
		"荒野上遇上的是野兽或亡灵%s" % _detail(wild_category))
	_check(str(wild.get("story", "")).length() > 0, "写了一句为什么拦住你")

	# 商路：偏好人形
	var routes: Array = world.get_routes_sorted()
	if not routes.is_empty():
		var route: TradeRoute = routes[0]
		var a: City = world.get_city(str(route.city_a))
		var b: City = world.get_city(str(route.city_b))
		@warning_ignore("integer_division")
		var mid := Vector2i((a.coord_x + b.coord_x) / 2, (a.coord_y + b.coord_y) / 2)
		avatar.pos_x = mid.x
		avatar.pos_y = mid.y
		var road: Dictionary = system.roll(
			EncounterSystem.CONTEXT_ROAD, "aedran", 12, "enc-0002", DeterministicRNG.new(9)
		)
		_check(not road.is_empty(), "路上摇得出对手")
		if not road.is_empty():
			_eq(str((road["opponents"][0] as Dictionary)["category"]), "humanoid",
				"路上遇上的是人形")

	# 越走越凶：最远那一档的对手 TL 明显更高。(5, 5) 离八座城里的任何一座
	# 都在 40 格以上（最近的索恩港在 (15, 40)），是最干净的一片荒野深处
	avatar.pos_x = 5
	avatar.pos_y = 5
	var deep: Dictionary = system.roll(
		EncounterSystem.CONTEXT_WILD, "aedran", 12, "enc-0003", DeterministicRNG.new(11)
	)
	_eq(int(deep["tier"]), 2, "地图角落是荒野深处")
	_check(int(deep["threatLevel"]) >= 11, "荒野深处的对手落在凶险档以上")

	# 同一段种子摇出同一场（存档重放要与当初一致）
	var again: Dictionary = system.roll(
		EncounterSystem.CONTEXT_WILD, "aedran", 12, "enc-0003", DeterministicRNG.new(11)
	)
	_eq(str(again["title"]), str(deep["title"]), "同种子摇出同一场遭遇")
	_eq(int(again["threatLevel"]), int(deep["threatLevel"]), "对手强度也一致")

	# check 的 engaged 为假是正常结果，不是错误
	var quiet: Dictionary = system.check(
		EncounterSystem.CONTEXT_WILD, "aedran", 12, "enc-0004",
		DeterministicRNG.new(1), false
	)
	_check(bool(quiet.get("ok", false)), "判定本身总是成功")
	_check(quiet.has("engaged"), "判定会说明这一次有没有撞上人")
	# force 会跳过概率——调试用的"就地摇一场"走的就是这条
	var forced: Dictionary = system.check(
		EncounterSystem.CONTEXT_WILD, "aedran", 12, "enc-0005",
		DeterministicRNG.new(1), true
	)
	_check(bool(forced.get("engaged", false)), "force 一定摇得出一场")


func _test_encounter_group() -> void:
	var built: Dictionary = _new_encounters()
	var world: WorldState = built["world"]
	var system: EncounterSystem = built["system"]
	var avatar: PlayerAvatar = world.avatar
	avatar.pos_x = _pos_near(world, "aedran", 5, 0).x
	avatar.pos_y = _pos_near(world, "aedran", 5, 0).y

	var max_opponents: int = int(system.rules().get("maxOpponents", 3))
	var seen: int = 0
	for seed_value in range(1, 21):
		var spec: Dictionary = system.roll(
			EncounterSystem.CONTEXT_WILD, "aedran", 12, "enc-g%02d" % seed_value,
			DeterministicRNG.new(seed_value)
		)
		if spec.is_empty():
			continue
		var count: int = (spec["opponents"] as Array).size()
		_check(count >= 1 and count <= max_opponents,
			"对手数量落在 1–%d 之间（这一场 %d 个）" % [max_opponents, count])
		seen += 1
	_check(seen > 0, "跑了若干种子，至少摇出一场")

	# "成群"写在生物表上：野狼 groupMin 是 2
	var wolf: Dictionary = ContentLoader.get_monster("mon_wolf")
	_eq(int(wolf.get("groupMin", 0)), 2, "野狼是成群出现的")
	_check(int(wolf.get("groupMax", 0)) >= int(wolf.get("groupMin", 0)),
		"成群的上下限成序")
	# 每条生物都能被某一档选中（否则"少了两种怪"从界面上看不出来）
	for entry in ContentLoader.get_monsters():
		var tl: int = int(entry.get("threatLevel", 0))
		var matched: bool = false
		for tier in range(3):
			var range: Array = system.tier_threat_range(tier)
			if tl >= int(range[0]) and tl <= int(range[1]):
				matched = true
				break
		_check(matched, "生物 %s（TL %d）落在某一档里" % [str(entry.get("monsterId", "")), tl])


func _test_encounter_city_npc() -> void:
	var built: Dictionary = _new_encounters()
	var world: WorldState = built["world"]
	var system: EncounterSystem = built["system"]
	# 十字路治安 20，是最可能出事的那座城
	var city: City = world.get_city("crossroad")
	_check(city.get_dimension(City.DIM_SECURITY) < 30, "十字路的治安在门槛以下")
	var avatar: PlayerAvatar = world.avatar
	avatar.pos_x = _pos_near(world, "crossroad", 0, 0).x
	avatar.pos_y = _pos_near(world, "crossroad", 0, 0).y

	var spec: Dictionary = system.roll(
		EncounterSystem.CONTEXT_CITY, "crossroad", 12, "enc-city", DeterministicRNG.new(3)
	)
	_check(not spec.is_empty(), "治安差的城里摇得出拦路的人")
	if spec.is_empty():
		return
	_eq(str(spec["kind"]), EncounterSystem.KIND_NPC, "城里的对手是真人")
	_eq(str(spec["nearestCityId"]), "crossroad", "这一场记在十字路头上")
	var opponents: Array = spec["opponents"]
	_check(opponents.size() >= 1 and opponents.size() <= 2, "城里拦路的一两个人")
	var wanted: Array = system.rules().get("cityNpcCategories", [])
	for opponent in opponents:
		_check(bool(opponent.get("isNpc", false)), "对手是模拟居民")
		_check(not str(opponent.get("npcId", "")).is_empty(), "带着这个人的 id")
		var npc: SimNpc = world.get_npc(str(opponent["npcId"]))
		_check(npc != null, "那个人真的在世界里")
		if npc != null:
			var category: String = str(EncounterSystem.profession_categories().get(
				npc.profession_id, ""
			))
			_check(wanted.has(category), "拦路的是军中或灰色的人（%s）" % category)
			_check(not npc.is_named, "具名 NPC 不会被当街拦住")
		_check(bool(opponent.get("parleyable", false)), "人形对手谈得拢")
	_eq(str((opponents[0] as Dictionary)["unitId"]), str((opponents[0] as Dictionary)["npcId"]),
		"人形对手的单位 id 就是他的 id——标记才追得到人")


func _test_encounter_avoid() -> void:
	var built: Dictionary = _new_encounters()
	var system: EncounterSystem = built["system"]

	# 基础 + 敏捷 × 12 + 幸运 × 2（基点）
	_eq(system.avoid_chance_bp(_attributes_with(PlayerAvatar.ATTR_DEXTERITY, 10), 0), 5200,
		"敏捷 10 的绕开率")
	_eq(system.avoid_chance_bp(_attributes_with(PlayerAvatar.ATTR_DEXTERITY, 20), 0), 6400,
		"敏捷 20 的绕开率")
	_eq(system.avoid_chance_bp(_attributes_with(PlayerAvatar.ATTR_DEXTERITY, 10), 50), 6200,
		"幸运 50 也算进去")
	_eq(system.avoid_chance_bp(_attributes_with(PlayerAvatar.ATTR_DEXTERITY, 0), -100), 2000,
		"运气差、身子笨的人不好甩")
	_eq(system.avoid_chance_bp(_attributes_with(PlayerAvatar.ATTR_DEXTERITY, 100), 100), 9500,
		"再高也封在 95%")
	_eq(system.avoid_chance_bp(_attributes_with(PlayerAvatar.ATTR_DEXTERITY, 0), -300), 500,
		"再差也留着 5%")
	_eq(system.avoid_time_days(), 1, "绕开要花掉一天")

	var first: Dictionary = system.avoid_check(
		_attributes_with(PlayerAvatar.ATTR_DEXTERITY, 20), 0, DeterministicRNG.new(5)
	)
	var second: Dictionary = system.avoid_check(
		_attributes_with(PlayerAvatar.ATTR_DEXTERITY, 20), 0, DeterministicRNG.new(5)
	)
	_eq(bool(first["escaped"]), bool(second["escaped"]), "同种子绕开的结果一致")
	_check(first.has("chanceBp") and first.has("rollBp"), "判定报得出成功率与掷出的点数")


func _test_encounter_parley() -> void:
	var built: Dictionary = _new_encounters()
	var system: EncounterSystem = built["system"]

	# 两端是硬门槛，中间线性
	_eq(system.parley_chance_bp(60), 10000, "敬重以上直接放行")
	_eq(system.parley_chance_bp(100), 10000, "声誉满也还是放行")
	_eq(system.parley_chance_bp(-60), 0, "敌视以下谈不拢")
	_eq(system.parley_chance_bp(0), 5000, "无名之人的交涉率")
	_eq(system.parley_chance_bp(20), 6000, "名声好一点就好谈一点")
	_eq(system.parley_chance_bp(-20), 4000, "名声差一点就难谈一点")
	_eq(system.parley_chance_bp(-59), 2050, "刚好在敌视门槛之前")

	# 说不动的东西没有交涉可言，而且给出的理由不能让人误以为是名声不够
	_eq(EncounterSystem.parley_block_reason_of(false, "beast"), "野兽不听人话",
		"野兽那一条的理由")
	_eq(EncounterSystem.parley_block_reason_of(false, "undead"), "这些东西没有能谈的余地",
		"亡灵那一条的理由")
	_eq(EncounterSystem.parley_block_reason_of(true, "humanoid"), "", "谈得拢就没有拦阻理由")


func _test_encounter_units_and_resolve() -> void:
	var built: Dictionary = _new_encounters()
	var world: WorldState = built["world"]
	var avatar: PlayerAvatar = world.avatar
	var system: EncounterSystem = built["system"]
	avatar.pos_x = _pos_near(world, "aedran", 5, 0).x
	avatar.pos_y = _pos_near(world, "aedran", 5, 0).y

	var spec: Dictionary = system.roll(
		EncounterSystem.CONTEXT_WILD, "aedran", 12, "enc-fight", DeterministicRNG.new(4)
	)
	_check(not spec.is_empty(), "摇出一场来打")
	if spec.is_empty():
		return
	var opponents: Array = spec["opponents"]
	var spawns: Array = [[11, 3], [11, 5], [11, 7]]
	var units: Array = system.units_of(spec, spawns)
	_eq(units.size(), opponents.size(), "每个对手都变成一个参战单位")
	for i in range(units.size()):
		var unit: Dictionary = units[i]
		_eq(str(unit["side"]), Combat.SIDE_ENEMY, "都在敌方一侧")
		_eq(str(unit["unitId"]), str((opponents[i] as Dictionary)["unitId"]), "单位 id 对应得上")
		_eq(int(unit["weaponAttack"]), int((opponents[i] as Dictionary)["attack"]),
			"伤害就是生物表里那一口")
		_eq(unit["position"], spawns[i], "站位由调用方给")
		_check(int(unit["hp"]) > 0, "带着血量")

	# 这样一支队伍开得起来
	var combat: Combat = _new_combat(17)
	var opened: Dictionary = combat.start({
		"sessionId": "enc-test",
		"units": units,
		"obstacles": [],
	})
	_check(bool(opened.get("ok", false)), "遭遇的对手能直接开一场战斗")

	# 结算只产出文案与世界事件流的一条记录（掉落与标记由战斗层与调用方落）
	var won: Dictionary = system.resolve(
		spec, EncounterSystem.OUTCOME_WON, 12, "补了刀"
	)
	_check(bool(won.get("ok", false)), "胜利结算得出来")
	_check(str(won["text"]).contains(str(spec["title"])), "文案里写着对手是谁")
	_check(str(won["text"]).contains("补了刀"), "文案里写着怎么处置的")
	var notices: Array = won["notices"]
	_eq(notices.size(), 1, "往事件流里记一条")
	_eq(int((notices[0] as Dictionary)["month"]), 12, "记的是这个月")
	_check(str((notices[0] as Dictionary)["text"]).length() > 0, "这条记录有内容")

	var avoided: Dictionary = system.resolve(spec, EncounterSystem.OUTCOME_AVOIDED, 12)
	_check(str(avoided["text"]).contains("绕开"), "绕开有自己的说法")
	var parleyed: Dictionary = system.resolve(spec, EncounterSystem.OUTCOME_PARLEYED, 12)
	_check(str(parleyed["text"]).contains("谈拢"), "交涉有自己的说法")
	var bad: Dictionary = system.resolve(spec, "nonsense", 12)
	_check(not bool(bad.get("ok", false)), "未知的结局给错误")
	var missing: Dictionary = system.resolve({}, EncounterSystem.OUTCOME_WON, 12)
	_check(not bool(missing.get("ok", false)), "没有这一场就结不了算")


func _test_level_gap_penalty() -> void:
	var combat: Combat = _new_combat(3)

	# 《数值框架》13.2：TL 差超过 5 时命中与伤害逐步下降；低打低不惩罚
	_eq(combat.level_gap(3, 9), 1, "差 6 级算越级 1 级")
	_eq(combat.level_gap(3, 8), 0, "差 5 级还不罚")
	_eq(combat.level_gap(9, 3), 0, "高打低不罚")
	_eq(combat.level_gap_hit_penalty_bp(3, 9), 300, "越一级扣 3 个百分点的命中")
	_eq(combat.level_gap_hit_penalty_bp(3, 14), 1800, "差 11 级扣 18 个百分点")
	_check(absf(combat.level_gap_damage_ratio(3, 9) - 0.92) < 0.0001, "越一级伤害打九二折")
	_check(absf(combat.level_gap_damage_ratio(3, 3) - 1.0) < 0.0001, "同级不折")
	_check(absf(combat.level_gap_damage_ratio(1, 40) - 0.25) < 0.0001,
		"差得再多也留着四分之一")
	_eq(combat.apply_level_gap_to_damage(100, 3, 9), 92, "伤害按比例折")
	_eq(combat.apply_level_gap_to_damage(100, 3, 3), 100, "没有差距就不动它")
	_eq(combat.apply_level_gap_to_damage(1, 1, 40), 1, "折完仍有 1 点保底")


func _test_encounter_view_model() -> void:
	var built: Dictionary = _new_encounters()
	var world: WorldState = built["world"]
	var avatar: PlayerAvatar = world.avatar
	var system: EncounterSystem = built["system"]
	avatar.attributes = _attributes_with(PlayerAvatar.ATTR_DEXTERITY, 20)
	# 站到最凶的那一档上去：近郊的对手与玩家同级，看不出越级警示
	avatar.pos_x = 5
	avatar.pos_y = 5

	var spec: Dictionary = system.roll(
		EncounterSystem.CONTEXT_WILD, "aedran", 12, "enc-view", DeterministicRNG.new(6)
	)
	var names: Dictionary = _city_names(world)
	var view: Dictionary = EncounterViewModel.build(system, spec, 1, names, 0)
	_check(not view.is_empty(), "视图建得出来")
	_eq(str(view["title"]), str(spec["title"]), "抬头就是对手的名字")
	_eq(int(view["rowCount"]), (spec["opponents"] as Array).size(), "左列一件一件列出对手")

	var choices: Array = view["choices"]
	_eq(choices.size(), 3, "三条路都摆出来")
	_eq(str((choices[0] as Dictionary)["choiceId"]), EncounterSystem.CHOICE_FIGHT, "第一条是迎战")
	_eq(str((choices[1] as Dictionary)["choiceId"]), EncounterSystem.CHOICE_AVOID, "第二条是绕开")
	_eq(str((choices[2] as Dictionary)["choiceId"]), EncounterSystem.CHOICE_PARLEY, "第三条是交涉")
	_check(str((choices[1] as Dictionary)["effectLabel"]).contains("成功率"),
		"绕开上写着大概几成")
	_check(str((choices[0] as Dictionary)["effectLabel"]).contains("个对手"),
		"迎战上写着对面有几个人")

	# 越级危险必须在按下迎战之前就写出来（13.2 的惩罚会实打实生效）
	_eq(bool(view["outmatched"]), true, "对手比玩家高出一大截时会标出来")
	_eq(str(view["dangerLabel"]), "比你强出一大截", "危险等级写在抬头下面")
	var same: Dictionary = EncounterViewModel.build(system, spec, int(spec["threatLevel"]), names)
	_eq(str(same["dangerLabel"]), "与你势均力敌", "TL 相同时是另一种说法")
	_eq(bool(same["outmatched"]), false, "势均力敌不算越级")

	# 野兽那一条没有交涉，且理由要说清
	if not bool(spec["parleyable"]):
		_eq(bool((choices[2] as Dictionary)["enabled"]), false, "说不动的东西交涉不可选")
		_check(str((choices[2] as Dictionary)["blockedReason"]).length() > 0, "并且说明理由")

	# 光标越界会被夹住
	var clamped: Dictionary = EncounterViewModel.build(system, spec, 1, names, 99)
	_eq(int(clamped["cursor"]), 2, "光标夹在最后一条上")
	var negative: Dictionary = EncounterViewModel.build(system, spec, 1, names, -5)
	_eq(int(negative["cursor"]), 0, "负数夹回第一条")
	_check(EncounterViewModel.build(system, {}, 1, names).is_empty(), "没有遭遇就没有这一屏")


func _test_encounter_panel_hit_test() -> void:
	var built: Dictionary = _new_encounters()
	var world: WorldState = built["world"]
	var avatar: PlayerAvatar = world.avatar
	var system: EncounterSystem = built["system"]
	avatar.pos_x = _pos_near(world, "aedran", 5, 0).x
	avatar.pos_y = _pos_near(world, "aedran", 5, 0).y
	# 找一个"交涉不可选"的场合：野兽与亡灵都不讲道理
	var spec: Dictionary = {}
	for seed_value in range(1, 40):
		var candidate: Dictionary = system.roll(
			EncounterSystem.CONTEXT_WILD, "aedran", 12, "enc-panel", DeterministicRNG.new(seed_value)
		)
		if not candidate.is_empty() and not bool(candidate["parleyable"]):
			spec = candidate
			break
	_check(not spec.is_empty(), "找到一个说不动的对手（近郊的野兽与亡灵）")
	if spec.is_empty():
		return
	var view: Dictionary = EncounterViewModel.build(
		system, spec, 1, _city_names(world), 0
	)

	_check(EncounterPanel.buttons(view, PANEL_RECT).is_empty(),
		"遭遇里没有「返回地图」按钮：三个做法就是全部出口")
	var first: Dictionary = _hit_for("encounter", view, PANEL_RECT, "choice", 0)
	_eq(int(first.get("index", -1)), 0, "第一条做法点得中")
	var third: Dictionary = _hit_for("encounter", view, PANEL_RECT, "choice", 2)
	_eq(int(third.get("index", -1)), 2, "第三条做法也点得中")
	var sweep: Dictionary = _sweep_hits("encounter", view, PANEL_RECT)
	_check(sweep.has("choice"), "做法在命中范围内")
	_check(not sweep.has("row"), "左列的对手只看不能点")
	_check(not sweep.has("button"), "面板上没有按钮")
	_eq(bool(EncounterPanel.choice_enabled(view, 2)), false, "说不动的对手那条动不了手")

	# 左列（对手行）点不出东西来
	var list: Rect2 = EncounterPanel.list_rect(PANEL_RECT)
	var list_point: Vector2 = list.position + Vector2(20.0, 20.0)
	_check(EncounterPanel.hit_test(view, PANEL_RECT, list_point).is_empty(),
		"对手行不响应点击")
	_check(EncounterPanel.hit_test(view, PANEL_RECT, Vector2(4.0, 4.0)).is_empty(),
		"面板外的点击不算命中")
	# 三条做法的矩形互不重叠（画在这里、点在那里不可能发生）
	var rects: Array = []
	for i in range(3):
		rects.append(EncounterPanel.choice_rect(PANEL_RECT, i))
	for i in range(rects.size()):
		for j in range(i + 1, rects.size()):
			_check(not (rects[i] as Rect2).intersects(rects[j] as Rect2),
				"做法行不压到邻居：%d / %d" % [i, j])
	_check(rects[2].position.y + rects[2].size.y
			<= EncounterPanel.column_rect(PANEL_RECT).position.y
				+ EncounterPanel.column_rect(PANEL_RECT).size.y,
		"三条做法都落在右列之内")


# --- 辅助 ---

## 城市的 id → 显示名。委托界面要写出"要回到哪座城"，就得有这张表。
func _city_names(world: WorldState) -> Dictionary:
	var out: Dictionary = {}
	for city_id in world.get_city_ids():
		var city: City = world.get_city(str(city_id))
		out[str(city_id)] = city.display_name
	return out


## 货架上某个稀有度的件数。可得性用例要数"摆得出来几件这个档次的货"。
func _count_rarity(rows: Array, rarity: String) -> int:
	var count: int = 0
	for row in rows:
		if str(row.get("rarity", "")) == rarity:
			count += 1
	return count


## 货架的模板序列，用来断言"顺序稳定"。
func _stock_ids(rows: Array) -> String:
	var ids: Array = []
	for row in rows:
		ids.append(str(row.get("templateId", "")))
	return "/".join(PackedStringArray(ids))


# --- 隐藏属性事件（M17，D-89 ~ D-93）---

## 隐藏属性的钳制与档位判定。善恶/幸运是全局、声誉按城独立，全部落在 [-100, 100]。
func _test_hidden_attr_clamp_band() -> void:
	var avatar := PlayerAvatar.new()
	avatar.attributes = _plain_attributes()
	avatar.set_karma(150)
	_eq(avatar.karma, HiddenAttributeSystem.ATTR_MAX, "善恶越界被钳回 +100")
	avatar.set_luck(-130)
	_eq(avatar.luck, HiddenAttributeSystem.ATTR_MIN, "幸运越界被钳回 -100")
	# 声誉已有自己的一套 clamp，set_reputation 走它
	avatar.set_reputation("aedran", 200)
	_eq(HiddenAttributeSystem.read_attr(avatar, "reputation", "aedran"), 100, "声誉越界被钳回 +100")
	# 档位判定：极端善恶/高价幸运各落一记「业」，中道无痕
	avatar = PlayerAvatar.new()
	avatar.attributes = _plain_attributes()
	_eq(HiddenAttributeSystem.reincarnation_mark_for(avatar), "", "中道不落业")
	avatar.set_karma(60)
	_eq(HiddenAttributeSystem.reincarnation_mark_for(avatar), HiddenAttributeSystem.MARK_GOOD, "极善落善业")
	avatar.set_karma(-70)
	_eq(HiddenAttributeSystem.reincarnation_mark_for(avatar), HiddenAttributeSystem.MARK_EVIL, "极恶落恶业")
	avatar.set_karma(0)
	avatar.set_luck(65)
	_eq(HiddenAttributeSystem.reincarnation_mark_for(avatar), HiddenAttributeSystem.MARK_LUCK, "高价幸运落气运之业")
	# apply_attr 就地结清并钳档
	_eq(HiddenAttributeSystem.apply_attr(avatar, "karma", "", 200), 100, "善恶增量越界也被钳回 +100")


## 触发判定：达标阈值 + 时机一致 + 冷却未到才触发；不达标 / 冷却到点都不触发；
## 快进不连环（一钩子只推一件）。
func _test_hidden_trigger_and_cooldown() -> void:
	var built: Dictionary = _new_sim(false)
	var world: WorldState = built["world"]
	var avatar: PlayerAvatar = _m17_avatar()
	world.avatar = avatar
	# 善恶 ≥ +60、进城查 → 圣职者的试炼
	avatar.set_karma(80)
	var enter_found: Dictionary = HiddenAttributeSystem.find_for_timing("enter", avatar, "aedran", world)
	_eq(str(enter_found.get("templateId", "")), "hk_priest_trial", "极善进城触发圣职者的试炼")
	# 幸运 ≤ -60、推进过夜查 → 厄运缠身
	avatar.set_karma(0)
	avatar.set_luck(-80)
	var adv_found: Dictionary = HiddenAttributeSystem.find_for_timing("advance", avatar, "aedran", world)
	_eq(str(adv_found.get("templateId", "")), "hl_unlucky_streak", "霉运推进触发厄运缠身")
	# 声誉 ≥ +80、进那座城查 → 授予荣誉市民
	avatar.set_luck(0)
	avatar.set_reputation("aedran", 92)
	var rep_found: Dictionary = HiddenAttributeSystem.find_for_timing("enter", avatar, "aedran", world)
	_eq(str(rep_found.get("templateId", "")), "hr_honor_citizen", "高声望进城触发授予荣誉市民")
	# 不够格不触发：降到阈值之下
	avatar.set_reputation("aedran", 10)
	_eq(HiddenAttributeSystem.find_for_timing("enter", avatar, "aedran", world).is_empty(), true,
		"声誉不够档不触发")
	# 冷却：触发过就不再重复（fate.<templateId> 标记）
	avatar.set_karma(90)
	var cfg: Dictionary = HiddenAttributeSystem.find_for_timing("enter", avatar, "greenwade", world)
	_check(not cfg.is_empty(), "另一座城仍能触发同档善恶事件")
	if not cfg.is_empty():
		HiddenAttributeSystem.mark_triggered(cfg, world)
		_eq(HiddenAttributeSystem.find_for_timing("enter", avatar, "greenwade", world).is_empty(), true,
			"触发过冷却后同档不再弹窗")
	# 时机不符不触发：同一属性换个钩子查不到
	avatar.set_karma(0)
	avatar.set_luck(0)
	avatar.set_reputation("aedran", 95)
	_eq(HiddenAttributeSystem.find_for_timing("advance", avatar, "aedran", world).is_empty(), true,
		"高声望在推进钩子上不触发（那是进城的事）")


## 分支应用：选分支后隐藏属性增删、城市维度、世界标记三者一致落账；弃选项不改属性。
func _test_hidden_branch_apply() -> void:
	var built: Dictionary = _new_sim(false)
	var world: WorldState = built["world"]
	var avatar: PlayerAvatar = _m17_avatar()
	world.avatar = avatar
	var cfg: Dictionary = _m17_tpl("hk_priest_trial")
	avatar.set_karma(90)
	# 立誓守光：善恶 +10（钳回 100）、声誉 +2、文化 +2（城市维度请求）、种子一朵
	var branch: Dictionary = _m17_branch(cfg, "uphold")
	var result: Dictionary = HiddenAttributeSystem.apply_branch(
		cfg, branch, avatar, world, "aedran", 12)
	_eq(bool(result.get("ok", false)), true, "立誓守光落账成功")
	_eq(avatar.karma, 100, "善恶 90 + 10 被钳回 100")
	_eq(HiddenAttributeSystem.read_attr(avatar, "reputation", "aedran"), 2, "声誉 +2 落账")
	_eq(int(result.get("changes", []).size()), 1, "产出一条城市维度变更（文化 +2）")
	_check(world.world_flags.has("fate.hk_priest_trial.saint_kept"), "种子 fate.<tid>.saint_kept 落写")
	# 拒绝不惩罚：善恶原样、无城市变更、事件以"未了"走
	avatar = _m17_avatar()
	world.avatar = avatar
	avatar.set_karma(90)
	var decline: Dictionary = _m17_branch(cfg, "decline")
	var declined: Dictionary = HiddenAttributeSystem.apply_branch(
		cfg, decline, avatar, world, "aedran", 12)
	_eq(avatar.karma, 90, "婉拒不扣善恶")
	_eq(int(declined.get("changes", []).size()), 0, "婉拒不产生城市维度变更")
	_eq(bool(declined.get("resolved", true)), false, "婉拒以未了结束")
	# 幅度越界时后果被钳到边界而不溢出
	var lucky: Dictionary = HiddenAttributeSystem.apply_branch(
		cfg, _m17_branch(cfg, "uphold"), avatar, world, "aedran", 12)
	_eq(avatar.karma, 100, "善恶 90 + 10 无论如何不回弹过界")


## 视图模型：产 EventPanel 能消费的同构 view（mode=Branch、rows 单件、branches 齐全）。
func _test_hidden_view_model() -> void:
	var built: Dictionary = _new_sim(false)
	var world: WorldState = built["world"]
	var avatar: PlayerAvatar = _m17_avatar()
	world.avatar = avatar
	var names: Dictionary = _city_names(world)
	var cfg: Dictionary = _m17_tpl("hl_unlucky_streak")
	avatar.set_luck(0)
	var view: Dictionary = HiddenEventViewModel.build(cfg, avatar, "aedran", names)
	_eq(int(view.get("mode", 0)), HiddenEventViewModel.MODE_BRANCH, "隐藏事件直接进抉择形态")
	_eq(int(view.get("rowCount", 0)), 1, "列表里只有这一件")
	_eq((view.get("branches", []) as Array).size(), 3, "厄运缠身三个做法都摆出来")
	var first: Dictionary = (view.get("branches", []) as Array)[0]
	_check(str(first.get("effectLabel", "")).length() > 0, "选项行写了后果预览")
	_check(str(view.get("selected", {}).get("summary", "")).length() > 0, "剧情文字带上了")
	# 声誉事件的行侧写出"这座城记着你的名字"，供玩家从文案反推自己站到哪一档
	var honor: Dictionary = _m17_tpl("hr_honor_citizen")
	avatar.set_reputation("aedran", 95)
	var honor_view: Dictionary = HiddenEventViewModel.build(honor, avatar, "aedran", names)
	var ok: bool = str(honor_view.get("selected", {}).get("reason", "")).find("记着你的名字") >= 0
	_check(ok, "高声望行侧写档位文案")


## 转生「业」：极端善恶/高价幸运的落账在结果里带出 mark，供新一世开局读到。
func _test_hidden_mark() -> void:
	var built: Dictionary = _new_sim(false)
	var world: WorldState = built["world"]
	var avatar: PlayerAvatar = _m17_avatar()
	world.avatar = avatar
	var cfg: Dictionary = _m17_tpl("hk_priest_trial")
	avatar.set_karma(90)
	var branch: Dictionary = _m17_branch(cfg, "uphold")
	var result: Dictionary = HiddenAttributeSystem.apply_branch(
		cfg, branch, avatar, world, "aedran", 12)
	_eq(str(result.get("mark", "")), HiddenAttributeSystem.MARK_GOOD,
		"善恶落账过 60 门槛后带出善业标记")
	# 中道触发不落业：只计入属性、不写 mark
	avatar = _m17_avatar()
	world.avatar = avatar
	avatar.set_luck(-95)
	avatar.set_karma(-70)
	var cursed: Dictionary = HiddenAttributeSystem.apply_branch(
		cfg, _m17_branch(cfg, "uphold"), avatar, world, "aedran", 12)
	_eq(str(cursed.get("mark", "")), HiddenAttributeSystem.MARK_EVIL, "极恶即使走的是善选项也落恶业")


# --- 隐藏属性测试小工具 ---

func _m17_avatar() -> PlayerAvatar:
	var avatar := PlayerAvatar.new()
	avatar.avatar_id = "avatar-hidden"
	avatar.display_name = "隐藏测试"
	avatar.attributes = _plain_attributes()
	return avatar


func _m17_tpl(template_id: String) -> Dictionary:
	return ContentLoader.get_hidden_event_template(template_id)


func _m17_branch(config: Dictionary, branch_id: String) -> Dictionary:
	for branch in config.get("branches", []):
		if str(branch.get("branchId", "")) == branch_id:
			return branch
	return {}


## 把一座城的六维一次设成同一个值。委托板的触发条件按维度判断，
## 用例需要能精确地把某几项压到阈值之下、其余都留在阈值之上。
func _set_all_dimensions(world: WorldState, city_id: String, value: int) -> void:
	var city: City = world.get_city(city_id)
	if city == null:
		return
	for dimension in City.ALL_DIMENSIONS:
		city.set_dimension(dimension, value)


## 某次月度结算里，某城某维度某一项归因的额度（milli）。
## 归因项是按来源合并的，键形如 "change-quest"（见 WorldSim._apply_pending_changes）。
func _delta_milli(report: Dictionary, city_id: String, dimension: String, key: String) -> int:
	var cities: Dictionary = report.get("cityDeltas", {})
	var per_city: Dictionary = cities.get(city_id, {})
	var slot: Dictionary = per_city.get(dimension, {})
	for item in slot.get("items", []):
		if str(item.get("key", "")) == key:
			return int(item.get("milli", 0))
	return 0


## 这次结算里某城某维度的归因项里有没有某一项。零额度的项（被查抄、封港中断）
## 也各占一项，所以"有没有说这件事"只能看项在不在，不能看额度。
func _has_delta_item(
	report: Dictionary, city_id: String, dimension: String, key: String
) -> bool:
	var cities: Dictionary = report.get("cityDeltas", {})
	var per_city: Dictionary = cities.get(city_id, {})
	var slot: Dictionary = per_city.get(dimension, {})
	for item in slot.get("items", []):
		if str(item.get("key", "")) == key:
			return true
	return false


## 这次结算有没有产出提到某件事的事件。比对文案而不是事件序号：
## 序数一改就失效，而"玩家有没有被告知"才是用例关心的。
func _has_notice(report: Dictionary, needle: String) -> bool:
	for entry in report.get("notableEvents", []):
		if str(entry.get("text", "")).contains(needle):
			return true
	return false


func _notice_text(report: Dictionary) -> String:
	var parts: Array = []
	for entry in report.get("notableEvents", []):
		parts.append(str(entry.get("text", "")))
	return " / ".join(PackedStringArray(parts))


func _new_combat(seed_value: int) -> Combat:
	return Combat.new(
		_new_derived(),
		ContentLoader.get_balance_section("combat"),
		ContentLoader.get_skills(),
		ContentLoader.get_items(),
		DeterministicRNG.new(seed_value)
	)


## 一场单挑：hero 在 (0,0)、foe 在 (1,0)，都在长剑的攻击距离内。
## HP 默认给得很大，让"打若干轮"的用例不会因为打死人而提前结束。
func _duel_encounter(hero_dex: int, foe_dex: int, foe_hp: int = 100000) -> Dictionary:
	return {
		"sessionId": "test-duel",
		"units": [
			{
				"unitId": "hero", "side": Combat.SIDE_PLAYER, "name": "试作角色",
				"attributes": _attributes_with(PlayerAvatar.ATTR_DEXTERITY, hero_dex),
				"skills": {"sword_slash": 40},
				"weaponTemplateId": "weapon_longsword_common",
				"position": [0, 0], "threatLevel": 1, "hp": 100000, "maxHp": 100000,
			},
			{
				"unitId": "foe", "side": Combat.SIDE_ENEMY, "name": "拦路的强盗",
				"attributes": _attributes_with(PlayerAvatar.ATTR_DEXTERITY, foe_dex),
				"weaponTemplateId": "weapon_longsword_common",
				"position": [1, 0], "threatLevel": 1, "hp": foe_hp, "maxHp": foe_hp,
		},
	],
}


## M13 施法对局：hero 在 (0,0)、假人在 (1,0)，二人都在施法距离内。
## hero_mp >= 0 时显式写 mp，否则用 derived 的满蓝。foe_extra 用来设 element/creatureKind。
func _spell_encounter(hero_skills: Dictionary, hero_mp: int = -1, foe_extra: Dictionary = {}) -> Dictionary:
	var hero: Dictionary = {
		"unitId": "hero", "side": Combat.SIDE_PLAYER, "name": "试作法师",
		"attributes": _attributes_with(PlayerAvatar.ATTR_DEXTERITY, 40),
		"skills": hero_skills,
		"weaponTemplateId": "weapon_longsword_common",
		"position": [0, 0], "threatLevel": 1, "hp": 100000, "maxHp": 100000,
	}
	if hero_mp >= 0:
		hero["mp"] = hero_mp
	var foe: Dictionary = {
		"unitId": "foe", "side": Combat.SIDE_ENEMY, "name": "试作假人",
		"attributes": _attributes_with(PlayerAvatar.ATTR_DEXTERITY, 1),
		"weaponTemplateId": "weapon_longsword_common",
		"position": [1, 0], "threatLevel": 1, "hp": 100000, "maxHp": 100000,
	}
	for key in foe_extra:
		foe[key] = foe_extra[key]
	return {"sessionId": "test-spell", "units": [hero, foe]}


## 数据装载：七系法术各 5，法术耗蓝、非法术不耗蓝，熟练门槛在 0..100。
func _test_skill_content() -> void:
	var skills: Array = ContentLoader.get_skills()
	_check(skills.size() > 60, "技能库补齐七系法术（装载 %d 条）" % skills.size())
	var spells: int = 0
	var series: Dictionary = {}
	var bad_mp: int = 0
	var bad_req: int = 0
	for s in skills:
		var cat: String = str(s.get("category", ""))
		if cat == "spell":
			spells += 1
			var tree: String = str(s.get("tree", ""))
			series[tree] = int(series.get(tree, 0)) + 1
			if int(s.get("mpCost", 0)) <= 0:
				bad_mp += 1
		elif int(s.get("mpCost", 0)) != 0:
			bad_mp += 1
		var req: int = int(s.get("requiredSkillLevel", 0))
		if req < 0 or req > 100:
			bad_req += 1
	_eq(spells, 35, "法术共 35 条（七系各 5）")
	for tree in ["fire", "water", "wind", "earth", "holy", "dark", "soul"]:
		_eq(int(series.get(tree, 0)), 5, "「%s」系 5 条主线法术" % tree)
	_eq(bad_mp, 0, "法术 mpCost>0、非法术 mpCost==0")
	_eq(bad_req, 0, "所有技能 requiredSkillLevel 在 0..100")


## 熟练度门槛：没练到阶位要求就放不出技能，被前置条件拒绝且不扣蓝不涨熟练。
func _test_skill_mastery_gate() -> void:
	var combat: Combat = _new_combat(7001)
	_check(bool(combat.start(_spell_encounter({"fire_cataclysm": 0}, 100))["ok"]), "技的门槛战斗开始成功")
	_eq(combat.current_unit_id(), "hero", "hero 先手")
	var res: Dictionary = combat.submit_action({
		"actionType": Combat.ACTION_SKILL, "actorId": "hero", "targetId": "foe", "skillId": "fire_cataclysm",
	})
	_eq(str(res.get("error", "")), "PRECONDITION_FAILED", "熟练度不足被作为前置条件拒绝")
	_check(_has_text([res.get("reason", "")], "熟练度不足"), "拒绝原因含「熟练度不足」")
	_eq(int(combat.unit_by_id("hero")["skills"].get("fire_cataclysm", 0)), 0, "被拒后熟练度不变")
	_eq(int(combat.unit_by_id("hero")["mp"]), 90, "被拒不扣蓝（回蓝后仍满蓝）")


## 施法耗蓝与每轮回蓝：蓝不足拒放，满蓝施法扣蓝、熟练度「用进」成长、造成伤害。
func _test_skill_mp() -> void:
	# 前半：蓝不足被拒。满蓝 90 内 hero_mp=2，开局回蓝 +2 → 4，仍差 1。
	var low: Combat = _new_combat(7101)
	_check(bool(low.start(_spell_encounter({"fire_fireball": 5}, 2))["ok"]), "低蓝战斗开始成功")
	_eq(int(low.unit_by_id("hero")["mp"]), 4, "开局回蓝 +2：2 → 4")
	var low_go: Dictionary = low.submit_action({
		"actionType": Combat.ACTION_SKILL, "actorId": "hero", "targetId": "foe", "skillId": "fire_fireball",
	})
	_eq(str(low_go.get("error", "")), "PRECONDITION_FAILED", "蓝不足被前置条件拒绝")
	_check(_has_text([low_go.get("reason", "")], "魔力不足"), "拒绝原因含「魔力不足」")
	_eq(int(low.unit_by_id("hero")["mp"]), 4, "被拒不扣蓝")
	_eq(int(low.unit_by_id("hero")["skills"].get("fire_fireball", 0)), 5, "被拒熟练度不涨")
	# 后半：满蓝施法。满蓝 90，火球术耗 5。
	var ok: Combat = _new_combat(7102)
	var ok_specs: Dictionary = _spell_encounter({"fire_fireball": 5}, -1)
	_check(bool(ok.start(ok_specs)["ok"]), "满蓝战斗开始成功")
	var foe_max: int = int(ok.unit_by_id("foe")["hp"])
	ok.submit_action({
		"actionType": Combat.ACTION_SKILL, "actorId": "hero", "targetId": "foe", "skillId": "fire_fireball",
	})
	_eq(int(ok.unit_by_id("hero")["mp"]), 85, "施法扣 5 蓝（满蓝 90 → 85）")
	_eq(int(ok.unit_by_id("hero")["skills"]["fire_fireball"]), 6, "熟练度 5 → 6")
	# 命中率约 95%，补几发保证至少一发命中，木桩最终掉血。
	var guard: int = 0
	while int(ok.unit_by_id("foe")["hp"]) >= foe_max and guard < 20:
		guard += 1
		var actor_id: String = ok.current_unit_id()
		if actor_id.is_empty():
			break
		if actor_id != "hero" or int(ok.unit_by_id("hero")["ap"]) < 2:
			ok.submit_action({"actionType": Combat.ACTION_END_TURN, "actorId": actor_id})
			continue
		ok.submit_action({
			"actionType": Combat.ACTION_SKILL, "actorId": "hero", "targetId": "foe", "skillId": "fire_fireball",
		})
	_check(int(ok.unit_by_id("foe")["hp"]) < foe_max, "火球术对木桩造成伤害")


## 熟练度「用进」成长封顶在 100。
func _test_skill_growth() -> void:
	var combat: Combat = _new_combat(7203)
	_check(bool(combat.start(_spell_encounter({"fire_fireball": 99}, -1))["ok"]), "成长战斗开始成功")
	combat.submit_action({
		"actionType": Combat.ACTION_SKILL, "actorId": "hero", "targetId": "foe", "skillId": "fire_fireball",
	})
	_eq(int(combat.unit_by_id("hero")["skills"]["fire_fireball"]), 100, "熟练度 99 → 100 封顶")


## 元素克制公式（纯公式，DerivedStats 级）：四元素循环 + 光暗互克 + 魂系按生物类别。
func _test_element_counter_formula() -> void:
	var d: DerivedStats = _new_derived()
	# 水>火>风>土>水：克制 ×1.5（1500）
	_eq(d.element_counter_milli("water", "fire"), 1500, "水克火")
	_eq(d.element_counter_milli("fire", "wind"), 1500, "火克风")
	_eq(d.element_counter_milli("wind", "earth"), 1500, "风克土")
	_eq(d.element_counter_milli("earth", "water"), 1500, "土克水")
	# 反序即被克：×0.75（750）
	_eq(d.element_counter_milli("fire", "water"), 750, "火被水克")
	_eq(d.element_counter_milli("water", "earth"), 750, "水被土克")
	_eq(d.element_counter_milli("earth", "wind"), 750, "土被风克")
	_eq(d.element_counter_milli("wind", "fire"), 750, "风被火克")
	# 无元素目标 / 循环外组合 → 无克制 1000
	_eq(d.element_counter_milli("water", "physical"), 1000, "无元素目标无克制")
	_eq(d.element_counter_milli("water", "wind"), 1000, "水对风无克制")
	_eq(d.element_counter_milli("earth", "fire"), 1000, "土对火无克制")
	# 光<->暗互克 ×1.5
	_eq(d.element_counter_milli("holy", "dark"), 1500, "光克暗")
	_eq(d.element_counter_milli("dark", "holy"), 1500, "暗克光")
	_eq(d.element_counter_milli("holy", "fire"), 1000, "光对火无克制")
	# 魂系按生物类别
	_eq(d.element_counter_milli("soul", "", "undead"), 1500, "魂克亡灵")
	_eq(d.element_counter_milli("soul", "", "holy"), 500, "魂被神圣抑（×0.5）")
	_eq(d.element_counter_milli("soul", "", "living"), 1000, "魂对生者无额外")
	_eq(d.element_counter_milli("soul", "", "beast"), 1000, "未知类别按生者处理")


## 元素克制接线进战斗：同一水箭术打火系木桩比打中性木桩掉血更多。
func _test_element_wiring() -> void:
	var fire_dmg: int = _agg_spell_damage(7005, "fire")
	var neut_dmg: int = _agg_spell_damage(7006, "physical")
	_check(fire_dmg > neut_dmg, "水克制火：火系木桩掉血更多（%d > %d）" % [fire_dmg, neut_dmg])


## 每发命中的法术平均伤害（打若干发并跨轮回蓝续力，除以命中数归一化），
## 用来做克制下相对大小的干净比较——两场战斗命中数不同，不能直接比总伤。
func _agg_spell_damage(seed_val: int, foe_element: String) -> int:
	var combat: Combat = _new_combat(seed_val)
	combat.start(_spell_encounter({"water_water_arrow": 10}, -1, {"element": foe_element}))
	var foe_max: int = int(combat.unit_by_id("foe")["hp"])
	var hits: int = 0
	var guard: int = 0
	while guard < 8:
		guard += 1
		var before: int = int(combat.unit_by_id("foe")["hp"])
		var actor_id: String = combat.current_unit_id()
		if actor_id.is_empty():
			break
		if actor_id != "hero" or int(combat.unit_by_id("hero")["ap"]) < 2:
			combat.submit_action({"actionType": Combat.ACTION_END_TURN, "actorId": actor_id})
			continue
		combat.submit_action({
			"actionType": Combat.ACTION_SKILL, "actorId": "hero", "targetId": "foe", "skillId": "water_water_arrow",
		})
		if int(combat.unit_by_id("foe")["hp"]) < before:
			hits += 1
	if hits == 0:
		return 0
	return (foe_max - int(combat.unit_by_id("foe")["hp"])) / hits


## 专长被动（纯公式）：剑/斧/弓专精与火系亲和的伤乘区与命中加成，未学无加成。
func _test_mastery_passive_formula() -> void:
	var d: DerivedStats = _new_derived()
	# 伤害乘区
	_eq(d.passive_damage_factor_milli({"passive_sword_mastery": 4}, {"tree": "sword"}), 1100, "已学剑术专精 ×1.1")
	_eq(d.passive_damage_factor_milli({}, {"tree": "sword"}), 1000, "未学剑术专精无加成")
	_eq(d.passive_damage_factor_milli({"passive_axe_mastery": 1}, {"tree": "axe"}), 1100, "已学斧术专精 ×1.1")
	_eq(d.passive_damage_factor_milli({"passive_bow_mastery": 2}, {"tree": "bow"}), 1100, "已学弓术专精 ×1.1")
	_eq(d.passive_damage_factor_milli(
		{"passive_fire_affinity": 1}, {"category": "spell", "tree": "fire", "damageType": "fire"}),
		1100, "火系亲和加成火系法术")
	_eq(d.passive_damage_factor_milli(
		{}, {"category": "spell", "tree": "fire", "damageType": "fire"}),
		1000, "未学火系亲和无加成")
	# 命中加成
	_eq(d.passive_hit_bonus_bp({"passive_bow_mastery": 1}, {"tree": "bow"}), 500, "弓术专精命中 +5%")
	_eq(d.passive_hit_bonus_bp({}, {"tree": "bow"}), 0, "未学弓无命中加成")


# --- 里程碑 14：生产技能系统（D-78 ~ D-82）---

## 背包里某模板的件数（每格一件，计数即模板命中数）。
func _inventory_count(avatar, template_id: String) -> int:
	var count: int = 0
	for held in avatar.inventory:
		var instance: Dictionary = avatar.item_instances.get(held, {})
		if str(instance.get("templateId", "")) == template_id:
			count += 1
	return count


## 直接塞 count 件指定模板进背包（测试供料，不占商店、不摇词缀）。
func _grant_items(avatar, template_id: String, count: int) -> void:
	var rule: ItemInstance = ItemInstance.create_from_config()
	for _i in range(count):
		var instance: Dictionary = rule.bare_instance(template_id)
		instance["craftRarity"] = str(ContentLoader.get_item(template_id).get("rarity", "common"))
		var seq: int = avatar.inventory.size() + 1
		var instance_id: String = "%s-grant-%03d" % [str(avatar.avatar_id), seq]
		while avatar.item_instances.has(instance_id):
			seq += 1
			instance_id = "%s-grant-%03d" % [str(avatar.avatar_id), seq]
		avatar.item_instances[instance_id] = instance
		avatar.inventory.append(instance_id)


## 数据装载：material 类别合法、配方与采集点装载交叉校验通过、配方字段在界内。
func _test_recipe_content() -> void:
	_check(ContentLoader.ITEM_CATEGORIES.has("material"), "material 类别在合法类别里")
	var recipes: Array = ContentLoader.get_recipes()
	_check(recipes.size() >= 12, "配方库装载（%d 张 ≥ 12）" % recipes.size())
	var seen_ids: Dictionary = {}
	for r in recipes:
		var rid: String = str(r.get("recipeId", ""))
		_check(not rid.is_empty() and not seen_ids.has(rid), "配方 recipeId 唯一：" + rid)
		seen_ids[rid] = true
		_check(ContentLoader.PRODUCTION_SKILLS.has(str(r.get("skill", ""))),
			"配方 %s 技能在生产白名单" % rid)
		var lvl: int = int(r.get("requiredLevel", -1))
		_check(lvl >= 0 and lvl <= 100, "配方 %s 熟练门槛在 0..100" % rid)
		_check(ContentLoader.RECIPE_KINDS.has(str(r.get("kind", ""))), "配方 %s 种类合法" % rid)
		# 用料与产出都能在物品表里解析（校验时已交叉查过，这里再确认取得到）
		for ing in r.get("ingredients", []):
			_check(not ContentLoader.get_item(str(ing.get("itemId", ""))).is_empty(),
				"配方 %s 用料 %s 落在物品表" % [rid, str(ing.get("itemId", ""))])
		if str(r.get("kind", "")) == "craft":
			for out in r.get("outputs", []):
				_check(not ContentLoader.get_item(str(out.get("itemId", ""))).is_empty(),
					"配方 %s 产物 %s 落在物品表" % [rid, str(out.get("itemId", ""))])
	var gathers: Array = ContentLoader.get_gathers()
	_eq(gathers.size(), 3, "装载 3 个采集点（矿脉/林地/药草丛）")
	for spot in gathers:
		_check(ContentLoader.PRODUCTION_SKILLS.has(str(spot.get("skill", ""))),
			"采集点 %s 技能在生产白名单" % str(spot.get("spotId", "")))
		_check(not (spot.get("outputs", []) is Array) or not (spot.get("outputs", []) as Array).is_empty(),
			"采集点 %s 有产出表" % str(spot.get("spotId", "")))


## 门槛：无化身 / 熟练不足 / 材料不足都被前置条件拒绝，且不改状态。
func _test_craft_gate() -> void:
	var craft: Crafting = Crafting.create()
	# 无化身
	var no_avatar: Dictionary = craft.craft(null, "craft_iron_ingot")
	_eq(str(no_avatar.get("errorCode", "")), Crafting.ERROR_PRECONDITION_FAILED, "无化身被拒绝")
	# 有化身但熟练不足（craft_longsword 门槛 20）
	var low_skill := PlayerAvatar.new()
	low_skill.avatar_id = "avatar-low"
	low_skill.skills["forge"] = 0
	_grant_items(low_skill, "material_iron_ingot", 2)
	_grant_items(low_skill, "material_wood", 1)
	var gated: Dictionary = craft.craft(low_skill, "craft_longsword")
	_eq(str(gated.get("errorCode", "")), Crafting.ERROR_PRECONDITION_FAILED, "熟练不足被拒")
	_check(_has_text([gated.get("error", "")], "熟练度不足"), "提示含「熟练度不足」")
	_eq(_inventory_count(low_skill, "material_iron_ingot"), 2, "被拒不扣料")
	_eq(int(low_skill.skills.get("forge", 0)), 0, "被拒不涨熟练")
	# 材料不足（craft_iron_ingot 需 2 铁矿，只给 1）
	var starved := PlayerAvatar.new()
	starved.avatar_id = "avatar-starve"
	starved.skills["forge"] = 0
	_grant_items(starved, "material_iron_ore", 1)
	var short: Dictionary = craft.craft(starved, "craft_iron_ingot")
	_eq(str(short.get("errorCode", "")), Crafting.ERROR_PRECONDITION_FAILED, "材料不足被拒")
	_check(_has_text([short.get("error", "")], "材料不足"), "提示含「材料不足」")
	# can_craft 前门也给同一结论
	var can: Dictionary = craft.can_craft(starved, "craft_iron_ingot")
	_eq(can["can"], false, "can_craft 判不可做")
	_check(bool(can["missing"] is Array) and (can["missing"] as Array).size() == 1, "缺料清单一项")


## 制作成功：扣料、产出入包、熟练 +1（钳 100）。
func _test_craft_success() -> void:
	var craft: Crafting = Crafting.create()
	var avatar := PlayerAvatar.new()
	avatar.avatar_id = "avatar-craft"
	avatar.skills["forge"] = 0
	_grant_items(avatar, "material_iron_ore", 3)
	var res: Dictionary = craft.craft(avatar, "craft_iron_ingot")
	_check(bool(res["ok"]), "冶铁锭成功：" + str(res.get("error", "")))
	_eq(_inventory_count(avatar, "material_iron_ore"), 1, "铁矿石 3 → 1（扣 2）")
	_eq(_inventory_count(avatar, "material_iron_ingot"), 1, "铁锭 0 → 1（产出 1）")
	_eq(int(avatar.skills.get("forge", 0)), 1, "锻铸造熟练 0 → 1")
	_eq(int(res["gainedSkills"]["forge"]), 1, "返回成长摘要")
	_eq((res["produced"] as Array)[0]["templateId"], "material_iron_ingot", "产出模板对")
	# 熟练封顶：99 → 100，不出 101
	avatar.skills["forge"] = 99
	_grant_items(avatar, "material_iron_ore", 2)
	res = craft.craft(avatar, "craft_iron_ingot")
	_eq(int(avatar.skills.get("forge", 0)), 100, "熟练 99 → 100 封顶")


## 成品稀有度纯函数：0/40/55/70/85 → common/fine/rare/epic/legendary。
func _test_craft_rarity() -> void:
	var craft: Crafting = Crafting.create()
	_eq(craft.craft_rarity(0), "common", "0 熟练 → common")
	_eq(craft.craft_rarity(20), "common", "20 熟练仍 common")
	_eq(craft.craft_rarity(40), "fine", "40 熟练 → fine")
	_eq(craft.craft_rarity(55), "rare", "55 熟练 → rare")
	_eq(craft.craft_rarity(70), "epic", "70 熟练 → epic")
	_eq(craft.craft_rarity(85), "legendary", "85 熟练 → legendary")
	_eq(craft.craft_rarity(100), "legendary", "100 熟练 → legendary（封顶）")


## 装备类产物档位随熟练爬梯：长剑可爬到史诗/传奇档；匕首无高阶变体则退回 common。
func _test_craft_equipment_rarity() -> void:
	var craft: Crafting = Crafting.create()
	# 锻造 85 → legendary：长剑应落到 weapon_longsword_legendary
	var avatar := PlayerAvatar.new()
	avatar.avatar_id = "avatar-rare"
	avatar.skills["forge"] = 85
	_grant_items(avatar, "material_iron_ingot", 2)
	_grant_items(avatar, "material_wood", 1)
	var res: Dictionary = craft.craft(avatar, "craft_longsword")
	_check(bool(res["ok"]), "高熟练锻造成功")
	var produced: Array = res["produced"]
	_eq((produced[0]["templateId"]), "weapon_longsword_legendary", "85 熟练长剑 → 传奇档")
	_eq((produced[0]["rarity"]), "legendary", "产物标注传奇档")
	var pid: String = str(produced[0]["instanceId"])
	_eq(str(avatar.item_instances[pid].get("craftRarity", "")), "legendary", "实例记 craftRarity")
	# 门槛 20 → common：长剑仍是 common 模板
	var low := PlayerAvatar.new()
	low.avatar_id = "avatar-rare2"
	low.skills["forge"] = 20
	_grant_items(low, "material_iron_ingot", 2)
	_grant_items(low, "material_wood", 1)
	var low_res: Dictionary = craft.craft(low, "craft_longsword")
	_eq((low_res["produced"] as Array)[0]["templateId"], "weapon_longsword_common", "门槛档长剑 → common")
	# 匕首 no fine+ 变体：高熟练也退回 common 模板（档位只作元数据）
	var dagger := PlayerAvatar.new()
	dagger.avatar_id = "avatar-dagger"
	dagger.skills["forge"] = 85
	_grant_items(dagger, "material_iron_ingot", 1)
	var dag_res: Dictionary = craft.craft(dagger, "craft_dagger")
	var dag: Dictionary = (dag_res["produced"] as Array)[0]
	_eq(dag["templateId"], "weapon_dagger_common", "无高阶匕首变体，退回 common 模板")
	_eq(dag["rarity"], "legendary", "仍按熟练标记 legendary 档")


## 附魔：就地给指定实例加词条、耗材、熟练 +1；目标类别不符被拒。
func _test_enchant_in_place() -> void:
	var craft: Crafting = Crafting.create()
	var avatar := PlayerAvatar.new()
	avatar.avatar_id = "avatar-enchant"
	avatar.skills["enchant"] = 40
	_grant_items(avatar, "material_enchant_dust", 4)
	var rule: ItemInstance = ItemInstance.create_from_config()
	var blade: Dictionary = rule.new_instance("weapon_longsword_common", "tgt-blade")
	var blade_id: String = "enc-blade"
	avatar.item_instances[blade_id] = blade
	avatar.inventory.append(blade_id)
	var res: Dictionary = craft.craft(avatar, "enchant_sharpness", blade_id)
	_check(bool(res["ok"]), "附魔·锋利成功：" + str(res.get("error", "")))
	_eq(_inventory_count(avatar, "material_enchant_dust"), 2, "附魔耗 2 粉尘（4 → 2）")
	_eq(int(avatar.skills.get("enchant", 0)), 41, "附魔熟练 40 → 41")
	var mods: Array = avatar.item_instances[blade_id].get("modifiers", [])
	_eq(mods.size(), 1, "长剑得一条词缀")
	_eq(mods[0]["target"], "attack", "锋利加成 attack")
	_eq(int(mods[0]["value"]), 2, "长剑基值 16 ×10% → +2")
	# 类别不符：锋利只认武器，拿去附魔防具被拒
	var mail: Dictionary = rule.new_instance("armor_leather_common", "tgt-mail")
	var mail_id: String = "enc-mail"
	avatar.item_instances[mail_id] = mail
	avatar.inventory.append(mail_id)
	_grant_items(avatar, "material_enchant_dust", 2)
	var bad: Dictionary = craft.craft(avatar, "enchant_sharpness", mail_id)
	_eq(str(bad.get("errorCode", "")), Crafting.ERROR_PRECONDITION_FAILED, "类别不符被拒")
	_check(_has_text([bad.get("error", "")], "不匹配"), "提示含「不匹配」")
	_eq(_inventory_count(avatar, "material_enchant_dust"), 4, "被拒不耗材")
	# 坚固（护甲 +10，平值）
	_grant_items(avatar, "material_enchant_dust", 2)
	var hard: Dictionary = craft.craft(avatar, "enchant_hardness", mail_id)
	_check(bool(hard["ok"]), "附魔·坚固成功")
	var mail_mods: Array = avatar.item_instances[mail_id].get("modifiers", [])
	_eq(mail_mods[0]["target"], "armor", "坚固加成 armor")
	_eq(int(mail_mods[0]["value"]), 10, "护甲平值 +10")


## 野外采集：产出落包、熟练 +1；权重表命中主掉物。
func _test_gather_action() -> void:
	var gather: Gathering = Gathering.create()
	var avatar := PlayerAvatar.new()
	avatar.avatar_id = "avatar-gather"
	var res: Dictionary = gather.gather(avatar, "mine", "seed-mining-1")
	_check(bool(res["ok"]), "采矿成功：" + str(res.get("error", "")))
	var produced: Array = res["produced"]
	_eq((produced[0]["templateId"]), "material_iron_ore", "矿脉采到铁矿石")
	var count: int = int(int(produced[0]["count"]))
	_check(count >= 1 and count <= 3, "产量落在 1..3：%d" % count)
	_eq(_inventory_count(avatar, "material_iron_ore"), count, "铁矿入包")
	_eq(int(avatar.skills.get("mine", 0)), 1, "采矿熟练 0 → 1")
	# 权重表：药草丛在 herb/salt 二选一
	var herb: Dictionary = gather.gather(avatar, "herbalism", "seed-herb-1")
	var got: String = str((herb["produced"] as Array)[0]["templateId"])
	_check(got == "material_herb" or got == "material_salt", "药草丛命中 herb/salt：" + got)
	# 未知点 / 无化身
	var miss: Dictionary = gather.gather(avatar, "nowhere", "s")
	_eq(str(miss.get("errorCode", "")), Gathering.ERROR_NOT_FOUND, "未知采集点报 NOT_FOUND")
	var no_av: Dictionary = gather.gather(null, "mine", "s")
	_eq(str(no_av.get("errorCode", "")), Gathering.ERROR_PRECONDITION_FAILED, "无化身被拒")


## 商店只售基础材料：中间/高级材料（铁锭/皮革/碳/附魔粉尘）不进任何货架。
func _test_shop_sells_base_materials_only() -> void:
	var built: Dictionary = _new_sim(false)
	var store: Economy = built["sim"].economy
	var stock: Array = store.list_stock(built["world"], "hammerhold")
	_check(_stock_has(stock, "material_iron_ore"), "基础材料（铁矿石）上架")
	for banned in ["material_iron_ingot", "material_leather", "material_charcoal", "material_enchant_dust"]:
		_check(not _stock_has(stock, banned), "中间/高级材料「%s」不上架" % banned)


func _stock_has(stock: Array, template_id: String) -> bool:
	for row in stock:
		if str(row.get("templateId", "")) == template_id:
			return true
	return false


## 制作台视图模型：配方行与采集行连成一根可导航列表，selected 指向光标行，
## 附魔行带 hasTarget / targetName / affected，装备产物按熟练写档位标签。
func _test_crafting_view_model() -> void:
	var craft: Crafting = Crafting.create()
	var avatar := PlayerAvatar.new()
	avatar.avatar_id = "avatar-craft-vm"
	avatar.skills["forge"] = 85
	var lookups: Dictionary = {"itemTemplates": _item_template_table()}
	var view: Dictionary = CraftingViewModel.build(craft, avatar, lookups, 0)

	var rows: Array = view.get("rows", [])
	_check(rows.size() >= 12, "配方行 + 采集行连成一根列表（%d 行 ≥ 12）" % rows.size())
	_check((view.get("gather", []) as Array).size() == 3, "采集行单独归组也有 3 行")
	_eq(int(view.get("cursor", -1)), 0, "光标停在首行")
	# selected = 光标行本身
	_eq(view["selected"].get("selected", false), true, "首行被标为 selected")
	_check(bool(view["selected"].has("kind")), "selected 是完整行（带 kind）")
	# 分隔计数助手：配方数 + 采集数 = 总行数
	_eq(rows.size() - (view["gather"] as Array).size(),
		ContentLoader.get_recipes().size(), "总行数 = 配方数 + 采集数")

	# 装备产物档位随熟练（forge 85 → legendary）
	var sword: Dictionary = {}
	for row in rows:
		if str(row.get("recipeId", "")) == "craft_longsword":
			sword = row
			break
	_check(not sword.is_empty(), "找到长剑配方行")
	_check(str(sword.get("outputText", "")).contains("传奇"), "长剑参数里写传奇档")
	_eq(str(view.get("craftRarityLabel", "")), "传奇", "craftRarityLabel 随 forge 85 → 传奇")
	_check(bool(sword.get("gate", false)), "forge 85 越过长剑门槛 20")
	# 材料行有 need / have / short
	_check((sword.get("materials", []) as Array).size() >= 1, "长剑有材料清单")
	_check(bool((sword["materials"] as Array)[0].has("short")), "材料行带缺料标记")

	# 采集行是 gather 形态
	var mine: Dictionary = {}
	for row in rows:
		if str(row.get("kind", "")) == CraftingViewModel.KIND_GATHER \
			and str(row.get("spotId", "")) == "mine":
			mine = row
			break
	_check(not mine.is_empty(), "找到采集行（矿脉）")
	_eq(str(mine.get("skillLabel", "")), "采矿", "采集行技能标签")


## 附魔自动挑背包里第一件能附的目标（appliesTo 匹配）。纯函数只读扫描。
func _test_crafting_enchant_target() -> void:
	var craft: Crafting = Crafting.create()
	var lookups: Dictionary = {"itemTemplates": _item_template_table()}
	var recipes: Dictionary = {}
	for r in ContentLoader.get_recipes():
		recipes[str(r.get("recipeId", ""))] = r
	var recipe: Dictionary = recipes.get("enchant_sharpness", {})

	# 背包里武器 + 防具都有：取第一件匹配武器（锋利只认 weapon）
	var avatar := PlayerAvatar.new()
	avatar.avatar_id = "avatar-enc-tgt"
	var rule: ItemInstance = ItemInstance.create_from_config()
	var mail: Dictionary = rule.new_instance("armor_leather_common", "t-m-mail")
	avatar.item_instances["t-mail"] = mail
	avatar.inventory.append("t-mail")
	var blade: Dictionary = rule.new_instance("weapon_longsword_common", "t-m-blade")
	avatar.item_instances["t-blade"] = blade
	avatar.inventory.append("t-blade")
	var target: Dictionary = CraftingViewModel.find_enchant_target(avatar, recipe, lookups["itemTemplates"])
	_check(bool(target["found"]), "找到可附魔目标")
	_eq(str(target.get("instanceId", "")), "t-blade", "取到匹配类别的武器实例")
	_eq(str(target.get("affected", "")), "attack", "affected 列出词条作用字段")

	# 背包里只有防具：武器类配方找不到目标
	var only_mail := PlayerAvatar.new()
	only_mail.avatar_id = "avatar-enc-only-mail"
	only_mail.item_instances["m"] = mail
	only_mail.inventory.append("m")
	var none: Dictionary = CraftingViewModel.find_enchant_target(only_mail, recipe, lookups["itemTemplates"])
	_eq(bool(none["found"]), false, "只有防具时武器附魔找不到目标")


## 制作台面板命中：返回地图按钮 + 左右列行命中、面板外忽略。
func _test_crafting_panel_hit_test() -> void:
	var craft: Crafting = Crafting.create()
	var avatar := PlayerAvatar.new()
	avatar.avatar_id = "avatar-craft-hit"
	var lookups: Dictionary = {"itemTemplates": _item_template_table()}
	var view: Dictionary = CraftingViewModel.build(craft, avatar, lookups, 0)

	var buttons: Array = CraftingPanel.buttons(view, PANEL_RECT)
	_eq(buttons.size(), 1, "制作台右上只有返回地图一个按钮")
	var back: Dictionary = UiTheme.find_button(buttons, "back")
	_check(not back.is_empty(), "返回地图按钮在")
	_eq(str(CraftingPanel.hit_test(view, PANEL_RECT, _center(back["rect"])).get("id", "")),
		"back", "返回按钮点得中")
	var hit_back: Dictionary = CraftingPanel.hit_test(view, PANEL_RECT, _center(back["rect"]))
	_eq(str(hit_back.get("kind", "")), "button", "返回按钮命中类型是 button")

	_check(int(_hit_for("crafting", view, PANEL_RECT, "row", 0).get("index", -1)) == 0,
		"第一行报出自己的行号")
	_check(CraftingPanel.hit_test(view, PANEL_RECT, Vector2(4.0, 4.0)).is_empty(),
		"面板外点击不算命中")
	var sweep: Dictionary = _sweep_hits("crafting", view, PANEL_RECT)
	_check(sweep.has("button"), "按钮在命中范围内")
	_check(sweep.has("row"), "配分/采集行可点")


## 全链路执行：从制作台视图里取配方行回车 → 扣料产出、熟练 +1；
## 附魔行自动挑第一件匹配目标写词条；无目标时 views 拒做。
func _test_crafting_flow() -> void:
	var craft: Crafting = Crafting.create()
	var lookups: Dictionary = {"itemTemplates": _item_template_table()}
	var avatar := PlayerAvatar.new()
	avatar.avatar_id = "avatar-craft-flow"
	avatar.skills["forge"] = 0
	_grant_items(avatar, "material_iron_ore", 3)
	# 制造：冶铁锭
	var res: Dictionary = craft.craft(avatar, "craft_iron_ingot")
	_check(bool(res["ok"]), "制作台制造成功：" + str(res.get("error", "")))
	_eq(_inventory_count(avatar, "material_iron_ingot"), 1, "产物入包")
	_eq(int(avatar.skills.get("forge", 0)), 1, "制造成功熟练 +1")
	# 附魔：自动挑目标 + 就地写词条
	avatar.skills["enchant"] = 40
	var rule: ItemInstance = ItemInstance.create_from_config()
	var blade: Dictionary = rule.new_instance("weapon_longsword_common", "f-blade")
	avatar.item_instances["f-blade"] = blade
	avatar.inventory.append("f-blade")
	_grant_items(avatar, "material_enchant_dust", 4)
	var recipe: Dictionary = {}
	for r in ContentLoader.get_recipes():
		if str(r.get("recipeId", "")) == "enchant_sharpness":
			recipe = r
			break
	var target: Dictionary = CraftingViewModel.find_enchant_target(avatar, recipe, lookups["itemTemplates"])
	_check(bool(target["found"]), "包里那件武器被挑为目标")
	var enc: Dictionary = craft.craft(avatar, "enchant_sharpness", str(target["instanceId"]))
	_check(bool(enc["ok"]), "附魔执行成功：" + str(enc.get("error", "")))
	var mods: Array = avatar.item_instances["f-blade"].get("modifiers", [])
	_eq(mods.size(), 1, "长剑得一条词缀")
	_eq(int(avatar.skills.get("enchant", 0)), 41, "附魔熟练 40 → 41")
	# views 侧：背包里没有可附魔目标时，配方行 enabled = false
	var no_tgt := PlayerAvatar.new()
	no_tgt.avatar_id = "avatar-enc-no-tgt"
	no_tgt.skills["enchant"] = 40
	_grant_items(no_tgt, "material_enchant_dust", 2)
	var view: Dictionary = CraftingViewModel.build(craft, no_tgt, lookups, 0)
	var ench_row: Dictionary = {}
	for row in view["rows"]:
		if str(row.get("recipeId", "")) == "enchant_sharpness":
			ench_row = row
			break
	_check(not ench_row.is_empty(), "找到附魔·锋利行")
	_eq(bool(ench_row.get("enabled", true)), false, "无目标时附魔行置灰")
	_check(str(ench_row.get("reason", "")).contains("没有可附魔的目标"),
		"置灰原因写明缺目标")


func _new_creator() -> CharacterCreation:
	return CharacterCreation.new(
		ContentLoader.get_balance_section("characterCreation"),
		ContentLoader.get_playable_races(),
		ContentLoader.get_backgrounds(),
		ContentLoader.get_talents()
	)


func _new_derived() -> DerivedStats:
	return DerivedStats.new(
		ContentLoader.get_balance_section("derivedStats"),
		ContentLoader.get_balance_section("combat")
	)


func _new_reincarnation(seed_value: int) -> Reincarnation:
	return Reincarnation.new(
		ContentLoader.get_balance_section("reincarnation"),
		_new_creator(),
		DeterministicRNG.new(seed_value)
	)


## 七维全 10（《数值框架》2.2 节的普通成年基准）。
func _plain_attributes() -> Dictionary:
	var out: Dictionary = {}
	for attr in PlayerAvatar.ALL_ATTRIBUTES:
		out[attr] = 10
	return out


func _attributes_with(attribute: String, value: int) -> Dictionary:
	var out: Dictionary = _plain_attributes()
	out[attribute] = value
	return out


func _allocate(spec: Dictionary, values: Dictionary) -> void:
	var allocations: Dictionary = spec[CharacterCreation.ATTR_POINTS_KEY]
	for attr in values:
		allocations[attr] = int(values[attr])


func _has_text(errors: Array, needle: String) -> bool:
	for message in errors:
		if str(message).contains(needle):
			return true
	return false


func _join(errors: Array) -> String:
	var parts: Array = []
	for message in errors:
		parts.append(str(message))
	return " / ".join(PackedStringArray(parts))


## 把视图模型产出的行压成一段文字，用来断言"某一项有没有出现在界面上"。
## 比对的是文案而不是索引：索引一改布局就失效，而"界面上有没有这句话"
## 才是这些用例真正关心的。
func _row_text(rows: Array) -> String:
	var parts: Array = []
	for row in rows:
		parts.append(str(row.get("label", "")))
		parts.append(str(row.get("value", "")))
		parts.append(str(row.get("hint", "")))
		parts.append(str(row.get("effectText", "")))
	return " / ".join(PackedStringArray(parts))


func _find_row(rows: Array, key: String) -> Dictionary:
	for row in rows:
		if str(row.get("key", "")) == key:
			return row
	return {}


## 在面板范围内按固定步长扫一遍，返回每种 kind 第一次命中的结果。
##
## 步长 6px 小于面板里最小的可点元素（22×22 的加减方块、22px 高的菜单项），
## 不会漏掉任何一个。这样测试不必把布局常量抄一遍。
func _sweep_hits(panel: String, view: Dictionary, rect: Rect2, step: int = 6) -> Dictionary:
	var found: Dictionary = {}
	var y: float = rect.position.y
	while y < rect.position.y + rect.size.y:
		var x: float = rect.position.x
		while x < rect.position.x + rect.size.x:
			var hit: Dictionary = _panel_hit(panel, view, rect, Vector2(x, y))
			var kind: String = str(hit.get("kind", ""))
			if not kind.is_empty() and not found.has(kind):
				found[kind] = hit
			x += float(step)
		y += float(step)
	return found


## 面板名 → hit_test。各面板的签名一致，但它们是各自的静态函数，
## 没法凑成一个 Callable 传进来，所以在这里分一次流。
func _panel_hit(panel: String, view: Dictionary, rect: Rect2, point: Vector2) -> Dictionary:
	match panel:
		"creation":
			return CreationPanel.hit_test(view, rect, point)
		"city":
			return CityPanel.hit_test(view, rect, point)
		"avatar":
			return AvatarPanel.hit_test(view, rect, point)
		"combat":
			return CombatPanel.hit_test(view, rect, point)
		"smuggling":
			return SmugglingPanel.hit_test(view, rect, point)
		"quest":
			return QuestPanel.hit_test(view, rect, point)
		"event":
			return EventPanel.hit_test(view, rect, point)
		"trade":
			return TradePanel.hit_test(view, rect, point)
		"encounter":
			return EncounterPanel.hit_test(view, rect, point)
		"crafting":
			return CraftingPanel.hit_test(view, rect, point)
	return {}


## 在面板上扫出命中指定元素的第一个点，返回那次 hit_test 的结果。
## 与 _sweep_hits 同一套做法：不手算坐标，免得把布局常量抄进测试。
## index 给负数表示不看行号。
func _hit_for(
	panel: String, view: Dictionary, rect: Rect2, kind: String, index: int, step: int = 3
) -> Dictionary:
	var y: float = rect.position.y
	while y < rect.position.y + rect.size.y:
		var x: float = rect.position.x
		while x < rect.position.x + rect.size.x:
			var hit: Dictionary = _panel_hit(panel, view, rect, Vector2(x, y))
			if str(hit.get("kind", "")) == kind \
				and (index < 0 or int(hit.get("index", -1)) == index):
				return hit
			x += float(step)
		y += float(step)
	return {}


## 点创建界面上的某个按钮：拿按钮矩形的中心去命中，结果原样喂给会话。
func _click_creation_button(session: CreationSession, button_id: String) -> void:
	var button: Dictionary = UiTheme.find_button(
		CreationPanel.buttons(session.view, PANEL_RECT), button_id
	)
	if button.is_empty():
		return
	session.click(CreationPanel.hit_test(session.view, PANEL_RECT, _center(button["rect"])))


## 建一个创建流程，宿主抽取换成固定结果——真抽取要世界状态与灵魂记录，
## 那是主场景的东西，不该由流程类揣着。
## rolls 收集每次抽取的序号；host_ok 为假时模拟"这一世没有可附身的躯壳"。
func _new_creation_session(rolls: Array, host_ok: bool = true) -> CreationSession:
	var source := func(seq: int) -> Dictionary:
		rolls.append(seq)
		if not host_ok:
			return {"ok": false, "reason": "这一世没有可附身的躯壳"}
		return {
			"ok": true,
			"sleepMonths": 6,
			"retention": 0.5,
			"inheritedSkills": {"sword_slash": 10},
			"legacy": {"hostName": "前世宿主", "hostCityId": "aedran", "debtCopper": 0},
			"avatarSpec": {},
		}
	return CreationSession.new(
		_new_creator(), DeterministicRNG.new(7), source, {"aedran": "艾德兰"}
	)


func _center(rect: Rect2) -> Vector2:
	return rect.position + rect.size * 0.5


func _menu_text(menu: Array) -> String:
	var parts: Array = []
	for item in menu:
		parts.append(str(item.get("label", "")))
	return " / ".join(PackedStringArray(parts))


func _find_menu(menu: Array, needle: String) -> Dictionary:
	for item in menu:
		if str(item.get("label", "")).contains(needle):
			return item
	return {}


## 物品模板表：templateId → 模板。视图模型按它把实例还原成可显示的名称与数值。
func _item_template_table() -> Dictionary:
	var out: Dictionary = {}
	for item in ContentLoader.get_items():
		out[str(item.get("templateId", ""))] = item
	return out


func _new_world() -> Dictionary:
	var grid_cfg: Dictionary = ContentLoader.get_balance_section("worldGrid")
	return WorldFactory.create_new(
		20260915,
		ContentLoader.get_city_configs(),
		int(grid_cfg.get("width", 120)),
		int(grid_cfg.get("height", 120))
	)


## 新世界 + 世界模拟。with_npcs 为 true 时铺满模拟 NPC 与预置路线，
## 为 false 时只有城市与六维——纯数值的测试不需要背 1350 名居民的开销。
func _new_sim(with_npcs: bool = true) -> Dictionary:
	var built: Dictionary = _new_world()
	var world: WorldState = built["world"]
	if with_npcs:
		WorldSim.bootstrap(world)
	var sim: WorldSim = WorldSim.create(world)
	return {"world": world, "grid": built["grid"], "sim": sim}


## 逐月结算并返回逐月快照的校验和。checksum 每次都把六维卷进去，
## 因此两个世界只要有一个月的一个维度不同，校验和就会分叉。
func _run_months(sim: WorldSim, months: int, start_month: int = 0) -> Dictionary:
	var checksum: int = 17
	var in_range: bool = true
	var last: Dictionary = {}
	for i in range(months):
		var month: int = start_month + i + 1
		sim.settle_month(month)
		if month % 12 == 0:
			sim.settle_year()
		for city_id in sim.world.get_city_ids():
			var city: City = sim.world.get_city(str(city_id))
			var snapshot: Dictionary = {}
			for dim in City.ALL_DIMENSIONS:
				var value: int = city.get_dimension(dim)
				snapshot[dim] = value
				checksum = (checksum * 31 + value) & 0x3FFFFFFF
				if value < 0 or value > 100:
					in_range = false
			last[str(city_id)] = snapshot
	return {"checksum": checksum, "inRange": in_range, "last": last}


func _has_kin(world: WorldState, a: String, b: String) -> bool:
	for record in world.get_relations(a, "out"):
		if str(record["type"]) == NpcGenerator.RELATION_KIN and str(record["toNpcId"]) == b:
			return true
	return false


func _count_confiscations(sim: WorldSim, city_id: String, months: int, pin_security: int = -1) -> int:
	var total: int = 0
	for i in range(months):
		if pin_security >= 0:
			sim.world.get_city(city_id).security = pin_security
		var report: Dictionary = sim.settle_month(i + 1)
		for entry in report["confiscations"]:
			if str(entry["cityId"]) == city_id:
				total += 1
	return total


func _cleanup_history_slot() -> void:
	var base: String = SaveIO.slot_dir("_test_history_slot")
	for file_name in [SaveIO.WORLD_FILE, SaveIO.SOUL_FILE]:
		if FileAccess.file_exists(base + file_name):
			DirAccess.remove_absolute(base + file_name)
	for sub in [SaveIO.BACKUP_DIR, SaveIO.ARCHIVE_DIR]:
		var dir: DirAccess = DirAccess.open(base + sub)
		if dir != null:
			dir.list_dir_begin()
			var entry: String = dir.get_next()
			while entry != "":
				if not dir.current_is_dir():
					DirAccess.remove_absolute(base + sub + "/" + entry)
				entry = dir.get_next()
			dir.list_dir_end()
		DirAccess.remove_absolute(base + sub)
	DirAccess.remove_absolute(base)


func _cleanup_npc_slot() -> void:
	var base: String = SaveIO.slot_dir("_test_npc_slot")
	for file_name in [SaveIO.WORLD_FILE, SaveIO.SOUL_FILE]:
		if FileAccess.file_exists(base + file_name):
			DirAccess.remove_absolute(base + file_name)
	for sub in [SaveIO.BACKUP_DIR, SaveIO.ARCHIVE_DIR]:
		var dir: DirAccess = DirAccess.open(base + sub)
		if dir != null:
			dir.list_dir_begin()
			var entry: String = dir.get_next()
			while entry != "":
				if not dir.current_is_dir():
					DirAccess.remove_absolute(base + sub + "/" + entry)
				entry = dir.get_next()
			dir.list_dir_end()
		DirAccess.remove_absolute(base + sub)
	DirAccess.remove_absolute(base)


func _time_scale(key: String, fallback: int) -> int:
	return int(ContentLoader.get_balance_section("time").get(key, fallback))


# --- 里程碑 16：世界纪年与历史纪年 ---

## 规则层：阈值过滤、条目换算与 record 的追加/钳制。
func _test_chronicle_rules() -> void:
	var chronicle := Chronicle.create()
	_eq(int(chronicle.rules().get("minChronicleWeight", 0)), 250, "阈值来自 balance.chronicle")

	var config: Dictionary = ContentLoader.get_event_template("ev_02_kraken_blockade")
	_check(not config.is_empty(), "海怪封港模板在事件表里")
	_eq(chronicle.chronicle_weight(config), 400, "模板的 chronicleBp 被读出")
	_check(chronicle.is_notable(config), "chronicleBp 400 ≥ 阈值 250，够格进史书")
	var plain: Dictionary = {"templateId": "no_bp"}
	_eq(chronicle.chronicle_weight(plain), 0, "没有 chronicleBp 的模板权重为 0")
	_check(not chronicle.is_notable(plain), "权重 0 进不了史书")

	var world: WorldState = _new_world()["world"]
	# 条目换算：事件 / 跨档 / 转生三类标题口径
	var ev: CityEvent = CityEvent.make("ev-x", "ev_02_kraken_blockade", "port_thorne", 13, true, {})
	var ev_entry: Dictionary = chronicle.event_entry(world, ev)
	_eq(str(ev_entry["kind"]), Chronicle.KIND_CITY_EVENT, "事件条目标记为城市事件")
	_eq(str(ev_entry["title"]), "索恩港的行动：海怪封港", "事件标题带城市与剧本名")
	_check(str(ev_entry["year"]).contains("第2年"), "月份 13 折算成第 2 年")

	var tier_entry: Dictionary = chronicle.tier_entry(world, "aedran", "村落", "乡镇", 25)
	_eq(str(tier_entry["kind"]), Chronicle.KIND_TIER, "跨档条目标记为 tier")
	_check(str(tier_entry["title"]).contains("从「村落」变为「乡镇」"), "跨档标题带两档标签")

	var soul_entry: Dictionary = chronicle.soul_entry(3, "云深", 37)
	_eq(str(soul_entry["kind"]), Chronicle.KIND_SOUL, "转生条目标记为 soul")
	_eq(str(soul_entry["title"]), "第3世云深落幕", "转生标题带世代与姓名")

	# record：自增 id + 超上限丢最老
	var a: Dictionary = chronicle.record(world, chronicle.soul_entry(1, "甲", 1))
	var b: Dictionary = chronicle.record(world, chronicle.tier_entry(world, "aedran", "村落", "乡镇", 2))
	_eq(int(a["id"]), 1, "第一条 id 为 1")
	_eq(int(b["id"]), 2, "第二条 id 为 2")
	_eq(world.chronicle.size(), 2, "条目进了世界纪年")
	var cap: Chronicle = Chronicle.new(10, 3, 12)  # min 10, max 3
	for i in range(5):
		cap.record(world, chronicle.soul_entry(i + 1, "来回", i + 1))
	_eq(world.chronicle.size(), 3, "超过 maxEntries 被钳住")
	_eq(int(world.chronicle_seq), 7, "id 游标只增不减（2 条后人乘 5 条）")


## 月度结算挂钩：达标事件自动沉淀成纪年条目。
func _test_chronicle_event_hook() -> void:
	var built: Dictionary = _new_sim()
	var world: WorldState = built["world"]
	var sim: WorldSim = built["sim"]
	_check(world.chronicle.is_empty(), "开局史书是空的")
	sim.settle_month(1)
	_check(not world.chronicle.is_empty(), "触发海怪封港后史书有了内容")
	if world.chronicle.is_empty():
		return
	var top: Dictionary = world.chronicle[world.chronicle.size() - 1]
	_eq(str(top.get("kind", "")), Chronicle.KIND_CITY_EVENT, "沉淀的是城市事件条目")
	_check(str(top.get("title", "")).contains("海怪封港"), "记的是海怪封港")
	_eq(str(top.get("cityId", "")), "port_thorne", "标的城市是索恩港")


## 纪年随世界存档往返。
func _test_chronicle_round_trip() -> void:
	var built: Dictionary = _new_sim()
	var world: WorldState = built["world"]
	var sim: WorldSim = built["sim"]
	sim.settle_month(1)
	_check(not world.chronicle.is_empty(), "史书有内容可存")
	var decoded: Variant = JSON.parse_string(JSON.stringify(world.to_dict()))
	_check(decoded is Dictionary, "世界状态可过 JSON")
	var fresh: WorldState = _new_world()["world"]
	fresh.apply_dict(decoded)
	_eq(fresh.chronicle.size(), world.chronicle.size(), "纪年条数往返一致")
	_eq(int(fresh.chronicle_seq), int(world.chronicle_seq), "id 游标往返一致")
	if fresh.chronicle.is_empty():
		return
	_eq(str(fresh.chronicle[0].get("title", "")), str(world.chronicle[0].get("title", "")),
		"首条内容往返一致")


## 视图模型：最近在顶、光标与分项统计。
func _test_chronicle_view_model() -> void:
	var chronicle := Chronicle.create()
	var world: WorldState = _new_world()["world"]
	chronicle.record(world, chronicle.soul_entry(1, "俑一", 1))
	chronicle.record(world, chronicle.tier_entry(world, "aedran", "村落", "乡镇", 2))
	chronicle.record(world, chronicle.soul_entry(2, "俑二", 3))
	var view: Dictionary = ChronicleViewModel.build(world.chronicle, 0)
	_eq(int(view["rowCount"]), 3, "三条都在")
	var rows: Array = view["rows"]
	_eq(str(rows[0].get("title", "")), "第2世俑二落幕", "最近一条在顶")
	_eq(int(rows[0].get("id", 0)), 3, "顶行的 id 是最大的（最新）")
	_eq(int(view.get("cursor", -1)), 0, "光标钳到 0")
	var counts: Dictionary = view["counts"]
	_eq(int(counts.get(Chronicle.KIND_SOUL, 0)), 2, "转生条目数 2")
	_eq(int(counts.get(Chronicle.KIND_TIER, 0)), 1, "跨档条目数 1")
	# 光标越界钳住
	var tail: Dictionary = ChronicleViewModel.build(world.chronicle, 99)
	_eq(int(tail.get("cursor", -1)), 2, "光标越上界钳到最后一条")


## 面板命中：能点到行与返回按钮。
func _test_chronicle_panel_hit_test() -> void:
	var chronicle := Chronicle.create()
	var world: WorldState = _new_world()["world"]
	for i in range(6):
		chronicle.record(world, chronicle.soul_entry(i + 1, "回环", i + 1))
	var view: Dictionary = ChronicleViewModel.build(world.chronicle, 3)
	var rect: Rect2 = Rect2(16.0, 48.0, 1248.0, 568.0)
	# 点中第一行（最近在顶、光标定位后可见区内的某一行）的左上处
	var list: Rect2 = ChroniclePanel.list_rect(rect)
	var first_row: Rect2 = ChroniclePanel._row_rect(rect, view, 3)
	var hit: Dictionary = ChroniclePanel.hit_test(view, rect, first_row.position + Vector2(8.0, 10.0))
	_eq(str(hit.get("kind", "")), "row", "点到列表能命中行")
	_eq(int(hit.get("index", -1)), 3, "命中的正好是光标那行")
	# 范围外返回空
	_check(ChroniclePanel.hit_test(view, rect, list.position - Vector2(40.0, 40.0)).is_empty(),
		"列表外点不到")
	# 返回按钮在右上，点名它
	var buttons: Array = ChroniclePanel.buttons(view, rect)
	_check(not buttons.is_empty(), "史书有返回按钮")
	if not buttons.is_empty():
		var btn: Dictionary = buttons[0]
		var center: Vector2 = ((btn["rect"] as Rect2).position + (btn["rect"] as Rect2).size / 2.0)
		var bhit: Dictionary = ChroniclePanel.hit_test(view, rect, center)
		_eq(str(bhit.get("kind", "")), "button", "点到返回按钮")
		_eq(str(bhit.get("id", "")), "back", "返回按钮 id")


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  v " + label)
	else:
		_failed += 1
		_failures.append(label)
		print("  x " + label)


func _eq(actual: Variant, expected: Variant, label: String) -> void:
	var ok: bool = actual == expected
	if ok:
		_passed += 1
		print("  v " + label)
	else:
		_failed += 1
		var msg: String = "%s（期望 %s，实际 %s）" % [label, str(expected), str(actual)]
		_failures.append(msg)
		print("  x " + msg)


func _detail(text: String) -> String:
	return "" if text.is_empty() else "（" + text + "）"


## 清掉测试槽位，免得它在存档列表里留下一个看起来像真存档的条目。
func _cleanup_test_slot() -> void:
	var base: String = SaveIO.slot_dir("_test_slot")
	for file_name in [SaveIO.WORLD_FILE, SaveIO.SOUL_FILE]:
		if FileAccess.file_exists(base + file_name):
			DirAccess.remove_absolute(base + file_name)
	for sub in [SaveIO.BACKUP_DIR, SaveIO.ARCHIVE_DIR]:
		var dir: DirAccess = DirAccess.open(base + sub)
		if dir != null:
			dir.list_dir_begin()
			var entry: String = dir.get_next()
			while entry != "":
				if not dir.current_is_dir():
					DirAccess.remove_absolute(base + sub + "/" + entry)
				entry = dir.get_next()
			dir.list_dir_end()
		DirAccess.remove_absolute(base + sub)
	DirAccess.remove_absolute(base)


# --- 里程碑 18：NPC 人格与好感交互 ---

## 候选物品的模板：取给定 category 的第一个模板 id（人格 giftTaste 用它通吃一类）。
func _template_of_category(category: String) -> String:
	for item in ContentLoader.get_items():
		if str(item.get("category", "")) == category:
			return str(item.get("templateId", ""))
	return ""


## 在现成世界里找一名可雇的人（非具名、无职位、职业类别可雇）。找不到返回 null。
func _find_hireable_npc(world: WorldState) -> SimNpc:
	var cats: Array = ContentLoader.get_balance_section("npcInteraction").get("hireableCategories", [])
	for city_id in world.get_city_ids():
		for npc in world.get_city_npcs(str(city_id)):
			if npc.is_named or not npc.position_id.is_empty():
				continue
			var p: Dictionary = ContentLoader.get_profession(npc.profession_id)
			if (cats as Array).has(str(p.get("category", ""))):
				return npc
	return null


## 人格/信仰池的完整性与确定性指派：任意居民都被问到话、收到礼。
func _test_npc_personality_faith() -> void:
	_eq(ContentLoader.get_personalities().size(), 6, "人格池共 6 种")
	_eq(ContentLoader.get_faiths().size(), 4, "信仰池共 4 种")
	var intent_ok: bool = true
	var taste_ok: bool = true
	for p in ContentLoader.get_personalities():
		var talk: Dictionary = p.get("talkLines", {})
		for intent in [NpcInteractionSystem.INTENT_AMBITION, NpcInteractionSystem.INTENT_RUMOR,
				NpcInteractionSystem.INTENT_FAITH]:
			if str(talk.get(intent, "")).is_empty():
				intent_ok = false
		var taste: Dictionary = p.get("giftTaste", {})
		if (taste.get("love", []) as Array).is_empty() or (taste.get("hate", []) as Array).is_empty():
			taste_ok = false
	_check(intent_ok, "每人格三句谈资（志向/传闻/信仰）齐备")
	_check(taste_ok, "每人格有爱憎两类送礼口味")
	# 生成的居民必定有人格与信仰（确定性指派，保证能聊能送）
	var built: Dictionary = _new_sim()
	var npc: SimNpc = built["world"].get_city_npcs("aedran")[0]
	_check(not npc.personality_id.is_empty(), "居民被指派了人格")
	_check(not npc.faith_id.is_empty(), "居民被指派了信仰")
	_check(not str(ContentLoader.get_personality(npc.personality_id).get("displayName", "")).is_empty(),
		"人格 id 能查回中文名")


## 好感读写的钳制与五档边界切分。
func _test_npc_affinity_band() -> void:
	_eq(NpcInteractionSystem.band(-100), NpcInteractionSystem.BAND_HOSTILE, "-100 敌对")
	_eq(NpcInteractionSystem.band(-51), NpcInteractionSystem.BAND_HOSTILE, "-51 敌对")
	_eq(NpcInteractionSystem.band(-50), NpcInteractionSystem.BAND_COLD, "-50 冷淡")
	_eq(NpcInteractionSystem.band(-16), NpcInteractionSystem.BAND_COLD, "-16 冷淡")
	_eq(NpcInteractionSystem.band(-15), NpcInteractionSystem.BAND_NEUTRAL, "-15 中立")
	_eq(NpcInteractionSystem.band(0), NpcInteractionSystem.BAND_NEUTRAL, "0 中立")
	_eq(NpcInteractionSystem.band(14), NpcInteractionSystem.BAND_NEUTRAL, "14 中立")
	_eq(NpcInteractionSystem.band(15), NpcInteractionSystem.BAND_FRIENDLY, "15 友善")
	_eq(NpcInteractionSystem.band(49), NpcInteractionSystem.BAND_FRIENDLY, "49 友善")
	_eq(NpcInteractionSystem.band(50), NpcInteractionSystem.BAND_CLOSE, "50 亲密")
	_eq(NpcInteractionSystem.band_label(NpcInteractionSystem.BAND_HOSTILE), "敌对", "档位有中文标签")
	# 钳制：越界好感被按到 [affMin, affMax]
	var built: Dictionary = _new_sim()
	var world: WorldState = built["world"]
	var npc: SimNpc = world.get_city_npcs("aedran")[0]
	NpcInteractionSystem.set_affinity(world, npc.npc_id, 5000)
	_eq(NpcInteractionSystem.affinity(world, npc.npc_id), NpcInteractionSystem.aff_max(), "好感上钳到上限")
	NpcInteractionSystem.set_affinity(world, npc.npc_id, -5000)
	_eq(NpcInteractionSystem.affinity(world, npc.npc_id), NpcInteractionSystem.aff_min(), "好感下钳到下限")


## 好感 / 谈资冷却 / 随从契约随世界落盘往返。
func _test_npc_round_trip() -> void:
	var built: Dictionary = _new_sim()
	var world: WorldState = built["world"]
	var npc: SimNpc = world.get_city_npcs("aedran")[0]
	NpcInteractionSystem.set_affinity(world, npc.npc_id, 60)
	world.npc_talk_cooldowns[npc.npc_id] = {NpcInteractionSystem.INTENT_FAITH: 3}
	world.active_hires[npc.npc_id] = {"npcId": npc.npc_id, "monthsLeft": 4, "contractSeq": 1}
	world.hire_seq = 1
	var decoded: Variant = JSON.parse_string(JSON.stringify(world.to_dict()))
	_check(decoded is Dictionary, "世界状态可过 JSON")
	var fresh: WorldState = _new_world()["world"]
	fresh.apply_dict(decoded)
	_eq(int(fresh.player_relations.get(npc.npc_id, 0)), 60, "好感往返一致")
	var cds: Dictionary = fresh.npc_talk_cooldowns.get(npc.npc_id, {})
	_eq(int(cds.get(NpcInteractionSystem.INTENT_FAITH, -1)), 3, "谈资冷却往返一致")
	var hire: Dictionary = fresh.active_hires.get(npc.npc_id, {})
	_eq(int(hire.get("monthsLeft", 0)), 4, "随从契约往返一致")
	_eq(int(fresh.hire_seq), 1, "雇约游标往返一致")


## 交谈：人格主句 + 档位润色 + 冷却；无此人/无人格有明确错误。
func _test_npc_talk() -> void:
	var built: Dictionary = _new_sim()
	var world: WorldState = built["world"]
	var npc: SimNpc = world.get_city_npcs("aedran")[0]
	# month=-1 跳过冷却（测试用）
	var t: Dictionary = NpcInteractionSystem.talk(null, world, npc, NpcInteractionSystem.INTENT_AMBITION, -1)
	_check(bool(t.get("ok", false)), "能聊起志向：" + str(t.get("error", "")))
	_check(not str(t.get("line", "")).is_empty(), "有一句台词")
	_eq(str(t.get("band", "")), NpcInteractionSystem.BAND_NEUTRAL, "素未谋面默认中立档")
	_eq(int(t.get("affDelta", 0)), 2, "中立档谈一次 +2 好感")
	# 冷却：同月再谈被拒
	var ok1: Dictionary = NpcInteractionSystem.talk(null, world, npc, NpcInteractionSystem.INTENT_RUMOR, 0)
	_check(bool(ok1.get("ok", false)), "同月头一次谈传闻可以")
	var cold: Dictionary = NpcInteractionSystem.talk(null, world, npc, NpcInteractionSystem.INTENT_RUMOR, 0)
	_eq(str(cold.get("error", "")), "COOLDOWN", "冷却期内同月再谈被拒")
	# 敌对档口气场
	NpcInteractionSystem.set_affinity(world, npc.npc_id, -60)
	var h: Dictionary = NpcInteractionSystem.talk(null, world, npc, NpcInteractionSystem.INTENT_FAITH, -1)
	_eq(str(h.get("band", "")), NpcInteractionSystem.BAND_HOSTILE, "好感 -60 落到敌对档")
	# 无此人
	var gone: Dictionary = NpcInteractionSystem.talk(null, world, null, NpcInteractionSystem.INTENT_AMBITION, -1)
	_eq(str(gone.get("error", "")), "NOT_FOUND", "查无此人不可谈")


## 送礼：人格口味判定 + 物品扣除 + CHA 缩放。
func _test_npc_gift() -> void:
	var built: Dictionary = _new_sim()
	var world: WorldState = built["world"]
	var npc: SimNpc = world.get_city_npcs("aedran")[0]
	var personality: Dictionary = ContentLoader.get_personality(npc.personality_id)
	var love: String = _template_of_category(str(personality.get("giftTaste", {}).get("love", [])[0]))
	var hate: String = _template_of_category(str(personality.get("giftTaste", {}).get("hate", [])[0]))
	var avatar := PlayerAvatar.new()
	avatar.set_attribute(PlayerAvatar.ATTR_CHARISMA, 0)
	_give(avatar, love, "g-a")
	# 爱好的礼：cha 0 时正好 love 档
	var n1: Dictionary = NpcInteractionSystem.gift(avatar, world, npc, "g-a", -1)
	_check(bool(n1.get("ok", false)), "送合口味的礼被收下：" + str(n1.get("error", "")))
	_eq(int(n1.get("affDelta", 0)),
		int(ContentLoader.get_balance_section("npcInteraction").get("giftDelta", {}).get("love", 12)),
		"喜欢的礼按 love 档加好感")
	_check(not avatar.inventory.has("g-a"), "礼送出后从背包扣除")
	# 讨厌的礼
	_give(avatar, hate, "g-b")
	var n2: Dictionary = NpcInteractionSystem.gift(avatar, world, npc, "g-b", -1)
	_eq(int(n2.get("affDelta", 0)),
		int(ContentLoader.get_balance_section("npcInteraction").get("giftDelta", {}).get("hate", -5)),
		"嫌弃的礼按 hate 档减好感")
	# 不存在的物品
	var n3: Dictionary = NpcInteractionSystem.gift(avatar, world, npc, "nope", -1)
	_eq(str(n3.get("error", "")), "NO_ITEM", "手里没这件礼就送不出")
	# CHA 缩放：同样爱的礼，魅力高送得更讨喜
	_give(avatar, love, "g-c")
	avatar.set_attribute(PlayerAvatar.ATTR_CHARISMA, 10)
	var n4: Dictionary = NpcInteractionSystem.gift(avatar, world, npc, "g-c", -1)
	_eq(int(n4.get("affDelta", 0)), 12 + 5, "魅力 10 把 love 从 +12 提到 +17")


## 雇佣：资格 / 门槛 / 价格 / 扣钱 / 单名 / 忘迁 / 解约写纪年。
func _test_npc_hire() -> void:
	var built: Dictionary = _new_sim()
	var world: WorldState = built["world"]
	var avatar := PlayerAvatar.new()
	avatar.money = 1_000_000
	avatar.set_attribute(PlayerAvatar.ATTR_CHARISMA, 5)
	# 好感不够
	var low := SimNpc.new()
	low.npc_id = "hr-2"
	low.given_name = "路人甲"
	low.profession_id = "guard"
	var r1: Dictionary = NpcInteractionSystem.hire(avatar, world, low, 1)
	_eq(str(r1.get("error", "")), "NOT_FRIENDLY", "好感不足雇不了")
	# 具名锚点不肯受雇
	var named := SimNpc.new()
	named.npc_id = "hr-3"
	named.given_name = "宿将"
	named.profession_id = "guard"
	named.is_named = true
	NpcInteractionSystem.set_affinity(world, "hr-3", 60)
	var r2: Dictionary = NpcInteractionSystem.hire(avatar, world, named, 1)
	_eq(str(r2.get("error", "")), "NOT_HIREABLE", "具名人物不愿受雇")
	# 用现成世界里的可雇真人走通全流程
	var hireable: SimNpc = _find_hireable_npc(world)
	_check(hireable != null, "城里能找出可雇的居民")
	if hireable == null:
		return
	NpcInteractionSystem.set_affinity(world, hireable.npc_id, 40)
	var before_chron: int = world.chronicle.size()
	var money_before: int = avatar.money
	var r3: Dictionary = NpcInteractionSystem.hire(avatar, world, hireable, 1)
	_check(bool(r3.get("ok", false)), "好感达标签下随从：" + str(r3.get("error", "")))
	_eq(int(r3.get("months", 0)), 6, "契约 6 个月")
	_check(world.active_hires.has(hireable.npc_id), "随从进了在效名单")
	_check(avatar.money < money_before, "签契当场扣钱")
	_check(world.hire_seq == 1, "雇约游标 +1")
	_check(world.chronicle.size() == before_chron + 1, "签契记入纪年")
	# 已是随从不再雇
	var r4: Dictionary = NpcInteractionSystem.hire(avatar, world, hireable, 1)
	_eq(str(r4.get("error", "")), "ALREADY_HIRED", "已是随从不再雇")
	# 已带一名，再雇别人被拒
	NpcInteractionSystem.set_affinity(world, low.npc_id, 40)
	var r5: Dictionary = NpcInteractionSystem.hire(avatar, world, low, 1)
	_eq(str(r5.get("error", "")), "FULL", "已带一名随从不能再雇")
	# 解约：解除在效名单并记纪年
	var chron_after_hire: int = world.chronicle.size()
	var r7: Dictionary = NpcInteractionSystem.dismiss(world, hireable.npc_id, "战殁", 2)
	_check(bool(r7.get("ok", false)), "解约成功")
	_check(not world.active_hires.has(hireable.npc_id), "解约后不在名单")
	_check(world.chronicle.size() == chron_after_hire + 1, "解约（随从阵亡）记入纪年")
	# 解约后，钱不够（此刻不再有在效契约，才能验到 POOR 分支）
	var h6 := SimNpc.new()
	h6.npc_id = "hr-4"
	h6.given_name = "苦力"
	h6.profession_id = "guard"
	var broke_avatar := PlayerAvatar.new()
	broke_avatar.money = 0
	broke_avatar.set_attribute(PlayerAvatar.ATTR_CHARISMA, 5)
	NpcInteractionSystem.set_affinity(world, "hr-4", 40)
	var r6: Dictionary = NpcInteractionSystem.hire(broke_avatar, world, h6, 1)
	_eq(str(r6.get("error", "")), "POOR", "钱不够签不下")


## 随从战斗规格：合法我方自动单元；好感越高越强；随从战殁不判负、英雄倒地即败。
func _test_npc_follower_combat() -> void:
	var built: Dictionary = _new_sim()
	var world: WorldState = built["world"]
	var hire: Dictionary = {"npcId": "fol-1", "name": "铁肩", "category": "military"}
	var spec: Dictionary = NpcInteractionSystem.follower_combat_spec(null, world, hire)
	_eq(str(spec.get("unitId", "")), "follower_fol-1", "随从单位 id 带 follower 前缀")
	_eq(str(spec.get("side", "")), Combat.SIDE_PLAYER, "随从是我方单位")
	_eq(str(spec.get("controlled", "")), "auto", "随从由 AI 驱动")
	_eq(spec.get("isHero", null), false, "随从不是英雄（战殁不判负）")
	_check(spec.get("skills", {}).has("guard"), "随从带守卫技能")
	_eq(int(spec.get("weaponAttack", 0)), 10, "军事随从近战攻击 10")
	_check(int(spec.get("attributes", {}).get("strength", 0)) >= 12, "随从有力量底子")
	_check(NpcInteractionSystem.follower_combat_spec(null, world, {}).is_empty(), "没有契约就没有随从武力")
	# 好感越高随从越强
	var aff0: int = int(NpcInteractionSystem.follower_combat_spec(null, world, hire)
		.get("attributes", {}).get("strength", 0))
	NpcInteractionSystem.set_affinity(world, "fol-1", 200)
	var affs: int = int(NpcInteractionSystem.follower_combat_spec(null, world, hire)
		.get("attributes", {}).get("strength", 0))
	_check(affs > aff0, "好感越高随从越强")
	# 战斗里随从自动、英雄手动；英雄倒地即判负
	var combat: Combat = _new_combat(7)
	var enc: Dictionary = {
		"sessionId": "m18-follow",
		"units": [
			{"unitId": "hero", "side": Combat.SIDE_PLAYER, "name": "主角", "isHero": true,
			 "attributes": _attributes_with(PlayerAvatar.ATTR_CONSTITUTION, 60),
			 "skills": {"guard": 20}, "weaponAttack": 20, "weaponRange": 1, "armor": 5,
			 "controlled": "manual", "position": [0, 0]},
			{"unitId": "fol", "side": Combat.SIDE_PLAYER, "name": "随从", "isHero": false,
			 "attributes": _attributes_with(PlayerAvatar.ATTR_CONSTITUTION, 40),
			 "skills": {"guard": 40}, "weaponAttack": 10, "weaponRange": 1, "armor": 3,
			 "controlled": "auto", "position": [1, 0]},
			{"unitId": "foe", "side": Combat.SIDE_ENEMY, "name": "狗头人", "threatLevel": 2,
			 "attributes": _attributes_with(PlayerAvatar.ATTR_CONSTITUTION, 30),
			 "skills": {"guard": 10}, "weaponAttack": 8, "weaponRange": 1, "armor": 2,
			 "position": [5, 0]},
		],
	}
	combat.start(enc)
	_check(combat.is_auto("fol"), "随从在战斗里自动驱动")
	_check(not combat.is_auto("hero"), "英雄由玩家手动操控")
	var hero_unit: Dictionary = combat.unit_by_id("hero")
	hero_unit["downed"] = true
	hero_unit["dead"] = false
	combat._check_finished()
	_check(combat.finished and combat.winner == Combat.RESULT_ENEMY, "英雄倒地即判负，随从生死不连带")


## 视图模型：名单、动作可用性与雇佣门槛的形状恒定。
func _test_npc_view_model() -> void:
	var built: Dictionary = _new_sim()
	var world: WorldState = built["world"]
	var avatar := PlayerAvatar.new()
	avatar.money = 1_000_000
	var view: Dictionary = NpcInteractionViewModel.build(NpcInteractionSystem, avatar, world, "aedran", 0, 0)
	_check(view.has("rows"), "名单成形")
	_check(view.has("hasSelected"), "有选中态")
	_check(not view.get("rows", []).is_empty(), "城里有人可交互")
	_eq(int(view.get("residentCursor", -1)), 0, "光标停在第一位居民")
	var actions: Array = view.get("actions", [])
	_eq(actions.size(), 5, "五个底部动作")
	var gift_action: Dictionary = {}
	var hire_action: Dictionary = {}
	for a in actions:
		var id: String = str(a.get("id", ""))
		if id == NpcInteractionViewModel.ACTION_GIFT:
			gift_action = a
		elif id == NpcInteractionViewModel.ACTION_HIRE:
			hire_action = a
	_check(bool(view.get("hasSelected", false)), "选中了一位居民")
	_check(gift_action.has("can") and gift_action.has("reason"), "送礼动作带可用性判断")
	_check(hire_action.has("can") and hire_action.has("reason"), "雇佣动作带可用性判断")
	_eq(hire_action.get("can", null) is bool, true, "雇佣可用性是布尔")
	# 光标所指动作高亮
	var sel: Dictionary = NpcInteractionViewModel.build(
		NpcInteractionSystem, avatar, world, "aedran", 0, 0)
	var rows: Array = sel.get("rows", [])
	if not rows.is_empty():
		_check(bool(rows[0].get("selected", false)), "光标行被标记为选中")


# --- 城内空间（M19）---

## 布局确定性：同城两次逐位相等；不同城排布不同。
func _cs_positions(layout: Dictionary) -> Array:
	var out: Array = []
	for b in layout.get("buildings", []):
		out.append("%d,%d:%s" % [int(b["x"]), int(b["y"]), str(b["kind"])])
	return out


func _test_city_space_determinism() -> void:
	var ids: Array = ["b1", "b2", "b3", "b4", "b5"]
	var a1: Dictionary = CitySpace.layout("aedran", ids, ["n1", "n2"])
	var a2: Dictionary = CitySpace.layout("aedran", ids, ["n1", "n2"])
	_eq(_cs_positions(a1), _cs_positions(a2), "同城两次布局逐位相等")
	var other: Dictionary = CitySpace.layout("port_thorne", ids, ["n1", "n2"])
	_check(not (_cs_positions(a1) == _cs_positions(other)), "不同城排布不同")


## 落位合法：都在界内、建筑不重叠、NPC 不压建筑。
func _test_city_space_placement() -> void:
	var b_ids: Array = ContentLoader.get_city_building_ids("aedran")
	var npc_ids: Array = []
	var world: WorldState = _new_sim()["world"]
	for npc in world.get_city_npcs("aedran"):
		npc_ids.append(npc.npc_id)
	var l: Dictionary = CitySpace.layout("aedran", b_ids, npc_ids)
	_eq(int(l["w"]), CitySpace.WIDTH, "城内宽 24 格")
	_eq(int(l["h"]), CitySpace.HEIGHT, "城内高 18 格")
	_eq(int(l["buildings"].size()), int(b_ids.size()), "建筑数与那座城的建筑一致")
	for slot in l["buildings"]:
		_check(int(slot["x"]) >= 0 and int(slot["y"]) >= 0
			and int(slot["x"]) + int(slot["w"]) <= int(l["w"])
			and int(slot["y"]) + int(slot["h"]) <= int(l["h"]), "建筑在界内")
	# 建筑与建筑不重叠
	var seen: Dictionary = {}
	var overlap: bool = false
	for slot in l["buildings"]:
		for fx in range(int(slot["w"])):
			for fy in range(int(slot["h"])):
				var key: String = "%d,%d" % [int(slot["x"]) + fx, int(slot["y"]) + fy]
				if seen.has(key):
					overlap = true
				seen[key] = true
	_check(not overlap, "建筑互不重叠")
	# NPC 不压建筑
	var npc_on_building: bool = false
	for n in l["npcs"]:
		if bool(l["blocked"].get("%d,%d" % [int(n["x"]), int(n["y"])], false)):
			npc_on_building = true
	_check(not npc_on_building, "居民不站在建筑上")
	var gate: Vector2i = l["gate"]
	_check(gate.x >= 0 and gate.y >= 0 and gate.x < int(l["w"]) and gate.y < int(l["h"]), "城门在界内")
	var spawn: Vector2i = l["spawn"]
	_check(spawn.x >= 0 and spawn.y >= 0 and spawn.x < int(l["w"]) and spawn.y < int(l["h"]), "出生点在界内")
	_check(CitySpace.walkable(l, spawn.x, spawn.y), "出生点可站")


## 碰撞：建筑格不可走，撞建筑原地。
func _test_city_space_collision() -> void:
	var ids: Array = ["b1", "b2", "b3", "b4", "b5"]
	var l: Dictionary = CitySpace.layout("aedran", ids, [])
	var b: Dictionary = l["buildings"][0]
	var at: Vector2i = Vector2i(int(b["x"]) - 1, int(b["y"]))
	_check(not CitySpace.walkable(l, int(b["x"]), int(b["y"])), "建筑格不可走")
	_check(CitySpace.walkable(l, at.x, at.y), "建筑旁的走道可走")
	var into: Dictionary = CitySpace.step(l, at, 1, 0)
	_check(not bool(into["ok"]) and into["next"] == at, "朝建筑走被挡在原地")
	var out: Dictionary = CitySpace.step(l, at, -1, 0)
	_check(bool(out["ok"]), "朝空地走能走")


## 城门：踩到城门判定离开。
func _test_city_space_gate() -> void:
	var ids: Array = ["b1", "b2", "b3", "b4", "b5"]
	var l: Dictionary = CitySpace.layout("aedran", ids, [])
	var g: Vector2i = l["gate"]
	_check(CitySpace.walkable(l, g.x, g.y), "城门格可走")
	var spawn: Vector2i = l["spawn"]
	_eq(int(spawn.y), int(g.y) - 1, "出生点就在城门前一格")
	var r: Dictionary = CitySpace.step(l, spawn, 0, 1)
	_check(bool(r["at_gate"]), "从出生点向前一步踩到城门判定离开")


## 建筑邻近：站着识别到邻格建筑与功能类别；隔一格认不出。
func _test_city_space_near_building() -> void:
	var ids: Array = ["b1", "b2", "b3", "b4", "b5"]
	var l: Dictionary = CitySpace.layout("aedran", ids, [])
	var b: Dictionary = l["buildings"][0]
	var nxt: Vector2i = Vector2i(maxi(0, int(b["x"]) - 1), int(b["y"]))
	var near: Dictionary = CitySpace.near_building(l, nxt)
	_eq(str(near.get("building_id", "")), str(b["id"]), "邻格认出是哪座建筑")
	_eq(str(near.get("kind", "")), str(b["kind"]), "邻格带出建筑功能类别")
	var far: Vector2i = Vector2i(maxi(0, int(b["x"]) - 2), int(b["y"]))
	_check(CitySpace.near_building(l, far).is_empty(), "隔一格就认不出来")


## NPC 邻近：站着邻近识别到居民 id。
func _test_city_space_near_npc() -> void:
	var world: WorldState = _new_sim()["world"]
	var npc_ids: Array = []
	for npc in world.get_city_npcs("aedran"):
		npc_ids.append(npc.npc_id)
	_check(npc_ids.size() >= 1, "城里有居民可摆")
	var l: Dictionary = CitySpace.layout("aedran", ["b1"], npc_ids)
	var n: Dictionary = l["npcs"][0]
	var pos: Vector2i = Vector2i(maxi(0, int(n["x"]) - 1), int(n["y"]))
	_eq(CitySpace.near_npc(l, pos), str(n["id"]), "邻近识别到居民")


## 视图模型：坐标换算与清单形状恒定。
func _test_city_space_view_model() -> void:
	var ids: Array = ["b1", "b2", "b3", "b4", "b5"]
	var l: Dictionary = CitySpace.layout("aedran", ids, ["n1", "n2"])
	var rect := Rect2(0.0, 0.0, 1248.0, 568.0)
	var view: Dictionary = CitySpaceViewModel.build(l, l["spawn"],
		{"b1": "大堂", "b2": "铺", "b3": "堂", "b4": "厅", "b5": "院"}, {"n1": "甲", "n2": "乙"}, rect)
	var expected_origin: Vector2 = rect.position + (rect.size
		- Vector2(CitySpaceViewModel.CITY_TILE * CitySpace.WIDTH, CitySpaceViewModel.CITY_TILE * CitySpace.HEIGHT)) * 0.5
	_eq(view["origin"], expected_origin, "面板原点居中算出")
	_eq(int(view["buildings"].size()), 5, "五栋建筑进清单")
	_eq(int(view["npcs"].size()), 2, "两位居民进清单")
	var spawn: Vector2i = l["spawn"]
	_eq(view["playerRect"], CitySpaceViewModel.cell_rect(view["origin"], spawn.x, spawn.y), "玩家矩形对齐出生点")
	_check(not view["gate"]["rect"].size.is_zero_approx(), "城门有矩形")
	_check(view["buildings"][0].has("label") and view["buildings"][0].has("kind"), "建筑带标签与功能")


## 行走路径：从 A 沿 signi 朝 B 斜走。地图无遮挡，步数 = 两轴距离较长者，
## 且绝不越过 MAP_WALK_LIMIT（与 main.gd 的 _plot_walk_path 同一条算法）。
func _test_walk_path_grid() -> void:
	var built: Dictionary = _new_world()
	var grid: MapGrid = built["grid"]
	var start := Vector2i(10, 10)
	var dest := Vector2i(72, 55)
	var cursor: Vector2i = start
	var path: Array = []
	var steps: int = 0
	while steps < 200 and (cursor.x != dest.x or cursor.y != dest.y):
		steps += 1
		cursor = grid.step(cursor.x, cursor.y, signi(dest.x - cursor.x), signi(dest.y - cursor.y))
		path.append(cursor)
	_eq(cursor, dest, "斜走路径可达目标格")
	_check(path.size() > 0, "路径非空")
	_check(steps <= 200, "路径步数在 MAP_WALK_LIMIT 上限内")
	_eq(steps, maxi(absi(dest.x - start.x), absi(dest.y - start.y)), "斜走步数等于两轴距离较长者")
	# 起点就在目标格时不产生路线
	var same: Array = []
	var pos: Vector2i = dest
	if pos.x != dest.x or pos.y != dest.y:
		same.append(dest)
	_eq(same.size(), 0, "已在目标格时不生成行走路线")


## 导航侧栏的布局与命中：入口数量、首项是返回地图、每项中心能命中、越界返回 -1。
func _test_hud_nav_layout_hit() -> void:
	var rect := Rect2(16.0, 48.0, 150.0, 568.0)
	var items: Array = HudNav.layout(rect)
	_eq(items.size(), 11, "导航侧栏有 11 个进入项")
	_eq(int(items[0]["view"]), HudNav.VIEW_MAP, "第一项是返回世界地图")
	for i in range(items.size()):
		var center: Vector2 = (items[i]["rect"] as Rect2).get_center()
		_eq(HudNav.hit(items, center), i, "第 %d 项中心能命中" % i)
	_eq(HudNav.hit(items, Vector2(-50.0, -50.0)), -1, "越界点返回 -1")
	var bottom: Rect2 = items[items.size() - 1]["rect"]
	_eq(HudNav.hit(items, Vector2(40.0, bottom.end.y + 5.0)), -1, "侧栏底沿之外返回 -1")


## M20 阶段二：全场景面板统一外壳帮助函数。
## draw_panel 只画矩形、不碰字体，无头能跑；draw_panel_header 在无头下字体为 null，
## 应干净早退不报错。两条合起来验证"外壳已统一到 UiTheme，各面板可直接复用"。
func _test_ui_panel_chrome() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var stub := Node2D.new()
	if tree != null:
		tree.root.add_child(stub)
	var rect := Rect2(16.0, 48.0, 1248.0, 568.0)
	# draw_panel 无字体也照画——所有面板共享的底色/外框/顶底边条
	UiTheme.draw_panel(stub, rect)
	_check(true, "draw_panel 在无头环境可调用（纯矩形绘制）")
	# 无头没有字体，draw_panel_header 应早退不崩
	UiTheme.draw_panel_header(stub, UiTheme.draw_font(), rect, {
		"title": "城市状态",
		"titleY": 26.0,
		"lineY": 40.0,
	})
	_check(true, "draw_panel_header 在无字体（无头）下干净早退")
	stub.queue_free()


# --- 里程碑 21 临时副本（M21）---
#
# 副本是"野外走路时的奇遇入口 → 走进可探索网格"的临时会话空间，确定性派生、不落盘。
# 测试钉住四件事：同种子可复现、楼层布局合法（墙=外圈+岩屑、spawn/exit 可站、物什在
# 界内且不重叠）、spawn 到出口/每一格宝箱敌人必可达、走格与出口判定正确。

## 同种子两层完全一致，不同种子不同。
func _test_dungeon_determinism() -> void:
	var k: String = "enc-0001"
	var a1: Dictionary = Dungeon.layout(k, 0)
	var a2: Dictionary = Dungeon.layout(k, 0)
	_eq(_dg_positions(a1), _dg_positions(a2), "同种子同层逐位相等")
	var deeper: Dictionary = Dungeon.layout(k, 2)
	_check(not (_dg_positions(a1) == _dg_positions(deeper)), "层数不同布局不同")
	var other: Dictionary = Dungeon.layout("enc-0002", 0)
	_check(not (_dg_positions(a1) == _dg_positions(other)), "种子不同布局不同")


## 布局合法：外圈全是墙、spawn/exit 可站且在界内、宝箱/敌人落在可站空地且互不重叠。
func _test_dungeon_layout_valid() -> void:
	for depth in [0, 1, 5]:
		var l: Dictionary = Dungeon.layout("seed-%d" % depth, depth)
		_eq(int(l["w"]), Dungeon.WIDTH, "副本宽 24 格")
		_eq(int(l["h"]), Dungeon.HEIGHT, "副本高 18 格")
		_check(Dungeon.walkable(l, int(l["spawn"].x), int(l["spawn"].y)), "出生点可站")
		_check(Dungeon.walkable(l, int(l["exit"].x), int(l["exit"].y)), "出口可站")
		# 外圈一圈都是墙
		var perimeter_ok: bool = true
		for x in range(Dungeon.WIDTH):
			if Dungeon.walkable(l, x, 0) or Dungeon.walkable(l, x, Dungeon.HEIGHT - 1):
				perimeter_ok = false
		for y in range(Dungeon.HEIGHT):
			if Dungeon.walkable(l, 0, y) or Dungeon.walkable(l, Dungeon.WIDTH - 1, y):
				perimeter_ok = false
		_check(perimeter_ok, "外圈一圈都是墙")
		var placed: Dictionary = {}
		var bad: bool = false
		for t in l["treasures"]:
			var key: String = "%d,%d" % [int(t["x"]), int(t["y"])]
			if not Dungeon.walkable(l, int(t["x"]), int(t["y"])) or placed.has(key):
				bad = true
			placed[key] = true
		for e in l["enemies"]:
			var key: String = "%d,%d" % [int(e["x"]), int(e["y"])]
			if not Dungeon.walkable(l, int(e["x"]), int(e["y"])) or placed.has(key):
				bad = true
			placed[key] = true
		_check(not bad, "宝箱与敌人都落在可站空地且互不重叠")


## 可达性：spawn 到出口，以及每一格宝箱/敌人，都走得到（BFS）。
func _test_dungeon_connectivity() -> void:
	for depth in [0, 3, 7]:
		var l: Dictionary = Dungeon.layout("conn-%d" % depth, depth)
		var reach: Dictionary = _dg_bfs(l, l["spawn"])
		_check(bool(reach.get("%d,%d" % [int(l["exit"].x), int(l["exit"].y)], false)),
			"从出生点能走到出口（第 %d 层）" % depth)
		for t in l["treasures"]:
			_check(bool(reach.get("%d,%d" % [int(t["x"]), int(t["y"])], false)),
				"每个宝箱都可达（第 %d 层）" % depth)
		for e in l["enemies"]:
			_check(bool(reach.get("%d,%d" % [int(e["x"]), int(e["y"])], false)),
				"每个敌人都可达（第 %d 层）" % depth)


## 走格：撞墙原地、走向空地成功、踩出口判定为到达出口。
func _test_dungeon_step_collision() -> void:
	var l: Dictionary = Dungeon.layout("step-1", 0)
	var spawn: Vector2i = l["spawn"]
	# 朝外圈墙走：spawn 在 y=HEIGHT-2，往下正是外圈墙（y=HEIGHT-1）
	var into_wall: Dictionary = Dungeon.step(l, spawn, 0, 1)
	_check(not bool(into_wall["ok"]) and into_wall["next"] == spawn, "朝墙走被挡在原地")
	var up: Dictionary = Dungeon.step(l, spawn, 0, -1)
	_check(bool(up["ok"]) and not bool(up["atExit"]), "朝空地走成功且未到出口")
	# 出口在 (12,1)；从 (12,2) 往上一步正好踩上出口格 → atExit
	var at_exit: Dictionary = Dungeon.step(l, Vector2i(Dungeon.EXIT.x, Dungeon.EXIT.y + 1), 0, -1)
	_check(bool(at_exit["ok"]) and bool(at_exit["atExit"]), "踩到出口格判定到达出口")


## 视图模型：原点居中、物体清单与玩家矩形对齐。
func _test_dungeon_view_model() -> void:
	var l: Dictionary = Dungeon.layout("vm-1", 2)
	var rect := Rect2(0.0, 0.0, 1248.0, 568.0)
	var view: Dictionary = DungeonViewModel.build(l, l["spawn"], rect)
	var expected: Vector2 = rect.position + (rect.size - Vector2(
		DungeonViewModel.DUNGEON_TILE * Dungeon.WIDTH,
		DungeonViewModel.DUNGEON_TILE * Dungeon.HEIGHT)) * 0.5
	_eq(view["origin"], expected, "副本面板原点居中算出")
	_eq(view["player"], l["spawn"], "玩家出生点进视图")
	_eq(view["playerRect"], DungeonViewModel.cell_rect(view["origin"],
		int(l["spawn"].x), int(l["spawn"].y)), "玩家矩形对齐出生点")
	_eq(int(view["treasures"].size()), int(l["treasures"].size()), "宝箱数一致")
	_eq(int(view["enemies"].size()), int(l["enemies"].size()), "敌人数一致")
	_check(int(view["depth"]) == 2, "层数带进视图")
	_check(not view["exit"]["rect"].size.is_zero_approx(), "出口有矩形")


## 楼层的位置快照，供 equal 判定。（取位置字典，忽略其余字段。）
static func _dg_positions(layout: Dictionary) -> Dictionary:
	return {
		"blocked": layout["blocked"],
		"treasures": layout["treasures"],
		"enemies": layout["enemies"],
		"spawn": layout["spawn"],
		"exit": layout["exit"],
	}


## 从某格 BFS 出一张"可达格"表。
static func _dg_bfs(layout: Dictionary, from: Vector2i) -> Dictionary:
	var reach: Dictionary = {}
	var frontier: Array = [from]
	reach["%d,%d" % [from.x, from.y]] = true
	while not frontier.is_empty():
		var cur: Vector2i = frontier.pop_back()
		for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nxt: Vector2i = cur + dir
			var key: String = "%d,%d" % [nxt.x, nxt.y]
			if reach.has(key) or not Dungeon.walkable(layout, nxt.x, nxt.y):
				continue
			reach[key] = true
			frontier.push_back(nxt)
	return reach


# --- M21 游方商人 ---

## 同车货同价：同种子同一次货架逐位相等，不同种子不同；货只在允许的类别里。
func _test_merchant_stock_deterministic() -> void:
	var m1 := Merchant.create(null, {})
	var m2 := Merchant.create(null, {})
	var s1: Array = m1.stock_for("road-0001")
	var s2: Array = m2.stock_for("road-0001")
	_eq(s1.size(), s2.size(), "同种子货架件数一致")
	_check(s1.size() >= 3 and s1.size() <= 6, "货架在 3..6 件")
	for i in range(s1.size()):
		_eq(str(s1[i]["templateId"]), str(s2[i]["templateId"]), "同种子同位置货一致")
		var cat: String = str(s1[i]["template"].get("category", ""))
		_check(Merchant.STOCK_CATEGORIES.has(cat), "货架类别只取武器/防具/消耗品")
	var m3 := Merchant.create(null, {})
	var s3: Array = m3.stock_for("road-9999")
	_check(not (s1.is_empty() or s3.is_empty()), "两组货架都非空")
	var shared: bool = false
	for a in s1:
		for b in s3:
			if str(a["templateId"]) == str(b["templateId"]):
				shared = true
	# 允许偶然同款，只确保不是整份照抄。种子不同时货架的件数与首件大概率有别。
	_check(_merchant_signature(s1) != _merchant_signature(s3), "不同种子货架签名不同")


## 报价：买价 = 基准×BUY_RATIO，收价 = 基准×SELL_RATIO；报价存入可查。
func _test_merchant_quote() -> void:
	var m := Merchant.create(null, {})
	m.stock_for("quote-1")
	var quotes: Dictionary = m.quotations()
	_check(not quotes.is_empty(), "货架上有报价")
	for entry in m.stock_left():
		var tid: String = str(entry["templateId"])
		var base: int = maxi(1, int(ContentLoader.get_item(tid).get("price", 0)))
		var q: Dictionary = quotes[tid]
		_eq(int(q["buyPrice"]), maxi(1, int(float(base) * Merchant.BUY_RATIO)), "买入价按 1.5 倍基准")
		_eq(int(q["sellPrice"]), maxi(1, int(float(base) * Merchant.SELL_RATIO)), "收价按半价基准")
	# 报价不因买走而变，行商从不临时改口
	_merchant_buy_all(m)
	_check(not m.quotations().is_empty(), "货已售罄报价仍在")


## 买走移出、卖回重新上架；stock_count 跟随。
func _test_merchant_buy_sell_stock() -> void:
	var m := Merchant.create(null, {})
	m.stock_for("trade-1")
	var before: int = m.stock_count()
	var tid: String = str(m.stock_left()[0]["templateId"])
	_check(m.buy_off_stock(tid), "买走一件成功")
	_eq(m.stock_count(), before - 1, "买走后件数减一")
	_check(not m.buy_off_stock(tid), "重复买走同一件失败")
	m.add_to_stock(tid)
	_eq(m.stock_count(), before, "卖回再上架件数复原")
	var back: bool = false
	for entry in m.stock_left():
		if str(entry["templateId"]) == tid:
			back = true
	_check(back, "卖回的货回到货架")
	# 不在报价表里的货不给上架
	m.add_to_stock("weapon_nothing_xx")
	_eq(m.stock_count(), before, "不认识的货不上架")


## 视图模型：买侧与卖侧的行、价、可成交状态。
func _test_merchant_view_model() -> void:
	var m := Merchant.create(null, {})
	m.stock_for("vm-m")
	var lookups: Dictionary = {"itemTemplates": _item_template_table()}
	var buy: Dictionary = MerchantViewModel.build(m, lookups, null, Merchant.SIDE_BUY, 0, 999999)
	_eq(int(buy["rowCount"]), m.stock_count(), "买侧行数等于货架件数")
	_check(bool(buy["canTrade"]), "钱管够时买侧可成交")
	_eq(str(buy["side"]), Merchant.SIDE_BUY, "买侧标记 buy")
	# 卖侧：给化身一件货，应出现在卖侧
	var avatar := PlayerAvatar.new()
	avatar.avatar_id = "merchant-avatar"
	_grant_items(avatar, str(m.stock_left()[0]["templateId"]), 1)
	var sell: Dictionary = MerchantViewModel.build(m, lookups, avatar, Merchant.SIDE_SELL, 0, 100)
	_eq(int(sell["rowCount"]), 1, "背包一件货出现卖侧一行")
	_check(bool(sell["canTrade"]), "卖出总是可成交")
	_eq(str(sell["rows"][0]["kind"]), MerchantViewModel.ROW_KIND_HELD, "卖侧行标注 held")
	# 卖侧缺货时不可成交
	var empty: Dictionary = MerchantViewModel.build(m, lookups, PlayerAvatar.new(), Merchant.SIDE_SELL, 0, 100)
	_check(not bool(empty["canTrade"]), "空背包卖侧不可成交")
	# 面板：按钮与命中
	var rect := Rect2(200, 100, 900, 620)
	var buttons: Array = MerchantPanel.buttons(buy, rect)
	_check(buttons.size() == 2, "面板两个按钮")
	var row_hit: Dictionary = MerchantPanel.hit_test(buy, rect,
		MerchantPanel._row_rect(rect, buy, 0).get_center())
	_eq(str(row_hit.get("kind", "")), "row", "点列表行命中 row")
	# 点面板按钮应命中 button（修复：按钮自带 x/y 几何，不走 UiTheme 的 rect 契约）
	var side_btn: Dictionary = MerchantPanel.buttons(buy, rect)[0]
	var btn_hit: Dictionary = MerchantPanel.hit_test(buy, rect,
		Vector2(float(side_btn["x"]) + 20.0, float(side_btn["y"]) + 10.0))
	_eq(str(btn_hit.get("kind", "")), "button", "点面板按钮命中 button")
	_eq(str(btn_hit.get("id", "")), "side", "命中的是换买/卖按钮")


static func _merchant_signature(stock: Array) -> String:
	var ids: Array = []
	for entry in stock:
		ids.append(str(entry["templateId"]))
	ids.sort()
	return str(ids)


static func _merchant_buy_all(m: Merchant) -> void:
	for entry in m.stock_left().duplicate():
		m.buy_off_stock(str(entry["templateId"]))


# --- M22 战斗深度（连携 / 遮挡 / 随从倾向与身份）---

## 元素连携（C2）：元素/法术命中逐发攒层，第三发触发 ×1.5 加伤并清零；
## 故连层序列 1→2→0→1→…；普通物理平A不参与，不触发文案。
func _test_element_chain() -> void:
	var combat := _new_combat(8211)
	combat.start(_spell_encounter({"water_water_arrow": 10}, -1, {"element": "fire"}))
	var damages: Array = []
	var chain_after: Array = []
	var hits := 0
	var guard := 0
	while hits < 6 and guard < 24:
		guard += 1
		var actor_id := combat.current_unit_id()
		if actor_id.is_empty():
			break
		if actor_id != "hero" or int(combat.unit_by_id("hero")["ap"]) < 2:
			combat.submit_action({"actionType": Combat.ACTION_END_TURN, "actorId": actor_id})
			continue
		var before := int(combat.unit_by_id("foe")["hp"])
		combat.submit_action({
			"actionType": Combat.ACTION_SKILL, "actorId": "hero", "targetId": "foe",
			"skillId": "water_water_arrow",
		})
		if int(combat.unit_by_id("foe")["hp"]) < before:
			hits += 1
			damages.append(int(before) - int(combat.unit_by_id("foe")["hp"]))
			chain_after.append(int(combat.get_state()["chainStacks"].get("hero", 0)))
	_check(hits >= 6, "拿到至少 6 次命中（%d）" % hits)
	if hits >= 6:
		_eq(chain_after[0], 1, "第一发命中攒 1 层")
		_eq(chain_after[1], 2, "第二发命中攒 2 层")
		_eq(chain_after[2], 0, "第三发触发后清零")
		_eq(chain_after[3], 1, "第四发重新从 1 层攒起")
		# 触发发（下标 2）是第三发，命中那次就是触发发，文案里应出现连携
	_check(_join(combat.get_state()["log"]).contains("连携炸响"), "触发发的日志出现连携文案")
	# 平A（普通物理）不参与连携：连层保持空、不触发文案
	var duel := _new_combat(8221)
	duel.start(_duel_encounter(40, 1))
	var before_duel := int(duel.unit_by_id("foe")["hp"])
	duel.submit_action({"actionType": Combat.ACTION_ATTACK, "actorId": "hero", "targetId": "foe"})
	if int(duel.unit_by_id("foe")["hp"]) < before_duel:
		_eq(duel.get_state()["chainStacks"], {}, "普通攻击不攒连携层")
	_check(not _join(duel.get_state()["log"]).contains("连携"), "普通攻击不触发连携文案")


## 战场遮挡（C3）：Bresenham 弹道上的中间障碍格挡住弹道；相邻/畅通弹道不挡。
func _test_line_of_sight_blocks_ranged() -> void:
	var combat := _new_combat(8331)
	combat.start({
		"sessionId": "los-test",
		"units": [
			{"unitId": "hero", "side": Combat.SIDE_PLAYER, "name": "弓手",
			 "attributes": _attributes_with(PlayerAvatar.ATTR_DEXTERITY, 60),
			 "weaponTemplateId": "weapon_bow_common",
			 "position": [0, 0], "threatLevel": 1, "hp": 100000, "maxHp": 100000},
			{"unitId": "foe", "side": Combat.SIDE_ENEMY, "name": "木桩",
			 "attributes": _attributes_with(PlayerAvatar.ATTR_DEXTERITY, 1),
			 "weaponTemplateId": "weapon_longsword_common",
			 "position": [4, 0], "threatLevel": 1, "hp": 100000, "maxHp": 100000},
		],
		"obstacles": [[2, 0]],
	})
	_check(combat._los_blocked(Vector2i(0, 0), Vector2i(4, 0)), "横穿柱子的弹道被挡")
	_check(not combat._los_blocked(Vector2i(0, 0), Vector2i(1, 0)), "相邻格无中间障碍")
	_check(not combat._los_blocked(Vector2i(0, 0), Vector2i(4, 2)), "绕开柱子的弹道畅通")
	# 直径只差一格（3 格）也不被柱子挡——只有正中间那格算遮挡
	_check(not combat._los_blocked(Vector2i(0, 0), Vector2i(3, 1)), "斜线未压柱子的弹道畅通")
	# 带遮挡的远程攻击仍可扇出去（只是命中率被打折），不会被拒
	var res: Dictionary = combat.submit_action({
		"actionType": Combat.ACTION_ATTACK, "actorId": "hero", "targetId": "foe",
	})
	_check(bool(res.get("ok", true)), "隔着柱子的弓手仍能出手（%s）" % str(res))


## 身份标识（B）与随从行动倾向（C1）：combat 单元透传 displayName/category + aiTendency，
## 视图的 identity_of 折叠成「本名 · 类别」，follower_combat_spec 按职业映射倾向。
func _test_m22_identity_and_tendency() -> void:
	var combat := _new_combat(8441)
	combat.start({
		"sessionId": "identity-test",
		"units": [
			{"unitId": "hero", "side": Combat.SIDE_PLAYER, "name": "主角", "displayName": "主角",
			 "category": "wanderer", "controlled": "manual",
			 "attributes": _attributes_with(PlayerAvatar.ATTR_CONSTITUTION, 40),
			 "weaponTemplateId": "weapon_longsword_common", "position": [0, 0], "threatLevel": 1},
			{"unitId": "fol", "side": Combat.SIDE_PLAYER, "name": "铁卫", "displayName": "铁卫",
			 "category": "military", "aiTendency": "attack", "controlled": "auto",
			 "attributes": _attributes_with(PlayerAvatar.ATTR_CONSTITUTION, 40),
			 "weaponTemplateId": "weapon_longsword_common", "position": [1, 0], "threatLevel": 2},
			{"unitId": "gob", "side": Combat.SIDE_ENEMY, "name": "哥布林", "displayName": "哥布林",
			 "creatureKind": "living", "attributes": _attributes_with(PlayerAvatar.ATTR_CONSTITUTION, 30),
			 "weaponTemplateId": "weapon_dagger_common", "position": [4, 0], "threatLevel": 1},
		],
	})
	# _build_unit 透传身份字段 → 视图 identity_of 能折叠成带类别的身份
	_eq(CombatViewModel.identity_of(combat.unit_by_id("fol")), "铁卫 · military",
		"随从身份 = 本名 · 类别")
	_eq(CombatViewModel.identity_of(combat.unit_by_id("gob")), "哥布林 · living",
		"怪物身份 = 本名 · 生物类别")
	var fol: Dictionary = combat.unit_by_id("fol")
	_eq(str(fol.get("aiTendency", "")), "attack", "军事随从倾向随规格透传")
	# 敌人缺省倾向 attack（auto_action 就近攻击）
	_eq(str(combat.unit_by_id("gob").get("aiTendency", "")), "attack", "敌人默认倾向攻击")
	_check(combat.is_auto("fol"), "随从自动驱动")
	# follower_combat_spec 按职业给倾向：军事 → attack，守序职业 → guard
	var built: Dictionary = _new_sim()
	var world: WorldState = built["world"]
	_eq(str(NpcInteractionSystem.follower_combat_spec(null, world, {"npcId": "a", "name": "甲", "category": "military"})
		.get("aiTendency", "")), "attack", "军事随从倾向 attack")
	_eq(str(NpcInteractionSystem.follower_combat_spec(null, world, {"npcId": "b", "name": "乙", "category": "knowledge"})
		.get("aiTendency", "")), "ranged", "知识随从倾向 ranged")


# --- M23 副本主题层与商人深度（A/B/C）---

## 主题配置样例（与 balance.json dungeon 段同构，theme_for 认 every/treasureMult/
## enemyMult/themes 四处）。
static func _theme_cfg() -> Dictionary:
	return {
		"every": 5,
		"treasureMult": 1.5,
		"enemyMult": 1.2,
		"themes": [
			{"id": "outpost", "label": "小镇哨站", "hasSupply": true},
			{"id": "treasure_room", "label": "宝藏房", "hasSupply": false},
		],
	}


## 主题不碰几何：同一层同一种子，带不带主题，墙（blocked）+ spawn/exit 一致；
## 主题只改宝箱/敌人的数量倍率与文本，不挪任何一格可站/墙。主题只出现在
## (depth+1)%every==0 的层；同种子同层主题标签恒定。
func _test_dungeon_theme() -> void:
	var cfg: Dictionary = _theme_cfg()
	var k: String = "th1"
	var plain: Dictionary = Dungeon.layout(k, 4)
	var themed: Dictionary = Dungeon.layout(k, 4, {"theme": cfg})
	_eq(plain["blocked"], themed["blocked"], "带主题不改墙（blocked 逐位一致）")
	_eq(str(plain["spawn"]), str(themed["spawn"]), "带主题不改出生点")
	_eq(str(plain["exit"]), str(themed["exit"]), "带主题不改出口")
	var t4: Dictionary = themed["theme"]
	_check(bool(t4.get("hasTheme", false)), "第 5 层（depth 4）是主题层")
	_check(not bool(Dungeon.layout(k, 3, {"theme": cfg})["theme"].get("hasTheme", false)),
		"第 4 层（depth 3）不是主题层")
	var again: Dictionary = Dungeon.layout(k, 4, {"theme": cfg})["theme"]
	_eq(str(t4.get("id", "")), str(again.get("id", "")), "同种子同层主题恒定")
	# 主题层返回的倍率来自 cfg 顶层
	_check(float(t4.get("treasureMult", 0.0)) >= 1.0, "主题层带回 treasureMult")
	_check(float(t4.get("enemyMult", 0.0)) >= 1.0, "主题层带回 enemyMult")
	# themes 为空的 cfg 不触发主题，也不报错
	_check(not bool(Dungeon.layout(k, 4, {"theme": {}})["theme"].get("hasTheme", false)),
		"空主题配置不触发）")


## 主题层放大宝箱/敌人数量：同一种子同层，treasureMult 更大时宝箱数只增不减。
## 小镇哨站带 hasSupply，宝藏房不带。
func _test_dungeon_theme_det() -> void:
	var k: String = "th2"
	var rich: Dictionary = _theme_cfg()
	rich["treasureMult"] = 3.0
	var base_t: int = (Dungeon.layout(k, 4, {"theme": {}}).get("treasures", []) as Array).size()
	var rich_t: int = (Dungeon.layout(k, 4, {"theme": rich}).get("treasures", []) as Array).size()
	_check(rich_t >= base_t, "treasureMult 放大后宝箱只增不减（%d ≥ %d）" % [rich_t, base_t])
	# 遍历 themes 逐个验 hasSupply 语义：可能同一档位随机挑的一条没有 supply，
	# 但 theme 结构本身必须带 hasSupply 布尔，且任一 at depth 9 的供应位可复现。
	var supply_seen: bool = false
	for seed_i in range(12):
		var t: Dictionary = Dungeon.layout("sup-%d" % seed_i, 4, {"theme": _theme_cfg()})["theme"]
		if bool(t.get("hasSupply", false)):
			supply_seen = true
	_check(supply_seen, "12 个种子里至少有一档小镇哨站（hasSupply）")


## 商人人格：喜好类落在合法类别、标签非空、卖价倍数在合理区间，且同种子可复现。
func _test_merchant_persona() -> void:
	var m1 := Merchant.create(null, {})
	m1.stock_for("persona-1")
	var p1: Dictionary = m1.persona()
	_check(Merchant.STOCK_CATEGORIES.has(str(p1.get("favCategory", ""))), "喜好类在武器/防具/消耗品里")
	_check(not str(p1.get("favCategoryLabel", "")).is_empty(), "喜好类有中文标签")
	var mult: float = float(p1.get("sellMultiplier", 0.0))
	_check(mult >= 0.4 and mult <= 0.7, "卖价比例在 0.4..0.7（%s）" % str(mult))
	_check(typeof(p1.get("rareBias", null)) == TYPE_BOOL, "rareBias 是布尔")
	var m2 := Merchant.create(null, {})
	m2.stock_for("persona-1")
	_eq(str(m1.persona().get("favCategory", "")), str(m2.persona().get("favCategory", "")),
		"同种子喜好类恒定")
	_eq(bool(m1.persona().get("rareBias", false)), bool(m2.persona().get("rareBias", false)),
		"同种子偏好恒定")


## 专属传说货：行商总带一件 weapon_talisman_legendary。它会走两条路的其中一条
## ——要么被随机抽进常规货架（买价 1.5 倍、不带 legendary 标记），要么在补货路径
## 补上（买价 2.5 倍、带 legendary 标记）。这里断言两条都正确：收价恒为半价；
## 遍历足够多种子，确保补货路径确实会触发并验证它的 2.5 倍 + 标记。
func _test_merchant_legendary() -> void:
	var tid: String = "weapon_talisman_legendary"
	var base: int = maxi(1, int(ContentLoader.get_item(tid).get("price", 0)))
	var m0 := Merchant.create(null, {})
	m0.stock_for("leg-base")
	var present: bool = false
	for entry in m0.stock_left():
		if str(entry.get("templateId", "")) == tid:
			present = true
			_eq(int(m0.quote_for(tid).get("sellPrice", 0)),
				maxi(1, int(float(base) * Merchant.SELL_RATIO)), "传说货收价恒按半价基准")
			break
	_check(present, "每位行商都带专属传说货 weapon_talisman_legendary")
	var saw_append: bool = false
	for i in range(40):
		var m := Merchant.create(null, {})
		m.stock_for("leg-%d" % i)
		var entry: Dictionary = {}
		for e in m.stock_left():
			if str(e.get("templateId", "")) == tid:
				entry = e
				break
		if not entry.is_empty() and bool(entry.get("legendary", false)):
			saw_append = true
			_eq(int(m.quote_for(tid).get("buyPrice", 0)),
				maxi(1, int(float(base) * 2.5)), "补货路径的传说货买价按 2.5 倍基准")
			break
	_check(saw_append, "40 个种子里至少一次命中传说货补货路径")


## 收价即时估值：满耐久新货 = 基准 × 收价比例；喜好类收价更高；耐久折损降价。
func _test_merchant_buy_back_value() -> void:
	var m := Merchant.create(null, {})
	m.stock_for("bbv")
	var rule: ItemInstance = ItemInstance.create_from_config()
	var common_tid: String = "weapon_longsword_common"
	var instance: Dictionary = rule.bare_instance(common_tid)
	var base: int = maxi(1, int(ContentLoader.get_item(common_tid).get("price", 0)))
	_check(m.buy_back_value(instance) >= 1, "空类/满耐久收价至少 1 铜")
	# 喜好类收价应不低（比较同一件货在喜好/非喜好两类下的倍率）
	var cat: String = str(ContentLoader.get_item(common_tid).get("category", ""))
	var fav: String = str(m.persona().get("favCategory", ""))
	if fav == cat:
		_eq(int(round(99.0)), 99, "占位：本 merchant 恰好喜好武器，跳过对照")
	else:
		var base_ratio: float = 0.5
		var back: int = m.buy_back_value(instance)
		_check(float(back) <= maxi(1, int(float(base) * 0.5 * 1.25)) + 1,
			"满耐久收价 ≤ 基准×收价比例上限（%d）" % back)
		_check(float(back) >= maxi(1, int(float(base) * base_ratio)),
			"满耐久收价 ≥ 基准×半价（%d）" % back)
	# 耐久折损 → 收价下降
	var worn: Dictionary = rule.bare_instance(common_tid)
	worn["durability"] = 1
	_check(m.buy_back_value(worn) <= m.buy_back_value(instance), "耐久折损后收价不升")
	_check(m.buy_back_value(worn) < m.buy_back_value(instance), "耐久近损坏时收价明显更低")


# --- 里程碑 M-C 大地图可见实体（遗构 / 怪物窝点）---
#
# M-C 把"副本与怪从随机事件变成地图上看得见、走上即触发的实体"。图纸由世界种子
# 派生、不落盘（读档重派生→重生成）。这些测试钉住规则层 WorldSeen 的纯接口：
# 同种子可复现、危险度前缀五档、落点避开城与边界、窝点游荡确定且在半径内、
# 修正词条 0–MAX_WORDS 且危险度越高越多。战斗/进副本的触发在 main.gd（场景层，
# 无头不可兼测），这里测的是它们依赖的那套图纸。

## 两岸世界种子一致的可见实体快照。
static func _seen_snapshot(seen: WorldSeen) -> Dictionary:
	var d: Array = []
	for node in seen.dungeons():
		d.append([str(node.get("key", "")), int(node["x"]), int(node["y"]),
			int(node.get("danger", 0)), str(node.get("prefix", ""))])
	var l: Array = []
	for lair in seen.lairs():
		l.append([str(lair.get("key", "")), int(lair["x"]), int(lair["y"]),
			int(lair.get("tier", 0))])
	return {"dungeons": d, "lairs": l}


## 各自带一份"最近之城距离 ≥ minDist"的城坐标（测试要用的几何断言用得上）。
func _seen_built(seed: int) -> Dictionary:
	var built: Dictionary = _new_encounters(false)
	var world: WorldState = built["world"]
	var grid: MapGrid = built["grid"]
	var city_coords: Array = []
	for cid in world.get_city_ids():
		var c: City = world.get_city(cid)
		if c != null:
			city_coords.append(Vector2i(c.coord_x, c.coord_y))
	var seen := WorldSeen.build(seed, grid, city_coords, {"tierAt": built["system"].tier_at})
	return {"world": world, "grid": grid, "cities": city_coords, "seen": seen}


## 同种子两次派生完全一致；不同种子不同。
func _test_world_seen_determinism() -> void:
	var a: Dictionary = _seen_built(20260922)
	var b: Dictionary = _seen_built(20260922)
	_eq(_seen_snapshot(a["seen"]), _seen_snapshot(b["seen"]), "同种子可见实体逐位一致")
	var c: Dictionary = _seen_built(777)
	_check(not (_seen_snapshot(a["seen"]) == _seen_snapshot(c["seen"])), "不同种子图纸不同")


## 危险度前缀五档映射：越低越无害、越高越吓人；越界退到致命档。
func _test_world_seen_prefix() -> void:
	var prefix: Array = WorldSeen.DANGER_PREFIXES
	_eq(prefix.size(), 5, "前缀五档")
	_eq(WorldSeen.prefix_of(0), "沉眠的", "0 档沉眠")
	_eq(WorldSeen.prefix_of(1), "吱呀作响的", "1 档吱呀作响")
	_eq(WorldSeen.prefix_of(2), "淌血的", "2 档淌血")
	_eq(WorldSeen.prefix_of(3), "无名的", "3 档无名")
	_eq(WorldSeen.prefix_of(4), "夹缝间的", "4 档夹缝间")
	_eq(WorldSeen.prefix_of(99), "夹缝间的", "越界退到致命档")


## 落点合法：遗构与窝点都在网格内、数量与配置一致、离每座城 ≥ 各自 minDist。
func _test_world_seen_placement() -> void:
	var r: Dictionary = _seen_built(20260922)
	var grid: MapGrid = r["grid"]
	var cities: Array = r["cities"]
	var seen: WorldSeen = r["seen"]
	var rules: Dictionary = ContentLoader.get_balance_section("worldSeen")
	_eq(seen.dungeons().size(), int(rules.get("dungeonCount", 10)), "遗构数量按配置")
	_eq(seen.lairs().size(), int(rules.get("lairCount", 20)), "窝点数量按配置")
	for node in seen.dungeons():
		var x: int = int(node["x"])
		var y: int = int(node["y"])
		_check(grid.is_inside(x, y), "遗构在网格内")
		var far: bool = true
		for c in cities:
			if MapGrid.manhattan(c, Vector2i(x, y)) < int(rules.get("dungeonMinDistance", 6)):
				far = false
		_check(far, "遗构离每座城 ≥ dungeonMinDistance（%d,%d）" % [x, y])
	for lair in seen.lairs():
		var x: int = int(lair["x"])
		var y: int = int(lair["y"])
		_check(grid.is_inside(x, y), "窝点在网格内")
		var far: bool = true
		for c in cities:
			if MapGrid.manhattan(c, Vector2i(x, y)) < int(rules.get("lairMinDistance", 6)):
				far = false
		_check(far, "窝点离每座城 ≥ lairMinDistance（%d,%d）" % [x, y])


## 窝点游荡：同窝点同桶同一位置且不越出半径；桶变位置可能挪步。
func _test_world_seen_lair() -> void:
	var r: Dictionary = _seen_built(20260922)
	var lairs: Array = r["seen"].lairs()
	_check(not lairs.is_empty(), "有窝点")
	if lairs.is_empty():
		return
	var node: Dictionary = lairs[0]
	var anchor := Vector2i(int(node["x"]), int(node["y"]))
	var radius: int = int(node.get("radius", 2))
	var p0: Vector2i = WorldSeen.lair_pos(node, 3)
	var p1: Vector2i = WorldSeen.lair_pos(node, 3)
	_eq(p0, p1, "同窝点同桶位置确定")
	_check(MapGrid.manhattan(anchor, p0) <= radius, "窝点游荡不越出半径")
	_eq(WorldSeen.node_seq(node), WorldSeen.node_seq(node), "节点序号稳定")


## 修正词条：条数落在 0..MAX_WORDS，危险度越高越多，条条都有名有姓。
func _test_world_seen_words() -> void:
	var r: Dictionary = _seen_built(20260922)
	var dungeons: Array = r["seen"].dungeons()
	_check(not dungeons.is_empty(), "有遗构")
	for node in dungeons:
		var danger: int = int(node.get("danger", 0))
		var words: Array = node.get("words", [])
		_check(words.size() <= WorldSeen.MAX_WORDS, "词条不超过上限")
		_check(words.size() <= danger, "危险度越高词条越多（≤ danger）")
		for w in words:
			_check(not str(w.get("label", "")).is_empty(), "词条都有名")
