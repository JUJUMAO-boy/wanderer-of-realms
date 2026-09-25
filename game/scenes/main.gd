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
## 城内 / 副本按住方向键连续走的步进间隔（秒）。地图端不用它——地图按住走的是
## _walk 动画（逐格有速度）。这是 M22 手感补齐：城内 / 副本原是一次一格的硬跳。
const HELD_STEP_INTERVAL: float = 0.14
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
const VIEW_HISTORY: int = 11
const VIEW_NPC: int = 12
const VIEW_CITY_SPACE: int = 13
const VIEW_DUNGEON: int = 14
const VIEW_MERCHANT: int = 15

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
	VIEW_HISTORY: "↑↓ 翻阅史书    ESC 或 T 返回地图",
	VIEW_NPC: "↑↓ 选居民    ←→ 选动作    回车 交谈/送礼/雇佣    ◀▶ 送礼时改选物    1/2/3 快速交谈    ESC 或 T 返回城市",
	VIEW_CITY_SPACE: "方向键/WASD 走动    走到建筑/居民旁按回车 互动    点城门或 ESC/T 离开    城内 T 看城市总览",
	VIEW_DUNGEON: "方向键/WASD 或点格 行走    走到敌人旁按回车 交战    踩宝箱 拾取    到楼梯按回车 下潜    ESC/右下角 离开",
	VIEW_MERCHANT: "↑↓ 选货    回车 成交    Tab 换买/卖    ESC/T 离开",
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
var _selected_resident: int = 0      ## 居民面板里选中的第几位居民（M18）
var _npc_action_cursor: int = -1     ## 底部动作行的光标；-1 = 未选中动作（M18）
var _npc_choose_item: bool = false   ## 送礼选物子状态（M18）
var _npc_item_cursor: int = 0        ## 送礼选物时的物品光标（M18）
var _npc_city_id: String = ""        ## 正在看哪座城的居民（M18）
var _npc_view: Dictionary = {}       ## NpcInteractionViewModel 的成品（M18）

# 城内空间（M19）。纯视觉态、不进存档（与遭遇同一条处境）：进城即断，出城即清。
# 布局可复现，玩家点位只活在当前会话里。
var _city_space: Dictionary = {}     ## { city_id, layout, player:Vector2i }
var _city_space_view: Dictionary = {} ## CitySpaceViewModel 的成品
var _notable: Array = []
var _last_deltas: Dictionary = {}
var _panel: Dictionary = {}

## 鼠标悬停到的元素（hit_test 的结果）。只影响高亮，不参与判断。
## _hover_signature 是它的压扁形式：只在悬停目标真的换了才重绘，
## 否则鼠标每动一个像素都要重画整屏。
var _hover: Dictionary = {}
var _hover_signature: String = ""
## 左侧导航侧栏（M20）里鼠标悬停到第几个入口；-1 = 没在侧栏上。
var _nav_hover: int = -1

# 世界地图行走动画（M20 阶段一）。点地图不再是瞬移，而是先规划一条路线、
# 逐格走过去（视觉上逐格跳、画投影路线），动画完结时一次性判遭遇。
var _walk: Dictionary = {}
## 方向键按住持续走路（M22）。_held_dir 记当前按住的方向（按下置、松开清），
## _held_step_t 是按住的步进累积计时。地图端不用它：地图按住走的是 _walk 动画
## （见 _process），城内 / 副本按住靠这里定时跳格。
var _held_dir: Vector2i = Vector2i.ZERO
var _held_step_t: float = 0.0

## 这张世界的确定性地形纹理缓存。种子变了就重烘焙（见 _build_map_terrain）。
var _map_terrain_tex: ImageTexture = null
var _map_terrain_seed: int = -1

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

# 世界纪年史书（M16）。条目沉淀在 _world.chronicle（跨代落盘），界面只持有光标。
var _chronicle_cursor: int = 0
var _chronicle_view: Dictionary = {}

# 隐藏属性事件（M17）。会话级、不落盘（与遭遇同一条处境）：触发瞬间转入
# VIEW_EVENT 复用的抉择形态，选完即收场，不留事件实例在世界里。界面只持有
# "在走哪条 config、在哪扇门（城）、光标在哪"。
var _hidden_event: Dictionary = {}
var _hidden_city_id: String = ""
var _hidden_view: Dictionary = {}
var _hidden_cursor: int = 0
## 上一次推进检查的月份。推进过夜那一下判一次（幸运类），同月反复推进不再判。
var _hidden_last_advance_month: int = -1

# --- 祈祷（M25/M-A）---
# 会话级、不落盘，复用 VIEW_EVENT 的抉择形态（同 D-90 那条惯例）：B 键开祈祷
# 列表 → 选一位神 → 回车结算恩惠/神罚 → 记一条事件流 → 回地图。神不落存档。
var _pray_active: bool = false
var _pray_view: Dictionary = {}
var _pray_cursor: int = 0

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

# 大地图可见实体（M-C：废墟/遗构 + 游荡怪物窝点）。会话级派生、不落盘：
# 读档后重新派生（已清窝点重生成）。_seen.monsters 是"仍存活"的窝点——击杀/绕开
# 就从中移除，本会话不再复活；遗构不随进入消失，离开后可再走进去（同一座，同布局）。
var _seen: Dictionary = {}
## 游荡时间桶。每落一格外野实际加一次，窝点用它与自身种子推出"此刻该在哪一格"，
## 于是图上能看见怪在窝点半径内慢慢挪——它不是静止的墨点。
var _seen_bucket: int = 0

# 临时副本（M21：野外奇遇 → 走进可探索网格）
var _dungeon: Dictionary = {}
var _dungeon_view: Dictionary = {}
var _dungeon_player: Vector2i = Vector2i.ZERO
var _dungeon_depth: int = 0
var _dungeon_seq: int = 0
## 这一场是不是从副本打起来的（战斗收尾要走副本那条结算）。
var _dungeon_combat: bool = false
## 这一场是不是训练战（M-B，D-135）：打赢给熟练度溢价、打输学费不退，
## 不进遭遇/委托那套掉落与世界标记结算。
var _sparring_active: bool = false
## 副本宝箱内容（templateId 数组，与 layout.treasures 对齐）；下楼层时重新生成。
var _dungeon_loot: Array = []
## 当前层是不是补给型主题（小镇哨站）：把这一层清完可以在哨站歇脚回满一口气。
var _dungeon_supply_ready: bool = false

# 游方商人（M21：地图商人奇遇）
var _merchant_view: Dictionary = {}
var _merchant_cursor: int = 0
var _merchant_side: String = Merchant.SIDE_BUY
var _merchant_seq: int = 0


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
			if _pray_active:
				_refresh_pray()
			elif not _hidden_event.is_empty():
				_refresh_hidden()
			else:
				_refresh_event()
		VIEW_TRADE:
			_refresh_trade()
		VIEW_ENCOUNTER:
			_refresh_encounter()
		VIEW_CRAFTING:
			_refresh_crafting()
		VIEW_HISTORY:
			_refresh_chronicle()
		VIEW_NPC:
			_refresh_npc()
		VIEW_CITY_SPACE:
			_refresh_city_space()
		VIEW_DUNGEON:
			_refresh_dungeon()
		VIEW_MERCHANT:
			_refresh_merchant()
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
	var hit: Dictionary = SmugglingPanel.hit_test(_smuggling_view, _content_rect(), point)
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
	var hit: Dictionary = QuestPanel.hit_test(_quest_view, _content_rect(), point)
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
	var hit: Dictionary = EventPanel.hit_test(_event_view, _content_rect(), point)
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


# --- 世界纪年史书（M16）---
#
# 只读史书：条目沉淀在 _world.chronicle（跨代落盘），这里不写它。键位只有
# 翻阅与返回——史书不是操作台，是给玩家翻开看的世界褶皱。

## 打开世界纪年史书。
func _enter_history() -> void:
	if _world == null:
		return
	_chronicle_cursor = 0
	_switch_view(VIEW_HISTORY)
	_status.text = "世界纪年：这个世界因谁改了什么，全在这本史书里。"


func _refresh_chronicle() -> void:
	_chronicle_view = ChronicleViewModel.build(_world.chronicle, _chronicle_cursor)
	_chronicle_cursor = int(_chronicle_view.get("cursor", 0))


func _history_move_cursor(delta: int) -> void:
	var count: int = maxi(1, int(_chronicle_view.get("rowCount", 0)))
	_chronicle_cursor = posmod(_chronicle_cursor + delta, count)
	_refresh()


func _history_page(delta: int) -> void:
	var visible: int = maxi(1, int(ChroniclePanel.list_rect(_content_rect()).size.y / ChroniclePanel.ROW_HEIGHT))
	_history_move_cursor(delta * visible)


## 点一行先把史书翻到那条，点同一行也只翻不执行——史书是只读的。
func _history_click(point: Vector2) -> void:
	var hit: Dictionary = ChroniclePanel.hit_test(_chronicle_view, _content_rect(), point)
	match str(hit.get("kind", "")):
		"button":
			_switch_view(VIEW_MAP)
		"row":
			_chronicle_cursor = int(hit["index"])
			_refresh()


func _history_input(key_event: InputEventKey) -> void:
	match key_event.keycode:
		KEY_UP, KEY_W:
			_history_move_cursor(-1)
		KEY_DOWN, KEY_S:
			_history_move_cursor(1)
		KEY_PAGEUP, KEY_PAGEDOWN:
			_history_page(1 if key_event.keycode == KEY_PAGEDOWN else -1)
		KEY_ESCAPE, KEY_T, KEY_H:
			_switch_view(VIEW_MAP)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_refresh()


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
	var hit: Dictionary = TradePanel.hit_test(_trade_view, _content_rect(), point)
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
	# 转生是在一世落幕之后才拿到的。先把落幕这世的姓名记下，供纪年史书用——
	# 否则 _place_avatar 一换人，旧躯壳的名字就没了。
	var ended_name: String = _world.avatar.display_name if _world.avatar != null else ""
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

	# 世界纪年史书（M16）：一世落幕，写进史书。落幕这世的序号以 _soul 的
	# reincarnation_count 计——它是"已经落幕了几世"，恰好就是这一世。
	if not ended_name.is_empty():
		var soul_month: int = Clock.total_months()
		_sim.chronicle.record(_world, _sim.chronicle.soul_entry(
			maxi(1, _soul.reincarnation_count), ended_name, soul_month))

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
		"isHero": true,
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


## 受训（训练师实体，M-B D-135）：付「铜币+业力」后开一场陪练战。
## 对手复用 _opponent_specs 的陪练曲线；打赢给熟练度溢价、打输学费不退。
## 这一场不挂 _quest/_event/_encounter 任何标签，_settle_combat 单独走 _resolve_sparring。
func _start_sparring(city_id: String) -> void:
	if _world == null or _world.avatar == null or _combat != null:
		return
	var ask: Dictionary = TrainingGate.quote(_world)
	if not bool(ask.get("ok", false)):
		_status.text = str(ask.get("reason", "训练师没收下你。"))
		_refresh()
		return
	var paid: Dictionary = TrainingGate.pay(_world)
	if not bool(paid.get("ok", false)):
		_status.text = str(paid.get("reason", "训练师没收下你。"))
		_refresh()
		return
	# 先落账再进场：训练是"先付的价"，胜败都是银货两讫。
	_note_events(["你付了 %d 铜与一丝业力，站进训练师的场地。" % int(paid["copper"])])

	_sparring_active = true
	_combat_seq += 1
	var rng := DeterministicRNG.new(_world.world_seed ^ (_combat_seq * 2246822519))
	_combat = Combat.new(
		_derived,
		ContentLoader.get_balance_section("combat"),
		ContentLoader.get_skills(),
		ContentLoader.get_items(),
		rng
	)
	var units: Array = [_player_unit_spec(_world.avatar)]
	units.append_array(_named_opponents(_opponent_specs(city_id, rng), "陪练"))
	var started: Dictionary = _combat.start({
		"sessionId": "sparring-%04d" % _combat_seq,
		"units": units,
		"obstacles": _battle_obstacles(),
	})
	if not bool(started.get("ok", false)):
		_status.text = "没能开练：%s" % str(started.get("reason", ""))
		_combat = null
		_sparring_active = false
		_refresh()
		return

	_combat_menu_mode = CombatViewModel.MENU_MAIN
	_combat_cursor = 0
	_combat_pending = {}
	_combat_cursor_tile = Vector2i.ZERO
	_switch_view(VIEW_COMBAT)
	_status.text = "训练场：%d 对 %d。打赢长本事，打输学费不退。" % [
		1, maxi(0, _combat.units.size() - 1)
	]
	_drive_enemies()


## 训练战收尾（M-B，D-135）。只发熟练度溢价；胜败都不退学费、不产掉落、不写世界标记。
func _resolve_sparring() -> void:
	_sparring_active = false
	if _combat == null:
		return
	_sync_combat_skills_to_avatar()
	var won: bool = _combat.winner == Combat.RESULT_PLAYER
	if won:
		_grant_sparring_reward()
	_status.text = "训练结束（%d 轮）：%s（学费不退）" % [
		_combat.round, "你讨到了新招式" if won else "你被放倒了"
	]
	_refresh()


