extends Node2D

## 可运行骨架：时间推进、存档读写、地图移动、世界模拟月度结算、城市状态面板
## （M6.3）、开局创建（M3.1 / M3.2）、角色面板（M6.2）、战斗（M5）与世界遭遇。
##
## 十个视图：
##   开局创建     ↑↓ 选条目    ←→ 改值/加减点数    空格 勾选天赋缺陷
##                TAB 或 1–5 换段    回车 开始这一生    R 切换自由生成/随机转生
##                ESC 或点「← 上一步」回上一段
##   地图         方向键 / WASD   移动一格（野外每走若干格会判定一次遭遇）
##                空格            推进 1 天
##                M / Y           推进 1 月 / 1 年（逐月结算）
##                G               快进 10 年（批量结算）
##                Z               静默行走：不再判定遭遇，但时间照走
##                T               打开城市面板
##                C               打开角色面板
##                X               打开走私航线界面
##                Q               打开委托板
##                E               打开城中大事（城市事件）
##                R               打开商铺（含铁匠铺）
##                B               就地按正式规则摇一场遭遇（调试入口）
##                F5 / F9         保存 / 读取
##   城市面板     ↑↓ / W S        切换城市
##                ←→ / A D        切换趋势维度
##                T               返回地图     点「走私航线」「委托板」「城中大事」进对应界面
##   角色面板     C               返回地图
##   战斗         ↑↓ 选行动   回车 执行   ESC 取消/返回
##   走私航线     ←→ 换城市   ↑↓ 选条目   回车 建立/撤销   ESC 或 T 返回地图
##   委托板       ←→ 换城市   ↑↓ 选单子   回车 接受/办理   Del 放弃   ESC 或 T 返回地图
##   城中大事     ←→ 换城市   ↑↓ 选一件   回车 处置   ESC 或 T 返回地图
##   商铺         ←→ 换城市看价   ↑↓ 选货   回车 成交/敲一炉   Tab 换买卖   X 换渠道
##   遭遇         ↑↓ 选做法   回车 执行   （没有返回键：三个做法就是全部出口）
##
## 十个视图都能用鼠标。位置不另算一份：每个面板的 hit_test 与 draw 共用同一组
## 布局函数，所以"按钮画在这里、点在那里"这种漂移不可能发生。悬停只影响高亮，
## 不参与判断——判断一律走点击。
##
## 跑验收测试（无头，不需要显卡）：
##   godot --headless --path game -- --test
##
## 界面全部用代码构建，main.tscn 里只有一个挂脚本的根节点。理由是骨架阶段
## 界面会频繁改动，用代码写比手改场景文件更不容易出错。
##
## 视图模型（CityViewModel / CreationViewModel / AvatarViewModel /
## CombatViewModel / SmugglingViewModel / QuestViewModel / EventViewModel /
## TradeViewModel / EncounterViewModel）是纯函数，负责"该显示什么"；面板类
## （CityPanel / CreationPanel / AvatarPanel / CombatPanel / SmugglingPanel /
## QuestPanel / EventPanel / TradePanel / EncounterPanel）只负责"怎么画"。
## 数值一律由视图模型算好，面板与主场景都不再自己算一遍。
##
## 主场景本身不存游戏流程的状态。开局创建整套规则在 CreationSession 里，主场景
## 只把键位与点击翻译成它的方法调用，并在它说"可以开始了"之后装配化身。原因是
## 主场景在无头测试中不存在——状态一旦留在这里，"点第二行却改了第一行"这类错误
## 就没有任何东西能拦住。遭遇的规则同样在 EncounterSystem 里，这里只留
## "现在这一场是谁、光标在第几条"这类会话状态（与战斗同一条处境：都不落盘）。

const TILE: int = 5
const MAP_ORIGIN: Vector2 = Vector2(16.0, 16.0)
## 地图上点城市方块的判定半径。方块实际只有 TILE 到 2×TILE 见方（5–17px），
## 按像素精点等于点不中，所以往外扩一圈。
const MAP_CITY_PICK_RADIUS: float = 12.0
## 点地图"走过去"的步数上限。地图上没有任何障碍（MapGrid.can_enter 只查边界），
## 所以到得了；上限只是防止将来某处改出"原地不动"时这里变成死循环。
## 120×120 的地图上斜走最远也就 119 步。
const MAP_WALK_LIMIT: int = 200
const SAVE_SLOT: String = "slot1"
const FAST_FORWARD_YEARS: int = 10
const NOTABLE_KEEP: int = 40
## 底部事件流一次显示几条。这个数字由空间倒推：地图区高 600px（120×5，
## 占 16–616），底部条不能往上越过它，否则会盖住地图。720 − 616 = 104px，
## 减掉 4px 下边距与 23px 状态行，只剩 77px 给事件流——size 14 的单行实占
## 23px，所以最多 3 行。想多显示就得先缩小地图或加大视口。
const NOTABLE_SHOW: int = 3

## 面板占用的屏幕区域。底边与地图区、右侧信息栏对齐（都在 y = 616），
## 剩下的 620–716 留给底部信息条。视口 1280×720。
const PANEL_RECT: Rect2 = Rect2(16.0, 48.0, 1248.0, 568.0)

## 底部信息条的纵向余量（相对视口下沿）。上沿贴在 616，正好接住地图区的底边——
## 再往上就会盖住地图。条内从上到下是状态行（23px）与事件流（3 行 69px）。
const BOTTOM_STRIP_TOP: float = -104.0
const BOTTOM_STRIP_BOTTOM: float = -4.0

const VIEW_MAP: int = 0
const VIEW_CITY: int = 1
const VIEW_CREATION: int = 2
const VIEW_AVATAR: int = 3
const VIEW_COMBAT: int = 4
const VIEW_SMUGGLING: int = 5
const VIEW_QUEST: int = 6
const VIEW_EVENT: int = 7
const VIEW_TRADE: int = 8
const VIEW_ENCOUNTER: int = 9
const VIEW_CRAFTING: int = 10

## 状态行左边的键位参考。按视图给一份，免得切换视图后提示还停在上一屏。
## 八个视图都能用鼠标，但键位仍然写全——两套输入并存时，键位是"操作全集"，
## 鼠标只是其中一部分。
const VIEW_HINTS: Dictionary = {
	VIEW_MAP: "方向键/WASD 或点地图 移动    空格 1天    M 1月    Y 1年    G 快进10年    Z 静默行走    点城市走进去（再点一次/T 看状态）    X 走私    Q 委托    E 城中大事    R 商铺    C 角色    B 惹一场    F5 保存    F9 读取",
	VIEW_CITY: "点城市看详情    ◀▶ 换趋势维度    T 或点「返回地图」    点「商铺」「走私航线」「委托板」「城中大事」    C 角色面板    M/Y 推进时间",
	VIEW_CREATION: "↑↓ 选条目    ←→ 改值    空格 勾选    TAB/1-5 换段    ESC 或「← 上一步」退回    回车 确认",
	VIEW_AVATAR: "C / ESC 或点右上「返回地图」",
	VIEW_COMBAT: "↑↓←→ 选行动    回车 执行    ESC 取消/返回    点敌人打它    点空格走过去",
	VIEW_SMUGGLING: "←→ 换城市    ↑↓ 选条目    回车 建立/撤销    ESC 或 T 返回地图",
	VIEW_QUEST: "←→ 换城市    ↑↓ 选单子    回车 接受/办理    Del 放弃    ESC 或 T 返回地图",
	VIEW_EVENT: "←→ 换城市    ↑↓ 选一件    回车 处置    ESC 或 T 返回地图",
	VIEW_TRADE: "←→ 换城市    ↑↓ 选货    回车 成交 / 敲一炉    Tab 换买卖    X 换渠道    F 铁匠铺    ESC 或 T 返回地图",
	VIEW_ENCOUNTER: "↑↓ 选做法    回车 执行    点做法行也行    （遭遇里没有回头路）",
	VIEW_CRAFTING: "↑↓ 选配方 / 采集    回车 制作 / 采集    点行先选中、再点同一行执行    ESC 或 T 返回地图",
}

## 训练战里最多拉几个居民当对手。取 2 是为了让"多对多"的回合顺序
## 真的会换人——一个对手永远打不出先攻排序的效果。
const SPARRING_OPPONENTS: int = 2

## 战场尺寸与双方的起始站位。与 CombatViewModel.BATTLE_WIDTH/HEIGHT 一致。
## 对手站位给三个：遭遇里的"成群"最多这么多（balance.encounters.maxOpponents）。
const BATTLE_COLS: int = 14
const BATTLE_ROWS: int = 9
const PLAYER_SPAWN: Array = [2, 4]
const OPPONENT_SPAWNS: Array = [[11, 3], [11, 5], [11, 7]]

var _world: WorldState = null
var _grid: MapGrid = null
var _soul: SoulRecord = null
var _sim: WorldSim = null

var _creator: CharacterCreation = null
var _reincarnation: Reincarnation = null
var _derived: DerivedStats = null

## 名字表与模板表在启动时建一次。面板每次重绘都要拿它们做 ID→名称的翻译，
## 逐次去 ContentLoader 里线性找会把每帧变成几百次遍历。
## _lookups 是这几张表的合集，原样交给视图模型。
var _lookups: Dictionary = {}

var _info: RichTextLabel = null
var _notable_label: Label = null
var _status: Label = null
var _hint: Label = null

## 装备规则（槽位清单、双手占用、合法槽位）。物品模板表在启动时建一次后交给它，
## 战斗取"这一身能打能扛多少"、面板穿脱、出生时把行李穿上都走它。
var _gear: Equipment = null

var _view: int = VIEW_MAP
var _selected_city: int = 0
var _trend_dimension: int = 0
## 详情栏建筑条里选中的那座（D-69~D-72）。按下回车对它投资。
var _selected_building: int = 0
var _notable: Array = []
var _last_deltas: Dictionary = {}
var _panel: Dictionary = {}

## 鼠标悬停到的元素（hit_test 的结果）。只影响高亮，不参与判断。
## _hover_signature 是它的压扁形式：只在悬停目标真的换了才重绘，
## 否则鼠标每动一个像素都要重画整屏。
var _hover: Dictionary = {}
var _hover_signature: String = ""

# 开局创建（M3.1 / M3.2）。段、光标、规格与视图都在会话里，主场景只做两件事：
# 把键位与点击翻译成会话的方法调用，以及会话说"可以开始了"之后装配化身。
var _creation_session: CreationSession = null

# 角色面板（M6.2）
var _avatar_view: Dictionary = {}
## 装备槽与背包共用的光标（0–4 是槽位、5 起是背包，见 AvatarViewModel）
var _avatar_cursor: int = 0

# 走私航线（玩家自己建立/撤销的那些）
var _smuggling_city_id: String = ""
var _smuggling_cursor: int = 0
var _smuggling_view: Dictionary = {}

# 委托（M4）。板子不落盘，每次刷新按当前城市状态重新推导；手上接下的在 world.quests。
var _quest_city_id: String = ""
var _quest_cursor: int = 0
var _quest_branch_cursor: int = 0
var _quest_mode: int = QuestViewModel.MODE_BOARD
var _quest_view: Dictionary = {}
## 委托战斗：从委托界面打起来的那一场，打完之后按战场上的处置决定交付后果
var _quest_combat: Dictionary = {}

# 城市事件（M7.1）。事件实例在 world.events 里，界面只持有"在看哪座城、光标在哪"。
var _event_city_id: String = ""
var _event_cursor: int = 0
var _event_branch_cursor: int = 0
var _event_mode: int = EventViewModel.MODE_LIST
var _event_view: Dictionary = {}
## 事件战斗：讨伐利维坦那一场，胜负决定走 victory 还是 defeat 那一套后果
var _event_combat: Dictionary = {}

# 商铺与黑市（M8）。界面只持有"在看哪座城、买还是卖、哪条渠道、光标在哪"——
# 价格与货架每次都按当前城市状态重算，不落盘（物价随城长，存下来就会过期）。
var _trade_city_id: String = ""
var _trade_cursor: int = 0
var _trade_channel: String = Economy.CHANNEL_SHOP
var _trade_side: String = TradeViewModel.SIDE_BUY
var _trade_view: Dictionary = {}
var _trade_pane: String = TradeViewModel.PANE_TRADE
## 修理页当前的档位（工匠/满修），G 键切换。便携工具不走这块版面（D-64）。
var _trade_repair_tier: String = ItemInstance.REPAIR_CRAFTSMAN
## 敲炉的随机源游标。与战斗同一个做法：强化用自己的种子序列，不该改变世界的演化。
var _forge_seq: int = 0

# 野外采集（M14）。界面只持有采集层实例与"下一个采哪个点"的游标；产出入包、
# 熟练 +1 都写在 Gathering 里，就地改化身。
var _gathering: Gathering = null
## 在采集点列表里轮转的游标。野外按 F 依次采矿脉/林地/药草丛，好把三类基础料都补齐。
var _gather_seq: int = 0

# 制作台（M15）。规则层 Crafting 持配方便捷，视图用 CraftingViewModel 产出
# 配方/采集行与选中明细；光标只记"在列表哪一行"。制作与采集都就地改化身。
var _crafting: Crafting = null
var _crafting_view: Dictionary = {}
var _crafting_cursor: int = 0

# 战斗（M5）
var _combat: Combat = null
var _combat_seq: int = 0
var _combat_menu_mode: int = CombatViewModel.MENU_MAIN
var _combat_cursor: int = 0
var _combat_pending: Dictionary = {}
var _combat_cursor_tile: Vector2i = Vector2i.ZERO
var _combat_view: Dictionary = {}
var _loot_seq: int = 0
## 打完之后把磨损落到装备实例的随机序列（D-62）。与锻造、遭遇各自独立——
## 磨损是世界演化的"读数"，不应反过来改变世界 or 掉落。
var _wear_seq: int = 0

# 世界遭遇（M9：谁在什么地方因为什么拦住你）
var _encounter_system: EncounterSystem = null
var _encounter: Dictionary = {}
var _encounter_view: Dictionary = {}
var _encounter_cursor: int = 0
## 离上一次判定走了几格。野外按 stepInterval 累计，进城那一下另判。
var _encounter_steps: int = 0
## 判定与做法的随机源游标。与战斗同一个做法：遭遇用自己的种子序列，
## "路上撞见一头狼"不该改变城市接下来的演化。
var _encounter_seq: int = 0
## 当前这一场是不是从遭遇打起来的（战斗收尾要走遭遇那条结算）。
var _encounter_combat: bool = false
## 静默行走：不再判定遭遇，时间照走。
var _silent_walk: bool = false
## 上一次所处的城。进城那一瞬间判一次城内遭遇，站在城里反复走不再判。
var _last_city_id: String = ""


func _ready() -> void:
	if "--test" in OS.get_cmdline_user_args():
		var suite := TestSuite.new()
		var failures: int = suite.run_all()
		get_tree().quit(1 if failures > 0 else 0)
		return

	# 主题挂在 Window 上，整棵界面树继承，不必逐个控件设字体
	get_tree().root.theme = UiTheme.theme()

	_build_ui()
	_report_font()
	if not ContentLoader.is_loaded():
		_show_content_error()
		return
	_build_lookup_tables()
	_gear = Equipment.create(_table("itemTemplates"))
	_gathering = Gathering.create()
	_crafting = Crafting.create()
	_creator = CharacterCreation.new(
		ContentLoader.get_balance_section("characterCreation"),
		ContentLoader.get_playable_races(),
		ContentLoader.get_backgrounds(),
		ContentLoader.get_talents()
	)
	_derived = DerivedStats.new(
		ContentLoader.get_balance_section("derivedStats"),
		ContentLoader.get_balance_section("combat")
	)
	Clock.period_reached.connect(_on_period_reached)
	_start_new_world()


## ID → 显示名 / 模板的查询表。建一次，之后面板重绘只做字典取值。
func _build_lookup_tables() -> void:
	var skill_names: Dictionary = {}
	var talent_names: Dictionary = {}
	var item_templates: Dictionary = {}
	var city_names: Dictionary = {}
	var race_names: Dictionary = {}
	for skill in ContentLoader.get_skills():
		skill_names[str(skill.get("skillId", ""))] = str(skill.get("displayName", ""))
	for talent in ContentLoader.get_talents():
		talent_names[str(talent.get("talentId", ""))] = str(talent.get("displayName", ""))
	for item in ContentLoader.get_items():
		item_templates[str(item.get("templateId", ""))] = item
	for city in ContentLoader.get_city_configs():
		city_names[str(city.get("cityId", ""))] = str(city.get("displayName", ""))
	for race in ContentLoader.get_playable_races():
		race_names[str(race.get("raceId", ""))] = str(race.get("displayName", ""))
	_lookups = {
		"skillNames": skill_names,
		"talentNames": talent_names,
		"itemTemplates": item_templates,
		"cityNames": city_names,
		"raceNames": race_names,
	}


func _table(key: String) -> Dictionary:
	var value: Variant = _lookups.get(key, null)
	return value if value is Dictionary else {}


## 启动时把界面字体落到日志里。字体选错的表现是"中文一片空白"，
## 那种界面看起来像坏了却看不出原因，所以先把来源打出来。
func _report_font() -> void:
	if UiTheme.is_headless():
		print("[UI] 无头运行，不加载界面字体")
		return
	var font: Font = UiTheme.font()
	var name: String = font.get_font_name() if font != null else "（未取到）"
	print("[UI] 界面字体：%s  来源=%s" % [name, UiTheme.font_source()])
	if not UiTheme.is_cjk_capable():
		push_warning("[UI] 界面字体不含中文字形，中文会显示为空白")