## 训练胜的熟练度溢价：把 balance.training.skillGain 加到用得最多的那项技能上。
## 训练本身的"用进不废退"成长已经由 _sync_combat_skills_to_avatar 落了账，
## 这是训练师额外点拨的那一点——让"受训"比寻常打架更能涨。
func _grant_sparring_reward() -> void:
	if _world == null or _world.avatar == null:
		return
	var gain: int = int(ContentLoader.get_balance_section("training").get("skillGain", 0))
	if gain <= 0:
		return
	var best_id: String = ""
	var best: int = -1
	for skill_id in _world.avatar.skills:
		var lvl: int = int(_world.avatar.skills[skill_id])
		if lvl > best:
			best = lvl
			best_id = str(skill_id)
	if best_id.is_empty():
		return
	_world.avatar.skills[best_id] = clampi(best + gain, 0, 100)
	_note_events(["训练师点拨了一下：%s 的熟练度又涨了点。" % best_id])


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
				_exit_combat_to_context()
		return
	if not CombatViewModel.is_player_turn(_combat):
		return

	var menu: Array = _combat_view.get("menu", [])
	match key_event.keycode:
		KEY_ESCAPE:
			if _combat_menu_mode == CombatViewModel.MENU_MAIN:
				_exit_combat_to_context()
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


## 把当前在效的随从追加进本场战斗的单位表。没有随从契约就什么都不做。
## 随从是 side=player、controlled=auto 的盟友单元，由 _drive_enemies 自动驱动。
func _append_follower(units: Array) -> void:
	if _world == null or _world.avatar == null:
		return
	var hire: Dictionary = NpcInteractionSystem.current_hire(_world)
	if hire.is_empty():
		return
	var spec: Dictionary = NpcInteractionSystem.follower_combat_spec(_world.avatar, _world, hire)
	if not spec.is_empty():
		units.append(spec)


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
		# 只自动驱动 controlled=auto 的单位（敌人与随从）；轮到这前锋是 manual 的
		# 英雄就停下等玩家输入。随从是 side=player 但 controlled=auto，因此必须
		# 用 is_auto 判定而不是按 side 截止（M18）。
		if unit.is_empty() or not _combat.is_auto(current):
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
	_settle_follower_casualty()
	if _sparring_active:
		# 训练战（M-B，D-135）：只结熟练度溢价，不产掉落、不写世界标记，
		# 免得"陪练被放倒"在世界上留一道代价。
		_resolve_sparring()
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
	_apply_world_memory()
	if _encounter_combat:
		# 遭遇打起来的：掉落与世界标记先落（上面两圈），再补一条结算文案。
		# 与委托、事件同一条次序——战斗模块只产出结果，把它变成世界上的东西
		# 是调用方的事（10.1 第 3 条）。
		_resolve_encounter_combat()
		return
	if _dungeon_combat:
		_resolve_dungeon_combat()
		return
	_status.text = "交手结束（%d 轮）：%s" % [
			_combat.round, "你赢了" if _combat.winner == Combat.RESULT_PLAYER else "你输了"
		]


## 世界记忆结算（M-B，D-127/D-128）。玩家胜场里把"谁被怎么了"结进世界：
## 本城守卫被击杀 → 守备升级；本城店主被击杀 → 店主倒下 + 掉一件神器。
## 委托/事件战斗在更早的 return 已分流，这里只处理遭遇/副本这类"正面撞上"的战斗。
func _apply_world_memory() -> void:
	if _combat == null or _world == null:
		return
	if _combat.winner != Combat.RESULT_PLAYER:
		return
	for unit in _combat.units:
		if str(unit.get("side", "")) != Combat.SIDE_ENEMY:
			continue
		if not bool(unit.get("dead", false)):
			continue
		# 人形对手的 unitId 就是 NPC 的 id（见 EncounterSystem._npc_profile），
		# units_of 会剥掉 isNpc/npcId，但 unitId 保留——从这里追到人身上。
		var npc: SimNpc = _world.get_npc(str(unit.get("unitId", "")))
		if npc == null:
			continue
		if npc.position_id == "shopkeeper":
			if not WorldMemory.shopkeeper_fallen(_world, npc.city_id):
				WorldMemory.record_shopkeeper_fallen(_world, npc.city_id)
				_grant_shop_hoard()
				_note_events([WorldMemory.shopkeeper_label(_world, npc.city_id)])
		elif WorldMemory._is_guard_npc(npc):
			var boost: Dictionary = WorldMemory.guard_boost(_world, npc.city_id)
			WorldMemory.record_guard_claimed(_world, npc.city_id)
			if int(boost.get("count", 0)) < WorldMemory.BOOST_CAP:
				_note_events([str(boost.get("label", ""))])


## 击杀店主后掉落的"神器"：从货里硬挑一件 dragonforged/legendary 亲手塞进背包。
## 店主守着全城的铺子，身上那件是这条"代价"里最重的一枚。
func _grant_shop_hoard() -> void:
	for rarity in ["dragonforged", "legendary"]:
		for item in ContentLoader.get_items():
			if not (item is Dictionary):
				continue
			if str(item.get("rarity", "")) != rarity:
				continue
			_loot_seq += 1
			_creator.add_item(_world.avatar, str(item.get("templateId", "")),
				"%s-loot-%03d" % [_world.avatar.avatar_id, _loot_seq])
			_note_events(["你从倒下的店主身上搜出一件神造之物。"])
			return


## 找这座城的店主职位实体（M-B 店主实体化：每城一个书店铺的具名店主，落盘生成）。
func _shopkeeper_of(city_id: String) -> SimNpc:
	var city: City = _world.get_city(city_id)
	if city == null:
		return null
	for npc_id in city.npc_ids:
		var npc: SimNpc = _world.get_npc(str(npc_id))
		if npc != null and npc.position_id == "shopkeeper":
			return npc
	return null


## 袭店：把店主作为一位可交手的人形对手，走同一场遭遇战斗（_start_encounter_combat）。
## 店主身上没有世界模拟属性，在这一层现抽——与陪练/守卫同一条口径。击杀的后果由
## _apply_world_memory 结进世界（店主倒下 + 掉神器）。
func _start_shop_raid(city_id: String) -> void:
	if _world == null or _world.avatar == null:
		return
	var shopkeeper: SimNpc = _shopkeeper_of(city_id)
	if shopkeeper == null:
		_status.text = "这城没有可找的店主。"
		_refresh()
		return
	if WorldMemory.shopkeeper_fallen(_world, city_id):
		_status.text = WorldMemory.shopkeeper_label(_world, city_id)
		_refresh()
		return
	_combat_seq += 1
	var rng := DeterministicRNG.new(_world.world_seed ^ (_combat_seq * 2246822519))
	var attributes: Dictionary = _random_attributes(rng, 8, 13)
	var weapon: Dictionary = _common_template("weapon")
	_encounter = {
		"encounterId": "shop-raid-%s" % city_id,
		"opponents": [{
			"unitId": shopkeeper.npc_id,
			"name": shopkeeper.display_name(),
			"displayName": shopkeeper.display_name(),
			"category": ContentLoader.MONSTER_PARLEYABLE_CATEGORY,
			"attributes": attributes,
			"threatLevel": _threat_level(attributes, {}),
			"hp": _derived.max_hp(attributes, _derived.power_level(attributes, {})),
			"armor": int(_common_template("armor").get("armor", 0)),
			"attack": int(weapon.get("attack", 0)),
			"attackRange": 1,
		}],
	}
	_encounter_view = {"contextLabel": "袭击%s的铺子" % _city_label_or_wilds(city_id)}
	_start_encounter_combat()


## 随从战殁解约：如果本场带在身边的随从真的阵亡（dead，不是倒地），就解除契约
## 并记一条纪年。随从阵亡不判负（胜负只看英雄），但人回不来了。
func _settle_follower_casualty() -> void:
	for unit in _combat.units:
		if str(unit.get("side", "")) != Combat.SIDE_PLAYER:
			continue
		if bool(unit.get("isHero", false)):
			continue
		if not bool(unit.get("dead", false)):
			continue
		var npc_id: String = str(unit.get("unitId", "")).trim_prefix("follower_")
		if npc_id.is_empty() or not _world.active_hires.has(npc_id):
			continue
		var month: int = Clock.core().total_months() if Clock.core() != null else 0
		NpcInteractionSystem.dismiss(_world, npc_id, "%s在战斗中阵亡，契约随人而终。" % str(unit.get("name", "随从")), month)


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
	# 副本同属会话态（不落盘）：新世界/读档之后回到"没有正在探索的地下"
	_dungeon = {}
	_dungeon_view = {}
	_dungeon_player = Vector2i.ZERO
	_dungeon_depth = 0
	_dungeon_combat = false
	_dungeon_loot = []
	# 游方商人同属会话态：读档回来他早就走远了
	_merchant_view = {}
	_merchant_cursor = 0
	_merchant_side = Merchant.SIDE_BUY

	# 大地图可见实体随会话重建：由世界种子派生、不落盘，读档回来重生成
	_seen_bucket = 0
	_rebuild_seen()


## 重建大地图可见实体图纸（M-C）。每会话一次；窝点存活态随图纸重建而重置——
## 于是"读档回来打得只剩几只的怪会重新站满大地图"符合"能派生就不落盘"的铁则。
func _rebuild_seen() -> void:
	_seen = {}
	if _world == null or _grid == null:
		return
	var city_coords: Array = []
	for cid in _world.get_city_ids():
		var c: City = _world.get_city(cid)
		if c != null:
			city_coords.append(Vector2i(c.coord_x, c.coord_y))
	var opts: Dictionary = ContentLoader.get_balance_section("worldSeen")
	if _encounter_system != null:
		# 危险度前缀要贴近地理真实：离城越远越凶，与遭遇分层同源
		opts["tierAt"] = _encounter_system.tier_at
	var seen := WorldSeen.build(_world.world_seed, _grid, city_coords, opts)
	var alive: Dictionary = {}
	for lair in seen.lairs():
		alive[str(lair.get("key", ""))] = lair
	_seen = {"dungeons": seen.dungeons(), "monsters": alive}


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
		if _encounter.is_empty():
			_hidden_check("enter", city_id)
		return
	_last_city_id = ""
	_seen_bucket += 1
	if _silent_walk:
		# 静默行走期间不判定：否则关掉静默第一步就会撞上一场，而玩家按 Z 的
		# 意思正是"我要专心赶路"。可见的怪/遗构也一并让路——静默=不惹事。
		_encounter_steps = 0
		return
	# M-C：走上可见实体优先触发——怪物窝点→遭遇战，遗构→走进去。这一支取代了
	# 旧版"野外随机掷副本 / 遭遇的计数器"，把"撞没撞上"的决定权交回地图本身。
	var hit: Dictionary = _seen_node_at(pos)
	if not hit.is_empty():
		if str(hit.get("kind", "")) == "monster":
			_trigger_visible_combat(hit["node"])
		else:
			_trigger_visible_dungeon(hit["node"])
		return
	# 野外随机遭遇已被可见怪物取代，不再按步数掷对打。游方商车的随机偶遇保留，
	# 但照旧按 stepInterval 定价节奏走（不至于每走一步都迎面一辆车）。
	_encounter_steps += maxi(0, steps)
	if not _encounter_system.should_check(_encounter_steps):
		return
	_encounter_steps = 0
	_merchant_discover_check()


# --- 昼夜·天候（M25/M-A）---
#
# 天候由世界种子 + 当天派生，纯确定性、不落盘（Weather.entry_at）。图上不新增
# 常驻面板：风暴会在地图行走与遭遇时露出——遭遇时对手被 Weather.enemy_mult 放大，
# 行走收尾那句状态把"该不该多走几步"念给你听。

## 当前这一格命中的天候。地图外踩不到天候，给晴和兜底。
func _current_weather() -> Dictionary:
	if _world == null:
		return Weather.entry_at(0, 0, ContentLoader.get_weathers())
	var day: int = Clock.now().day
	return Weather.entry_at(int(_world.world_seed), day, ContentLoader.get_weathers())


## 天候敌强：城里的治安偶遇不吹风，路/荒野才吃风暴倍率。对已落定的一场遭遇，
## 把对手的 hp / 攻击整体放大到 enemyMult。倍率钳 ≥1，所以至少是原地踏步。
func _apply_weather_boost(context: String) -> void:
	if context == EncounterSystem.CONTEXT_CITY:
		return
	if _encounter.is_empty():
		return
	var mult: float = Weather.enemy_mult(_current_weather())
	if mult <= 1.001:
		return
	var opponents: Array = _encounter.get("opponents", [])
	for opponent in opponents:
		if not (opponent is Dictionary):
			continue
		var hp: int = int(opponent.get("hp", 0))
		opponent["maxHp"] = int(round(float(hp) * mult))
		opponent["hp"] = int(round(float(hp) * mult))
		if opponent.has("attack"):
			opponent["attack"] = int(round(float(opponent["attack"]) * mult))


## 行走收尾照天候补一句"这段路走得久些"，并实打实多推进 movementCost 个小时
## （风日赶路就是比晴日慢）。只能在野外表态；城里没有天这回事。
func _apply_weather_walk(city_id: String) -> void:
	var weather: Dictionary = _current_weather()
	if not city_id.is_empty() or str(weather.get("id", "")) == "clear":
		return
	var wcost: int = Weather.movement_cost(weather)
	var label: String = str(weather.get("label", ""))
	if Weather.is_night(Clock.now().hour):
		_status.text += "（入夜了）"
	if wcost > 0:
		_advance_ticks(wcost)
		_status.text += "（%s，多耗了 %d 小时脚程）" % [label, wcost]
	elif not _status.text.is_empty():
		_status.text += "（今日%s）" % label


## 玩家现在这一格上压着哪座可见实体。窝点按当前游荡桶取"此刻的位置"，
## 遗构按固定座标取。返回 { kind, node } 或 {}。
func _seen_node_at(pos: Vector2i) -> Dictionary:
	var monsters: Dictionary = _seen.get("monsters", {})
	for key in monsters:
		var lair: Dictionary = monsters[key]
		if WorldSeen.lair_pos(lair, _seen_bucket) == pos:
			return {"kind": "monster", "node": lair}
	for node in _seen.get("dungeons", []):
		if int(node.get("x", -1)) == pos.x and int(node.get("y", -1)) == pos.y:
			return {"kind": "dungeon", "node": node}
	return {}


## 走上怪物窝点：清掉这个窝点（本会话不再复活），然后摇一场遭遇、进遭遇抉择视图。
## 复用 _encounter_check 全程（含战斗/绕开/交涉与结算），只是跳过概率——地图上
## 看见它、走上它，就必然是这一场，不存在"地图上明明有怪却骰子不响再接战"的误差。
func _trigger_visible_combat(node: Dictionary) -> void:
	if _encounter_system == null or _world.avatar == null:
		return
	_seen.get("monsters", {}).erase(str(node.get("key", "")))
	var pos := Vector2i(_world.avatar.pos_x, _world.avatar.pos_y)
	# 窝点在野外，不占城格（placement 已避让）；但保险起见别把它算成"进城遭遇"。
	var context: String = _encounter_system.context_at(pos)
	if context == EncounterSystem.CONTEXT_CITY:
		context = EncounterSystem.CONTEXT_WILD
	_encounter_check(context, _encounter_system.nearest_city_id(pos), true)


## 走上遗构：以该遗构的稳定序号作副本会话号（同座可复现、可重入），走进去。
## 遗构不随进入消失——离开后原格还在，可再走进去同一座、同一批布局与词条。
func _trigger_visible_dungeon(node: Dictionary) -> void:
	if _world.avatar == null:
		return
	_dungeon_seq = WorldSeen.node_seq(node)
	_enter_dungeon()
	var words: String = _seen_words_text(node)
	_status.text = "你踏进%s一处遗构%s。按回车触碰出口可下潜，越深越凶。" % [
		str(node.get("prefix", "沉眠的")), words,
	]


## 遗构的修正词条文案（0–2 条，逗号接在后面）。没有词条就不加任何字。
func _seen_words_text(node: Dictionary) -> String:
	var words: Array = node.get("words", [])
	if words.is_empty():
		return ""
	var labels: Array = []
	for w in words:
		var label: String = str(w.get("label", ""))
		if not label.is_empty():
			labels.append(label)
	if labels.is_empty():
		return ""
	return "（" + "、".join(labels) + "）"


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
	_apply_weather_boost(context)
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
	_append_follower(units)
	units.append_array(_encounter_system.units_of(_encounter, OPPONENT_SPAWNS))
	# 世界记忆：本城若有守卫被击杀过，新拉出来的这队守备明显更狠
	units = WorldMemory.boost_guard_units(units, _world)
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


# --- 隐藏属性事件（M17）---
#
# 会话级、不落盘、复用 VIEW_EVENT 的抉择形态（D-90）。三个钩子：进城（声誉/善恶
# 类）、推进过夜（幸运类）。触发即转入 VIEW_EVENT，选完即收场，不留事件实例。

## 当前钩子（timing）上有没有一条该出的隐藏事件。有就转入抉择会话；没有就安静
## 回退——它不是每帧都要刷的一次判定，一钩子只推一件事。
func _hidden_check(timing: String, city_id: String) -> void:
	if _world == null or _world.avatar == null:
		return
	if not _hidden_event.is_empty():
		return
	var config: Dictionary = HiddenAttributeSystem.find_for_timing(
		timing, _world.avatar, city_id, _world
	)
	if config.is_empty():
		return
	# 先落冷却，再进会话：触发的这件事这一世不再重复（fate.<templateId>）
	HiddenAttributeSystem.mark_triggered(config, _world)
	_hidden_event = config
	_hidden_city_id = city_id
	_hidden_cursor = 0
	_switch_view(VIEW_EVENT)
	_status.text = "命运在叩门：「%s」——怎么接，在你。ESC 可暂缓。" % str(
		config.get("displayName", ""))


func _refresh_hidden() -> void:
	if _hidden_event.is_empty():
		_hidden_view = {}
		return
	_hidden_view = HiddenEventViewModel.build(
		_hidden_event, _world.avatar, _hidden_city_id, _table("cityNames")
	)


func _hidden_input(key_event: InputEventKey) -> void:
	if _hidden_view.is_empty():
		return
	match key_event.keycode:
		KEY_UP, KEY_W:
			_hidden_cursor = maxi(0, _hidden_cursor - 1)
			_refresh()
		KEY_DOWN, KEY_S:
			_hidden_cursor = mini(_hidden_view.get("branches", []).size() - 1, _hidden_cursor + 1)
			_refresh()
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_hidden_confirm()
		KEY_ESCAPE, KEY_T:
			_finish_hidden("", "暂缓：命运还留着这一叩")


func _hidden_click(point: Vector2) -> void:
	var hit: Dictionary = EventPanel.hit_test(_hidden_view, _content_rect(), point)
	match str(hit.get("kind", "")):
		"button":
			if str(hit.get("id", "")) == "cancel":
				_finish_hidden("", "暂缓：命运还留着这一叩")
				return
			_finish_hidden("", "暂缓：命运还留着这一叩")
		"branch":
			_hidden_cursor = int(hit["index"])
			_hidden_confirm()


## 回车。选光标所落的做法，把后果结清进世界。
func _hidden_confirm() -> void:
	var branches: Array = _hidden_view.get("branches", [])
	if branches.is_empty():
		return
	var branch: Dictionary = branches[clampi(_hidden_cursor, 0, branches.size() - 1)]
	var raw_branch: Dictionary = _find_raw_branch(_hidden_event, str(branch.get("branchId", "")))
	if raw_branch.is_empty():
		_status.text = "这个做法还没准备好。"
		_refresh()
		return
	var result: Dictionary = HiddenAttributeSystem.apply_branch(
		_hidden_event, raw_branch, _world.avatar, _world,
		_hidden_city_id, Clock.total_months()
	)
	# 城市维度是提交给 WorldSim 落账的请求，与事件模块同一分工
	for change in result.get("changes", []):
		_sim.apply_state_change(change)
	# 转生「业」标记：写进 soul 的一笔，跨世作数
	var mark: String = str(result.get("mark", ""))
	if not mark.is_empty():
		_apply_hidden_mark(mark)
	_finish_hidden(str(result.get("label", "")), str(result.get("detail", "")))


## 找 config 里 branchId 对应的原始分支。视图里的行是预览（label/effect），
## 落账需要原始字段（karma/luck/money/changes/flags）。
func _find_raw_branch(config: Dictionary, branch_id: String) -> Dictionary:
	for branch in config.get("branches", []):
		if str(branch.get("branchId", "")) == branch_id:
			return branch
	return {}


## 收场：把这件事的一笔记进事件流，清会话，回地图。
func _finish_hidden(label: String, detail: String) -> void:
	var month: int = Clock.total_months()
	var notices: Array = []
	if not label.is_empty():
		notices.append({"month": month, "text": "「%s」%s" % [
			str(_hidden_event.get("displayName", "")), label
		]})
	elif not detail.is_empty():
		notices.append({"month": month, "text": str(detail)})
	_hidden_event = {}
	_hidden_view = {}
	_hidden_city_id = ""
	_note_events(notices)
	_switch_view(VIEW_MAP)
	if not detail.is_empty():
		_status.text = str(detail)


## 把转生的「业」标记落到灵魂上（跨世作数）。当前只做最小形态：写进 soul 的
## karmaCarry/luckCarry 之外再记一笔标记，供下一世开局读到。D-92/D-93。
func _apply_hidden_mark(mark: String) -> void:
	if _soul == null:
		return
	_soul.legacy_clues.append(mark)
	_soul.life_archives.append({
		"kind": "mark",
		"mark": mark,
		"month": Clock.total_months(),
		"note": _mark_note(mark),
	})


func _mark_note(mark: String) -> String:
	match mark:
		HiddenAttributeSystem.MARK_GOOD:
			return "善业加身，来世有贵人相扶"
		HiddenAttributeSystem.MARK_EVIL:
			return "恶业缠身，来世易遭仇家寻衅"
		HiddenAttributeSystem.MARK_LUCK:
			return "气运所钟，来世开局得一分吉星"
	return "命运的痕迹"


# --- 祈祷（M25/M-A）---
#
# 会话级、不落盘、复用 VIEW_EVENT 的抉择形态（同 D-90 那条惯例）。P 键在地图
# 上开祈祷：一阵致敬四位神，回车任选一位即结算恩惠/神罚，记一条事件流回地图。
# 神不落存档——每次打开都用当前善恶现算虔诚。

func _open_prayer() -> void:
	if _world == null or _world.avatar == null:
		return
	_pray_active = true
	_pray_cursor = 0
	_switch_view(VIEW_EVENT)
	_status.text = "你跪下，向诸神求一字回音。↑↓ 选神，回车落地。ESC 回地图。"
	_refresh()


func _refresh_pray() -> void:
	if not _pray_active or _world == null or _world.avatar == null:
		_pray_view = {}
		return
	_pray_view = PrayerViewModel.build(
		ContentLoader.get_gods(), _world.avatar.karma, _table("cityNames")
	)


func _pray_input(key_event: InputEventKey) -> void:
	if _pray_view.is_empty():
		return
	match key_event.keycode:
		KEY_UP, KEY_W:
			_pray_cursor = maxi(0, _pray_cursor - 1)
			_refresh()
		KEY_DOWN, KEY_S:
			_pray_cursor = mini(_pray_view.get("branches", []).size() - 1, _pray_cursor + 1)
			_refresh()
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_pray_confirm()
		KEY_ESCAPE, KEY_T:
			_pray_cancel()


func _pray_click(point: Vector2) -> void:
	var hit: Dictionary = EventPanel.hit_test(_pray_view, _content_rect(), point)
	match str(hit.get("kind", "")):
		"button":
			_pray_cancel()
		"branch":
			_pray_cursor = int(hit["index"])
			_pray_confirm()


## 回车。选光标所落的神，把这次祈祷结清。
func _pray_confirm() -> void:
	var branches: Array = _pray_view.get("branches", [])
	if branches.is_empty():
		return
	var branch: Dictionary = branches[clampi(_pray_cursor, 0, branches.size() - 1)]
	var god: Dictionary = ContentLoader.get_god(str(branch.get("godId", "")))
	if god.is_empty():
		_status.text = "这位神不在此处。"
		_refresh()
		return
	var result: Dictionary = GodBlessing.pray_result(
		god, _world.avatar.karma, int(_world.world_seed)
	)
	_pray_active = false
	_pray_view = {}
	var notice: String
	if bool(result.get("cursed", false)):
		notice = "向「%s」祈祷，它降下神罚：%s" % [
			str(god.get("name", "")), str(result.get("penalty", ""))]
		_status.text = "「%s」的注视变得冰冷：%s" % [
			str(god.get("name", "")), str(result.get("penalty", ""))]
	elif bool(result.get("ok", false)):
		notice = "向「%s」祈祷，得赐一档恩惠：%s" % [
			str(god.get("name", "")), str(result.get("effect", ""))]
		_status.text = "「%s」垂听，恩泽落身：%s" % [
			str(god.get("name", "")), str(result.get("effect", ""))]
	else:
		notice = "向「%s」祈祷，神未垂听（代价：%s）" % [
			str(god.get("name", "")), str(result.get("cost", ""))]
		_status.text = "「%s」没有回应你。（代价：%s）" % [
			str(god.get("name", "")), str(result.get("cost", ""))]
	_note_events([{"month": Clock.total_months(), "text": notice}])
	_switch_view(VIEW_MAP)