func _start_new_world() -> void:
	var grid_cfg: Dictionary = ContentLoader.get_balance_section("worldGrid")
	var built: Dictionary = WorldFactory.create_new(
		# 固定种子，便于复现；后续接上"玩家输入种子/分享种子"的界面
		20260915,
		ContentLoader.get_city_configs(),
		int(grid_cfg.get("width", 120)),
		int(grid_cfg.get("height", 120))
	)
	_world = built["world"]
	_grid = built["grid"]
	_sim = WorldSim.create(_world)
	_encounter_system = EncounterSystem.create(_world, _grid, _derived)
	_reset_encounter_session()

	# 化身留到开局创建结束时才装配。这一步之前 _world.avatar 是 null——
	# 地图与面板都对 null 有守卫，这是"新世界已生成、玩家还没出生"的正常中间态。
	_world.avatar = null

	_soul = SoulRecord.new()
	_soul.soul_id = "soul-0001"

	_combat = null
	_combat_seq = 0
	_notable = WorldSim.bootstrap(_world)
	_status.text = "新世界已生成（种子 %d，%d 座城，%d 名居民）——先决定这个人是谁。" % [
		_world.world_seed, _world.get_city_count(), _world.get_npc_count()
	]
	_enter_creation()


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "UI"
	add_child(layer)

	var bg := ColorRect.new()
	bg.name = "MapPanelBg"
	bg.color = Color(0.0, 0.0, 0.0, 0.62)
	bg.position = Vector2(648.0, 16.0)
	bg.size = Vector2(616.0, 600.0)
	layer.add_child(bg)

	_info = RichTextLabel.new()
	_info.name = "MapPanel"
	_info.bbcode_enabled = true
	_info.position = Vector2(660.0, 28.0)
	_info.size = Vector2(592.0, 580.0)
	layer.add_child(_info)

	# 底部信息条用容器托底，而不是逐个写坐标。原因：字号、行距、事件条数
	# 任何一个变了，手算的 y 就会算错——事件流曾经在 40px 的框里塞 4 行
	# （size 14 的单行实占 25px，需要 101px），文字溢出到 720 下沿之外还压住了
	# 状态行。交给容器算高度，这类错误就不会再出现；底部锚定也让事件变少时
	# 整条自然上收。
	var strip := VBoxContainer.new()
	strip.name = "BottomStrip"
	strip.anchor_left = 0.0
	strip.anchor_right = 1.0
	strip.anchor_top = 1.0
	strip.anchor_bottom = 1.0
	strip.offset_left = 16.0
	strip.offset_right = -16.0
	strip.offset_top = BOTTOM_STRIP_TOP
	strip.offset_bottom = BOTTOM_STRIP_BOTTOM
	strip.add_theme_constant_override("separation", 2)
	layer.add_child(strip)

	# 状态行：左边是固定键位参考，右边是最近一次操作的反馈。
	# 两段实测最宽 665 + 481 = 1146px，条宽 1248px，余量 98px，不会撞上。
	var bar := HBoxContainer.new()
	bar.name = "StatusBar"
	strip.add_child(bar)

	_hint = Label.new()
	_hint.name = "Hint"
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(_hint)

	_status = Label.new()
	_status.name = "Status"
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bar.add_child(_status)

	# 事件流：每行一条，靠换行符分行，所以关掉自动折行——开着的话一旦某条
	# 事件文本变长，会自动多折出一行，又溢出去。
	_notable_label = Label.new()
	_notable_label.name = "NotableLog"
	_notable_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	strip.add_child(_notable_label)

	_apply_view_visibility()


func _apply_view_visibility() -> void:
	var map_mode: bool = _view == VIEW_MAP
	if _info != null:
		_info.visible = map_mode
		var bg: Node = _info.get_parent().get_node_or_null("MapPanelBg")
		if bg != null:
			(bg as ColorRect).visible = map_mode
	if _notable_label != null:
		_notable_label.visible = map_mode
	if _hint != null:
		_hint.text = str(VIEW_HINTS.get(_view, ""))


func _show_content_error() -> void:
	_status.text = "配置装载失败，游戏未启动。"
	var lines: Array[String] = ["[color=#ff8888][b]配置校验未通过[/b][/color]", ""]
	for err in ContentLoader.get_errors():
		lines.append("• " + err)
	_info.text = "\n".join(lines)


## 时钟周期事件。月事件驱动世界模拟结算，年事件驱动 NPC 生命周期。
func _on_period_reached(period: String, elapsed_months: int, _tick_in_month: int) -> void:
	if _sim == null:
		return
	match period:
		ClockCore.PERIOD_MONTH:
			var report: Dictionary = _sim.settle_month(elapsed_months)
			_last_deltas = report["cityDeltas"]
			_note_events(report["notableEvents"])
			_status.text = "第 %d 月结算完成：落账 %d 条变更，%d 名居民迁出" % [
				elapsed_months, int(report["appliedChanges"]), _migration_total(report)
			]
		ClockCore.PERIOD_YEAR:
			var yearly: Dictionary = _sim.settle_year(elapsed_months)
			_note_events(yearly["notableEvents"])
			_status.text = "第 %d 年结算完成：%d 名居民过世" % [
				Clock.now().year, int(yearly["deaths"])
			]


func _migration_total(report: Dictionary) -> int:
	var total: int = 0
	for city_id in report.get("migration", {}):
		total += int(report["migration"][city_id]["out"])
	return total


func _note_events(events: Array) -> void:
	if events.is_empty():
		return
	for event in events:
		_notable.append(event)
	while _notable.size() > NOTABLE_KEEP:
		_notable.pop_front()


func _refresh() -> void:
	queue_redraw()
	if _world == null:
		return
	match _view:
		VIEW_CREATION:
			# 创建流程的视图由 CreationSession 在每次状态变更后自己重建
			# （见它的 sync），这里没有第二份需要重算的东西
			pass
		VIEW_AVATAR:
			_refresh_avatar()
		VIEW_COMBAT:
			_refresh_combat()
		VIEW_CITY:
			_refresh_city_panel()
		VIEW_SMUGGLING:
			_refresh_smuggling()
		VIEW_QUEST:
			_refresh_quest()
		VIEW_EVENT:
			_refresh_event()
		VIEW_TRADE:
			_refresh_trade()
		VIEW_ENCOUNTER:
			_refresh_encounter()
		VIEW_CRAFTING:
			_refresh_crafting()
		_:
			_refresh_map_panel()
	if _notable_label != null and _view == VIEW_MAP:
		var tail: Array = []
		for i in range(maxi(0, _notable.size() - NOTABLE_SHOW), _notable.size()):
			var record: Dictionary = _notable[i]
			tail.append("[%s] %s" % [_event_month_label(record), str(record["text"])])
		_notable_label.text = "\n".join(PackedStringArray(tail))


func _event_month_label(record: Dictionary) -> String:
	var month: int = int(record.get("month", 0))
	@warning_ignore("integer_division")
	var year: int = month / 12 + 1
	var month_in_year: int = month % 12
	return "第%d年%d月" % [year, month_in_year if month_in_year != 0 else 12]


func _refresh_map_panel() -> void:
	var lines: Array[String] = []
	lines.append("[b]%s[/b]" % Clock.now().format())
	lines.append("")

	if _world.avatar != null:
		lines.append("[b]化身[/b]  %s  位置 (%d, %d)" % [
			_world.avatar.display_name, _world.avatar.pos_x, _world.avatar.pos_y
		])
		var standing: String = _grid.get_city_id_at(_world.avatar.pos_x, _world.avatar.pos_y)
		if not standing.is_empty():
			lines.append("      正站在 [color=#e0c060]%s[/color]" % standing)
		lines.append("      灵魂 SOU %d   善恶 %d   幸运 %d" % [
			_world.avatar.get_attribute(PlayerAvatar.ATTR_SOUL),
			_world.avatar.karma,
			_world.avatar.luck,
		])
		if _silent_walk:
			lines.append("      [color=#e0c060]静默行走中[/color]  [color=#808080]不再遇敌，按 Z 关掉[/color]")
	lines.append("")

	lines.append("[b]城市概览[/b]  模拟居民 %d 名  [color=#808080]按 T 看逐项归因与趋势[/color]"
		% _world.get_npc_count())
	for city_id in _world.get_city_ids():
		var city: City = _world.get_city(city_id)
		var slot: Dictionary = _last_deltas.get(city_id, {})
		var population_milli: int = int(slot.get(City.DIM_POPULATION, {}).get("milli", 0))
		var delta_color: String = "#909090"
		if population_milli > 0:
			delta_color = "#66c07a"
		elif population_milli < 0:
			delta_color = "#de7070"
		lines.append("  [color=#e0c060]%s[/color]  %s  居民 %d  人口 %d [color=%s](%s)[/color]" % [
			city.display_name, city.get_tier_label(), city.npc_ids.size(), city.population,
			delta_color, CityViewModel.format_signed(population_milli),
		])
	lines.append("")
	lines.append("[color=#808080]M/Y 逐月结算，G 快进 10 年。野外按 F 采集，城市阶段由发展度与人口中较低者决定。[/color]")
	_info.text = "\n".join(lines)


func _selected_city_id() -> String:
	var ids: Array = Array(_world.get_city_ids())
	if ids.is_empty():
		return ""
	_selected_city = clampi(_selected_city, 0, ids.size() - 1)
	return str(ids[_selected_city])


func _refresh_city_panel() -> void:
	var ids: Array = Array(_world.get_city_ids())
	if ids.is_empty():
		return
	_selected_city = clampi(_selected_city, 0, ids.size() - 1)
	var city_id: String = str(ids[_selected_city])
	var detail: Dictionary = CityViewModel.build_detail(_world, city_id, _last_deltas)
	var dimensions: Array = CityViewModel.DIMENSION_ORDER
	_trend_dimension = clampi(_trend_dimension, 0, dimensions.size() - 1)
	detail["trendDimension"] = str(dimensions[_trend_dimension])
	# 建筑条：把当前选中的那座标出来，并夹住索引（切城后可能超出范围）。
	var buildings: Array = detail.get("buildings", [])
	_selected_building = clampi(_selected_building, 0, maxi(0, buildings.size() - 1))
	for i in range(buildings.size()):
		buildings[i]["selected"] = (i == _selected_building)
	_panel = {
		"monthLabel": Clock.now().format(),
		"list": CityViewModel.build_list(_world, _last_deltas),
		"detail": detail,
		"selectedIndex": _selected_city,
	}


# --- 走私航线（量化规则 6 章的玩家干预：垄断贸易路线）---
#
# 走私航线本身是世界侧的机制（NPC 商旅自己跑），这里给玩家的是**自己开一条**
# 的权力：自己开的航线归自己，每月进账，被查抄才算在自己头上。世界的航线被查抄
# 与玩家无关——那是城市自己的损失。

## 打开走私航线界面。不指定城市时落在化身所在的城；在野外就落在第一座城，
## 反正 ←→ 随时能换。
func _enter_smuggling(city_id: String = "") -> void:
	if _sim == null:
		return
	var ids: Array = Array(_world.get_city_ids())
	if ids.is_empty():
		return
	var target: String = city_id
	if target.is_empty() and _world.avatar != null:
		target = _grid.get_city_id_at(_world.avatar.pos_x, _world.avatar.pos_y)
	if target.is_empty() or not ids.has(target):
		target = str(ids[0])
	_smuggling_city_id = target
	_smuggling_cursor = 0
	_switch_view(VIEW_SMUGGLING)
	_status.text = "走私航线：在这座城开通一条，或撤销你自己开的那些。"


func _refresh_smuggling() -> void:
	if _smuggling_city_id.is_empty():
		_smuggling_city_id = _selected_city_id()
	_smuggling_view = SmugglingViewModel.build(
		_world,
		_sim.smuggling_options(_smuggling_city_id),
		_sim.player_smuggling_routes(_smuggling_city_id),
		_smuggling_city_id,
		_table("cityNames"),
		_smuggling_cursor,
		_smuggling_rules()
	)
	_smuggling_cursor = int(_smuggling_view.get("cursor", 0))


## 界面上要摆出来的那几个配置值。一次取齐交给视图模型，免得它自己去读配置——
## 视图模型只做"该显示什么"，不该知道配置放在哪儿。
func _smuggling_rules() -> Dictionary:
	var trade: Dictionary = ContentLoader.get_balance_section("trade")
	return {
		"confiscationPermille": int(round(
			float(trade.get("smugglingConfiscationSecurityFactor", 0.2)) * 1000.0
		)),
		"incomePerRoute": int(trade.get("playerSmugglingIncomeCopper", 0)),
		"reputationLoss": int(trade.get("smugglingConfiscationReputationLoss", 0)),
		"karmaLoss": int(trade.get("smugglingConfiscationKarmaLoss", 0)),
		"maxPerCity": int(trade.get("smugglingMaxPerCity", 0)),
	}


## ←→ 换这一端的城市。候选与己方航线都跟着重算，光标回到第一行。
func _smuggling_cycle_city(delta: int) -> void:
	var ids: Array = Array(_world.get_city_ids())
	if ids.is_empty():
		return
	var index: int = ids.find(_smuggling_city_id)
	_smuggling_city_id = str(ids[posmod((index if index >= 0 else 0) + delta, ids.size())])
	_smuggling_cursor = 0
	_refresh()


func _smuggling_move_cursor(delta: int) -> void:
	var count: int = maxi(1, int(_smuggling_view.get("rowCount", 0)))
	_smuggling_cursor = posmod(_smuggling_cursor + delta, count)
	_refresh()


## 执行光标所在那一行。行自己带着种类：己方航线是撤销，候选城市是建立。
##
## 光标取 _smuggling_cursor，**不取 view 里的那一份**：view 是"上一次刷新时的显示
## 依据"，点击只改了 _smuggling_cursor，还没重建 view——回头从 view 里读光标，就会
## "点了第 5 行却执行第 1 行"。这与创建界面那次是同一类错误，所以这里必须读活的。
func _smuggling_confirm() -> void:
	var rows: Array = _smuggling_view.get("rows", [])
	if rows.is_empty():
		return
	_smuggling_cursor = clampi(_smuggling_cursor, 0, rows.size() - 1)
	var row: Dictionary = rows[_smuggling_cursor]
	var label: String = str(row.get("label", ""))
	var cancelling: bool = str(row.get("kind", "")) == SmugglingViewModel.ROW_KIND_CANCEL
	var result: Dictionary = {}
	if cancelling:
		result = _sim.cancel_route(str(row.get("key", "")))
	else:
		result = _sim.establish_route(
			_smuggling_city_id, str(row.get("cityId", "")),
			TradeRoute.KIND_SMUGGLING, Clock.total_months(), TradeRoute.OWNER_PLAYER
		)
	if bool(result.get("ok", false)):
		_status.text = "%s %s" % [label, "已撤销。" if cancelling else "已开通，月入 %s。" % \
			AvatarViewModel.money_label(int(_smuggling_view.get("incomePerRoute", 0)))]
	else:
		# 不可建的条目也让它走到这里：理由由 WorldSim 给出，界面不自己编一套
		_status.text = "%s %s：%s" % [
			label, "撤不掉" if cancelling else "建不了", str(result.get("error", ""))
		]
	_refresh()