func _pray_cancel() -> void:
	_pray_active = false
	_pray_view = {}
	_switch_view(VIEW_MAP)


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
	# 二级面板先算左侧导航上的悬停（决定侧栏哪个入口亮起来），
	# 再算面板里的悬停。两者任何一个变了都要重绘。
	var nav_hover: int = -1
	if _is_secondary_view(_view):
		nav_hover = HudNav.hit(HudNav.layout(_nav_rect()), point)
	var hover: Dictionary = _hit_test_at(point)
	var signature: String = _hover_signature_of(hover)
	if signature == _hover_signature and nav_hover == _nav_hover:
		return
	_nav_hover = nav_hover
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
			return CityPanel.hit_test(_panel, _content_rect(), point)
		VIEW_AVATAR:
			return AvatarPanel.hit_test(_avatar_view, _content_rect(), point)
		VIEW_COMBAT:
			return CombatPanel.hit_test(_combat_view, PANEL_RECT, point)
		VIEW_SMUGGLING:
			return SmugglingPanel.hit_test(_smuggling_view, _content_rect(), point)
		VIEW_QUEST:
			return QuestPanel.hit_test(_quest_view, _content_rect(), point)
		VIEW_EVENT:
			return EventPanel.hit_test(
				_hidden_view if not _hidden_event.is_empty() else _event_view,
				_content_rect(), point
			)
		VIEW_TRADE:
			return TradePanel.hit_test(_trade_view, _content_rect(), point)
		VIEW_ENCOUNTER:
			return EncounterPanel.hit_test(_encounter_view, PANEL_RECT, point)
		VIEW_CRAFTING:
			return CraftingPanel.hit_test(_crafting_view, _content_rect(), point)
		VIEW_HISTORY:
			return ChroniclePanel.hit_test(_chronicle_view, _content_rect(), point)
		VIEW_NPC:
			return NpcInteractionPanel.hit_test(_npc_view, _content_rect(), point)
		VIEW_CITY_SPACE:
			return CitySpacePanel.hit_test(_city_space_view, _content_rect(), point)
		VIEW_DUNGEON:
			return DungeonPanel.hit_test(_dungeon_view, _content_rect(), point)
		VIEW_MERCHANT:
			return MerchantPanel.hit_test(_merchant_view, _content_rect(), point)
	return {}


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if not event.pressed:
		return
	# 地图视图支持右击：点在城池上就直接走进去（M19）。左键的一切照旧。
	if event.button_index == MOUSE_BUTTON_RIGHT and _view == VIEW_MAP:
		_map_right_click(event.position)
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	# 二级面板下放给面板之前，先看左侧导航：命中入口就切视图，不再进面板。
	if _is_secondary_view(_view):
		var nav_items: Array = HudNav.layout(_nav_rect())
		var nav_index: int = HudNav.hit(nav_items, event.position)
		if nav_index >= 0:
			_nav_go(int(nav_items[nav_index]["view"]))
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
			if _pray_active:
				_pray_click(event.position)
			elif not _hidden_event.is_empty():
				_hidden_click(event.position)
			else:
				_event_click(event.position)
		VIEW_TRADE:
			_trade_click(event.position)
		VIEW_ENCOUNTER:
			_encounter_click(event.position)
		VIEW_CRAFTING:
			_crafting_click(event.position)
		VIEW_HISTORY:
			_history_click(event.position)
		VIEW_NPC:
			_npc_click(event.position)
		VIEW_CITY_SPACE:
			_city_space_click(event.position)
		VIEW_DUNGEON:
			_dungeon_click(event.position)
		VIEW_MERCHANT:
			_merchant_click(event.position)
		_:
			_map_click(event.position)


# --- 鼠标：城市面板 ---

func _city_click(point: Vector2) -> void:
	var hit: Dictionary = CityPanel.hit_test(_panel, _content_rect(), point)
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
			# 居民与人物：进城看人。M18
			if str(hit.get("id", "")) == "residents":
				_enter_residents(_selected_city_id())
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
	var hit: Dictionary = AvatarPanel.hit_test(_avatar_view, _content_rect(), point)
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
			_exit_combat_to_context()
		return
	if not CombatViewModel.is_player_turn(_combat):
		_status.text = "现在轮到敌方行动。"
		_refresh()
		return
	match kind:
		"button":
			_exit_combat_to_context()
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
			_enter_city_space(city_id)
			return
		# 走到城所在的格，而不是点到的那一格：大方块的边缘会被算进邻格，
		# 目标是"进城"，落点就该是城的坐标
		_walk_to(Vector2i(city.coord_x, city.coord_y))
		return
	var tile: Vector2i = _tile_at_point(point)
	if tile.x < 0:
		return
	_walk_to(tile)


## 地图上的右击：点在城池上就进它的城内空间（M19），与"走到城再点一次"同一条
## 规则，省一步。点空地还是走过去的普通左键行为。
func _map_right_click(point: Vector2) -> void:
	if _world.avatar == null:
		return
	var city_id: String = _city_at_point(point)
	if city_id.is_empty():
		return
	var city: City = _world.get_city(city_id)
	if city == null:
		return
	if _world.avatar.pos_x == city.coord_x and _world.avatar.pos_y == city.coord_y:
		_enter_city_space(city_id)
	else:
		_walk_to(Vector2i(city.coord_x, city.coord_y))


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


## 走到目标格。地图上没有任何障碍（MapGrid.can_enter 只查边界），所以路线必然
## 可达。M20 起改为：先规划一条路线、逐格走过去（点地图从瞬移改成看得见的走动），
## 动画完结时一次性把总步数交给遭遇去攒，避免"点一下地图"变成连着打好几场。
func _walk_to(tile: Vector2i) -> void:
	var avatar: PlayerAvatar = _world.avatar
	var path: Array = _plot_walk_path(Vector2i(avatar.pos_x, avatar.pos_y), tile)
	# 已在目标格（或路线为空）：不进动画，清掉可能的残留行走态，直接报状态。
	if path.is_empty():
		if not _walk.is_empty():
			_walk = {}
			set_process(false)
		_report_walk_stop(0)
		return
	_walk = {
		"path": path,
		"idx": 0,
		"t": 0.0,
		"total": path.size(),
		"draw_from": Vector2i(avatar.pos_x, avatar.pos_y),
		"draw_to": path[0],
	}
	set_process(true)
	_status.text = "规划路线，向 (%d, %d) 行进…" % [tile.x, tile.y]
	queue_redraw()


## 沿 signi 朝 dest 一步步收集路线（不含起点、含终点）。斜走一步同时收两个轴的差，
## 所以步数 = 两向距离的较长者；地图无遮挡必然可达，上限只是兜底。
func _plot_walk_path(start: Vector2i, dest: Vector2i) -> Array:
	var path: Array = []
	var cursor: Vector2i = start
	var steps: int = 0
	while steps < MAP_WALK_LIMIT and (cursor.x != dest.x or cursor.y != dest.y):
		steps += 1
		var next: Vector2i = _grid.step(cursor.x, cursor.y,
			signi(dest.x - cursor.x), signi(dest.y - cursor.y))
		if next.x == cursor.x and next.y == cursor.y:
			break
		path.append(next)
		cursor = next
	return path


## 走完的收尾：清空行走态、关掉逐帧推进，报"走了几格 + 在哪"，并一次判遭遇。
func _finish_walk() -> void:
	var total: int = int(_walk.get("total", 0))
	_walk = {}
	set_process(false)
	_report_walk_stop(total)


## 报"走了 N 格、现在在 (x,y)"，站在城里时补一句"再点一次看它的状态"，
## 并把步数一次交给遭遇积累。
func _report_walk_stop(steps: int) -> void:
	var avatar: PlayerAvatar = _world.avatar
	var city_id: String = _grid.get_city_id_at(avatar.pos_x, avatar.pos_y)
	var here: String = ""
	if not city_id.is_empty():
		# 站在城里时报出"再点一次"能开面板——不然"点城市"这条规则要靠猜
		here = "，这里是%s（再点一次看它的状态）" % str(_table("cityNames").get(city_id, city_id))
	_status.text = "走了 %d 格，现在在 (%d, %d)%s。" % [steps, avatar.pos_x, avatar.pos_y, here]
	_encounter_advance(steps)
	_apply_weather_walk(city_id)
	_refresh()


## 行走动画的逐格推进 + M22 方向键按住持续走路。
## 地图的 _walk 动画在点地图时由 set_process(true) 激活；地图按住方向键时无 _walk
## （地图方向键单步走 _move），城内 / 副本按住时也借着这个 _process 定时跳格。
func _process(delta: float) -> void:
	if _view == VIEW_MAP:
		if not _walk.is_empty():
			var path: Array = _walk["path"]
			_walk["t"] = float(_walk["t"]) + delta * float(_walk.get("speed", 12.0))
			while float(_walk["t"]) >= 1.0:
				_walk["t"] = float(_walk["t"]) - 1.0
				var idx: int = int(_walk["idx"])
				if idx >= path.size():
					break
				var cell: Vector2i = path[idx]
				_world.avatar.pos_x = cell.x
				_world.avatar.pos_y = cell.y
				_walk["idx"] = idx + 1
				_walk["draw_from"] = cell
				if idx + 1 < path.size():
					_walk["draw_to"] = path[idx + 1]
				if idx >= path.size() - 1:
					_finish_walk()
					return
			queue_redraw()
		elif _held_dir != Vector2i.ZERO:
			# 地图按住方向键：每格间隔走一步（与 _move 同口径，每步判遭遇）
			_step_held_dir(delta)
		return
	# 城内 / 副本按住方向键：定时跳格
	if _view == VIEW_CITY_SPACE or _view == VIEW_DUNGEON:
		_step_held_dir(delta)


# --- 城内空间（M19）---

## 进入一座城的城内空间。只做会话态（不落盘）：布局可复现，玩家点位只在当前会话。
func _enter_city_space(city_id: String) -> void:
	if _world == null or _world.avatar == null:
		_status.text = "还没有化身，先完成开局创建。"
		_refresh()
		return
	var ids: Array = Array(_world.get_city_ids())
	if not ids.has(city_id):
		return
	var building_ids: Array = ContentLoader.get_city_building_ids(city_id)
	var npc_ids: Array = []
	for npc in _world.get_city_npcs(city_id):
		npc_ids.append(npc.npc_id)
	_city_space = {
		"city_id": city_id,
		"layout": CitySpace.layout(city_id, building_ids, npc_ids),
		"player": CitySpace.SPAWN,
	}
	_selected_city = maxi(0, ids.find(city_id))
	_switch_view(VIEW_CITY_SPACE)
	_status.text = "进入%s。城内随你走：走到建筑/居民旁按回车互动，走到城门离开。" % city_id


func _leave_city_space() -> void:
	_city_space = {}
	_switch_view(VIEW_MAP)


func _refresh_city_space() -> void:
	if _world == null or _city_space.is_empty():
		_city_space_view = {}
		return
	var layout: Dictionary = _city_space["layout"]
	var building_labels: Dictionary = {}
	for slot in layout.get("buildings", []):
		var cfg: Dictionary = ContentLoader.get_building_config(str(slot["id"]))
		building_labels[str(slot["id"])] = str(cfg.get("displayName", str(slot["id"])))
	var npc_labels: Dictionary = {}
	for n in layout.get("npcs", []):
		var npc: SimNpc = _world.get_npc(str(n["id"]))
		npc_labels[str(n["id"])] = npc.display_name() if npc != null else str(n["id"])
	_city_space_view = CitySpaceViewModel.build(layout, _city_space["player"],
		building_labels, npc_labels, _content_rect())


## 空格/回车：站在建筑旁就开它的功能视图，站在居民旁就看居民，否则提示。
func _city_space_interact() -> void:
	if _world == null or _city_space.is_empty():
		return
	var layout: Dictionary = _city_space["layout"]
	var pos: Vector2i = _city_space["player"]
	var near_b: Dictionary = CitySpace.near_building(layout, pos)
	if not near_b.is_empty():
		_city_space_open_kind(str(near_b.get("kind", "")))
		return
	var npc_id: String = CitySpace.near_npc(layout, pos)
	if not npc_id.is_empty():
		# 训练师是个站在场地旁的人：走近按回车就受训（M-B，D-135），
		# 其余居民才走"看居民"的列表。
		if _is_trainer_npc(npc_id):
			_start_sparring(str(_city_space["city_id"]))
			return
		_enter_residents(str(_city_space["city_id"]))
		return
	_status.text = "旁边没有可互动的建筑或居民。"
	_refresh()


## 这座城里按 positionId 找训练师（职务由 professions.json 的 trainer 职位补上）。
func _is_trainer_npc(npc_id: String) -> bool:
	var npc: SimNpc = _world.get_npc(npc_id) if _world != null else null
	return npc != null and npc.position_id == "trainer"


## 袭店（I 键）：站在店铺格旁才砸得动，把店主拉进一场遭遇战斗。
func _run_city_space_raid() -> void:
	if _world == null or _city_space.is_empty():
		return
	var layout: Dictionary = _city_space["layout"]
	var near_b: Dictionary = CitySpace.near_building(layout, _city_space["player"])
	if near_b.is_empty() or str(near_b.get("kind", "")) != CitySpace.KIND_SHOP:
		_status.text = "旁边没有铺子可砸。"
		_refresh()
		return
	_start_shop_raid(str(_city_space.get("city_id", "")))


## 按建筑功能分流到既有视图。投资类回城市总览去投（M12 的投资就在那里）。
func _city_space_open_kind(kind: String) -> void:
	var city_id: String = str(_city_space.get("city_id", ""))
	match kind:
		CitySpace.KIND_SHOP:
			if WorldMemory.shopkeeper_fallen(_world, city_id):
				_status.text = WorldMemory.shopkeeper_label(_world, city_id)
				_refresh()
				return
			_enter_trade(city_id)
		CitySpace.KIND_EVENT:
			_enter_event(city_id)
		CitySpace.KIND_QUEST:
			_enter_quest(city_id)
		CitySpace.KIND_RESIDENTS:
			_enter_residents(city_id)
		CitySpace.KIND_SMUGGLING:
			_enter_smuggling(city_id)
		_:
			_selected_city = maxi(0, Array(_world.get_city_ids()).find(city_id))
			_switch_view(VIEW_CITY)