func _smuggling_input(key_event: InputEventKey) -> void:
	match key_event.keycode:
		KEY_LEFT, KEY_A:
			_smuggling_cycle_city(-1)
		KEY_RIGHT, KEY_D:
			_smuggling_cycle_city(1)
		KEY_UP, KEY_W:
			_smuggling_move_cursor(-1)
		KEY_DOWN, KEY_S:
			_smuggling_move_cursor(1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_smuggling_confirm()
		KEY_ESCAPE, KEY_T, KEY_X:
			_switch_view(VIEW_MAP)


## 点行即执行：光标也一并挪过去，免得"执行了第 3 行、高亮还在第 1 行"。
## 不可建的那几行照样收——理由由 WorldSim 给出，状态行说出来比什么都不做强。
func _smuggling_click(point: Vector2) -> void:
	var hit: Dictionary = SmugglingPanel.hit_test(_smuggling_view, PANEL_RECT, point)
	match str(hit.get("kind", "")):
		"button":
			_switch_view(VIEW_MAP)
		"row":
			_smuggling_cursor = int(hit["index"])
			_smuggling_confirm()


# --- 委托（M4：委托板生成 / 交接与落账 / 后果链）---
#
# 一条闭环：委托板贴出这座城缺什么 → 接下一张 → 回到这座城办理 → 选一个做法
# → 玩家的钱与名声当场结清，城市的那一份排进月末的变更队列（10.4 节：月中不变）
# → 若干月后延迟后果到点，再落一次账并留在事件流里。
#
# 板子是城市六维与世界标记的纯函数（QuestBoard），所以它不落盘；落盘的只有玩家
# 接下的那些（world.quests），因为那才是玩家欠世界的账。

## 打开委托界面。不指定城市时落在化身所在的城；在野外就落在第一座城，
## 反正 ←→ 随时能换，而且标题会写明"你不在这座城"。
func _enter_quest(city_id: String = "") -> void:
	if _sim == null or _world.avatar == null:
		_status.text = "还没有化身，先完成开局创建。"
		return
	var ids: Array = Array(_world.get_city_ids())
	if ids.is_empty():
		return
	var target: String = city_id
	if target.is_empty():
		target = _here_city_id()
	if target.is_empty() or not ids.has(target):
		target = str(ids[0])
	_quest_city_id = target
	_quest_cursor = 0
	_quest_branch_cursor = 0
	_quest_mode = QuestViewModel.MODE_BOARD
	_switch_view(VIEW_QUEST)
	_status.text = "委托板：接下这座城缺的活，办完它这座城市会记住。"


## 化身所在的城。在野外返回空串——委托只能在城里接与办。
func _here_city_id() -> String:
	if _world == null or _world.avatar == null:
		return ""
	return _grid.get_city_id_at(_world.avatar.pos_x, _world.avatar.pos_y)


func _refresh_quest() -> void:
	if _quest_city_id.is_empty():
		_quest_city_id = _selected_city_id()
	var month: int = Clock.total_months()
	# 手上没办完的委托不分城市全都列出来：玩家会跑出去，忘了自己在别处还欠着账
	var active: Array = []
	for quest in _world.get_quests():
		if quest.is_active():
			active.append(quest)
	_quest_view = QuestViewModel.build(
		_world,
		_sim.quests.list_available(_quest_city_id, month),
		active,
		_quest_city_id,
		_here_city_id(),
		_table("cityNames"),
		_quest_cursor,
		_sim.quests.rules(),
		_quest_mode
	)
	_quest_cursor = int(_quest_view.get("cursor", 0))
	_quest_branch_cursor = clampi(
		_quest_branch_cursor, 0, maxi(0, (_quest_view.get("branches", []) as Array).size() - 1)
	)
	# 抉择是"对某一张单子"的抉择。光标一移开就退回看板，免得在另一张单子上
	# 执行上一步选的选项。
	if _quest_mode == QuestViewModel.MODE_BRANCH and not _quest_selected_is_deliverable():
		_quest_mode = QuestViewModel.MODE_BOARD
		_quest_view["mode"] = QuestViewModel.MODE_BOARD


func _quest_selected_is_deliverable() -> bool:
	var selected: Dictionary = _quest_view.get("selected", {})
	if str(selected.get("kind", "")) != QuestViewModel.ROW_KIND_ACTIVE:
		return false
	return bool(selected.get("canDeliver", false))


## ←→ 换城市。板子与候选都跟着重算，光标回到第一行。
func _quest_cycle_city(delta: int) -> void:
	var ids: Array = Array(_world.get_city_ids())
	if ids.is_empty():
		return
	var index: int = ids.find(_quest_city_id)
	_quest_city_id = str(ids[posmod((index if index >= 0 else 0) + delta, ids.size())])
	_quest_cursor = 0
	_quest_mode = QuestViewModel.MODE_BOARD
	_refresh()


func _quest_move_cursor(delta: int) -> void:
	var count: int = maxi(1, int(_quest_view.get("rowCount", 0)))
	_quest_cursor = posmod(_quest_cursor + delta, count)
	_quest_mode = QuestViewModel.MODE_BOARD
	_refresh()


func _quest_move_branch_cursor(delta: int) -> void:
	var count: int = maxi(1, (_quest_view.get("branches", []) as Array).size())
	_quest_branch_cursor = posmod(_quest_branch_cursor + delta, count)
	_refresh()


## 回车。看板上是"接受 / 办理"，抉择里是"执行这个做法"。
func _quest_confirm() -> void:
	if _quest_mode == QuestViewModel.MODE_BRANCH:
		_quest_execute_branch(_quest_branch_cursor)
		return
	var rows: Array = _quest_view.get("rows", [])
	if rows.is_empty():
		_status.text = "这座城现在没有可接的活。"
		_refresh()
		return
	var row: Dictionary = rows[clampi(_quest_cursor, 0, rows.size() - 1)]
	if str(row.get("kind", "")) == QuestViewModel.ROW_KIND_OFFER:
		_quest_accept(str(row.get("questId", "")))
		return
	if not bool(row.get("canDeliver", false)):
		_status.text = str(row.get("blockedReason", "现在办不了这张委托。"))
		_refresh()
		return
	# 进抉择：把这张单子的做法与各自动静摊开
	_quest_mode = QuestViewModel.MODE_BRANCH
	_quest_branch_cursor = 0
	_status.text = "「%s」怎么办？" % str(row.get("title", ""))
	_refresh()


## 放弃光标所在的那张委托。不扣声誉——账是交付时才结的，人还没交付就没什么可扣；
## 但名额腾出来了（上限是硬的，否则"先办掉几张"就是一句玩家做不到的话）。
##
## 读的是 rows[_quest_cursor] 而不是 view 里的 selected：光标与行号都是活的，
## 快照只用于画上一次那一屏（走私界面踩过这个坑）。
func _quest_abandon() -> void:
	var rows: Array = _quest_view.get("rows", [])
	if rows.is_empty():
		return
	var row: Dictionary = rows[clampi(_quest_cursor, 0, rows.size() - 1)]
	if str(row.get("kind", "")) != QuestViewModel.ROW_KIND_ACTIVE:
		return
	var result: Dictionary = _sim.quests.abandon(str(row.get("questId", "")))
	if bool(result.get("ok", false)):
		_status.text = "把「%s」让给了别人。" % str(row.get("title", ""))
	else:
		_status.text = "放弃不了：%s" % str(result.get("error", ""))
	_refresh()


func _quest_accept(quest_id: String) -> void:
	var result: Dictionary = _sim.quests.accept(quest_id, Clock.total_months())
	if bool(result.get("ok", false)):
		_status.text = "接下了%s的委托。" % str(_table("cityNames").get(
			str(result.get("cityId", "")), str(result.get("cityId", ""))))
	else:
		_status.text = "接不了：%s" % str(result.get("error", ""))
	_refresh()


## 执行光标所在的选项。普通选项直接交付；带战斗的那一行先打一场，
## 打完之后由战场上的处置（M5.4 的倒地选择）决定交付后果。
func _quest_execute_branch(index: int) -> void:
	var branches: Array = _quest_view.get("branches", [])
	if branches.is_empty():
		_status.text = "要回到委托所在的城市才能办理。"
		_refresh()
		return
	var branch: Dictionary = branches[clampi(index, 0, branches.size() - 1)]
	var quest_id: String = str(_quest_view.get("selected", {}).get("questId", ""))
	if bool(branch.get("isCombat", false)):
		_start_quest_combat(quest_id)
		return
	_quest_complete(quest_id, str(branch.get("branchId", "")))


## 交付。城市的变更请求在这里提交、月末落账——玩家自己的钱与名声当场结清。
func _quest_complete(quest_id: String, branch_id: String) -> void:
	var result: Dictionary = _sim.quests.complete(quest_id, branch_id, Clock.total_months())
	if not bool(result.get("ok", false)):
		_status.text = "交不了：%s" % str(result.get("error", ""))
		_refresh()
		return
	var change: StateChange = result.get("change", null)
	if change != null:
		var submitted: Dictionary = _sim.apply_state_change(change)
		if not bool(submitted.get("ok", false)):
			_status.text = "城市的账没能提交：%s" % str(submitted.get("error", ""))
			_refresh()
			return
	_quest_mode = QuestViewModel.MODE_BOARD
	_status.text = _quest_outcome_text(result)
	_refresh()


## 交付结果的说明行。摆在状态行上让玩家看见"我这一下改变了什么"——
## 城市的数字要等月末，所以这里写的是"已提交、月末落账"，不是"已经涨了"。
func _quest_outcome_text(result: Dictionary) -> String:
	var parts: Array = [str(result.get("label", ""))]
	var state_delta: int = int(result.get("stateDelta", 0))
	if state_delta != 0:
		parts.append("%s %+d（月末落账）" % [
			str(City.DIMENSION_LABELS.get(str(result.get("dimension", "")), "")), state_delta
		])
	if int(result.get("money", 0)) > 0:
		parts.append("得 %s" % AvatarViewModel.money_label(int(result.get("money", 0))))
	if int(result.get("reputation", 0)) != 0:
		parts.append("声誉 %+d" % int(result.get("reputation", 0)))
	if int(result.get("karma", 0)) != 0:
		parts.append("善恶 %+d" % int(result.get("karma", 0)))
	return " · ".join(PackedStringArray(parts))


func _quest_click(point: Vector2) -> void:
	var hit: Dictionary = QuestPanel.hit_test(_quest_view, PANEL_RECT, point)
	match str(hit.get("kind", "")):
		"button":
			if str(hit.get("id", "")) == "cancel":
				_quest_mode = QuestViewModel.MODE_BOARD
				_refresh()
				return
			if str(hit.get("id", "")) == "abandon":
				_quest_abandon()
				return
			_switch_view(VIEW_MAP)
		"row":
			# 点一行先挪光标与展开详情，再点同一行才执行——免得鼠标扫过列表就把
			# 单子接了。走私界面是"点行即执行"，那里一行的后果是一进一出；委托
			# 误点则会凭空欠世界一张单子，值得多一次确认。
			var index: int = int(hit["index"])
			if index == _quest_cursor:
				_quest_confirm()
				return
			_quest_cursor = index
			_quest_mode = QuestViewModel.MODE_BOARD
			_refresh()
		"branch":
			_quest_branch_cursor = int(hit["index"])
			_quest_execute_branch(_quest_branch_cursor)


func _quest_input(key_event: InputEventKey) -> void:
	match key_event.keycode:
		KEY_LEFT, KEY_A:
			if _quest_mode == QuestViewModel.MODE_BRANCH:
				return
			_quest_cycle_city(-1)
		KEY_RIGHT, KEY_D:
			if _quest_mode == QuestViewModel.MODE_BRANCH:
				return
			_quest_cycle_city(1)
		KEY_UP, KEY_W:
			if _quest_mode == QuestViewModel.MODE_BRANCH:
				_quest_move_branch_cursor(-1)
			else:
				_quest_move_cursor(-1)
		KEY_DOWN, KEY_S:
			if _quest_mode == QuestViewModel.MODE_BRANCH:
				_quest_move_branch_cursor(1)
			else:
				_quest_move_cursor(1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_quest_confirm()
		KEY_DELETE, KEY_BACKSPACE:
			# 只在看板上放弃：抉择里的 Del 容易被当成"退回"按出去
			if _quest_mode == QuestViewModel.MODE_BOARD:
				_quest_abandon()
		KEY_ESCAPE, KEY_T, KEY_Q:
			if _quest_mode == QuestViewModel.MODE_BRANCH:
				_quest_mode = QuestViewModel.MODE_BOARD
				_refresh()
				return
			_switch_view(VIEW_MAP)


# --- 委托：接一场仗 ---

## 从委托里打起来的那一场。对手挂着委托里的名号（盗匪 / 乱兵），
## 打完之后的处置决定交付后果，所以这一场的结果不能丢。
func _start_quest_combat(quest_id: String) -> void:
	var quest: Quest = _world.find_quest(quest_id)
	if quest == null:
		_status.text = "这张委托已经不在了。"
		_refresh()
		return
	var avatar: PlayerAvatar = _world.avatar
	_quest_combat = {"questId": quest_id, "cityId": quest.city_id}

	_combat_seq += 1
	var rng := DeterministicRNG.new(_world.world_seed ^ (_combat_seq * 2246822519))
	_combat = Combat.new(
		_derived,
		ContentLoader.get_balance_section("combat"),
		ContentLoader.get_skills(),
		ContentLoader.get_items(),
		rng
	)
	var config: Dictionary = ContentLoader.get_quest_type(quest.quest_type)
	var label: String = str(config.get("combat", {}).get("opponentLabel", "对手"))
	var units: Array = [_player_unit_spec(avatar)]
	units.append_array(_named_opponents(_opponent_specs(quest.city_id, rng), label))
	var started: Dictionary = _combat.start({
		"sessionId": "quest-combat-%04d" % _combat_seq,
		"units": units,
		"obstacles": _battle_obstacles(),
	})
	if not bool(started.get("ok", false)):
		_status.text = "战斗没能开始：%s" % str(started.get("reason", ""))
		_combat = null
		_quest_combat = {}
		_refresh()
		return

	_combat_menu_mode = CombatViewModel.MENU_MAIN
	_combat_cursor = 0
	_combat_pending = {}
	_combat_cursor_tile = Vector2i.ZERO
	_switch_view(VIEW_COMBAT)
	_status.text = "%s：%d 对 %d。打完怎么处置倒地的人，就按那个交差。" % [
		label, 1, maxi(0, _combat.units.size() - 1)
	]
	_drive_enemies()


## 把陪练对手改挂上委托里的名号。规模与属性沿用训练战那一套——
## 委托战斗不该另有一套强度曲线，那会让"这一仗有多难"变成第二个真相。
func _named_opponents(specs: Array, label: String) -> Array:
	var out: Array = []
	for i in range(specs.size()):
		var spec: Dictionary = specs[i]
		spec["name"] = "%s %d" % [label, i + 1]
		out.append(spec)
	return out


## 委托战斗收尾：按胜负与战场上的处置挑一个结局，交给 QuestSystem 交付。
func _resolve_quest_combat() -> void:
	if _quest_combat.is_empty() or _combat == null:
		return
	var quest_id: String = str(_quest_combat.get("questId", ""))
	_quest_combat = {}
	var won: bool = _combat.winner == Combat.RESULT_PLAYER
	_sync_combat_skills_to_avatar()
	var branch_id: String = QuestSystem.COMBAT_PREFIX + _combat_outcome_key(won)
	var result: Dictionary = _sim.quests.complete(quest_id, branch_id, Clock.total_months())
	if not bool(result.get("ok", false)):
		_status.text = "委托没能了结：%s" % str(result.get("error", ""))
		return
	var change: StateChange = result.get("change", null)
	if change != null:
		_sim.apply_state_change(change)
	_quest_mode = QuestViewModel.MODE_BOARD
	_status.text = "%s · %s" % [
		"你赢了" if won else "你输了", _quest_outcome_text(result)
	]


## 战场上的处置 → 配置里的结局名。一个敌人一种处置，这里取最重的那个：
## 补刀 > 俘虏 > 放走 > 搜身。打输了直接是 defeat。
##
## 取"最重"而不是"第一个"：一场仗里对两个人分别做了不同处置时，
## 玩家看到的是自己做过的最狠的那一件算数，这比按遍历顺序取更可预期。
func _combat_outcome_key(won: bool) -> String:
	if not won:
		return "defeat"
	var priority: Array = [
		Combat.DOWNED_FINISH, Combat.DOWNED_CAPTURE,
		Combat.DOWNED_RELEASE, Combat.DOWNED_SEARCH,
	]
	for choice in priority:
		for flag in _combat.world_flags:
			if str(flag).begins_with("combat.%s." % str(choice)):
				return str(choice)
	# 一个倒地者都没处置过（理论上不会发生：战斗要等处置做完才结束），
	# 退回"放走"——总比默认成屠杀好
	return Combat.DOWNED_RELEASE


# --- 城市事件（M7.1：触发 / 持续 / 三个做法 / 传奇航线）---
#
# 与委托的分别：委托是玩家去接的活，事件是城里自己出的事。玩家能做的只有
# "处置它"，而三个做法各有一套后果——其中讨伐要真打一场。
#
# 一件事分三段落地，正好是三种不同的时间：
#   触发时  城被扣一笔，该城的航线收益整条中断（当月的月度结算里就发生）
#   未了结  每月继续流血，直到有人管它或者世界自己缓过来
#   了结时  玩家自己的钱/名声当场结清，城市的增量排进月末队列，世界标记与
#           传奇航线是往后的事

## 打开城中大事。不指定城市时落在化身所在的城，与委托板同一套走法。
func _enter_event(city_id: String = "") -> void:
	if _sim == null or _world.avatar == null:
		_status.text = "还没有化身，先完成开局创建。"
		return
	var ids: Array = Array(_world.get_city_ids())
	if ids.is_empty():
		return
	var target: String = city_id
	if target.is_empty():
		target = _here_city_id()
	if target.is_empty() or not ids.has(target):
		target = str(ids[0])
	_event_city_id = target
	_event_cursor = 0
	_event_branch_cursor = 0
	_event_mode = EventViewModel.MODE_LIST
	_switch_view(VIEW_EVENT)
	_status.text = "城中大事：出了事总得有人管，不管它城就一直在流血。"


func _refresh_event() -> void:
	if _event_city_id.is_empty():
		_event_city_id = _selected_city_id()
	_event_view = EventViewModel.build(
		_world,
		_world.get_events(),
		_event_city_id,
		_here_city_id(),
		_table("cityNames"),
		_event_cursor,
		_event_mode
	)
	_event_cursor = int(_event_view.get("cursor", 0))
	_event_branch_cursor = clampi(
		_event_branch_cursor, 0, maxi(0, (_event_view.get("branches", []) as Array).size() - 1)
	)
	# 抉择是"对某一件事"的抉择。光标一移开（或移到已了结的那一行）就退回列表，
	# 免得在另一件事上执行上一步选的做法。
	if _event_mode == EventViewModel.MODE_BRANCH \
			and not bool(_event_view.get("selectedIsActive", false)):
		_event_mode = EventViewModel.MODE_LIST
		_event_view["mode"] = EventViewModel.MODE_LIST


func _event_cycle_city(delta: int) -> void:
	var ids: Array = Array(_world.get_city_ids())
	if ids.is_empty():
		return
	var index: int = ids.find(_event_city_id)
	_event_city_id = str(ids[posmod((index if index >= 0 else 0) + delta, ids.size())])
	_event_cursor = 0
	_event_mode = EventViewModel.MODE_LIST
	_refresh()


func _event_move_cursor(delta: int) -> void:
	var count: int = maxi(1, int(_event_view.get("rowCount", 0)))
	_event_cursor = posmod(_event_cursor + delta, count)
	_event_mode = EventViewModel.MODE_LIST
	_refresh()


func _event_move_branch_cursor(delta: int) -> void:
	var count: int = maxi(1, (_event_view.get("branches", []) as Array).size())
	_event_branch_cursor = posmod(_event_branch_cursor + delta, count)
	_refresh()


## 回车。列表上是"看看怎么办"，抉择里是"就按这么做"。
##
## 已了结的那些行照样能选中——它们的用处是回答"这事还会不会再来"，
## 但没有任何可执行的东西，所以这里只把上一次的收场说清楚。
func _event_confirm() -> void:
	if _event_mode == EventViewModel.MODE_BRANCH:
		_event_execute_branch(_event_branch_cursor)
		return
	var rows: Array = _event_view.get("rows", [])
	if rows.is_empty():
		_status.text = "这座城眼下没什么大事。"
		_refresh()
		return
	var row: Dictionary = rows[clampi(_event_cursor, 0, rows.size() - 1)]
	if str(row.get("kind", "")) != EventViewModel.ROW_KIND_ACTIVE:
		_status.text = "「%s」%s（%s）。" % [
			str(row.get("title", "")), str(row.get("reason", "")),
			str(row.get("outcomeLabel", "")),
		]
		_refresh()
		return
	if not bool(row.get("canResolve", false)):
		_status.text = str(row.get("blockedReason", "现在处置不了这件事。"))
		_refresh()
		return
	_event_mode = EventViewModel.MODE_BRANCH
	_event_branch_cursor = 0
	_status.text = "「%s」怎么办？" % str(row.get("title", ""))
	_refresh()


## 执行光标所在的做法。讨伐那一行先打一场，胜负决定走哪一套后果；
## 其余两个做法当场结算。
func _event_execute_branch(index: int) -> void:
	var branches: Array = _event_view.get("branches", [])
	if branches.is_empty():
		_status.text = "要回到事发的那座城才能处置。"
		_refresh()
		return
	var branch: Dictionary = branches[clampi(index, 0, branches.size() - 1)]
	var event_id: String = str(_event_view.get("selected", {}).get("eventId", ""))
	if bool(branch.get("isCombat", false)):
		_start_event_combat(event_id)
		return
	_event_resolve(event_id, str(branch.get("branchId", "")))


func _event_resolve(event_id: String, branch_id: String) -> void:
	var result: Dictionary = _sim.events.resolve(event_id, branch_id, Clock.total_months())
	if not bool(result.get("ok", false)):
		_status.text = "处置不了：%s" % str(result.get("error", ""))
		_refresh()
		return
	_event_mode = EventViewModel.MODE_LIST
	_status.text = _event_apply_result(result)
	_refresh()


## 把一次了结的产物落进世界，并给出状态行的说明。
##
## 事件模块只产出请求（变更、解锁航线的描述），提交与建航线是调用方的事——
## 与委托交付同一条分工（QuestSystem.complete 的说明）。分两层的好处是事件模块
## 不必引用 WorldSim，依赖方向保持单向。
func _event_apply_result(result: Dictionary) -> String:
	for change in result.get("changes", []):
		var submitted: Dictionary = _sim.apply_state_change(change)
		if not bool(submitted.get("ok", false)):
			return "城市的账没能提交：%s" % str(submitted.get("error", ""))
	return _event_outcome_text(result) + _event_unlock_route(result)


## 讨伐的报酬里那条传奇航线。它归玩家（既然是奖给玩家的东西，进账就不能绕开他，
## 见 WorldSim 的 _apply_player_route_income），所以以 OWNER_PLAYER 建。
##
## 建不起来也不该把这次了结算失败：后果已经落账了，航线是额外的彩头。
func _event_unlock_route(result: Dictionary) -> String:
	var unlock: Dictionary = result.get("unlockRoute", {})
	if unlock.is_empty():
		return ""
	var city_a: String = str(unlock.get("cityA", ""))
	var city_b: String = str(unlock.get("cityB", ""))
	var kind: String = str(unlock.get("kind", TradeRoute.KIND_LEGENDARY))
	var established: Dictionary = _sim.establish_route(
		city_a, city_b, kind, Clock.total_months(), TradeRoute.OWNER_PLAYER
	)
	var route_label: String = WorldSim.route_kind_label(kind)
	if not bool(established.get("ok", false)):
		return " · %s没能开通：%s" % [route_label, str(established.get("error", ""))]
	return " · %s ↔ %s 的%s归你了" % [
		str(_table("cityNames").get(city_a, city_a)),
		str(_table("cityNames").get(city_b, city_b)),
		route_label,
	]


## 了结结果的说明行。城市的数字要等月末，所以这里写的是"已提交、月末落账"，
## 不是"已经涨了"——与委托交付的状态行同一个口径。
func _event_outcome_text(result: Dictionary) -> String:
	var parts: Array = [str(result.get("label", ""))]
	for entry in result.get("deltas", []):
		parts.append("%s %+d（月末落账）" % [
			str(City.DIMENSION_LABELS.get(str(entry.get("dimension", "")), "")),
			int(entry.get("delta", 0)),
		])
	if int(result.get("reputation", 0)) != 0:
		parts.append("声誉 %+d" % int(result.get("reputation", 0)))
	if int(result.get("karma", 0)) != 0:
		parts.append("善恶 %+d" % int(result.get("karma", 0)))
	if bool(result.get("recurrence", false)):
		parts.append("病根未除，日后可能再犯")
	if not bool(result.get("eventEnded", true)):
		parts.append("事还没了，城还封着")
	return " · ".join(PackedStringArray(parts))


## 点一行先挪光标与展开详情，再点同一行才进抉择——与委托板同一条理由：
## 鼠标扫过列表就把整座城的命运押上去，值得多一次确认。
func _event_click(point: Vector2) -> void:
	var hit: Dictionary = EventPanel.hit_test(_event_view, PANEL_RECT, point)
	match str(hit.get("kind", "")):
		"button":
			if str(hit.get("id", "")) == "cancel":
				_event_mode = EventViewModel.MODE_LIST
				_refresh()
				return
			_switch_view(VIEW_MAP)
		"row":
			var index: int = int(hit["index"])
			if index == _event_cursor:
				_event_confirm()
				return
			_event_cursor = index
			_event_mode = EventViewModel.MODE_LIST
			_refresh()
		"branch":
			_event_branch_cursor = int(hit["index"])
			_event_execute_branch(_event_branch_cursor)


func _event_input(key_event: InputEventKey) -> void:
	match key_event.keycode:
		KEY_LEFT, KEY_A:
			if _event_mode == EventViewModel.MODE_BRANCH:
				return
			_event_cycle_city(-1)
		KEY_RIGHT, KEY_D:
			if _event_mode == EventViewModel.MODE_BRANCH:
				return
			_event_cycle_city(1)
		KEY_UP, KEY_W:
			if _event_mode == EventViewModel.MODE_BRANCH:
				_event_move_branch_cursor(-1)
			else:
				_event_move_cursor(-1)
		KEY_DOWN, KEY_S:
			if _event_mode == EventViewModel.MODE_BRANCH:
				_event_move_branch_cursor(1)
			else:
				_event_move_cursor(1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_event_confirm()
		KEY_ESCAPE, KEY_T, KEY_E:
			if _event_mode == EventViewModel.MODE_BRANCH:
				_event_mode = EventViewModel.MODE_LIST
				_refresh()
				return
			_switch_view(VIEW_MAP)


# --- 商铺与黑市（《数值框架》9.3 动态物价）---
#
# 买卖是"当场结清"：钱与货在 Economy.execute_trade 里就落了账，不进变更队列，
# 城市六维一动不动——物价只读城市状态（D-43）。这也是它必须亲自到场的原因：
# 换一座城买，价就不一样，而"走过去"这件事本身就是要付的代价（D-44）。

## 打开商铺界面。不指定城市时落在化身所在的城；在野外就落在第一座城，
## 那时页脚会写明"你不在这座城"——看得到价，做不成买卖。
func _enter_trade(city_id: String = "") -> void:
	if _sim == null:
		return
	var ids: Array = Array(_world.get_city_ids())
	if ids.is_empty():
		return
	var target: String = city_id
	if target.is_empty():
		target = _here_city_id()
	if target.is_empty() or not ids.has(target):
		target = str(ids[0])
	_trade_city_id = target
	_trade_cursor = 0
	_trade_side = TradeViewModel.SIDE_BUY
	_trade_channel = Economy.CHANNEL_SHOP
	_trade_pane = TradeViewModel.PANE_TRADE
	_switch_view(VIEW_TRADE)
	_status.text = "商铺：这座城摆得出什么货、按什么价收，都写在这张价目上。"


func _refresh_trade() -> void:
	if _trade_city_id.is_empty():
		_trade_city_id = _selected_city_id()
	_trade_view = TradeViewModel.build(
		_world,
		_sim.economy,
		_lookups,
		_trade_city_id,
		_here_city_id(),
		_trade_channel,
		_trade_side,
		_trade_cursor,
		_trade_pane
	)
	_trade_cursor = int(_trade_view.get("cursor", 0))
	# 换了城市或渠道之后，原来那条渠道可能不成立（黑市只存在于少数几座城），
	# 视图模型不会替你换回来——它只是照实说"这里没有黑市"。所以反过来：
	# 走到没有黑市的城时退回商铺，免得玩家对着一张空货架找原因。
	if _trade_pane == TradeViewModel.PANE_TRADE \
			and _trade_channel == Economy.CHANNEL_BLACK_MARKET \
			and not bool(_trade_view.get("hasBlackMarket", false)):
		_trade_channel = Economy.CHANNEL_SHOP
		_refresh_trade()


func _trade_cycle_city(delta: int) -> void:
	var ids: Array = Array(_world.get_city_ids())
	if ids.is_empty():
		return
	var index: int = ids.find(_trade_city_id)
	_trade_city_id = str(ids[posmod((index if index >= 0 else 0) + delta, ids.size())])
	_trade_cursor = 0
	_refresh()


func _trade_move_cursor(delta: int) -> void:
	var count: int = maxi(1, int(_trade_view.get("rowCount", 0)))
	_trade_cursor = posmod(_trade_cursor + delta, count)
	_refresh()


## 买 ⇄ 卖。光标归零：两边的列表是两份不同的东西，"上次看的是第 5 件"
## 换到另一边毫无意义。
func _trade_switch_side() -> void:
	_trade_side = TradeViewModel.SIDE_SELL \
		if _trade_side == TradeViewModel.SIDE_BUY else TradeViewModel.SIDE_BUY
	_trade_cursor = 0
	_status.text = "%s：%s" % [
		str(_trade_view.get("cityLabel", "")),
		"看货架上的价" if _trade_side == TradeViewModel.SIDE_BUY else "看你身上能卖的东西",
	]
	_refresh()


## 商铺 ⇄ 黑市。黑市只在有它的城开张，所以换过去之前先看一眼——没有就直说。
func _trade_switch_channel() -> void:
	if _trade_channel == Economy.CHANNEL_SHOP:
		if not bool(_trade_view.get("hasBlackMarket", false)):
			_status.text = "%s 没有黑市。" % str(_trade_view.get("cityLabel", ""))
			return
		_trade_channel = Economy.CHANNEL_BLACK_MARKET
	else:
		_trade_channel = Economy.CHANNEL_SHOP
	_trade_cursor = 0
	_status.text = "换到%s。" % Economy.channel_label(_trade_channel)
	_refresh()


## 回车。买卖页就是成交，铁匠铺页就是敲一炉——两页的动作不同，所以按视图模型
## 给出的 pane 分派，不在这里自己数"现在在哪一页"。
func _trade_confirm() -> void:
	if _trade_pane == TradeViewModel.PANE_FORGE:
		_forge_confirm()
		return
	if _trade_pane == TradeViewModel.PANE_REPAIR:
		_repair_confirm()
		return
	if not bool(_trade_view.get("canTrade", false)):
		_status.text = str(_trade_view.get("blockedReason", "现在做不成这笔买卖。"))
		_refresh()
		return
	var row: Dictionary = _trade_view.get("selected", {})
	# 卖的是具体那一件：同名多件时界面点的是哪一行，卖的就是哪一件
	var result: Dictionary = _sim.economy.execute_trade(
		_world,
		_trade_city_id,
		str(row.get("templateId", "")),
		_trade_side,
		_trade_channel,
		str(row.get("instanceId", ""))
	)
	if not bool(result.get("ok", false)):
		_status.text = "做不成：%s" % str(result.get("error", ""))
		_refresh()
		return
	var verb: String = "买入" if _trade_side == TradeViewModel.SIDE_BUY else "卖出"
	_status.text = "%s %s，%s %s；身上还剩 %s。" % [
		verb,
		str(result.get("displayName", "")),
		"付了" if _trade_side == TradeViewModel.SIDE_BUY else "到手",
		AvatarViewModel.money_label(int(result.get("money", 0))),
		AvatarViewModel.money_label(int(result.get("moneyAfter", 0))),
	]
	_refresh()


## 点一行先挪光标，再点同一行才成交——与委托板、城中大事同一条理由：
## 鼠标扫过列表就把钱花出去，值得多一次确认。
func _trade_click(point: Vector2) -> void:
	var hit: Dictionary = TradePanel.hit_test(_trade_view, PANEL_RECT, point)
	match str(hit.get("kind", "")):
		"button":
			match str(hit.get("id", "")):
				"deal":
					_trade_confirm()
				"side":
					_trade_switch_side()
				"channel":
					_trade_switch_channel()
				"forge":
					_trade_enter_forge()
				"leaveForge":
					_trade_leave_forge()
				_:
					_switch_view(VIEW_MAP)
		"row":
			var index: int = int(hit["index"])
			if index == _trade_cursor:
				_trade_confirm()
				return
			_trade_cursor = index
			_refresh()


func _trade_input(key_event: InputEventKey) -> void:
	match key_event.keycode:
		KEY_LEFT, KEY_A:
			_trade_cycle_city(-1)
		KEY_RIGHT, KEY_D:
			_trade_cycle_city(1)
		KEY_UP, KEY_W:
			_trade_move_cursor(-1)
		KEY_DOWN, KEY_S:
			_trade_move_cursor(1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_trade_confirm()
		KEY_TAB:
			if _trade_pane == TradeViewModel.PANE_TRADE:
				_trade_switch_side()
		KEY_X:
			if _trade_pane == TradeViewModel.PANE_TRADE:
				_trade_switch_channel()
		KEY_F:
			if _trade_pane == TradeViewModel.PANE_FORGE:
				_trade_leave_forge()
			elif _trade_pane == TradeViewModel.PANE_REPAIR:
				_trade_enter_forge()
			else:
				_trade_enter_repair()
		KEY_G:
			if _trade_pane == TradeViewModel.PANE_REPAIR:
				_trade_cycle_repair_tier()
		KEY_ESCAPE, KEY_T:
			_switch_view(VIEW_MAP)


# --- 铁匠铺 ---

## 进铁匠铺。光标归零：两页的列表是两份不同的东西，"上次看的是第 5 件"
## 换到另一页毫无意义（与切买卖方向同一条理由）。
func _trade_enter_forge() -> void:
	_trade_pane = TradeViewModel.PANE_FORGE
	_trade_cursor = 0
	_status.text = "铁匠铺：只收武器与防具，每级按基础数值加一成，第 3 级起会失手。"
	_refresh()


func _trade_leave_forge() -> void:
	_trade_pane = TradeViewModel.PANE_TRADE
	_trade_cursor = 0
	_status.text = "回到商铺。"
	_refresh()


## 进修理页。与强化同一块版面，但只谈"修"，不谈"烧"。
func _trade_enter_repair() -> void:
	_trade_pane = TradeViewModel.PANE_REPAIR
	_trade_cursor = 0
	_trade_repair_tier = ItemInstance.REPAIR_CRAFTSMAN
	_status.text = "修理：工匠修回九成，满修修到满（按强化等级加价）。G 切档位，回车修。"
	_refresh()


func _trade_leave_repair() -> void:
	_trade_pane = TradeViewModel.PANE_TRADE
	_trade_cursor = 0
	_status.text = "回到商铺。"
	_refresh()


## G：在工匠/满修之间换档位。只在这两档之间切——便携工具不占炉子（背包里用）。
func _trade_cycle_repair_tier() -> void:
	_trade_repair_tier = ItemInstance.REPAIR_FULL \
		if _trade_repair_tier == ItemInstance.REPAIR_CRAFTSMAN else ItemInstance.REPAIR_CRAFTSMAN
	var label: String = _gear.rules().repair_tier_label(_trade_repair_tier)
	_status.text = "修理档位切到：%s。回车修理当前这一件。" % label
	_refresh()


## 修这一件。档位用 G 定下的那个；便携工具不在这块版面（D-64）。先扣工钱再修，
## 钱不够或已经不需要修是同一句话的位置——与 forge 同一条边界。
func _repair_confirm() -> void:
	if _world.avatar == null:
		return
	if not bool(_trade_view.get("canTrade", false)):
		_status.text = str(_trade_view.get("blockedReason", "这一件现在修不成。"))
		_refresh()
		return
	var row: Dictionary = _trade_view.get("selected", {})
	var instance_id: String = str(row.get("instanceId", ""))
	var instance: Dictionary = _world.avatar.item_instances.get(instance_id, {})
	var rules: ItemInstance = _gear.rules()
	var cost: int = rules.repair_cost(instance, _trade_repair_tier)
	if cost > _world.avatar.money:
		_status.text = "修不起：%s 档要 %s，你只有 %s。" % [
			rules.repair_tier_label(_trade_repair_tier),
			AvatarViewModel.money_label(cost),
			AvatarViewModel.money_label(_world.avatar.money),
		]
		_refresh()
		return
	var before: int = rules.durability(instance)
	var result: Dictionary = rules.apply_repair(instance, _trade_repair_tier)
	if not bool(result.get("ok", false)):
		_status.text = "修不成：%s" % str(result.get("error", ""))
		_refresh()
		return
	_world.avatar.money -= cost
	_status.text = "「%s」%s，耐久 %d → %d，花了 %s。" % [
		rules.display_name(instance),
		rules.repair_tier_label(_trade_repair_tier),
		before, int(result.get("after", before)),
		AvatarViewModel.money_label(int(result.get("cost", 0))),
	]
	_refresh()


## 敲一炉。规则、成功率与工钱都在 ItemInstance.forge 里，这里只负责三件事：
## 给一个随机源、扣钱、把结果说清楚。判定与扣钱放在同一步，不留"扣了钱没改成"的中间态。
func _forge_confirm() -> void:
	if _world.avatar == null:
		return
	if not bool(_trade_view.get("canTrade", false)):
		_status.text = str(_trade_view.get("blockedReason", "这一炉现在敲不成。"))
		_refresh()
		return
	var row: Dictionary = _trade_view.get("selected", {})
	var instance_id: String = str(row.get("instanceId", ""))
	var instance: Dictionary = _world.avatar.item_instances.get(instance_id, {})
	var rules: ItemInstance = _gear.rules()
	_forge_seq += 1
	var result: Dictionary = rules.forge(
		instance, _world.avatar.money,
		DeterministicRNG.new(_world.world_seed ^ (_forge_seq * 40503))
	)
	if not bool(result.get("ok", false)):
		_status.text = "敲不成：%s" % str(result.get("error", ""))
		_refresh()
		return
	_world.avatar.money -= int(result.get("cost", 0))
	_status.text = _forge_result_text(result, rules, instance)
	_refresh()


## 一次敲炉的说明行。成败与掉级都要写出来——状态行是唯一会告诉玩家
## "刚才那一炉到底怎么了"的地方，而"没成"与"掉了"是两件事。
func _forge_result_text(
	result: Dictionary, rules: ItemInstance, instance: Dictionary
) -> String:
	var template: Dictionary = rules.template_of(str(instance.get("templateId", "")))
	var name: String = str(template.get("displayName", ""))
	var before: int = int(result.get("levelBefore", 0))
	var after: int = int(result.get("levelAfter", 0))
	var cost: String = AvatarViewModel.money_label(int(result.get("cost", 0)))
	if bool(result.get("upgraded", false)):
		return "「%s」锻成了 +%d，花了 %s。" % [name, after, cost]
	if after == before:
		return "这一炉没成：「%s」原样留在 %s，%s 照扣。" % [
			name, _level_label(before), cost
		]
	return "这一炉没成：「%s」从 %s 退到 %s，%s 照扣。" % [
		name, _level_label(before), _level_label(after), cost
	]


func _level_label(level: int) -> String:
	return "未强化" if level <= 0 else "+%d" % level


# --- 事件：讨伐利维坦 ---

## 打一场。对手写在 events.json 里，所以这一场不是"随机拉两个同城居民"，
## 而是一头配得上"封港"这两个字的巨兽。战斗的随机源与世界模拟分开——
## 打不打这一场不该改变城市接下来的演化（同训练战）。
func _start_event_combat(event_id: String) -> void:
	if _world.find_event(event_id) == null:
		_status.text = "这件事已经不在了。"
		_refresh()
		return
	var config: Dictionary = ContentLoader.get_event_template(
		_world.find_event(event_id).template_id
	)
	var raw: Variant = config.get("combat", null)
	var combat_cfg: Dictionary = raw if raw is Dictionary else {}
	if combat_cfg.is_empty():
		_status.text = "「%s」没有可打的分支。" % EventSystem.template_label(config, event_id)
		_refresh()
		return
	var avatar: PlayerAvatar = _world.avatar
	_event_combat = {"eventId": event_id, "cityId": _world.find_event(event_id).city_id}

	_combat_seq += 1
	var rng := DeterministicRNG.new(_world.world_seed ^ (_combat_seq * 2246822519))
	_combat = Combat.new(
		_derived,
		ContentLoader.get_balance_section("combat"),
		ContentLoader.get_skills(),
		ContentLoader.get_items(),
		rng
	)
	var label: String = str(combat_cfg.get("label", "打一场"))
	var units: Array = [_player_unit_spec(avatar), _event_opponent_spec(combat_cfg, rng)]
	var started: Dictionary = _combat.start({
		"sessionId": "event-combat-%04d" % _combat_seq,
		"units": units,
		"obstacles": _battle_obstacles(),
	})
	if not bool(started.get("ok", false)):
		_status.text = "战斗没能开始：%s" % str(started.get("reason", ""))
		_combat = null
		_event_combat = {}
		_refresh()
		return

	_combat_menu_mode = CombatViewModel.MENU_MAIN
	_combat_cursor = 0
	_combat_pending = {}
	_combat_cursor_tile = Vector2i.ZERO
	_switch_view(VIEW_COMBAT)
	_status.text = "%s：1 对 1。赢了港口就开，输了什么都白说。" % label
	_drive_enemies()


## 巨兽的单位规格。数值取自事件配置（初值，需实测，见 D-40），不再现抽属性——
## 利维坦必须是同一头利维坦，玩家的准备才有意义。
func _event_opponent_spec(combat_cfg: Dictionary, _rng: DeterministicRNG) -> Dictionary:
	var raw: Variant = combat_cfg.get("opponent", null)
	var unit: Dictionary = raw if raw is Dictionary else {}
	var attributes: Variant = unit.get("attributes", null)
	var spawn: Array = OPPONENT_SPAWNS[0]
	return {
		"unitId": "unit-enemy-1",
		"side": Combat.SIDE_ENEMY,
		"name": str(unit.get("name", "巨兽")),
		"attributes": (attributes as Dictionary).duplicate() if attributes is Dictionary else {},
		"skills": {},
		"weaponTemplateId": "",
		"armor": int(unit.get("armor", 0)),
		"magicResist": 0,
		"luck": 0,
		"position": spawn.duplicate(),
		"threatLevel": int(unit.get("threatLevel", 10)),
		"hp": int(unit.get("hp", 0)),
		"maxHp": int(unit.get("maxHp", 0)),
	}


## 讨伐的收尾：胜负两套后果二选一，交给 EventSystem 了结。
##
## 与委托的战斗不同，这里不看战场上怎么处置倒地者——利维坦是巨兽，
## 没有"生擒押回城"这回事（events.json 的注释里写着这条取舍）。
func _resolve_event_combat() -> void:
	if _event_combat.is_empty() or _combat == null:
		return
	var event_id: String = str(_event_combat.get("eventId", ""))
	_event_combat = {}
	var won: bool = _combat.winner == Combat.RESULT_PLAYER
	_sync_combat_skills_to_avatar()
	var result: Dictionary = _sim.events.resolve_combat(event_id, won, Clock.total_months())
	if not bool(result.get("ok", false)):
		_status.text = "这件事没能了结：%s" % str(result.get("error", ""))
		return
	_event_mode = EventViewModel.MODE_LIST
	_status.text = "%s · %s" % [
		"你赢了" if won else "你输了", _event_apply_result(result)
	]


# --- 开局创建（M3.1 自由生成 / M3.2 随机转生）---

## 开始新的一生：把创建的活交给 CreationSession，主场景只负责装配它的依赖。
##
## 姓名抽取用一个独立的随机源（种子取自世界种子），不复用世界模拟那个——抽名字
## 不该打乱世界演化的随机序列。
func _enter_creation() -> void:
	_creation_session = CreationSession.new(
		_creator,
		DeterministicRNG.new(_world.world_seed),
		Callable(self, "_roll_rebirth"),
		_table("cityNames")
	)
	_creation_session.enter()
	_switch_view(VIEW_CREATION)
	_status.text = "自由生成：种族、出身、属性、天赋缺陷都能自己挑。按 R 改走随机转生。"


## 抽一具宿主躯壳，供 CreationSession 调用（它不持有世界与时钟）。
## 每次抽取换一个随机源：用固定种子的话连按 R 只会抽到同一具躯壳；
## 种子由世界种子与次数共同决定，因此"同一世界的第 n 次抽取"仍可复现。
func _roll_rebirth(seq: int) -> Dictionary:
	_reincarnation = Reincarnation.new(
		ContentLoader.get_balance_section("reincarnation"),
		_creator,
		DeterministicRNG.new(_world.world_seed ^ (seq * 2654435761))
	)
	return _reincarnation.rebirth(_world, _soul, _soul.luck_carry)


## 把状态行更新成创建流程最近一次的反馈。流程不说话时保持原样——
## 状态行上可能还留着上一条有用的信息，没理由擦掉它。
func _apply_creation_status() -> void:
	if _creation_session == null:
		return
	var message: String = _creation_session.message
	if not message.is_empty():
		_status.text = message


# --- 开局创建：键盘 ---

func _creation_input(key_event: InputEventKey) -> void:
	var session: CreationSession = _creation_session
	# 开局请求统一走下面这一处：流程说的话要先落到状态行，再装配化身——
	# 顺序反了的话，"在某城开始这一生"会被流程上一条旧反馈（比如"改回自由生成。"）
	# 盖掉，而那条反馈说的是上一件事。
	var request: Dictionary = {"ok": false}
	match key_event.keycode:
		KEY_TAB:
			session.next_section()
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
			session.go_to_section(key_event.keycode - KEY_1)
		KEY_UP, KEY_W:
			session.move_cursor(-1)
		KEY_DOWN, KEY_S:
			session.move_cursor(1)
		KEY_LEFT, KEY_A:
			session.step(-1)
		KEY_RIGHT, KEY_D:
			session.step(1)
		KEY_SPACE:
			if session.section == CreationViewModel.SECTION_TRAITS:
				session.toggle_row(session.cursor)
			else:
				request = session.confirm()
		KEY_N:
			session.reroll_name()
		KEY_R:
			session.toggle_mode()
		KEY_ENTER, KEY_KP_ENTER:
			request = session.confirm()
		KEY_ESCAPE:
			session.back()
		KEY_F5, KEY_F9:
			# 化身还没装配，存下去会是一份"没有玩家"的存档
			_status.text = "先决定这个人是谁，再谈存读档。"
			return
	_apply_creation_status()
	_start_from_creation(request)
	_refresh()


# --- 开局创建：鼠标 ---

## 面板只报"点到了什么"，改状态是 CreationSession 的事。这样"点第二行勾第二项"
## 整条链子都在可测范围内，而不是只测到面板认出了行号。
func _creation_click(point: Vector2) -> void:
	var hit: Dictionary = CreationPanel.hit_test(_creation_session.view, PANEL_RECT, point)
	if hit.is_empty():
		return
	var request: Dictionary = _creation_session.click(hit)
	_apply_creation_status()
	_start_from_creation(request)
	_refresh()


# --- 开局创建：收尾 ---

## CreationSession 说"可以开始了"之后，装配化身。
##
## 这一步留在主场景：建造化身、推进时钟、落位都要动世界，而流程类只管判断
## "现在能不能开始"。返回的请求里带着模式与宿主结果，这里照着分派。
func _start_from_creation(request: Dictionary) -> void:
	if not bool(request.get("ok", false)):
		return
	if int(request.get("mode", CreationViewModel.MODE_FREE)) \
		== CreationViewModel.MODE_REBIRTH:
		_start_avatar_from_rebirth(request.get("rebirth", {}))
		return
	_start_avatar_from_free()


func _start_avatar_from_free() -> void:
	var spec: Dictionary = _creation_session.spec
	var avatar: PlayerAvatar = _creator.build_avatar(spec, "avatar-0001", _soul.soul_id)
	var city_id: String = str(spec.get("startCityId", ""))
	_place_avatar(avatar, city_id)
	_status.text = "%s（%s · %d 岁）在%s开始这一生。" % [
		avatar.display_name, avatar.race, avatar.age, _city_label_or_wilds(city_id),
	]
	_switch_view(VIEW_MAP)


func _start_avatar_from_rebirth(rebirth: Dictionary) -> void:
	# 沉眠：契约要求 rebirth 只给出月数，推进世界是调用方的事。
	# 先沉眠再落位，否则醒来时人已经不在原来的城市了。
	var sleep_months: int = int(rebirth.get("sleepMonths", 0))
	if sleep_months > 0:
		var report: Dictionary = _sim.fast_forward(Clock.total_months(), sleep_months)
		Clock.core().advance_months(sleep_months)
		_note_events(report["notableEvents"])
		_last_deltas = {}

	var spec: Dictionary = rebirth["avatarSpec"].duplicate(true)
	spec["displayName"] = _creation_session.roll_name()
	var avatar: PlayerAvatar = _creator.build_avatar(spec, "avatar-0001", _soul.soul_id)
	# 前世技能按保留率带过来。取「新躯壳已有的」与「继承的」中较高者，
	# 否则同一个技能会随转生次数反复下滑。
	for skill_id in rebirth.get("inheritedSkills", {}):
		var inherited: int = int(rebirth["inheritedSkills"][skill_id])
		avatar.skills[str(skill_id)] = maxi(int(avatar.skills.get(str(skill_id), 0)), inherited)
	# 宿主的债跟着躯壳一起接下来（出身没有债务，所以这里直接加）
	var legacy: Dictionary = rebirth.get("legacy", {})
	avatar.debt_copper += maxi(0, int(legacy.get("debtCopper", 0)))
	_place_avatar(avatar, str(legacy.get("hostCityId", "")))

	_status.text = "沉眠 %d 个月后，你在%s的躯壳里醒来（记忆保留率 %d%%）。" % [
		sleep_months, _city_label_or_wilds(str(legacy.get("hostCityId", ""))),
		int(round(float(rebirth.get("retention", 0.0)) * 100.0)),
	]
	_switch_view(VIEW_MAP)


## 落位。化身只有在开局创建结束时才装配，这一步之前 _world.avatar 是 null。
func _place_avatar(avatar: PlayerAvatar, city_id: String) -> void:
	_world.avatar = avatar
	_equip_initial_items(avatar)
	var city: City = _world.get_city(city_id)
	if city != null:
		avatar.pos_x = city.coord_x
		avatar.pos_y = city.coord_y
		return
	# 出身没给城市（或城市不存在）时退回地图正中，总比停在 (0,0) 角落好找
	@warning_ignore("integer_division")
	var center_x: int = _grid.width / 2
	@warning_ignore("integer_division")
	var center_y: int = _grid.height / 2
	avatar.pos_x = center_x
	avatar.pos_y = center_y


func _city_label_or_wilds(city_id: String) -> String:
	if city_id.is_empty() or _world.get_city(city_id) == null:
		return "荒野"
	return str(_table("cityNames").get(city_id, city_id))


## 出身给的行装先穿上。理由有两条：那些东西本来就是"这个人带着的"，不是背包里的
## 战利品；而且不穿上的话，新角色赤手空拳打 1 点伤害，而"背包里有剑却没拿在手上"
## 这件事只有玩家自己打开面板才会发现（D-52）。
##
## 同一个槽有多件时先列出的先穿（配置次序即优先级）。出生只有一次，不做比较——
## 用"哪件更强"来挑会让"配置里写了什么"与"身上穿着什么"之间多一条看不见的规则。
func _equip_initial_items(avatar: PlayerAvatar) -> void:
	if avatar == null or _gear == null:
		return
	for instance_id in avatar.inventory.duplicate():
		var slot: String = _gear.slot_of(
			str(avatar.item_instances.get(instance_id, {}).get("templateId", ""))
		)
		if slot.is_empty() or not _gear.equipped_instance(avatar, slot).is_empty():
			continue
		_gear.equip(avatar, str(instance_id))


# --- 角色面板（M6.2）---

## 打开角色面板。每次进去光标归零（停在主手那一行）——面板打开时玩家多半是来
## 看"我现在什么样"，而不是接着上一次的动作往下做。
func _enter_avatar() -> void:
	_avatar_cursor = 0
	_switch_view(VIEW_AVATAR)


func _refresh_avatar() -> void:
	if _world.avatar == null:
		_avatar_view = {}
		return
	_avatar_view = AvatarViewModel.build(
		_world.avatar, _derived, _lookups, _location_label(), _gear, _avatar_cursor,
		_encumbrance(_world.avatar)
	)
	_avatar_cursor = int(_avatar_view.get("cursor", 0))


## 回车。光标在装备槽上就是脱下，在背包里就是穿上——两段共用一个光标，
## 所以这里按视图模型给出的 kind 分派，不自己数"第几行属于哪一段"。
func _avatar_act() -> void:
	var selected: Dictionary = _avatar_view.get("selected", {})
	if selected.is_empty():
		_status.text = "没有可以动手的行。"
		_refresh()
		return
	if not bool(selected.get("canAct", false)):
		_status.text = str(selected.get("actionLine", "这一行现在动不了。"))
		_refresh()
		return
	var result: Dictionary = {}
	if str(selected.get("kind", "")) == AvatarViewModel.CURSOR_KIND_SLOT:
		result = _gear.unequip(_world.avatar, str(selected.get("slot", "")))
	else:
		result = _gear.equip(_world.avatar, str(selected.get("instanceId", "")))
	if not bool(result.get("ok", false)):
		_status.text = "没动成：%s" % str(result.get("error", ""))
		_refresh()
		return
	_status.text = _equip_result_text(result, str(selected.get("kind", "")))
	_refresh()


## 一次穿脱的说明行。换下来的那件要写出来——玩家按下回车之后身上的东西换了位，
## 而状态行是唯一会告诉他这件事的地方。
func _equip_result_text(result: Dictionary, kind: String) -> String:
	var parts: Array = ["%s「%s」" % [
		"脱下" if kind == AvatarViewModel.CURSOR_KIND_SLOT else "穿上",
		str(result.get("displayName", "")),
	]]
	if not str(result.get("replaced", "")).is_empty():
		parts.append("换下的已放回背包")
	return " · ".join(PackedStringArray(parts))


func _avatar_move_cursor(delta: int) -> void:
	var count: int = maxi(1, int(_avatar_view.get("rowCount", 0)))
	_avatar_cursor = posmod(_avatar_cursor + delta, count)
	_refresh()


## 用身上的修补工具就地修光标停着的那件装备。判断（有没有工具、受不受伤）都在
## 视图模型的 portableRepair 里；这里只照着它做。工具可反复用，不消耗也不花钱，
## 与铁匠铺的工匠/满修（要工钱）是两条路（D-64）。
func _avatar_repair_portable() -> void:
	if _world.avatar == null:
		return
	var selected: Dictionary = _avatar_view.get("selected", {})
	var repair: Dictionary = selected.get("portableRepair", {})
	if not bool(repair.get("canRepair", false)):
		var blocked: String = str(repair.get("actionLine", ""))
		var fallback: String = str(selected.get("actionLine", ""))
		_status.text = "%s%s" % [
			blocked if not blocked.is_empty() else "这一件现在用不了修补工具。",
			"　" + fallback if not fallback.is_empty() and fallback != blocked else "",
		]
		_refresh()
		return
	var instance: Dictionary = _world.avatar.item_instances.get(
		str(selected.get("instanceId", "")), {}
	)
	if instance.is_empty():
		_status.text = "这件找不到实例，修不成。"
		_refresh()
		return
	var rules: ItemInstance = _gear.rules()
	var before: int = rules.durability(instance)
	var result: Dictionary = rules.apply_repair(
		instance, ItemInstance.REPAIR_PORTABLE
	)
	if not bool(result.get("ok", false)):
		_status.text = "修不成：%s" % str(result.get("error", ""))
		_refresh()
		return
	_status.text = "「%s」就地修了一手，耐久 %d → %d；修补工具还能再用。" % [
		rules.display_name(instance),
		before, int(result.get("after", before)),
	]
	_refresh()


func _location_label() -> String:
	if _world.avatar == null:
		return ""
	var city_id: String = _grid.get_city_id_at(_world.avatar.pos_x, _world.avatar.pos_y)
	if city_id.is_empty():
		return "野外 (%d, %d)" % [_world.avatar.pos_x, _world.avatar.pos_y]
	return "在%s" % str(_table("cityNames").get(city_id, city_id))


# --- 战斗（M5）---

## 就地按正式规则摇一场遭遇（B 键）。留这个入口只为了"想立刻看一场"：
## 它走的仍是野外行进那一套（同样的分档、同样的对手表、同样的三个做法），
## 只是跳过了概率——所以调试时看到的与真遇上是同一件事，不存在第二套规则。
func _force_encounter() -> void:
	if _encounter_system == null or _world.avatar == null:
		return
	var pos := Vector2i(_world.avatar.pos_x, _world.avatar.pos_y)
	var city_id: String = _grid.get_city_id_at(pos.x, pos.y)
	if city_id.is_empty():
		city_id = _encounter_system.nearest_city_id(pos)
	_encounter_check(_encounter_system.context_at(pos), city_id, true)


# --- 战场版式 ---

## 战场上的几根柱子。位置写死而不是随机：单位站位也是写死的，
## 随机会出现"柱子正好压在出生点上"这种需要额外处理的组合。
func _battle_obstacles() -> Array:
	@warning_ignore("integer_division")
	var centre: int = BATTLE_COLS / 2
	var out: Array = []
	for y in [1, BATTLE_ROWS - 2]:
		for dx in [0, 1]:
			out.append([centre + dx, y])
	return out


## 玩家的七维（含身上装备的词缀加成）。
##
## 只算**穿在身上**的装备。在这之前这里是"背包里攻击最高的武器 + 所有防具的
## 护甲之和"，于是买一把更好的剑还没穿上就先加了伤害（见 D-52）。
## 数值再往下走一层：同一件模板强化过、带着词缀，挥出去的伤害就该不一样（D-54）。
func _player_attributes(avatar: PlayerAvatar) -> Dictionary:
	var loadout: Dictionary = _gear.summary(avatar)
	var attributes: Dictionary = avatar.attributes.duplicate()
	for attr in loadout["attributes"]:
		var key: String = str(attr)
		attributes[key] = int(attributes.get(key, 0)) + int(loadout["attributes"][attr])
	return attributes


## 玩家的威胁等级。遭遇界面上的"对手最高 TL ｜ 你 TL"与越级警示都读它——
## 玩家得先知道这一场是不是打不过，才谈得上要不要绕开。
func _player_threat(avatar: PlayerAvatar) -> int:
	if avatar == null:
		return 1
	return _threat_level(_player_attributes(avatar), avatar.skills)


func _player_unit_spec(avatar: PlayerAvatar) -> Dictionary:
	var loadout: Dictionary = _gear.summary(avatar)
	var attributes: Dictionary = _player_attributes(avatar)
	return {
		"unitId": "unit-player",
		"side": Combat.SIDE_PLAYER,
		"name": avatar.display_name,
		"attributes": attributes,
		"skills": avatar.skills.duplicate(),
		"weaponTemplateId": str(loadout["weapon"].get("templateId", "")),
		# 武器伤害与射程由装备层给出（模板 + 强化 + 词缀），Combat 照单收下
		"weaponAttack": int(loadout["attack"]),
		"weaponRange": int(loadout["attackRange"]),
		"armor": int(loadout["armor"]),
		"magicResist": int(loadout["magicResist"]),
		"luck": avatar.luck,
		"position": PLAYER_SPAWN.duplicate(),
		"threatLevel": _threat_level(attributes, avatar.skills),
		# 超重惩罚在战斗里生效（AP/移动/命中/TU），由负重推导（D-66）
		"encumbrance": _encumbrance(avatar),
	}


## 战斗结束把玩家单位已成长的熟练度回写化身，让「用进」练出的熟练度落盘
## （avatar.skills 走 to_dict/from_dict 存档）。玩家单位是从 avatar.skills 拷一份
## 出来的（上面 _player_unit_spec），战里 Combat 只在快照上给它 +1，
## 不写回读档就全丢了（M13）。
func _sync_combat_skills_to_avatar() -> void:
	if _combat == null or _world == null or _world.avatar == null:
		return
	var unit: Dictionary = _combat.unit_by_id("unit-player")
	if unit.is_empty():
		return
	for skill_id in unit.get("skills", {}):
		_world.avatar.skills[skill_id] = clampi(
			int(unit["skills"][skill_id]), 0, 100
		)


## 玩家的负重现状（D-66）：当前负重 + 上限 + 超重惩罚。面板显示与战斗单位
## 都读这一份——两处各算一遍的话，"力量 +3 是不是真的拉高了上限"会分叉。
## 上限是派生值，由属性、负重技能熟练度、装备 carryBonus、天赋 carryBonus 实时重算。
func _encumbrance(avatar: PlayerAvatar) -> Dictionary:
	if avatar == null:
		return {}
	var current: int = _gear.carried_weight(avatar)
	var skill_level: int = int(avatar.skills.get("passive_load_bearing", 0))
	var equip_bonus: int = _gear.carry_bonus(avatar)
	var talent_bonus: int = 0
	for talent_id in avatar.talents:
		var talent: Dictionary = ContentLoader.get_talent(str(talent_id))
		if str(talent.get("effectKind", "")) == "carry_capacity":
			talent_bonus += int(talent.get("effectValue", 0))
	var limit: int = _derived.encumbrance_limit(
		avatar.attributes, skill_level, equip_bonus, talent_bonus
	)
	var result: Dictionary = _derived.encumbrance_penalty(current, limit)
	result["current"] = current
	result["limit"] = limit
	return result


## 威胁等级用于掉落分档。取对手实力等级的量级，钳到 1–40 之间。
func _threat_level(attributes: Dictionary, skills: Dictionary) -> int:
	var power: int = _derived.power_level(attributes, skills)
	@warning_ignore("integer_division")
	var level: int = 1 + power / 4
	return clampi(level, 1, 40)


## 从同城成年居民里等距取几个当陪练。等距而不是随机：随机取会在同一城里
## 反复抽到同一批人，等距让不同时候按 B 遇到的面孔不一样。
func _opponent_specs(city_id: String, rng: DeterministicRNG) -> Array:
	var pool: Array = []
	var city: City = _world.get_city(city_id)
	if city != null:
		for npc_id in city.npc_ids:
			var npc: SimNpc = _world.get_npc(str(npc_id))
			if npc != null and not npc.is_named and npc.age >= NpcGenerator.ADULT_AGE:
				pool.append(npc)

	var out: Array = []
	var count: int = mini(SPARRING_OPPONENTS, maxi(1, pool.size()))
	for index in range(count):
		var spawn: Array = OPPONENT_SPAWNS[index % OPPONENT_SPAWNS.size()]
		if pool.is_empty():
			out.append(_vagrant_spec(index, spawn, rng))
			continue
		@warning_ignore("integer_division")
		var stride: int = maxi(1, pool.size() / count)
		var npc: SimNpc = pool[mini(pool.size() - 1, index * stride)]
		out.append(_npc_unit_spec(npc, index, spawn, rng))
	return out


func _npc_unit_spec(npc: SimNpc, index: int, spawn: Array, rng: DeterministicRNG) -> Dictionary:
	var attributes: Dictionary = _random_attributes(rng, 8, 14)
	var weapon: Dictionary = _common_template("weapon")
	var armor: Dictionary = _common_template("armor")
	# 名字撞车（同名同城）时靠 unitId 区分，界面上仍显示姓名
	return {
		"unitId": "unit-enemy-%d" % (index + 1),
		"side": Combat.SIDE_ENEMY,
		"name": npc.display_name(),
		"attributes": attributes,
		"skills": {},
		"weaponTemplateId": str(weapon.get("templateId", "")),
		"armor": int(armor.get("armor", 0)),
		"magicResist": int(armor.get("magicResist", 0)),
		"luck": 0,
		"position": spawn.duplicate(),
		"threatLevel": _threat_level(attributes, {}),
	}


## 城里一个成年居民都没有时的兜底对手。这是理论上才会走到的分支，
## 但战斗入口不该因为一座城的人口构成而整个失效。
func _vagrant_spec(index: int, spawn: Array, rng: DeterministicRNG) -> Dictionary:
	var attributes: Dictionary = _random_attributes(rng, 6, 12)
	return {
		"unitId": "unit-enemy-%d" % (index + 1),
		"side": Combat.SIDE_ENEMY,
		"name": "流浪者 %d" % (index + 1),
		"attributes": attributes,
		"skills": {},
		"weaponTemplateId": str(_common_template("weapon").get("templateId", "")),
		"armor": 0,
		"magicResist": 0,
		"luck": 0,
		"position": spawn.duplicate(),
		"threatLevel": _threat_level(attributes, {}),
	}


## 陪练对手的属性。模拟 NPC 身上没有属性字段（世界模拟不需要它），
## 所以只能在这一层现抽——用注入的随机源，保证同一场次可复现。
func _random_attributes(rng: DeterministicRNG, low: int, high: int) -> Dictionary:
	var out: Dictionary = {}
	for attr in PlayerAvatar.ALL_ATTRIBUTES:
		out[attr] = rng.range_int(low, high)
	return out


## 按「类别 + 普通稀有度」在配置里找一件模板。不写死物品 ID：
## 硬编码的 ID 在物品表改名后会静默退化成赤手空拳（伤害 1），那种失败很难发现。
func _common_template(category: String) -> Dictionary:
	var templates: Dictionary = _table("itemTemplates")
	var ids: Array = templates.keys()
	ids.sort()
	for template_id in ids:
		var template: Dictionary = templates[template_id]
		if str(template.get("category", "")) == category \
			and str(template.get("rarity", "")) == "common":
			return template
	return {}


func _refresh_combat() -> void:
	if _combat == null:
		_combat_view = {}
		return
	_combat_view = CombatViewModel.build(
		_combat, _table("skillNames"), _combat_menu_mode, _combat_cursor,
		_combat_pending, _combat_cursor_tile
	)
	# 选落点时战场上的光标跟着菜单高亮走，不单独维护第二套光标状态
	if _combat_menu_mode == CombatViewModel.MENU_TARGET_TILE:
		var menu: Array = _combat_view.get("menu", [])
		var cursor: int = int(_combat_view.get("cursor", 0))
		if cursor >= 0 and cursor < menu.size():
			var action: Dictionary = menu[cursor].get("action", {})
			_combat_cursor_tile = Vector2i(int(action.get("x", 0)), int(action.get("y", 0)))


func _combat_input(key_event: InputEventKey) -> void:
	if _combat == null:
		return
	if _combat.finished:
		match key_event.keycode:
			KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE, KEY_SPACE:
				_switch_view(VIEW_MAP)
		return
	if not CombatViewModel.is_player_turn(_combat):
		return

	var menu: Array = _combat_view.get("menu", [])
	match key_event.keycode:
		KEY_ESCAPE:
			if _combat_menu_mode == CombatViewModel.MENU_MAIN:
				_switch_view(VIEW_MAP)
			else:
				_combat_menu_mode = CombatViewModel.MENU_MAIN
				_combat_pending = {}
				_combat_cursor = 0
				_refresh()
		KEY_UP, KEY_W:
			_move_combat_cursor(-1, menu)
		KEY_DOWN, KEY_S:
			_move_combat_cursor(1, menu)
		KEY_LEFT, KEY_A:
			_move_combat_cursor(-1, menu)
		KEY_RIGHT, KEY_D:
			_move_combat_cursor(1, menu)
		KEY_ENTER, KEY_KP_ENTER:
			_confirm_combat_menu(menu)
			return
	_refresh()


func _move_combat_cursor(delta: int, menu: Array) -> void:
	if menu.is_empty():
		return
	_combat_cursor = posmod(_combat_cursor + delta, menu.size())


## 菜单项直接携带完整动作字典（见 CombatViewModel），这里只判断"是进入下一层
## 子菜单"还是"直接提交"。动作的构造在视图模型里，翻译只此一处，不来回倒手。
func _confirm_combat_menu(menu: Array) -> void:
	if menu.is_empty():
		return
	var cursor: int = clampi(_combat_cursor, 0, menu.size() - 1)
	_combat_cursor = cursor
	var item: Dictionary = menu[cursor]
	if not bool(item.get("enabled", true)):
		_status.text = "这一项现在用不了：%s" % str(item.get("label", ""))
		_refresh()
		return

	var action: Dictionary = item.get("action", {})
	var actor: Dictionary = _combat.unit_by_id(_combat.current_unit_id())
	match str(action.get("kind", "")):
		"move":
			var cost: int = maxi(1, _combat.unit_move_cost(actor))
			@warning_ignore("integer_division")
			var reach: int = maxi(1, int(actor["ap"]) / cost)
			_combat_pending = {"reach": reach, "moveCost": cost}
			_combat_menu_mode = CombatViewModel.MENU_TARGET_TILE
			_combat_cursor = 0
			_refresh()
		"attack":
			_combat_pending = {
				"label": "普通攻击",
				"attackRange": maxi(1, int(actor["weapon"].get("attackRange", 1))),
			}
			_combat_menu_mode = CombatViewModel.MENU_TARGET_UNIT
			_combat_cursor = 0
			_refresh()
		"skill":
			var skill: Dictionary = _combat.skill_def(str(action.get("skillId", "")))
			var skill_range: int = int(skill.get("attackRange", 0))
			_combat_pending = {
				"label": str(action.get("label", "技能")),
				"skillId": str(action.get("skillId", "")),
				"attackRange": skill_range if skill_range > 0 \
					else maxi(1, int(actor["weapon"].get("attackRange", 1))),
			}
			_combat_menu_mode = CombatViewModel.MENU_TARGET_UNIT
			_combat_cursor = 0
			_refresh()
		"downed":
			_combat_menu_mode = CombatViewModel.MENU_DOWNED
			_combat_pending = {}
			_combat_cursor = 0
			_refresh()
		"end_turn":
			_submit_combat({"actionType": Combat.ACTION_END_TURN, "actorId": _actor_id()})
		"target_unit":
			var pending: Dictionary = action.get("pending", {})
			_combat_pending = pending
			_submit_target_unit(str(action.get("targetId", "")))
		"target_tile":
			_submit_move(Vector2i(int(action.get("x", 0)), int(action.get("y", 0))))
		"downed_choice":
			_submit_combat({
				"actionType": Combat.ACTION_DOWNED_CHOICE,
				"actorId": _actor_id(),
				"targetId": str(action.get("targetId", "")),
				"downedChoice": str(action.get("downedChoice", "")),
			})
		_:
			_status.text = "这个动作界面还不认识：%s" % str(action.get("kind", ""))
			_refresh()


func _actor_id() -> String:
	return _combat.current_unit_id() if _combat != null else ""


## 提交一次指向单位的动作。键盘（在子菜单里选中目标后回车）与鼠标（直接点战场上
## 的敌人）走同一条路：用不用技能由 _combat_pending 决定，两处不必各判一次。
func _submit_target_unit(target_id: String) -> void:
	var skill_id: String = str(_combat_pending.get("skillId", ""))
	_submit_combat({
		"actionType": Combat.ACTION_SKILL if not skill_id.is_empty() else Combat.ACTION_ATTACK,
		"actorId": _actor_id(),
		"targetId": target_id,
		"skillId": skill_id,
	})


func _submit_move(tile: Vector2i) -> void:
	_submit_combat({
		"actionType": Combat.ACTION_MOVE,
		"actorId": _actor_id(),
		"moveTo": [tile.x, tile.y],
	})


func _submit_combat(action: Dictionary) -> void:
	var submitted: Dictionary = _combat.submit_action(action)
	if not bool(submitted.get("ok", false)):
		_status.text = "动作没被接受：%s" % str(submitted.get("reason", ""))
		_refresh()
		return
	_combat_menu_mode = CombatViewModel.MENU_MAIN
	_combat_pending = {}
	_combat_cursor = 0
	_drive_enemies()


## 把行动权交回玩家之前，替所有敌方单位行动完。
##
## 不逐帧停顿：整个界面本来就是键驱动的、没有动画，把一次攻击拆成几帧只会
## 让人反复按键盘却看不到新东西。玩家按一次键，做完自己的事，敌人接着做完
## 它们的事，然后把结果一次性摆在日志里。
func _drive_enemies() -> void:
	var guard: int = 0
	while _combat != null and not _combat.finished and guard < 200:
		guard += 1
		var current: String = _combat.current_unit_id()
		if current.is_empty():
			break
		var unit: Dictionary = _combat.unit_by_id(current)
		if unit.is_empty() or str(unit["side"]) == Combat.SIDE_PLAYER:
			break
		var result: Dictionary = _combat.auto_action(current)
		if not bool(result.get("ok", false)):
			# 剩下的 AP 不够任何动作时 auto_action 会拒绝，而拒绝不改状态。
			# 不在这里替它结束回合，循环就会停在同一人身上空转。
			_combat.submit_action({"actionType": Combat.ACTION_END_TURN, "actorId": current})

	if _combat != null and _combat.finished:
		_settle_combat()
	_refresh()


## 战斗收尾。战斗模块只产出结果，把它变成世界上的东西（进背包、落标记）
## 是调用方的事——技术设计文档 2.3 节的"战斗不产生世界后果"。
func _settle_combat() -> void:
	if _combat == null or _world.avatar == null:
		return
	if not _quest_combat.is_empty():
		# 委托战斗的收尾不走上面那条路：战果要变成委托交付（分支后果、世界标记、
		# 城市维度变更），而不是把敌人的东西塞进背包了事。
		_resolve_quest_combat()
		return
	if not _event_combat.is_empty():
		# 事件战斗同理：讨伐的胜负决定走 victory 还是 defeat 那一套后果。
		_resolve_event_combat()
		return
	for entry in _combat.loot:
		var template_id: String = str(entry.get("templateId", ""))
		if template_id.is_empty():
			continue
		_loot_seq += 1
		_creator.add_item(_world.avatar, template_id,
			"%s-loot-%03d" % [_world.avatar.avatar_id, _loot_seq])
	for key in _combat.world_flags:
		_world.world_flags[str(key)] = true
	if _combat.wear_player_attacks > 0 or _combat.wear_player_taken > 0:
		_wear_seq += 1
		_apply_combat_wear(
			_combat.wear_player_attacks, _combat.wear_player_taken,
			DeterministicRNG.new(_world.world_seed ^ (_wear_seq * 2862933555777941757))
		)
	if _encounter_combat:
		# 遭遇打起来的：掉落与世界标记先落（上面两圈），再补一条结算文案。
		# 与委托、事件同一条次序——战斗模块只产出结果，把它变成世界上的东西
		# 是调用方的事（10.1 第 3 条）。
		_resolve_encounter_combat()
		return
	_status.text = "交手结束（%d 轮）：%s" % [
		_combat.round, "你赢了" if _combat.winner == Combat.RESULT_PLAYER else "你输了"
	]


## 把这场战斗的磨损落到玩家佩戴的装备实例上（D-62）。规则只数了"打出一刀命中、
## 挨了一刀命中"，这里是真正的账：命中数磨武器、受击数均摊到穿着的护甲。
## 每一刀按 ItemInstance.wear 的概率决定掉不掉 1 点，所以"更耐用"体现在小数里——
## 一场仗几刀下去，多数时候一件装备毫发无损。
func _apply_combat_wear(attacks: int, taken: int, rng: DeterministicRNG) -> void:
	var avatar: PlayerAvatar = _world.avatar
	if avatar == null:
		return
	var rules: ItemInstance = _gear.rules()
	# 玩家打的每一刀命中都磨主手武器（没摸到武器就无处可磨）
	for _i in range(maxi(0, attacks)):
		var weapon_id: String = _gear.equipped_instance(avatar, "main_hand")
		if weapon_id.is_empty():
			continue
		var weapon: Dictionary = avatar.item_instances.get(weapon_id, {})
		if not weapon.is_empty() and not rules.broken(weapon):
			rules.wear(weapon, true, rng)
	# 挨的每一刀命中，按槽位轮到正在穿的一件护甲（不含主手武器槽）
	var armor_slots: Array = []
	for slot in _gear.slots():
		if str(slot) == "main_hand" or str(slot) == "off_hand":
			continue
		var instance_id: String = _gear.equipped_instance(avatar, str(slot))
		if not instance_id.is_empty():
			armor_slots.append(str(slot))
	if armor_slots.is_empty():
		return
	var wearing: Array = []
	for slot in armor_slots:
		var inst: Dictionary = avatar.item_instances.get(
			_gear.equipped_instance(avatar, slot), {}
		)
		if not inst.is_empty() and not rules.broken(inst):
			wearing.append(inst)
	if wearing.is_empty():
		return
	for _i in range(maxi(0, taken)):
		var piece: Dictionary = wearing[_i % wearing.size()]
		rules.wear(piece, false, rng)


# --- 世界遭遇（M9：谁在什么地方因为什么拦住你）---
#
# 触发在两处：野外每走 stepInterval 格判一次，进城那一瞬间判一次（治安低才判）。
# 三个做法就是全部出口，没有"返回地图"——绕开要花时间且可能甩不掉，交涉只对
# 人形有效，所以每一条路都通向结果，不会把人卡住。
#
# 与委托、事件一样分两层：规则在 EncounterSystem 里（纯函数、可断言），
# 这里只留"现在这一场是谁、光标在第几条"这类会话状态。遭遇不落盘，与战斗同一条
# 处境：读档回到地图，那一场就没了。

## 清空遭遇的会话状态。新世界与读档各调一次——它不落盘，所以每换一个世界都要重来。
func _reset_encounter_session() -> void:
	_encounter = {}
	_encounter_view = {}
	_encounter_cursor = 0
	_encounter_steps = 0
	_encounter_combat = false
	_last_city_id = ""


## 走了一格（点地图的连续走法会把步数一次给全）。攒够 stepInterval 就在野外判一次；
## 进城那一瞬间另判一次城内遭遇——城里不能按格走，所以"每 8 格"这条规则在城里
## 没有意义，能判的时机只有"进门那一刻"。
func _encounter_advance(steps: int) -> void:
	if _encounter_system == null or _world.avatar == null or not _encounter.is_empty():
		return
	var pos := Vector2i(_world.avatar.pos_x, _world.avatar.pos_y)
	var city_id: String = _grid.get_city_id_at(pos.x, pos.y)
	if not city_id.is_empty():
		if city_id == _last_city_id:
			return
		_last_city_id = city_id
		_encounter_check(EncounterSystem.CONTEXT_CITY, city_id, false)
		return
	_last_city_id = ""
	if _silent_walk:
		# 静默行走期间不攒步数：否则关掉它的第一步就会立刻撞上一场，
		# 而玩家刚才按 Z 的意思正是"我要专心赶路"
		_encounter_steps = 0
		return
	_encounter_steps += maxi(0, steps)
	if not _encounter_system.should_check(_encounter_steps):
		return
	_encounter_steps = 0
	_encounter_check(
		_encounter_system.context_at(pos), _encounter_system.nearest_city_id(pos), false
	)


## 判一次遭遇。判定与做法各用一支自己的随机源（与世界演化分开），
## 种子由世界种子与序号决定，所以"同一存档的第 n 次判定"仍然可复现。
func _encounter_check(context: String, city_id: String, force: bool) -> void:
	if _encounter_system == null or _world.avatar == null or not _encounter.is_empty():
		return
	_encounter_seq += 1
	var rng := DeterministicRNG.new(_world.world_seed ^ (_encounter_seq * 40503))
	var result: Dictionary = _encounter_system.check(
		context, city_id, Clock.total_months(), "enc-%04d" % _encounter_seq, rng, force
	)
	if not bool(result.get("ok", false)):
		_status.text = "遭遇没能开始：%s" % str(result.get("error", ""))
		_refresh()
		return
	if not bool(result.get("engaged", false)):
		if force:
			_status.text = "这一带暂时没人拦你。"
			_refresh()
		return
	_encounter = result["encounter"]
	_encounter_cursor = 0
	_switch_view(VIEW_ENCOUNTER)
	_status.text = "遇上「%s」——迎战、绕开、交涉，总得选一个。" % str(_encounter.get("title", ""))


## 这一场是骰子摇出来的还是按 B 强摇的，决定绕开后要不要继续攒步数。
func _refresh_encounter() -> void:
	if _encounter.is_empty():
		_encounter_view = {}
		return
	_encounter_view = EncounterViewModel.build(
		_encounter_system, _encounter, _player_threat(_world.avatar), _table("cityNames"),
		_encounter_cursor
	)
	_encounter_cursor = int(_encounter_view.get("cursor", 0))


func _encounter_input(key_event: InputEventKey) -> void:
	if _encounter_view.is_empty():
		return
	match key_event.keycode:
		KEY_UP, KEY_W:
			_encounter_cursor = maxi(0, _encounter_cursor - 1)
			_refresh()
		KEY_DOWN, KEY_S:
			_encounter_cursor = mini(_encounter_view["choiceCount"] - 1, _encounter_cursor + 1)
			_refresh()
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_encounter_confirm()
		KEY_ESCAPE:
			# 遭遇里没有回头路。ESC 不退出，只说清楚为什么。
			_status.text = "遇上了就不能装没看见：迎战、绕开、交涉，选一个。"


func _encounter_click(point: Vector2) -> void:
	var hit: Dictionary = EncounterPanel.hit_test(_encounter_view, PANEL_RECT, point)
	if str(hit.get("kind", "")) != "choice":
		return
	var index: int = int(hit.get("index", -1))
	# 与委托、商铺同一条：先挪光标、再动手。迎战不可逆，值得多一次确认
	if index != _encounter_cursor:
		_encounter_cursor = index
		_refresh()
		return
	if not EncounterPanel.choice_enabled(_encounter_view, index):
		_status.text = str(_encounter_view["selected"].get("blockedReason", "这个做法现在用不了。"))
		return
	_encounter_confirm()


func _encounter_confirm() -> void:
	var choice: String = str(_encounter_view.get("selected", {}).get("choiceId", ""))
	if not EncounterPanel.choice_enabled(_encounter_view, _encounter_cursor):
		_status.text = str(_encounter_view["selected"].get("blockedReason", "这个做法现在用不了。"))
		_refresh()
		return
	match choice:
		EncounterSystem.CHOICE_FIGHT:
			_start_encounter_combat()
		EncounterSystem.CHOICE_AVOID:
			_encounter_try_avoid()
		EncounterSystem.CHOICE_PARLEY:
			_encounter_try_parley()
		_:
			_status.text = "这个做法还没做出来。"


## 绕开：掷一次，成则花掉一天走人，败则只能打——所以它不是一个"跳过键"。
func _encounter_try_avoid() -> void:
	var avatar: PlayerAvatar = _world.avatar
	_encounter_seq += 1
	var rng := DeterministicRNG.new(_world.world_seed ^ (_encounter_seq * 2654435761))
	var result: Dictionary = _encounter_system.avoid_check(avatar.attributes, avatar.luck, rng)
	if not bool(result.get("escaped", false)):
		_status.text = "没能甩掉（成功率 %d%%）——只能打了。" % _percent_bp(int(result["chanceBp"]))
		_start_encounter_combat()
		return
	var days: int = _encounter_system.avoid_time_days()
	# 花掉的时间照走：绕路是有代价的，而代价必须落在时钟上，
	# 否则"绕开"就成了一次免费的取消（D-60）
	Clock.advance(days * _ticks_per_day())
	_finish_encounter(EncounterSystem.OUTCOME_AVOIDED, "")


## 交涉：只对人形有效，判据是这座城市对你的声誉（±60 是硬门槛，与委托、
## 商铺取同一组）。谈不拢就只能打。
func _encounter_try_parley() -> void:
	var avatar: PlayerAvatar = _world.avatar
	var city_id: String = str(_encounter.get("nearestCityId", ""))
	_encounter_seq += 1
	var rng := DeterministicRNG.new(_world.world_seed ^ (_encounter_seq * 2246822519))
	var result: Dictionary = _encounter_system.parley_check(avatar.get_reputation(city_id), rng)
	if not bool(result.get("accepted", false)):
		_status.text = "谈不拢（成功率 %d%%）——只能打了。" % _percent_bp(int(result["chanceBp"]))
		_start_encounter_combat()
		return
	_finish_encounter(EncounterSystem.OUTCOME_PARLEYED, "")


## 迎战。对手规格由 EncounterSystem 给（它是"这些人是谁、有多强"），
## 站位与障碍仍留在这一层（战场版式属表现层）。
func _start_encounter_combat() -> void:
	var avatar: PlayerAvatar = _world.avatar
	_combat_seq += 1
	var rng := DeterministicRNG.new(_world.world_seed ^ (_combat_seq * 2246822519))
	_combat = Combat.new(
		_derived,
		ContentLoader.get_balance_section("combat"),
		ContentLoader.get_skills(),
		ContentLoader.get_items(),
		rng
	)
	var units: Array = [_player_unit_spec(avatar)]
	units.append_array(_encounter_system.units_of(_encounter, OPPONENT_SPAWNS))
	var started: Dictionary = _combat.start({
		"sessionId": "encounter-%s" % str(_encounter.get("encounterId", "")),
		"units": units,
		"obstacles": _battle_obstacles(),
	})
	if not bool(started.get("ok", false)):
		_status.text = "战斗没能开始：%s" % str(started.get("reason", ""))
		_combat = null
		return

	_encounter_combat = true
	_combat_menu_mode = CombatViewModel.MENU_MAIN
	_combat_cursor = 0
	_combat_pending = {}
	_combat_cursor_tile = Vector2i.ZERO
	_switch_view(VIEW_COMBAT)
	_status.text = "在%s交手：%d 对 %d。" % [
		str(_encounter_view.get("contextLabel", "")), 1,
		maxi(0, _combat.units.size() - 1)
	]
	# 先攻可能把第一个回合判给敌方，所以进场就驱动一次
	_drive_enemies()


## 战后收尾。掉落与世界标记已经在 _settle_combat 里落过了，这里只补一条文案：
## 谁被怎么了（处置）写进底部事件流——那是世界自己的记录，不是玩家的战报。
func _resolve_encounter_combat() -> void:
	var spec: Dictionary = _encounter
	var won: bool = _combat.winner == Combat.RESULT_PLAYER
	_sync_combat_skills_to_avatar()
	var outcome: String = EncounterSystem.OUTCOME_WON if won else EncounterSystem.OUTCOME_LOST
	_encounter_combat = false
	_encounter = {}
	_encounter_view = {}
	var result: Dictionary = _encounter_system.resolve(
		spec, outcome, Clock.total_months(), _combat_outcome_label(won)
	)
	_note_events(result.get("notices", []))
	_status.text = "交手结束（%d 轮）：%s" % [_combat.round, str(result.get("text", ""))]


## 战场上的处置写成一句话，缀在结算文案后面（补刀 / 生擒 / 放走 / 搜身）。
func _combat_outcome_label(won: bool) -> String:
	if not won:
		return "命还在，爬起来了"
	match _combat_outcome_key(true):
		Combat.DOWNED_FINISH:
			return "补了刀"
		Combat.DOWNED_CAPTURE:
			return "生擒了"
		Combat.DOWNED_RELEASE:
			return "放走了"
		Combat.DOWNED_SEARCH:
			return "搜了身"
	return ""


## 绕开 / 交涉的收尾：换回地图，把这一场写进事件流。
func _finish_encounter(outcome: String, detail: String) -> void:
	var result: Dictionary = _encounter_system.resolve(
		_encounter, outcome, Clock.total_months(), detail
	)
	_encounter = {}
	_encounter_view = {}
	_note_events(result.get("notices", []))
	_switch_view(VIEW_MAP)
	_status.text = str(result.get("text", ""))


func _percent_bp(bp: int) -> int:
	return int(round(float(bp) / 100.0))


# --- 鼠标 ---
#
# 悬停与点击都交给当前视图面板的 hit_test，主场景只负责"拿到的这个 kind 该
# 触发哪个状态变更"。位置不在这一层另算一份：面板里 draw 与 hit_test 共用同一
# 组布局函数，所以两边算出来的矩形必然相同。

## 鼠标悬停。只更新高亮用的 _hover，不参与任何判断。
##
## 只在悬停目标真的换了才重绘：面板全在 _draw 里逐行画字，鼠标每动一个像素都
## 重画整屏的话，滚动列表时帧率会肉眼可见地掉下来。
func _update_hover(point: Vector2) -> void:
	var hover: Dictionary = _hit_test_at(point)
	var signature: String = _hover_signature_of(hover)
	if signature == _hover_signature:
		return
	_hover = hover
	_hover_signature = signature
	queue_redraw()


## 悬停目标的压扁形式，用来判断"换了没有"。带上视图号：切视图时旧的高亮不该
## 跟过来（城市面板与角色面板都有一个 id 为 back 的按钮）。
func _hover_signature_of(hover: Dictionary) -> String:
	if hover.is_empty():
		return "%d:-" % _view
	return "%d:%s:%s:%d:%d" % [
		_view, str(hover.get("kind", "")), str(hover.get("id", "")),
		int(hover.get("index", -1)), int(hover.get("delta", 0)),
	]


## 当前视图下 point 落在什么上。地图视图返回空——城市方块只有十几像素，
## 逐个高亮反而看不清哪块是城，所以那里不给悬停反馈，只在点击时反应。
func _hit_test_at(point: Vector2) -> Dictionary:
	match _view:
		VIEW_CREATION:
			return CreationPanel.hit_test(_creation_session.view, PANEL_RECT, point)
		VIEW_CITY:
			return CityPanel.hit_test(_panel, PANEL_RECT, point)
		VIEW_AVATAR:
			return AvatarPanel.hit_test(_avatar_view, PANEL_RECT, point)
		VIEW_COMBAT:
			return CombatPanel.hit_test(_combat_view, PANEL_RECT, point)
		VIEW_SMUGGLING:
			return SmugglingPanel.hit_test(_smuggling_view, PANEL_RECT, point)
		VIEW_QUEST:
			return QuestPanel.hit_test(_quest_view, PANEL_RECT, point)
		VIEW_EVENT:
			return EventPanel.hit_test(_event_view, PANEL_RECT, point)
		VIEW_TRADE:
			return TradePanel.hit_test(_trade_view, PANEL_RECT, point)
		VIEW_ENCOUNTER:
			return EncounterPanel.hit_test(_encounter_view, PANEL_RECT, point)
		VIEW_CRAFTING:
			return CraftingPanel.hit_test(_crafting_view, PANEL_RECT, point)
	return {}


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return
	match _view:
		VIEW_CREATION:
			_creation_click(event.position)
		VIEW_CITY:
			_city_click(event.position)
		VIEW_AVATAR:
			_avatar_click(event.position)
		VIEW_COMBAT:
			_combat_click(event.position)
		VIEW_SMUGGLING:
			_smuggling_click(event.position)
		VIEW_QUEST:
			_quest_click(event.position)
		VIEW_EVENT:
			_event_click(event.position)
		VIEW_TRADE:
			_trade_click(event.position)
		VIEW_ENCOUNTER:
			_encounter_click(event.position)
		VIEW_CRAFTING:
			_crafting_click(event.position)
		_:
			_map_click(event.position)


# --- 鼠标：城市面板 ---

func _city_click(point: Vector2) -> void:
	var hit: Dictionary = CityPanel.hit_test(_panel, PANEL_RECT, point)
	match str(hit.get("kind", "")):
		"button":
			# 从这个城直接进走私界面，省得回地图再按 X
			if str(hit.get("id", "")) == "smuggling":
				_enter_smuggling(_selected_city_id())
				return
			# 委托板同理：在哪个城就开哪个城的板子
			if str(hit.get("id", "")) == "quest":
				_enter_quest(_selected_city_id())
				return
			# 城中大事同理
			if str(hit.get("id", "")) == "event":
				_enter_event(_selected_city_id())
				return
			# 商铺同理：选中哪座城就开哪座城的价目；人不在那儿就只看得见价
			if str(hit.get("id", "")) == "shop":
				_enter_trade(_selected_city_id())
				return
			_switch_view(VIEW_MAP)
		"city":
			_selected_city = int(hit["index"])
			_refresh()
		"dimension":
			_trend_dimension = posmod(_trend_dimension + int(hit["delta"]),
				CityViewModel.DIMENSION_ORDER.size())
			_refresh()
		"building":
			_selected_building = int(hit["index"])
			_refresh()


# --- 鼠标：角色面板 ---

## 角色面板上点一下。装备槽与背包行都"先挪光标、再动手"——与委托板、商铺同一条
## 理由：鼠标扫过列表就把身上的行头换掉，值得多一次确认。
func _avatar_click(point: Vector2) -> void:
	var hit: Dictionary = AvatarPanel.hit_test(_avatar_view, PANEL_RECT, point)
	var kind: String = str(hit.get("kind", ""))
	if kind == "button":
		_switch_view(VIEW_MAP)
		return
	if kind != AvatarViewModel.CURSOR_KIND_SLOT and kind != AvatarViewModel.CURSOR_KIND_BAG:
		return
	var index: int = int(hit.get("index", -1))
	if index == _avatar_cursor:
		_avatar_act()
		return
	_avatar_cursor = index
	_refresh()


# --- 鼠标：战斗 ---

## 战场与菜单上的点击。面板只说"点到了哪儿"，"点这一格该做什么"由当前菜单层
## 决定：
##   主菜单层   点敌人 = 普通攻击      点空格 = 走过去
##   选目标层   点敌人 = 确认目标
##   选落点层   点格子 = 走到那里
## 技能要先在菜单里选（键位提示也是这么写的），所以主菜单层点敌人不替玩家猜技能。
func _combat_click(point: Vector2) -> void:
	if _combat == null:
		return
	var hit: Dictionary = CombatPanel.hit_test(_combat_view, PANEL_RECT, point)
	if hit.is_empty():
		return
	var kind: String = str(hit.get("kind", ""))
	if _combat.finished:
		if kind == "button":
			_switch_view(VIEW_MAP)
		return
	if not CombatViewModel.is_player_turn(_combat):
		_status.text = "现在轮到敌方行动。"
		_refresh()
		return
	match kind:
		"button":
			_switch_view(VIEW_MAP)
		"menu":
			# 点菜单项与键盘选中后回车走同一条路：先挪光标再提交，
			# 这样"点了哪一项"与"高亮在哪一项"不会脱节
			_combat_cursor = int(hit["index"])
			_confirm_combat_menu(_combat_view.get("menu", []))
		"tile":
			_combat_tile_click(hit)
		"unit":
			_combat_unit_click(int(hit["index"]))


func _combat_tile_click(hit: Dictionary) -> void:
	var unit_id: String = str(hit.get("unitId", ""))
	match _combat_menu_mode:
		CombatViewModel.MENU_TARGET_UNIT:
			if unit_id.is_empty():
				_status.text = "这一格没有人。"
				_refresh()
				return
			_submit_target_unit(unit_id)
		CombatViewModel.MENU_TARGET_TILE:
			_submit_move(Vector2i(int(hit.get("x", 0)), int(hit.get("y", 0))))
		CombatViewModel.MENU_MAIN:
			if not unit_id.is_empty() and unit_id != _actor_id():
				_submit_target_unit(unit_id)
				return
			# 走不到（AP 不够或越出战场）由 Combat 拒绝并给出理由，
			# 界面这边不预先算一遍距离——那会变成第二份与规则不一致的判断
			_submit_move(Vector2i(int(hit.get("x", 0)), int(hit.get("y", 0))))
		_:
			_status.text = "这一层请用下方的菜单选。"
			_refresh()


## 点右边的参战者列表。只有"选目标"那一层有明确含义，其余时候只报一下状况——
## 那块列表是给人看的，不该在别的层里被点出意外动作。
func _combat_unit_click(index: int) -> void:
	var rows: Array = _combat_view.get("unitRows", [])
	if index < 0 or index >= rows.size():
		return
	var row: Dictionary = rows[index]
	if _combat_menu_mode == CombatViewModel.MENU_TARGET_UNIT:
		if str(row.get("side", "")) == Combat.SIDE_PLAYER:
			_status.text = "那是自己人。"
			_refresh()
			return
		_submit_target_unit(str(row.get("unitId", "")))
		return
	_status.text = "%s：%d/%d HP，%d AP，%s。" % [
		str(row.get("name", "")), int(row.get("hp", 0)), int(row.get("maxHp", 0)),
		int(row.get("ap", 0)), str(row.get("statusLabel", "")),
	]
	_refresh()


# --- 鼠标：地图 ---

## 地图上的点击。
##
## 城市方块只有十几像素，判定区往外扩了一圈；点中它就是"走进这座城"，而不是
## 「打开它的状态面板」——第一版按后者做，结果鼠标再也没有办法走进城里。
## 已经站在城里时再点一次才开面板，于是"走过去"与"看它的状态"两件事都在，
## 且顺序本来就该是先走过去、再看。
func _map_click(point: Vector2) -> void:
	if _world.avatar == null:
		_status.text = "还没有化身。"
		_refresh()
		return
	var city_id: String = _city_at_point(point)
	if not city_id.is_empty():
		var city: City = _world.get_city(city_id)
		if city == null:
			return
		if _world.avatar.pos_x == city.coord_x and _world.avatar.pos_y == city.coord_y:
			_open_city_panel(city_id)
			return
		# 走到城所在的格，而不是点到的那一格：大方块的边缘会被算进邻格，
		# 目标是"进城"，落点就该是城的坐标
		_walk_to(Vector2i(city.coord_x, city.coord_y))
		return
	var tile: Vector2i = _tile_at_point(point)
	if tile.x < 0:
		return
	_walk_to(tile)


func _open_city_panel(city_id: String) -> void:
	var ids: Array = Array(_world.get_city_ids())
	_selected_city = maxi(0, ids.find(city_id))
	_switch_view(VIEW_CITY)


func _city_at_point(point: Vector2) -> String:
	for city_id in _world.get_city_ids():
		var city: City = _world.get_city(city_id)
		if city == null:
			continue
		var center: Vector2 = MAP_ORIGIN + Vector2(city.coord_x * TILE, city.coord_y * TILE)
		if absf(point.x - center.x) <= MAP_CITY_PICK_RADIUS \
			and absf(point.y - center.y) <= MAP_CITY_PICK_RADIUS:
			return str(city_id)
	return ""


## 屏幕点 → 地图格。落在网格外返回 (-1, -1)。
func _tile_at_point(point: Vector2) -> Vector2i:
	var local: Vector2 = (point - MAP_ORIGIN) / float(TILE)
	if local.x < 0.0 or local.y < 0.0:
		return Vector2i(-1, -1)
	var tile := Vector2i(int(local.x), int(local.y))
	if not _grid.is_inside(tile.x, tile.y):
		return Vector2i(-1, -1)
	return tile


## 走到目标格。地图上没有任何障碍（MapGrid.can_enter 只查边界），移动也不推进
## 时间，所以直接一步步走到为止，不必让玩家为跨半张地图按住方向键。上限只是
## 兜底：万一以后哪里改出"原地不动"，这里不会变成死循环。
func _walk_to(tile: Vector2i) -> void:
	var avatar: PlayerAvatar = _world.avatar
	var steps: int = 0
	while steps < MAP_WALK_LIMIT and (avatar.pos_x != tile.x or avatar.pos_y != tile.y):
		steps += 1
		var next: Vector2i = _grid.step(avatar.pos_x, avatar.pos_y,
			signi(tile.x - avatar.pos_x), signi(tile.y - avatar.pos_y))
		if next.x == avatar.pos_x and next.y == avatar.pos_y:
			break
		avatar.pos_x = next.x
		avatar.pos_y = next.y
	var city_id: String = _grid.get_city_id_at(avatar.pos_x, avatar.pos_y)
	var here: String = ""
	if not city_id.is_empty():
		# 站在城里时报出"再点一次"能开面板——不然"点城市"这条规则要靠猜
		here = "，这里是%s（再点一次看它的状态）" % str(_table("cityNames").get(city_id, city_id))
	_status.text = "走了 %d 格，现在在 (%d, %d)%s。" % [steps, avatar.pos_x, avatar.pos_y, here]
	# 一次点出多格只判一次遭遇：把步数一次交给它去攒，
	# 免得"点一下地图"变成连着打好几场
	_encounter_advance(steps)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if _world == null:
		return
	# 鼠标先分流。悬停与点击都走面板的 hit_test，位置不在这里另算一份。
	if event is InputEventMouseMotion:
		_update_hover((event as InputEventMouseMotion).position)
		return
	if event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton)
		return
	if not (event is InputEventKey):
		return
	var key_event: InputEventKey = event
	if not key_event.pressed or key_event.echo:
		return
	match _view:
		VIEW_CREATION:
			_creation_input(key_event)
		VIEW_AVATAR:
			_avatar_input(key_event)
		VIEW_COMBAT:
			_combat_input(key_event)
		VIEW_CITY:
			_handle_city_input(key_event)
		VIEW_SMUGGLING:
			_smuggling_input(key_event)
		VIEW_QUEST:
			_quest_input(key_event)
		VIEW_EVENT:
			_event_input(key_event)
		VIEW_TRADE:
			_trade_input(key_event)
		VIEW_ENCOUNTER:
			_encounter_input(key_event)
		VIEW_CRAFTING:
			_crafting_input(key_event)
		_:
			_handle_map_input(key_event)


func _handle_map_input(key_event: InputEventKey) -> void:
	match key_event.keycode:
		KEY_LEFT, KEY_A:
			_move(-1, 0)
		KEY_RIGHT, KEY_D:
			_move(1, 0)
		KEY_UP, KEY_W:
			_move(0, -1)
		KEY_DOWN, KEY_S:
			_move(0, 1)
		KEY_SPACE:
			_advance_ticks(_ticks_per_day())
		KEY_M:
			_advance_ticks(_ticks_per_day() * _days_per_month())
		KEY_Y:
			_advance_ticks(_ticks_per_day() * _days_per_month() * _months_per_year())
		KEY_G:
			_fast_forward(_months_per_year() * FAST_FORWARD_YEARS)
		KEY_T:
			_switch_view(VIEW_CITY)
		KEY_C:
			_enter_avatar()
		KEY_B:
			_force_encounter()
		KEY_Z:
			_silent_walk = not _silent_walk
			_status.text = "静默行走：开——路上不再停下来，时间照旧流动。" if _silent_walk \
				else "静默行走：关——路上会撞上人了。"
			_refresh()
		KEY_X:
			_enter_smuggling()
		KEY_Q:
			_enter_quest()
		KEY_E:
			_enter_event()
		KEY_R:
			_enter_trade()
		KEY_V:
			_enter_crafting()
		KEY_F:
			_gather_action()
		KEY_F5:
			_save()
		KEY_F9:
			_load()


func _avatar_input(key_event: InputEventKey) -> void:
	match key_event.keycode:
		KEY_UP, KEY_W:
			_avatar_move_cursor(-1)
		KEY_DOWN, KEY_S:
			_avatar_move_cursor(1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_avatar_act()
		KEY_R:
			_avatar_repair_portable()
		KEY_ESCAPE, KEY_C, KEY_T:
			_switch_view(VIEW_MAP)
		KEY_F5:
			_save()
		KEY_F9:
			_load()


func _handle_city_input(key_event: InputEventKey) -> void:
	var ids: Array = Array(_world.get_city_ids())
	match key_event.keycode:
		KEY_UP, KEY_W:
			_selected_city = maxi(0, _selected_city - 1)
			_refresh()
		KEY_DOWN, KEY_S:
			_selected_city = mini(ids.size() - 1, _selected_city + 1)
			_refresh()
		KEY_LEFT, KEY_A:
			_trend_dimension = posmod(_trend_dimension - 1, CityViewModel.DIMENSION_ORDER.size())
			_refresh()
		KEY_RIGHT, KEY_D:
			_trend_dimension = posmod(_trend_dimension + 1, CityViewModel.DIMENSION_ORDER.size())
			_refresh()
		KEY_T:
			_switch_view(VIEW_MAP)
		KEY_C:
			_enter_avatar()
		KEY_M:
			_advance_ticks(_ticks_per_day() * _days_per_month())
		KEY_Y:
			_advance_ticks(_ticks_per_day() * _days_per_month() * _months_per_year())
		KEY_G:
			_fast_forward(_months_per_year() * FAST_FORWARD_YEARS)
		KEY_F5:
			_save()
		KEY_F9:
			_load()
		KEY_ENTER, KEY_KP_ENTER:
			_invest_building()


## 对建筑条里选中的那座投资一档（D-69~D-72）。玩家私有状态即时落盘，
## 并不改动城市六维；费用与生效信息走 Feedback。
func _invest_building() -> void:
	if _world == null:
		return
	var detail: Dictionary = _panel.get("detail", {})
	var buildings: Array = detail.get("buildings", [])
	if _selected_building < 0 or _selected_building >= buildings.size():
		return
	var slot: Dictionary = buildings[_selected_building]
	if not bool(slot.get("investEnabled", false)):
		_status.text = "这座现在投不进去（钱不够、没到招商门槛或已到上限）。"
		return
	var city_id: String = str(detail.get("cityId", ""))
	var building_id: String = str(slot.get("buildingId", ""))
	var cfg: Dictionary = ContentLoader.get_building_config(building_id)
	var balance: Dictionary = ContentLoader.get_balance_section("buildings")
	var result: Dictionary = CityBuildings.invest(_world, city_id, building_id, cfg, balance)
	if not bool(result.get("ok", false)):
		_status.text = "投资失败：%s" % str(result.get("error", ""))
	else:
		_status.text = "已投资「%s」到 L%d，花费 %d 金。收益并入每月进账。" % [
			str(slot.get("displayName", building_id)),
			int(result.get("level", 0)),
			int(result.get("cost", 0)),
		]
	_refresh()


## 野外采集（M14）。站在城郊/野外的空地按 F：在采集点之间轮转，采一件当前点的
## 主掉物入包，并把对应生产技能熟练 +1。站在城里不行——闹市里没有矿脉可凿。
func _gather_action() -> void:
	if _world == null or _world.avatar == null:
		_status.text = "还没有化身，先完成开局创建。"
		return
	if _gathering == null:
		_status.text = "采集层还没就绪。"
		return
	var standing: String = _grid.get_city_id_at(_world.avatar.pos_x, _world.avatar.pos_y)
	if not standing.is_empty():
		_status.text = "闹市没有可采的点——到城外来，按 F 采集。"
		return

	var spots: Array = ContentLoader.get_gathers()
	if spots.is_empty():
		_status.text = "这个世界还没布置采集点。"
		return
	_gather_seq = posmod(_gather_seq, spots.size())
	var spot: Dictionary = spots[_gather_seq]
	_gather_seq += 1
	var spot_id: String = str(spot.get("spotId", ""))
	var seed_text: String = "gather:%d,%d:%d" % [
		_world.avatar.pos_x, _world.avatar.pos_y, _gather_seq,
	]
	var result: Dictionary = _gathering.gather(_world.avatar, spot_id, seed_text)
	if not bool(result.get("ok", false)):
		_status.text = "采集失败：%s" % str(result.get("error", ""))
	else:
		var produced: Array = result.get("produced", [])
		var line: String = ""
		var first: Dictionary = produced[0] if not produced.is_empty() else {}
		if not first.is_empty():
			line = "%s ×%d" % [str(first.get("displayName", "")), int(first.get("count", 0))]
		var skill_label: String = str(spot.get("displayName", spot_id))
		_status.text = "在%s采到了 %s。%s熟练 +1。" % [
			skill_label, line, str(result.get("skill", "")),
		]
	_refresh()


# --- 制作台（M15）---

## 进入制作台。制作不需要挑城市——采到的材料带着走，在哪儿都做得成。
func _enter_crafting() -> void:
	if _world == null or _world.avatar == null:
		_status.text = "还没有化身，先完成开局创建。"
		return
	_crafting_cursor = 0
	_switch_view(VIEW_CRAFTING)
	_status.text = "制作台：采得的材料在这里变成用得上的货——熟练越高，做出的装备也越好。"


func _refresh_crafting() -> void:
	if _world == null or _world.avatar == null:
		_crafting_view = {}
		return
	_crafting_view = CraftingViewModel.build(
		_crafting, _world.avatar, _lookups, _crafting_cursor
	)
	_crafting_cursor = int(_crafting_view.get("cursor", 0))


func _crafting_move_cursor(delta: int) -> void:
	var rows: Array = _crafting_view.get("rows", [])
	if rows.is_empty():
		return
	_crafting_cursor = clampi(_crafting_cursor + delta, 0, rows.size() - 1)
	_refresh()


## 制作台回车：做选中那一行。配方行走 Crafting.craft（附魔自动挑第一件匹配目标），
## 采集行走 _gather_action 的同一套逻辑（采到的料当场入包）。
func _crafting_confirm() -> void:
	var row: Dictionary = _crafting_view.get("selected", {})
	if row.is_empty():
		return
	if str(row.get("kind", "")) == CraftingViewModel.KIND_GATHER:
		_gather_action()
		return
	var recipe_id: String = str(row.get("recipeId", ""))
	var target_id: String = ""
	if str(row.get("kind", "")) == "enchant":
		var target: Dictionary = CraftingViewModel.find_enchant_target(
			_world.avatar, _crafting.recipe(recipe_id), _table("itemTemplates"))
		if not bool(target.get("found", false)):
			_status.text = "背包里没有可附魔的目标——先拿一件能附的装备。"
			return
		target_id = str(target.get("instanceId", ""))
	var result: Dictionary = _crafting.craft(_world.avatar, recipe_id, target_id)
	if not bool(result.get("ok", false)):
		_status.text = "做不成：%s" % str(result.get("error", ""))
	else:
		var skill: String = str(result.get("skill", ""))
		if str(row.get("kind", "")) == "enchant":
			var tgt: Dictionary = result.get("target", {})
			_status.text = "附魔完成：%s已附上「%s」。%s熟练 +1。" % [
				str(tgt.get("templateId", "")), str(row.get("displayName", "")), skill,
			]
		else:
			var produced: Array = result.get("produced", [])
			var parts: Array = []
			for p in produced:
				parts.append("%s ×%d" % [str(p.get("displayName", "")), 1])
			var line: String = "、".join(PackedStringArray(parts))
			_status.text = "做成：%s。%s熟练 +1。" % [line, skill]
	_refresh()


func _crafting_click(point: Vector2) -> void:
	var hit: Dictionary = CraftingPanel.hit_test(_crafting_view, PANEL_RECT, point)
	match str(hit.get("kind", "")):
		"button":
			_switch_view(VIEW_MAP)
		"row":
			var index: int = int(hit.get("index", -1))
			if index == _crafting_cursor:
				_crafting_confirm()
				return
			_crafting_cursor = index
			_refresh()


func _crafting_input(key_event: InputEventKey) -> void:
	match key_event.keycode:
		KEY_UP, KEY_W:
			_crafting_move_cursor(-1)
		KEY_DOWN, KEY_S:
			_crafting_move_cursor(1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_crafting_confirm()
		KEY_ESCAPE, KEY_T:
			_switch_view(VIEW_MAP)


func _switch_view(view: int) -> void:
	_view = view
	# 悬停目标跟着视图走。不清掉的话，切过来的一瞬间新面板上会有一个
	# 莫名其妙高亮着的按钮——鼠标还没动过，却被上一屏的坐标指着。
	_hover = {}
	_hover_signature = ""
	_apply_view_visibility()
	_refresh()


func _move(dx: int, dy: int) -> void:
	if _world.avatar == null:
		return
	var moved: Vector2i = _grid.step(_world.avatar.pos_x, _world.avatar.pos_y, dx, dy)
	if moved.x == _world.avatar.pos_x and moved.y == _world.avatar.pos_y:
		_status.text = "已到地图边缘。"
	else:
		_world.avatar.pos_x = moved.x
		_world.avatar.pos_y = moved.y
		var city_id: String = _grid.get_city_id_at(moved.x, moved.y)
		_status.text = "" if city_id.is_empty() else "进入 %s。" % city_id
		# 走完这一步再判遭遇：先落到新格子上，判定读的才是"你站在哪里"
		_encounter_advance(1)
	_refresh()


func _advance_ticks(ticks: int) -> void:
	Clock.advance(ticks)
	_refresh()


## 快进：批量结算 + 只推进时钟核心，不经过信号。若快进也走信号，
## 时钟发一次、fastForward 里又结算一次，同一个月份会被结算两遍。
func _fast_forward(months: int) -> void:
	var report: Dictionary = _sim.fast_forward(Clock.total_months(), months)
	Clock.core().advance_months(months)
	_note_events(report["notableEvents"])
	# 快进期间不逐月留归因（中间态没人看），改由面板显示趋势
	_last_deltas = {}
	_status.text = "快进 %d 个月，至第 %d 月。按 T 查看这一百年的变化曲线。" % [
		int(report["monthsAdvanced"]), int(report["endMonth"])
	]
	_refresh()


func _save() -> void:
	if _world.avatar == null:
		_status.text = "还没有化身，先完成开局创建再保存。"
		_refresh()
		return
	# 战斗过程不进存档（会话是内存态的），所以战斗期间不给存——
	# 否则存下去的是"战斗前"的世界，读回来却以为刚打完，两边对不上。
	if _combat != null and not _combat.finished:
		_status.text = "战斗中不能保存：战斗过程不进存档。"
		_refresh()
		return
	var result: Dictionary = SaveIO.save_slot(SAVE_SLOT, _world, _soul, Clock.to_dict())
	if result.get("ok", false):
		_status.text = "已保存（%d 字节）。" % int(result.get("bytes", 0))
	else:
		_status.text = "保存失败：%s" % str(result.get("error", ""))
	_refresh()


func _load() -> void:
	var loaded: Dictionary = SaveIO.load_slot(SAVE_SLOT)
	if not loaded.get("ok", false):
		_status.text = "读取失败：%s" % str(loaded.get("error", ""))
		_refresh()
		return
	var grid_cfg: Dictionary = ContentLoader.get_balance_section("worldGrid")
	var rebuilt: Dictionary = WorldFactory.from_save(
		loaded["worldData"],
		ContentLoader.get_city_configs(),
		int(grid_cfg.get("width", 120)),
		int(grid_cfg.get("height", 120))
	)
	_world = rebuilt["world"]
	_grid = rebuilt["grid"]
	_sim = WorldSim.create(_world)
	_encounter_system = EncounterSystem.create(_world, _grid, _derived)
	Clock.restore(loaded["timeData"])
	if _soul != null:
		_soul = SoulRecord.from_dict(loaded["soulData"])
	_last_deltas = {}
	# 读档回到地图视图：存档里没有战斗会话。至于"创建到一半"的状态，它整个在
	# CreationSession 里，而读档之后没有回到创建界面的路径，所以不必清。
	_combat = null
	_combat_seq = 0
	_quest_combat = {}
	_event_combat = {}
	# 遭遇是会话状态（不落盘），读档之后回到"没有正在进行的遭遇"
	_reset_encounter_session()
	var note: String = "已读取。" if not loaded.get("usedBackup", false) else "主存档损坏，已从备份读取。"
	_status.text = note
	_switch_view(VIEW_MAP)


func _draw() -> void:
	if _grid == null or _world == null:
		return
	match _view:
		VIEW_CITY:
			CityPanel.draw(self, _panel, PANEL_RECT, _hover)
		VIEW_CREATION:
			CreationPanel.draw(self, _creation_session.view, PANEL_RECT, _hover)
		VIEW_AVATAR:
			AvatarPanel.draw(self, _avatar_view, PANEL_RECT, _hover)
		VIEW_COMBAT:
			CombatPanel.draw(self, _combat_view, PANEL_RECT, _hover)
		VIEW_SMUGGLING:
			SmugglingPanel.draw(self, _smuggling_view, PANEL_RECT, _hover)
		VIEW_QUEST:
			QuestPanel.draw(self, _quest_view, PANEL_RECT, _hover)
		VIEW_EVENT:
			EventPanel.draw(self, _event_view, PANEL_RECT, _hover)
		VIEW_TRADE:
			TradePanel.draw(self, _trade_view, PANEL_RECT, _hover)
		VIEW_ENCOUNTER:
			EncounterPanel.draw(self, _encounter_view, PANEL_RECT, _hover)
		VIEW_CRAFTING:
			CraftingPanel.draw(self, _crafting_view, PANEL_RECT, _hover)
		_:
			_draw_map()


func _draw_map() -> void:
	var map_px: Vector2 = Vector2(_grid.width * TILE, _grid.height * TILE)
	draw_rect(Rect2(MAP_ORIGIN, map_px), Color(0.07, 0.08, 0.10))

	var grid_color: Color = Color(0.15, 0.17, 0.21)
	for x in range(_grid.width + 1):
		var px: float = MAP_ORIGIN.x + x * TILE
		draw_line(Vector2(px, MAP_ORIGIN.y), Vector2(px, MAP_ORIGIN.y + map_px.y), grid_color, 1.0)
	for y in range(_grid.height + 1):
		var py: float = MAP_ORIGIN.y + y * TILE
		draw_line(Vector2(MAP_ORIGIN.x, py), Vector2(MAP_ORIGIN.x + map_px.x, py), grid_color, 1.0)

	# 先画商路，让城市方块压在上面
	for route in _world.get_routes_sorted():
		var ca: City = _world.get_city(str(route.city_a))
		var cb: City = _world.get_city(str(route.city_b))
		if ca == null or cb == null:
			continue
		var color: Color = Color(0.35, 0.75, 0.55)
		if route.is_smuggling():
			color = Color(0.78, 0.42, 0.85)
		draw_line(
			MAP_ORIGIN + Vector2(ca.coord_x * TILE, ca.coord_y * TILE),
			MAP_ORIGIN + Vector2(cb.coord_x * TILE, cb.coord_y * TILE),
			color, 1.0
		)

	for city_id in _world.get_city_ids():
		var c: City = _world.get_city(city_id)
		var pos: Vector2 = MAP_ORIGIN + Vector2(c.coord_x * TILE, c.coord_y * TILE)
		# 方块大小随城市阶段变化，让"建模变化"在地图上直接可见（M6.3）
		var scale: float = 1.0 + float(c.get_tier()) * 0.35
		draw_rect(Rect2(pos - Vector2(TILE, TILE) * scale, Vector2(TILE, TILE) * 2.0 * scale),
			Color(0.85, 0.72, 0.35))
		# 上月人口净流出用红环标出来，衰败的城市在地图上一眼可见
		var population_milli: int = int(
			_last_deltas.get(city_id, {}).get(City.DIM_POPULATION, {}).get("milli", 0)
		)
		if population_milli < 0:
			var radius: float = TILE * (2.0 * scale + 1.4)
			draw_arc(pos, radius, 0.0, TAU, 20, Color(0.87, 0.44, 0.41), 1.0)

	if _world.avatar != null:
		var p: Vector2 = MAP_ORIGIN + Vector2(_world.avatar.pos_x * TILE, _world.avatar.pos_y * TILE)
		draw_rect(Rect2(p - Vector2(TILE, TILE) * 0.5, Vector2(TILE, TILE)),
			Color(0.35, 0.85, 0.95))


func _ticks_per_day() -> int:
	return int(ContentLoader.get_balance_section("time").get("ticksPerDay", 24))


func _days_per_month() -> int:
	return int(ContentLoader.get_balance_section("time").get("daysPerMonth", 30))


func _months_per_year() -> int:
	return int(ContentLoader.get_balance_section("time").get("monthsPerYear", 12))