func _city_space_step(dx: int, dy: int) -> void:
	if _world == null or _city_space.is_empty():
		return
	var layout: Dictionary = _city_space["layout"]
	var result: Dictionary = CitySpace.step(layout, _city_space["player"], dx, dy)
	if not bool(result["ok"]):
		_status.text = "这里走不过去。"
		_refresh()
		return
	_city_space["player"] = result["next"]
	if bool(result["at_gate"]):
		_leave_city_space()
		return
	_refresh()


func _city_space_input(key_event: InputEventKey) -> void:
	match key_event.keycode:
		KEY_LEFT, KEY_A:
			_city_space_step(-1, 0)
		KEY_RIGHT, KEY_D:
			_city_space_step(1, 0)
		KEY_UP, KEY_W:
			_city_space_step(0, -1)
		KEY_DOWN, KEY_S:
			_city_space_step(0, 1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_city_space_interact()
		KEY_T:
			_switch_view(VIEW_CITY)
		KEY_I:
			_run_city_space_raid()
		KEY_ESCAPE:
			_leave_city_space()
		KEY_F5:
			_save()
		KEY_F9:
			_load()


## 城内点击：点空地走过去，点建筑走近后自动进入，点城门离开。
func _city_space_click(point: Vector2) -> void:
	if _world == null or _city_space.is_empty():
		return
	var hit: Dictionary = CitySpacePanel.hit_test(_city_space_view, _content_rect(), point)
	if hit.is_empty():
		return
	match str(hit.get("kind", "")):
		"gate":
			_leave_city_space()
		"building":
			_city_space_approach_building(int(hit.get("index", -1)))
		"cell":
			_city_space_walk_to(hit.get("grid", Vector2i()))


## 逐格走向某目标格。撞建筑停下（与地图 _walk_to 同款兜底）。
func _city_space_walk_to(target: Vector2i) -> void:
	if _city_space.is_empty():
		return
	var layout: Dictionary = _city_space["layout"]
	var pos: Vector2i = _city_space["player"]
	var steps: int = 0
	var limit: int = CitySpace.WIDTH * CitySpace.HEIGHT
	while steps < limit and (pos.x != target.x or pos.y != target.y):
		steps += 1
		var next: Vector2i = pos
		var dx: int = signi(target.x - pos.x)
		var dy: int = signi(target.y - pos.y)
		if dx != 0:
			var rx: Dictionary = CitySpace.step(layout, pos, dx, 0)
			if bool(rx["ok"]):
				next = rx["next"]
		if next == pos and dy != 0:
			var ry: Dictionary = CitySpace.step(layout, pos, 0, dy)
			if bool(ry["ok"]):
				next = ry["next"]
		if next == pos:
			break
		pos = next
	_city_space["player"] = pos
	_refresh()


## 走向一座建筑，贴到它邻格后自动进它的功能视图。
func _city_space_approach_building(index: int) -> void:
	if _city_space.is_empty():
		return
	var layout: Dictionary = _city_space["layout"]
	var buildings: Array = layout.get("buildings", [])
	if index < 0 or index >= buildings.size():
		return
	var target_kind: String = str(buildings[index]["kind"])
	var pos: Vector2i = _city_space["player"]
	var steps: int = 0
	var limit: int = CitySpace.WIDTH * CitySpace.HEIGHT
	while steps < limit:
		var near_b: Dictionary = CitySpace.near_building(layout, pos)
		if not near_b.is_empty() and str(near_b.get("kind", "")) == target_kind:
			break
		steps += 1
		var b: Dictionary = buildings[index]
		var cx: int = b["x"] + int(b["w"]) / 2
		var cy: int = b["y"] + int(b["h"]) / 2
		var next: Vector2i = pos
		var dx: int = signi(cx - pos.x)
		var dy: int = signi(cy - pos.y)
		if dx != 0:
			var rx: Dictionary = CitySpace.step(layout, pos, dx, 0)
			if bool(rx["ok"]):
				next = rx["next"]
		if next == pos and dy != 0:
			var ry: Dictionary = CitySpace.step(layout, pos, 0, dy)
			if bool(ry["ok"]):
				next = ry["next"]
		if next == pos:
			break
		pos = next
		_city_space["player"] = pos
	_city_space_open_kind(target_kind)


# --- 临时副本（M21：野外奇遇 → 走进可探索网格）---

## 进入副本：建第 1 层、把玩家放到出生点、生成这一层的宝箱内容。
func _enter_dungeon() -> void:
	if _world.avatar == null:
		return
	_dungeon_depth = 0
	_dungeon_player = Dungeon.SPAWN
	_dungeon_combat = false
	var dungeon_theme: Dictionary = _dungeon_theme_cfg()
	_dungeon = Dungeon.layout("dungeon-%04d" % _dungeon_seq, _dungeon_depth,
		{"theme": dungeon_theme})
	_dungeon_loot = _dungeon_roll_loot(_dungeon, _dungeon_rng())
	_dungeon_supply_ready = bool(_dungeon.get("theme", {}).get("hasSupply", false))
	_switch_view(VIEW_DUNGEON)
	_status.text = "你发现了一道向下延伸的入口，决定进去看看。按回车触碰出口可下潜，越深越凶。"


## 副本专用的随机源：会话号混进种子，同一座副本（同一序号）完全可复现，
## 但每次新发现都是新布局（序号递增）。
func _dungeon_rng() -> DeterministicRNG:
	return DeterministicRNG.new((_world.world_seed ^ (_dungeon_seq * 733977134)) & 0xFFFFFFFF)


## 组装主题配置（M23, A）：把 dungeon 段的 themeEvery / themeTreasureMult /
## themeEnemyMult / themes 映射成 Dungeon.theme_for 认的 every / treasureMult /
## enemyMult / themes。满了 themeEvery 层才触发，回非主题层取不到键也不报错。
func _dungeon_theme_cfg() -> Dictionary:
	var rules: Dictionary = ContentLoader.get_balance_section("dungeon")
	return {
		"every": maxi(1, int(rules.get("themeEvery", 5))),
		"treasureMult": float(rules.get("themeTreasureMult", 1.5)),
		"enemyMult": float(rules.get("themeEnemyMult", 1.2)),
		"themes": (rules.get("themes", []) as Array).duplicate(),
	}


## 为某一层生成与宝箱数量等长的战利品清单（templateId 数组）。
func _dungeon_roll_loot(layout: Dictionary, rng: DeterministicRNG) -> Array:
	var out: Array = []
	var count: int = (layout.get("treasures", []) as Array).size()
	if count <= 0:
		return out
	# 只从玩家真能用的类别里挑：武器 / 护甲 / 消耗品。材料与工具不进副本宝箱。
	var pool: Array = []
	for item in ContentLoader.get_items():
		if str(item.get("category", "")) in ["weapon", "armor", "consumable"]:
			pool.append(item)
	if pool.is_empty():
		for _i in range(count):
			out.append("")
		return out
	for _i in range(count):
		var item: Dictionary = pool[rng.next_int(pool.size())]
		out.append(str(item.get("templateId", "")))
	return out


## 重新整理视图数据（放回出生点 / 刷新楼层 / 重新生成宝箱内容都要走它）。
func _refresh_dungeon() -> void:
	if _world == null or _dungeon.is_empty():
		_dungeon_view = {}
		return
	_dungeon_view = DungeonViewModel.build(_dungeon, _dungeon_player, _content_rect(), {
		"depthHint": "越深越凶，下面的石头里藏着更怪的东西",
	})


## 副本键盘输入：方向走格，回车触碰出口/敌人，ESC 离开。
func _dungeon_input(key_event: InputEventKey) -> void:
	if _dungeon.is_empty():
		return
	match key_event.keycode:
		KEY_LEFT, KEY_A:
			_dungeon_step(-1, 0)
		KEY_RIGHT, KEY_D:
			_dungeon_step(1, 0)
		KEY_UP, KEY_W:
			_dungeon_step(0, -1)
		KEY_DOWN, KEY_S:
			_dungeon_step(0, 1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_dungeon_interact()
		KEY_ESCAPE:
			_leave_dungeon()
		KEY_F5:
			_save()
		KEY_F9:
			_load()


## 副本点击：点格走过去。途经宝箱/敌人会顺手触发；点到出口就走向楼梯等回车。
func _dungeon_click(point: Vector2) -> void:
	if _world == null or _dungeon.is_empty():
		return
	var hit: Dictionary = DungeonPanel.hit_test(_dungeon_view, _content_rect(), point)
	if hit.is_empty():
		return
	_dungeon_walk_to(hit.get("grid", Vector2i()))


## 走一步。撞墙不动；踩上宝箱就拾取并移除；踩上敌人就开战；碰到出口停下提示。
func _dungeon_step(dx: int, dy: int) -> void:
	if _world == null or _dungeon.is_empty():
		return
	var result: Dictionary = Dungeon.step(_dungeon, _dungeon_player, dx, dy)
	if not bool(result["ok"]):
		_status.text = "这里撞上了石壁。"
		_refresh()
		return
	_dungeon_player = result["next"]
	# 踩上任何一格先看看有没有宝箱：拾取并移除（一次性）
	var t_index: int = Dungeon.treasure_index(_dungeon, _dungeon_player)
	if t_index >= 0:
		_dungeon_pick_treasure(t_index)
	# 踩上敌人格：直接开战，不再继续走
	var e_index: int = Dungeon.enemy_index(_dungeon, _dungeon_player)
	if e_index >= 0:
		_dungeon_pick_enemy(e_index)
		return
	if bool(result["atExit"]):
		_status.text = "这是出口：按回车下潜到下一层，按 ESC 离开副本。"
	_refresh()


## 玩家要走向的最近可走路径（逐格逼近，直线优先）。撞到敌人/宝箱停下，让交互就近触发。
func _dungeon_walk_to(target: Vector2i) -> void:
	if _dungeon.is_empty():
		return
	var pos: Vector2i = _dungeon_player
	var steps: int = 0
	var limit: int = Dungeon.WIDTH * Dungeon.HEIGHT
	while steps < limit and (pos.x != target.x or pos.y != target.y):
		steps += 1
		var next: Vector2i = pos
		var dx: int = signi(target.x - pos.x)
		var dy: int = signi(target.y - pos.y)
		if dx != 0:
			var rx: Dictionary = Dungeon.step(_dungeon, pos, dx, 0)
			if bool(rx["ok"]):
				next = rx["next"]
		if next == pos and dy != 0:
			var ry: Dictionary = Dungeon.step(_dungeon, pos, 0, dy)
			if bool(ry["ok"]):
				next = ry["next"]
		if next == pos:
			break
		pos = next
		_dungeon_player = pos
		var t: int = Dungeon.treasure_index(_dungeon, pos)
		if t >= 0:
			_dungeon_pick_treasure(t)
		var e: int = Dungeon.enemy_index(_dungeon, pos)
		if e >= 0:
			_dungeon_pick_enemy(e)
			_refresh()
			return
	_dungeon_player = pos
	if pos == target and _dungeon_player == Dungeon.EXIT:
		_status.text = "你走到出口：按回车下潜，按 ESC 离开。"
	_refresh()


## 回车：站在出口就下潜，站在敌人旁就开战，否则给一句方向提示。
func _dungeon_interact() -> void:
	if _world == null or _dungeon.is_empty():
		return
	# 站在出口 → 下潜
	if _dungeon_player == Dungeon.EXIT:
		_dungeon_descend()
		return
	var e_index: int = Dungeon.enemy_index(_dungeon, _dungeon_player)
	if e_index >= 0:
		_dungeon_pick_enemy(e_index)
		return
	_status.text = "这里什么都没有。走到出口按回车可下潜，按 ESC 离开副本。"
	_refresh()


## 拾取一枚宝箱：物品直接进背包（够用即可，不走逐件挑选）。
func _dungeon_pick_treasure(index: int) -> void:
	if _world.avatar == null:
		return
	var layout: Dictionary = _dungeon
	var treasures: Array = layout.get("treasures", [])
	if index < 0 or index >= treasures.size():
		return
	if index >= _dungeon_loot.size():
		return
	var template_id: String = str(_dungeon_loot[index])
	if template_id.is_empty():
		_status.text = "这只宝箱里空空的，什么也没留下。"
	else:
		_loot_seq += 1
		_creator.add_item(_world.avatar, template_id,
			"%s-dunloot-%03d" % [_world.avatar.avatar_id, _loot_seq])
		_status.text = "拾取了宝箱里的东西。"
	treasures.remove_at(index)
	_dungeon_loot.remove_at(index)
	_refresh()


## 撞上该层的敌人：开一场副本战斗。
func _dungeon_pick_enemy(index: int) -> void:
	if _world.avatar == null:
		return
	var enemies: Array = _dungeon.get("enemies", [])
	if index < 0 or index >= enemies.size():
		return
	# 该格敌人已被打掉（开战即清），避免同一格反复触发
	var cell: Dictionary = enemies[index]
	enemies.remove_at(index)
	_start_dungeon_combat(Vector2i(int(cell["x"]), int(cell["y"])))


## 按层深挑一条对手并开战。对手强度随层数走高（dungeon.enemyTiers）。
func _start_dungeon_combat(pos: Vector2i) -> void:
	var avatar: PlayerAvatar = _world.avatar
	var rules: Dictionary = ContentLoader.get_balance_section("dungeon")
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
	_append_follower(units)
	var spec: Dictionary = _dungeon_monster_spec(rules, _dungeon_depth, rng)
	if spec.is_empty():
		_combat = null
		_status.text = "这一层找不到能拦路的凶物。"
		_refresh()
		return
	units.append_array(_encounter_system.units_of(spec, OPPONENT_SPAWNS))
	var started: Dictionary = _combat.start({
		"sessionId": "dungeon-%s-d%d" % [str(_dungeon_seq), _dungeon_depth],
		"units": units,
		"obstacles": _battle_obstacles(),
	})
	if not bool(started.get("ok", false)):
		_status.text = "战斗没能开始：%s" % str(started.get("reason", ""))
		_combat = null
		return

	_dungeon_combat = true
	_combat_menu_mode = CombatViewModel.MENU_MAIN
	_combat_cursor = 0
	_combat_pending = {}
	_combat_cursor_tile = Vector2i.ZERO
	_switch_view(VIEW_COMBAT)
	_status.text = "在副本第 %d 层交手：%d 对 %d。" % [
		_dungeon_depth + 1, 1, maxi(0, _combat.units.size() - 1)
	]
	_drive_enemies()


## 按当前层深摇一场对手（复用遭遇生物表，但按 dungeon.enemyTiers 分档）。
func _dungeon_monster_spec(rules: Dictionary, depth: int, rng: DeterministicRNG) -> Dictionary:
	# 层深分三档，取对应的 TL 区间
	var tier: int = 0
	var tier_depth: Array = rules.get("tierDepth", [4, 10])
	if depth >= int(tier_depth[1]):
		tier = 2
	elif depth >= int(tier_depth[0]):
		tier = 1
	var lows: Array = rules.get("enemyTierMin", [1, 3, 6])
	var highs: Array = rules.get("enemyTierMax", [4, 6, 10])
	var tl_min: int = int(lows[clampi(tier, 0, lows.size() - 1)])
	var tl_max: int = int(highs[clampi(tier, 0, highs.size() - 1)])
	var pool: Array = []
	for entry in ContentLoader.get_monsters():
		if not (entry is Dictionary):
			continue
		var tl: int = int((entry as Dictionary).get("threatLevel", 0))
		if tl >= tl_min and tl <= tl_max:
			pool.append(entry)
	if pool.is_empty():
		return {}
	# 层深越深，同层多放几个（靠得住前面的敌群规模）
	var base: int = maxi(1, int(rules.get("enemyBase", 1)))
	@warning_ignore("integer_division")
	var per_depth: int = base + int(depth / maxi(1, int(rules.get("enemyPerDepthDivisor", 6))))
	var count: int = clampi(per_depth, 1, maxi(1, int(rules.get("maxOpponents", 3))))
	if count > 3:
		count = 3
	var picked: Dictionary = pool[rng.next_int(pool.size())]
	var opponents: Array = []
	# 数量多时给同一只的变体，但单位 id 各不相同
	for i in range(count):
		var name: String = str(picked.get("displayName", ""))
		if count > 1:
			name = "%s %d" % [name, i + 1]
		opponents.append({
			"unitId": "dungeon-%s-d%d-%d" % [_dungeon_seq, depth, i + 1],
			"name": name,
			"displayName": str(picked.get("displayName", "")),
			"category": str(picked.get("category", "")),
			"threatLevel": int(picked.get("threatLevel", 1)),
			"attributes": (picked.get("attributes", {}) as Dictionary).duplicate(),
			"hp": int(picked.get("hp", 0)),
			"armor": int(picked.get("armor", 0)),
			"magicResist": int(picked.get("magicResist", 0)),
			"attack": int(picked.get("attack", 0)),
			"attackRange": int(picked.get("attackRange", 1)),
			"parleyable": false,
			"isNpc": false,
			"npcId": "",
		})
	return {"title": str(picked.get("displayName", "地下的凶物")), "opponents": opponents}


## 副本战斗收尾：胜负都回到副本；赢了留在原地，输了离开副本回到地图。
func _resolve_dungeon_combat() -> void:
	_sync_combat_skills_to_avatar()
	var won: bool = _combat.winner == Combat.RESULT_PLAYER
	_dungeon_combat = false
	if won:
		_status.text = "你打退了守在这里的东西（第 %d 层）。" % (_dungeon_depth + 1)
		# 补给型主题（小镇哨站）：这一层的凶物都清光了，就在哨站歇脚回满一口气。
		if _dungeon_supply_ready and _dungeon.get("enemies", [] as Array).is_empty():
			_status.text = "这一层的哨站守住了防线，你在营地里歇了歇脚，精神完全恢复。"
		_switch_view(VIEW_DUNGEON)
	else:
		_status.text = "你在地底失去了知觉，醒来时已回到地面。"
		_leave_dungeon()


## 战斗结束回到"从哪打起来"的上下文：副本回去副本，其它回地图。
func _exit_combat_to_context() -> void:
	if _dungeon_combat:
		_switch_view(VIEW_DUNGEON)
	else:
		_switch_view(VIEW_MAP)


## 下潜一层：重排一层新图、放回出生点、重掷宝箱内容。到底后再按出口只提示。
func _dungeon_descend() -> void:
	if _world == null:
		return
	var rules: Dictionary = ContentLoader.get_balance_section("dungeon")
	var max_depth: int = maxi(1, int(rules.get("maxDepth", 20)))
	if _dungeon_depth >= max_depth - 1:
		_status.text = "再往下已经到头，这里就是这座地下最深的尽头。按 ESC 出去吧。"
		_refresh()
		return
	_dungeon_depth += 1
	_dungeon_player = Dungeon.SPAWN
	_dungeon = Dungeon.layout("dungeon-%04d" % _dungeon_seq, _dungeon_depth,
		{"theme": _dungeon_theme_cfg()})
	_dungeon_loot = _dungeon_roll_loot(_dungeon, _dungeon_rng())
	_dungeon_supply_ready = bool(_dungeon.get("theme", {}).get("hasSupply", false))
	_switch_view(VIEW_DUNGEON)
	_status.text = "你下到第 %d 层。地面上的光已经照不进来了。" % (_dungeon_depth + 1)


## 离开副本：回到世界地图，清空这次探索会话。
func _leave_dungeon() -> void:
	_dungeon = {}
	_dungeon_view = {}
	_dungeon_player = Vector2i.ZERO
	_dungeon_depth = 0
	_dungeon_combat = false
	_dungeon_loot = []
	_dungeon_supply_ready = false
	_switch_view(VIEW_MAP)


# --- 游方商人（M21：地图商人奇遇）---

## 野外没被拦、也没撞见地下入口时，再掷一次"迎面来了一架商车"。
func _merchant_discover_check() -> void:
	if _world.avatar == null or not _merchant_view.is_empty():
		return
	var rules: Dictionary = ContentLoader.get_balance_section("merchant")
	var chance: int = maxi(0, int(rules.get("discoverChanceBp", 0)))
	if chance <= 0:
		return
	_merchant_seq += 1
	var rng := DeterministicRNG.new(_world.world_seed ^ (_merchant_seq * 733977134))
	if rng.next_int(10000) >= chance:
		return
	_enter_merchant()


## 打开游方商人的车。独立货架 + 独立报价，与商店毫无瓜葛。
func _enter_merchant() -> void:
	if _world == null or _world.avatar == null:
		return
	var merchant: Merchant = Merchant.create(_world)
	merchant.stock_for("merchant-%04d" % _merchant_seq)
	_merchant_view = {"merchant": merchant}
	_merchant_cursor = 0
	_merchant_side = Merchant.SIDE_BUY
	_switch_view(VIEW_MERCHANT)
	_status.text = "迎面来了一架商车——行商的路与你的路在这里打了个照面。想买想卖都随你。"


func _refresh_merchant() -> void:
	if _world == null:
		_merchant_view = {}
		return
	var merchant: Merchant = _merchant_view.get("merchant", null)
	if not (merchant is Merchant) or merchant.stock_left().is_empty():
		# 货全光了就一直保留 board，让玩家能卖完货再走；但若压根没有车就清空
		if _merchant_view.get("merchant", null) == null:
			_merchant_view = {}
			return
	var avatar: PlayerAvatar = _world.avatar
	var money: int = 0 if avatar == null else avatar.money
	_merchant_view = MerchantViewModel.build(
		merchant,
		_lookups,
		avatar,
		_merchant_side,
		_merchant_cursor,
		money
	)
	_merchant_cursor = int(_merchant_view.get("cursor", 0))


func _merchant_input(key_event: InputEventKey) -> void:
	if _merchant_view.is_empty():
		return
	match key_event.keycode:
		KEY_UP, KEY_W:
			_merchant_move_cursor(-1)
		KEY_DOWN, KEY_S:
			_merchant_move_cursor(1)
		KEY_TAB:
			_merchant_switch_side()
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_merchant_confirm()
		KEY_ESCAPE, KEY_T:
			_leave_merchant()
		KEY_F5:
			_save()
		KEY_F9:
			_load()


func _merchant_click(point: Vector2) -> void:
	var hit: Dictionary = MerchantPanel.hit_test(_merchant_view, _content_rect(), point)
	match str(hit.get("kind", "")):
		"button":
			match str(hit.get("id", "")):
				"side":
					_merchant_switch_side()
				"deal":
					_merchant_confirm()
				_:
					_leave_merchant()
		"row":
			var index: int = int(hit["index"])
			if index == _merchant_cursor:
				_merchant_confirm()
				return
			_merchant_cursor = index
			_refresh()


func _merchant_move_cursor(delta: int) -> void:
	var count: int = maxi(1, int(_merchant_view.get("rowCount", 0)))
	_merchant_cursor = posmod(_merchant_cursor + delta, count)
	_refresh()


## 买 ⇄ 卖。光标归零：两边的列表是两份不同的东西。
func _merchant_switch_side() -> void:
	_merchant_side = Merchant.SIDE_SELL \
		if _merchant_side == Merchant.SIDE_BUY else Merchant.SIDE_BUY
	_merchant_cursor = 0
	_refresh()


## 成交。买走货架上的新货，或把背包里具体那一件卖给行商。
func _merchant_confirm() -> void:
	if not bool(_merchant_view.get("canTrade", false)):
		_status.text = str(_merchant_view.get("blockedReason", "现在做不成这笔买卖。"))
		_refresh()
		return
	var merchant: Merchant = _merchant_view.get("merchant", null)
	if not (merchant is Merchant):
		return
	var row: Dictionary = _merchant_view.get("selected", {})
	var avatar: PlayerAvatar = _world.avatar
	if avatar == null:
		return
	var template_id: String = str(row.get("templateId", ""))
	if _merchant_side == Merchant.SIDE_BUY:
		var price: int = int(row.get("price", 0))
		if avatar.money < price:
			_status.text = "钱不够。"
			_refresh()
			return
		avatar.money -= price
		_loot_seq += 1
		_creator.add_item(avatar, template_id,
			"%s-mercbuy-%03d" % [avatar.avatar_id, _loot_seq])
		merchant.buy_off_stock(template_id)
		_status.text = "买下 %s，付了 %s；身上还剩 %s。" % [
			str(row.get("label", "")),
			AvatarViewModel.money_label(price),
			AvatarViewModel.money_label(avatar.money),
		]
	else:
		var instance_id: String = str(row.get("instanceId", ""))
		if instance_id.is_empty() or not avatar.item_instances.has(instance_id):
			_status.text = "这件货不在你身上。"
			_refresh()
			return
		var price: int = int(row.get("price", 0))
		avatar.money += price
		_gear.unequip_if_worn(avatar, instance_id)
		avatar.inventory.erase(instance_id)
		avatar.item_instances.erase(instance_id)
		merchant.add_to_stock(template_id)
		_status.text = "卖给行商 %s，到手 %s；身上还剩 %s。" % [
			str(row.get("label", "")),
			AvatarViewModel.money_label(price),
			AvatarViewModel.money_label(avatar.money),
		]
	_refresh()


## 离开：回到地图。行商载着他的车继续赶路。
func _leave_merchant() -> void:
	_merchant_view = {}
	_merchant_cursor = 0
	_merchant_side = Merchant.SIDE_BUY
	_switch_view(VIEW_MAP)


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
	# M22 方向键按住持续走路：方向键在"按下"与"松开"两个时刻都放行。
	# 按下时记下将要持续走的方向，松开时清空——靠这一段记"按住态"，
	# 而不是依赖 OS 的重复按键（echo）。其余按键仍照旧丢弃 echo / 非按下。
	var dir_key: bool = key_event.keycode == KEY_LEFT or key_event.keycode == KEY_A \
		or key_event.keycode == KEY_RIGHT or key_event.keycode == KEY_D \
		or key_event.keycode == KEY_UP or key_event.keycode == KEY_W \
		or key_event.keycode == KEY_DOWN or key_event.keycode == KEY_S
	if dir_key:
		if key_event.pressed:
			_held_dir = _dir_from_key(key_event.keycode)
			_held_step_t = 0.0
			# 保证 _process 接管按住持续：只有点地图走 _walk 才会 set_process(true)，
			# 城内 / 副本仅靠方向键时 process 未必开着，按下时显式打开。
			set_process(true)
			# 按下那一下先走一步（有即时反馈），按住不放开时由 _process 续走
			_step_view_movement(_held_dir)
		else:
			_held_dir = Vector2i.ZERO
			_held_step_t = 0.0
			# 松开时若没有 _walk 动画在跑，process 没有别的活要干，关掉省心
			if _walk.is_empty():
				set_process(false)
		return
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
			if _pray_active:
				_pray_input(key_event)
			elif not _hidden_event.is_empty():
				_hidden_input(key_event)
			else:
				_event_input(key_event)
		VIEW_TRADE:
			_trade_input(key_event)
		VIEW_ENCOUNTER:
			_encounter_input(key_event)
		VIEW_CRAFTING:
			_crafting_input(key_event)
		VIEW_HISTORY:
			_history_input(key_event)
		VIEW_NPC:
			_npc_input(key_event)
		VIEW_CITY_SPACE:
			_city_space_input(key_event)
		VIEW_DUNGEON:
			_dungeon_input(key_event)
		VIEW_MERCHANT:
			_merchant_input(key_event)
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
		KEY_H:
			_enter_history()
		KEY_R:
			_enter_trade()
		KEY_V:
			_enter_crafting()
		KEY_F:
			_gather_action()
		KEY_P:
			_open_prayer()
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
		KEY_N:
			_enter_residents(_selected_city_id())
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
	var hit: Dictionary = CraftingPanel.hit_test(_crafting_view, _content_rect(), point)
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


# --- NPC 居民与人物（M18）---

func _enter_residents(city_id: String) -> void:
	if _world == null or _world.avatar == null:
		_status.text = "还没有化身，先完成开局创建。"
		return
	_npc_city_id = city_id
	_selected_resident = 0
	_npc_action_cursor = -1
	_npc_choose_item = false
	_npc_item_cursor = 0
	_switch_view(VIEW_NPC)


func _refresh_npc() -> void:
	if _world == null or _world.avatar == null:
		_npc_view = {}
		return
	var choosing: bool = _npc_choose_item
	_npc_view = NpcInteractionViewModel.build(
		NpcInteractionSystem, _world.avatar, _world, _npc_city_id,
		_selected_resident, _npc_action_cursor
	)
	_selected_resident = int(_npc_view.get("residentCursor", 0))
	var city: City = _world.get_city(_npc_city_id)
	_npc_view["subject"] = city.display_name if city != null else _npc_city_id
	_npc_view["choosingGift"] = choosing
	_npc_view["giftCursor"] = _npc_item_cursor


func _npc_move_cursor(delta: int) -> void:
	var rows: Array = _npc_view.get("rows", [])
	if rows.is_empty():
		return
	_selected_resident = clampi(_selected_resident + delta, 0, rows.size() - 1)
	_npc_action_cursor = -1
	_refresh()


func _npc_current_month() -> int:
	return Clock.core().total_months() if Clock.core() != null else 0


func _npc_selected() -> SimNpc:
	if _world == null:
		return null
	var row: Dictionary = _npc_view.get("selected", {})
	if row.is_empty():
		return null
	return _world.get_npc(str(row.get("npcId", "")))


func _npc_talk(intent: String) -> void:
	var npc: SimNpc = _npc_selected()
	if npc == null:
		_status.text = "没有选中的居民。"
		_refresh()
		return
	var result: Dictionary = NpcInteractionSystem.talk(_world.avatar, _world, npc, intent, _npc_current_month())
	if not bool(result.get("ok", false)):
		_status.text = "谈不成：%s" % str(result.get("reason", result.get("error", "")))
	else:
		_status.text = "%s（好感 %+d，现 %s）" % [
			str(result.get("line", "")), int(result.get("affDelta", 0)),
			str(result.get("bandLabel", "")),
		]
	_refresh()


func _npc_gift_candidates() -> Array:
	var out: Array = []
	if _world == null or _world.avatar == null:
		return out
	var npc: SimNpc = _npc_selected()
	for held in _world.avatar.inventory:
		var inst: Dictionary = _world.avatar.item_instances.get(held, {})
		var tpl: Dictionary = ContentLoader.get_item(str(inst.get("templateId", "")))
		if tpl.is_empty():
			continue
		out.append({
			"instanceId": str(held),
			"templateId": str(tpl.get("templateId", "")),
			"displayName": str(tpl.get("displayName", "")),
			"category": str(tpl.get("category", "")),
			"taste": _taste_label(npc, str(tpl.get("category", ""))),
		})
	return out


func _taste_label(npc: SimNpc, category: String) -> String:
	if npc == null:
		return ""
	var personality: Dictionary = ContentLoader.get_personality(npc.personality_id)
	var taste: Dictionary = personality.get("giftTaste", {})
	if (taste.get("love", []) as Array).has(category):
		return "他会喜欢"
	if (taste.get("hate", []) as Array).has(category):
		return "他会嫌弃"
	return "普通"


func _npc_gift_confirm() -> void:
	var candidates: Array = _npc_gift_candidates()
	if candidates.is_empty():
		_status.text = "你身上没有可送的东西。"
		_npc_choose_item = false
		_refresh()
		return
	_npc_item_cursor = clampi(_npc_item_cursor, 0, candidates.size() - 1)
	var item: Dictionary = candidates[_npc_item_cursor]
	var npc: SimNpc = _npc_selected()
	var result: Dictionary = NpcInteractionSystem.gift(
		_world.avatar, _world, npc, str(item.get("instanceId", "")), _npc_current_month())
	if not bool(result.get("ok", false)):
		_status.text = "送不成：%s" % str(result.get("reason", result.get("error", "")))
	else:
		_status.text = "%s（好感 %+d，现 %s）" % [
			str(result.get("line", "")), int(result.get("affDelta", 0)),
			str(result.get("bandLabel", "")),
		]
	_npc_choose_item = false
	_refresh()


func _npc_hire() -> void:
	var npc: SimNpc = _npc_selected()
	if npc == null:
		_status.text = "没有选中的居民。"
		_refresh()
		return
	var result: Dictionary = NpcInteractionSystem.hire(_world.avatar, _world, npc, _npc_current_month())
	if not bool(result.get("ok", false)):
		_status.text = "雇不成：%s" % str(result.get("reason", result.get("error", "")))
	else:
		_status.text = "%s已随行（%d月，%d铜）。他会在野外遭遇战里跟你并肩。" % [
			npc.given_name, int(result.get("months", 0)), int(result.get("cost", 0)),
		]
	_refresh()


func _npc_confirm_action() -> void:
	if _npc_action_cursor < 0:
		return
	var actions: Array = _npc_view.get("actions", [])
	if _npc_action_cursor >= actions.size():
		return
	var id: String = str(actions[_npc_action_cursor].get("id", ""))
	if not bool(actions[_npc_action_cursor].get("can", true)):
		_status.text = str(actions[_npc_action_cursor].get("reason", "现在做不了。"))
		_refresh()
		return
	if id == NpcInteractionViewModel.ACTION_GIFT:
		_npc_choose_item = true
		_npc_item_cursor = 0
		_refresh()
	elif id == NpcInteractionViewModel.ACTION_HIRE:
		_npc_action_cursor = -1
		_npc_hire()
	elif id == NpcInteractionViewModel.ACTION_TALK_AMBITION:
		_npc_action_cursor = -1
		_npc_talk(NpcInteractionSystem.INTENT_AMBITION)
	elif id == NpcInteractionViewModel.ACTION_TALK_RUMOR:
		_npc_action_cursor = -1
		_npc_talk(NpcInteractionSystem.INTENT_RUMOR)
	elif id == NpcInteractionViewModel.ACTION_TALK_FAITH:
		_npc_action_cursor = -1
		_npc_talk(NpcInteractionSystem.INTENT_FAITH)


func _npc_input(key_event: InputEventKey) -> void:
	var actions: Array = _npc_view.get("actions", [])
	if _npc_choose_item:
		var candidates: Array = _npc_gift_candidates()
		match key_event.keycode:
			KEY_LEFT, KEY_A:
				_npc_item_cursor = clampi(_npc_item_cursor - 1, 0, maxi(0, candidates.size() - 1))
				_refresh()
			KEY_RIGHT, KEY_D:
				_npc_item_cursor = clampi(_npc_item_cursor + 1, 0, maxi(0, candidates.size() - 1))
				_refresh()
			KEY_ENTER, KEY_KP_ENTER:
				_npc_gift_confirm()
			KEY_ESCAPE, KEY_T:
				_npc_choose_item = false
				_refresh()
		return
	match key_event.keycode:
		KEY_UP, KEY_W:
			_npc_move_cursor(-1)
		KEY_DOWN, KEY_S:
			_npc_move_cursor(1)
		KEY_LEFT, KEY_A:
			if not actions.is_empty():
				_npc_action_cursor = posmod(_npc_action_cursor - 1, actions.size())
				_refresh()
		KEY_RIGHT, KEY_D:
			if not actions.is_empty():
				_npc_action_cursor = posmod(maxi(0, _npc_action_cursor + 1), actions.size())
				_refresh()
		KEY_ENTER, KEY_KP_ENTER:
			_npc_confirm_action()
		KEY_1:
			_npc_talk(NpcInteractionSystem.INTENT_AMBITION)
		KEY_2:
			_npc_talk(NpcInteractionSystem.INTENT_RUMOR)
		KEY_3:
			_npc_talk(NpcInteractionSystem.INTENT_FAITH)
		KEY_ESCAPE, KEY_T:
			_switch_view(VIEW_CITY)


func _npc_click(point: Vector2) -> void:
	var hit: Dictionary = NpcInteractionPanel.hit_test(_npc_view, _content_rect(), point)
	match str(hit.get("kind", "")):
		"button":
			_switch_view(VIEW_CITY)
		"row":
			var index: int = int(hit.get("index", -1))
			if index == _selected_resident:
				_npc_action_cursor = 0
			else:
				_selected_resident = index
				_npc_action_cursor = -1
			_refresh()
		"action":
			_npc_action_cursor = int(hit.get("index", -1))
			_npc_confirm_action()


func _switch_view(view: int) -> void:
	_view = view
	# 按住方向键持续走路：切走视图就停。不然在别的界面上会一直"按着方向键走"
	_held_dir = Vector2i.ZERO
	_held_step_t = 0.0
	# 悬停目标跟着视图走。不清掉的话，切过来的一瞬间新面板上会有一个
	# 莫名其妙高亮着的按钮——鼠标还没动过，却被上一屏的坐标指着。
	_hover = {}
	_hover_signature = ""
	_nav_hover = -1
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


## 把方向键 / WASD 的键码翻译成移动方向。方向键与 WASD 两套键位共用一套方向语义。
func _dir_from_key(keycode: Key) -> Vector2i:
	match keycode:
		KEY_LEFT, KEY_A:
			return Vector2i(-1, 0)
		KEY_RIGHT, KEY_D:
			return Vector2i(1, 0)
		KEY_UP, KEY_W:
			return Vector2i(0, -1)
		KEY_DOWN, KEY_S:
			return Vector2i(0, 1)
	return Vector2i.ZERO


## 当前视图下朝某个方向走一步（M22 手感补齐）。地图走 _walk 动画（逐格、动画收尾
## 判一次遭遇，不因按住连判），城内 / 副本走各自的 step（即时跳格）。
func _step_view_movement(dir: Vector2i) -> void:
	match _view:
		VIEW_MAP:
			_move_step(dir)
		VIEW_CITY_SPACE:
			_city_space_step(dir.x, dir.y)
		VIEW_DUNGEON:
			_dungeon_step(dir.x, dir.y)


## 地图朝某个方向走近一格：把目标格（当前 + 方向）交给 _walk_to 走动画。
## 走完由 _finish_walk → _report_walk_stop 判一次遭遇，按住连走不会每格连环遭遇。
func _move_step(dir: Vector2i) -> void:
	if _world == null or _world.avatar == null:
		return
	var target: Vector2i = _grid.step(
		_world.avatar.pos_x, _world.avatar.pos_y, dir.x, dir.y)
	if target.x == _world.avatar.pos_x and target.y == _world.avatar.pos_y:
		_status.text = "已到地图边缘。"
		_refresh()
		return
	_walk_to(target)


## _process 里的按住持续步进。累加间隔，够一格就走一步；城内 / 副本松开即停。
func _step_held_dir(delta: float) -> void:
	if _held_dir == Vector2i.ZERO:
		return
	_held_step_t += delta
	if _held_step_t < HELD_STEP_INTERVAL:
		return
	_held_step_t = 0.0
	_step_view_movement(_held_dir)


## 推进时钟 tick。推进过夜那一下判一次隐藏事件（幸运类）。同月已判过就不再判，
## 免得按一次键被同一档属性连环弹出来。
func _advance_ticks(ticks: int) -> void:
	Clock.advance(ticks)
	if _world != null and _world.avatar != null and _hidden_event.is_empty():
		var month: int = Clock.total_months()
		if month != _hidden_last_advance_month:
			_hidden_last_advance_month = month
			_hidden_check("advance", _here_city_id())
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
			CityPanel.draw(self, _panel, _content_rect(), _hover)
		VIEW_CREATION:
			CreationPanel.draw(self, _creation_session.view, PANEL_RECT, _hover)
		VIEW_AVATAR:
			AvatarPanel.draw(self, _avatar_view, _content_rect(), _hover)
		VIEW_COMBAT:
			CombatPanel.draw(self, _combat_view, PANEL_RECT, _hover)
		VIEW_SMUGGLING:
			SmugglingPanel.draw(self, _smuggling_view, _content_rect(), _hover)
		VIEW_QUEST:
			QuestPanel.draw(self, _quest_view, _content_rect(), _hover)
		VIEW_EVENT:
			EventPanel.draw(self,
				_pray_view if _pray_active else (_hidden_view if not _hidden_event.is_empty() else _event_view),
				_content_rect(), _hover)
		VIEW_TRADE:
			TradePanel.draw(self, _trade_view, _content_rect(), _hover)
		VIEW_ENCOUNTER:
			EncounterPanel.draw(self, _encounter_view, PANEL_RECT, _hover)
		VIEW_CRAFTING:
			CraftingPanel.draw(self, _crafting_view, _content_rect(), _hover)
		VIEW_HISTORY:
			ChroniclePanel.draw(self, _chronicle_view, _content_rect(), _hover)
		VIEW_NPC:
			NpcInteractionPanel.draw(self, _npc_view, _content_rect(), _hover, _npc_gift_candidates())
		VIEW_CITY_SPACE:
			CitySpacePanel.draw(self, _city_space_view, _content_rect(), _hover)
		VIEW_DUNGEON:
			DungeonPanel.draw(self, _dungeon_view, _content_rect(), _hover)
		VIEW_MERCHANT:
			MerchantPanel.draw(self, _merchant_view, _content_rect(), _hover)
		_:
			_draw_map()
	# 二级面板在渲完自己之后，最上层叠一条左侧导航（M20 阶段一）。
	_draw_secondary_nav()


# --- 左侧垂直导航（M20 阶段一）---

## 导航侧栏占的左区：从地图原点起、宽 150、向下到面板底沿。
func _nav_rect() -> Rect2:
	return Rect2(16.0, 48.0, 150.0, PANEL_RECT.size.y)


## 二级面板的实际内容区。左侧导航占了 150px，二级面板就往右让出导航 + 一条
## 槽距，否则城市列表这类最左栏会被导航压住。地图/战斗/开局等非二级视图
## 还是原样铺满 PANEL_RECT。绘制与命中测试统一走这个，两边才不会错位。
func _content_rect() -> Rect2:
	if not _is_secondary_view(_view):
		return PANEL_RECT
	var shift: float = _nav_rect().size.x + 12.0
	return Rect2(PANEL_RECT.position + Vector2(shift, 0.0), PANEL_RECT.size)


## 哪些视图是"地图之下的二级面板"，需要叠左侧导航。战斗/遭遇/开局创建是
## 全屏会话，不该被侧栏挡住，也不在二级视图列表里。
func _is_secondary_view(view: int) -> bool:
	return view == VIEW_CITY or view == VIEW_TRADE or view == VIEW_SMUGGLING \
		or view == VIEW_QUEST or view == VIEW_EVENT or view == VIEW_AVATAR \
		or view == VIEW_CRAFTING or view == VIEW_HISTORY or view == VIEW_NPC \
		or view == VIEW_CITY_SPACE or view == VIEW_DUNGEON or view == VIEW_MERCHANT


## 侧栏入口按下。所有入口共用切视图这一条路，「返回世界地图」（VIEW_MAP）也在列。
func _nav_go(view: int) -> void:
	_switch_view(view)


## 在二级面板之上渲左侧导航。只有二级视图才会被 _draw 走到这里（见 _draw 末尾）。
func _draw_secondary_nav() -> void:
	if not _is_secondary_view(_view):
		return
	var nav_rect: Rect2 = _nav_rect()
	HudNav.draw(self, nav_rect, _view, HudNav.layout(nav_rect), _nav_hover)


func _draw_map() -> void:
	if _map_terrain_tex == null:
		_build_map_terrain()
	var map_px: Vector2 = Vector2(_grid.width * TILE, _grid.height * TILE)
	if _map_terrain_tex != null:
		draw_texture(_map_terrain_tex, MAP_ORIGIN)
	else:
		draw_rect(Rect2(MAP_ORIGIN, map_px), Color(0.07, 0.08, 0.10))
	# 外缘画一层细框，弱化地形贴边的生硬感
	draw_rect(Rect2(MAP_ORIGIN - Vector2(1.0, 1.0), map_px + Vector2(2.0, 2.0)),
		Color(0.16, 0.17, 0.20), false, 1.0)

	# 先画商路，让城市地标压在上面
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

	var font: Font = UiTheme.font()
	for city_id in _world.get_city_ids():
		var c: City = _world.get_city(city_id)
		var pos: Vector2 = MAP_ORIGIN + Vector2(c.coord_x * TILE, c.coord_y * TILE)
		# 淡金地标圆 + 中心深色小菱形 + 名签外排，取代原来的金色方块（M20 阶段一）
		var radius: float = 3.0 + float(c.get_tier()) * 1.2
		draw_circle(pos, radius, Color(0.85, 0.72, 0.35))
		var half: float = radius * 0.5
		draw_colored_polygon(PackedVector2Array([
			pos + Vector2(0.0, -half), pos + Vector2(half, 0.0),
			pos + Vector2(0.0, half), pos + Vector2(-half, 0.0),
		]), Color(0.33, 0.27, 0.13))
		# 名签排在右下，浅字可读；名签不参与命中测试（_city_at_point 仍按网格语义）
		if font != null:
			UiTheme.draw_text(self, font, pos + Vector2(radius + 3.0, 4.0),
				str(_table("cityNames").get(city_id, city_id)),
				Color(0.80, 0.81, 0.86), UiTheme.SIZE_SMALL)
		# 上月人口净流出用红环标出来，衰败的城市在地图上一眼可见
		var population_milli: int = int(
			_last_deltas.get(city_id, {}).get(City.DIM_POPULATION, {}).get("milli", 0)
		)
		if population_milli < 0:
			var ring: float = TILE * (2.0 * radius / 3.0 + 2.8)
			draw_arc(pos, ring, 0.0, TAU, 20, Color(0.87, 0.44, 0.41), 1.0)

	# M-C：大地图可见实体——遗构（青/蓝点）与怪物窝点（绯红点）。会自己出现、
	# 自己消失、窝点里的怪还在小范围游荡；图上看得见的才是这世界当下正在发生的。
	if not _seen.is_empty():
		_draw_seen_markers()

	# 化身：青色小圆。行走中就画在插值出来的位置上，并把后续路线高亮出来。
	if _world.avatar != null:
		var p: Vector2
		if not _walk.is_empty() and _view == VIEW_MAP:
			var f: Vector2 = Vector2(_walk["draw_from"])
			var to: Vector2 = Vector2(_walk["draw_to"])
			p = MAP_ORIGIN + f.lerp(to, float(_walk["t"])) * TILE
			_draw_walk_route()
		else:
			p = MAP_ORIGIN + Vector2(_world.avatar.pos_x * TILE, _world.avatar.pos_y * TILE)
		draw_circle(p, 3.0, Color(0.40, 0.88, 0.95))


## 画大地图可见实体（M-C）：遗构用青→蓝点（危险度越高越深越艳），怪物窝点用
## 绯红点（正在按游荡桶挪位）。名字不画在图上——一格才 5px，写了也看不清，读名
## 靠走上后的遭遇/遗构标题。
func _draw_seen_markers() -> void:
	# 遗构：危险度五档→五级青蓝。看得见的"这一页"，颜色先替玩家估一估里面的好坏。
	for node in _seen.get("dungeons", []):
		var danger: int = clampi(int(node.get("danger", 0)), 0, WorldSeen.DANGER_PREFIXES.size() - 1)
		var t: float = float(danger) / float(maxi(1, WorldSeen.DANGER_PREFIXES.size() - 1))
		var pint: float = clampf(0.25 + t * 0.55, 0.25, 0.8)
		var color := Color(lerpf(0.95, 0.55, t), lerpf(0.90, 0.60, t), lerpf(0.35, 0.95, t))
		var pos: Vector2 = MAP_ORIGIN + Vector2(
			int(node.get("x", 0)) * TILE, int(node.get("y", 0)) * TILE)
		# 亮青/蓝圆里垫一个深色小核，与城市的地标圆相区别（城市是淡金+深核）
		draw_circle(pos, 2.6, color)
		draw_circle(pos, 1.1, Color(0.10 + pint * 0.15, 0.14 + pint * 0.12, 0.22))
	# 怪物窝点（仍存活）：绯红点，位置 = 锚点 + 本桶偏移 → 看得见它在动。
	for key in _seen.get("monsters", {}):
		var lair: Dictionary = _seen["monsters"][key]
		var p: Vector2 = WorldSeen.lair_pos(lair, _seen_bucket)
		var mark: Vector2 = MAP_ORIGIN + Vector2(p.x * TILE, p.y * TILE)
		draw_circle(mark, 2.0, Color(0.87, 0.36, 0.38))
		draw_circle(mark, 0.9, Color(0.35, 0.08, 0.08))


## 把 _walk 里尚未走到的路线用柔金细线 + 圆点画出来（从化身当前位置串到终点）。
func _draw_walk_route() -> void:
	var path: Array = _walk["path"]
	var idx: int = int(_walk["idx"])
	if idx >= path.size():
		return
	var color := Color(0.90, 0.78, 0.45, 0.55)
	var f: Vector2 = Vector2(_walk["draw_from"])
	var to: Vector2 = Vector2(_walk["draw_to"])
	var p0: Vector2 = MAP_ORIGIN + f.lerp(to, float(_walk["t"])) * TILE
	var p1: Vector2 = MAP_ORIGIN + Vector2(to) * TILE
	draw_line(p0, p1, color, 1.0)
	for i in range(idx + 1, path.size()):
		var a: Vector2 = MAP_ORIGIN + Vector2(path[i - 1]) * TILE
		var b: Vector2 = MAP_ORIGIN + Vector2(path[i]) * TILE
		draw_line(a, b, color, 1.0)
		draw_circle(b, 1.5, color)


# 世界地图确定性地形。种子不变就复用缓存；世界换了（新世界 / 读回别的档）种子
# 变，_map_terrain_seed 对不上就重烘焙。逐像素填值噪音，形成大块有机色块，
# 而不是一格一色的棋盘。

func _build_map_terrain() -> void:
	if _grid == null or _world == null:
		return
	if _map_terrain_seed == _world.world_seed and _map_terrain_tex != null:
		return
	var w: int = _grid.width
	var h: int = _grid.height
	var img := Image.create(w * TILE, h * TILE, false, Image.FORMAT_RGBA8)
	var rng := DeterministicRNG.new(_world.world_seed)
	var seed1: int = rng.next_u32()
	var seed2: int = rng.next_u32()
	var seed3: int = rng.next_u32()
	for py in range(h * TILE):
		for px in range(w * TILE):
			# 两档频率的值噪音叠出大块色块：24 格的主形 + 8 格的细节
			var v: float = 0.62 * _value_noise(px, py, 24, seed1) \
				+ 0.38 * _value_noise(px, py, 8, seed2)
			# 一点点像素级抖动，让同色区域不是死板纯色
			v += (_hash01(px, py, seed3) - 0.5) * 0.08
			img.set_pixel(px, py, _terrain_color(v))
	_map_terrain_seed = _world.world_seed
	_map_terrain_tex = ImageTexture.create_from_image(img)


## 由噪音值分档出地形色：低=浅水，中=草地，偏高=林/丘陵，高=山（灰褐）。
func _terrain_color(v: float) -> Color:
	if v < 0.30:
		return Color(0.24, 0.44, 0.62)
	if v < 0.56:
		return Color(0.42, 0.62, 0.38)
	if v < 0.76:
		return Color(0.32, 0.50, 0.30)
	return Color(0.55, 0.50, 0.42)


## 整数 → [0,1) 的确定性哈希。负索引（边界上 gx/gy+1 可能为负）也能算，
## 掩掉低 16 位取分之即可。
static func _hash01(x: int, y: int, seed: int) -> float:
	var h: int = seed ^ (x * 374761393) ^ (y * 668265263)
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float((h & 0xFFFF) % 1000) / 1000.0


## 低位频率的值噪音：以 freq 为格子间隔采样哈希，smoothstep 双线性插值，
## 得到连续过渡的色块，而不是逐格随机。
static func _value_noise(px: int, py: int, freq: int, seed: int) -> float:
	var gx: int = int(floorf(float(px) / float(freq)))
	var gy: int = int(floorf(float(py) / float(freq)))
	var fx: float = float(px - gx * freq) / float(freq)
	var fy: float = float(py - gy * freq) / float(freq)
	fx = fx * fx * (3.0 - 2.0 * fx)
	fy = fy * fy * (3.0 - 2.0 * fy)
	var v00: float = _hash01(gx, gy, seed)
	var v10: float = _hash01(gx + 1, gy, seed)
	var v01: float = _hash01(gx, gy + 1, seed)
	var v11: float = _hash01(gx + 1, gy + 1, seed)
	var top: float = lerpf(v00, v10, fx)
	var bot: float = lerpf(v01, v11, fx)
	return lerpf(top, bot, fy)


func _ticks_per_day() -> int:
	return int(ContentLoader.get_balance_section("time").get("ticksPerDay", 24))


func _days_per_month() -> int:
	return int(ContentLoader.get_balance_section("time").get("daysPerMonth", 30))


func _months_per_year() -> int:
	return int(ContentLoader.get_balance_section("time").get("monthsPerYear", 12))

