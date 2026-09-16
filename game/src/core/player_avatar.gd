class_name PlayerAvatar
extends RefCounted

## 当前这一世玩家的化身（身体 + 角色数据）。
##
## 转生时整体销毁重建——声誉不跨世（委托任务剧本 QT-01 明确），所以它存在
## 这里而不是 City 上：化身销毁，声誉自然归零，不需要额外的清理逻辑。
##
## 派生值（生命、魔力、行动点、负重）一律不落盘，每次由属性、装备与部位
## 状态重新计算。落盘派生值会导致属性变更后派生值不同步，是存档不一致的
## 常见来源。

const ATTR_STRENGTH: String = "strength"
const ATTR_DEXTERITY: String = "dexterity"
const ATTR_CONSTITUTION: String = "constitution"
const ATTR_INTELLIGENCE: String = "intelligence"
const ATTR_PERCEPTION: String = "perception"
const ATTR_CHARISMA: String = "charisma"
const ATTR_SOUL: String = "soul"

const ALL_ATTRIBUTES: Array = [
	ATTR_STRENGTH, ATTR_DEXTERITY, ATTR_CONSTITUTION,
	ATTR_INTELLIGENCE, ATTR_PERCEPTION, ATTR_CHARISMA, ATTR_SOUL,
]

const ATTRIBUTE_LABELS: Dictionary = {
	ATTR_STRENGTH: "力量 STR",
	ATTR_DEXTERITY: "敏捷 DEX",
	ATTR_CONSTITUTION: "体质 CON",
	ATTR_INTELLIGENCE: "智力 INT",
	ATTR_PERCEPTION: "感知 PER",
	ATTR_CHARISMA: "魅力 CHA",
	ATTR_SOUL: "灵魂 SOU",
}

## 身体部位，可分别受伤（《游戏设计文档》第 7 章）。
const BODY_PARTS: Array = [
	"head", "torso", "left_arm", "right_arm", "left_leg", "right_leg",
]

## 性别（《世界模拟量化规则》11.4 节：男/女各 50%）
const GENDER_MALE: String = "male"
const GENDER_FEMALE: String = "female"
const GENDER_DEFAULT: String = GENDER_FEMALE

## 声誉的取值范围（《数值框架》3.3 节：每城独立，-100～+100）。写入要钳制：
## 声誉的档位（敬重 +60、通缉 -70 之类）全部按区间判定，跌出范围之后这些判定
## 就读不到有效档位了。
const REPUTATION_MIN: int = -100
const REPUTATION_MAX: int = 100

## 善恶/幸运的取值范围（同《数值框架》3.3 节：-100~+100）。写入要钳制：档位判定
## （善恶 ±60、幸运 +60）全按区间取，跌破范围就读不到有效档；越界也压不住 Marker
## 的极端惩罚（详见 hidden_attribute_system.gd）。
const HIDDEN_ATTR_MIN: int = -100
const HIDDEN_ATTR_MAX: int = 100

var avatar_id: String = ""
var soul_id: String = ""
var display_name: String = ""
var gender: String = "female"
var age: int = 20
var race: String = "human"
var background_id: String = ""
var host_avatar_id: String = ""  ## 随机转生时继承的原宿主，用于"既有历史与待办"

var attributes: Dictionary = {}
var karma: int = 0
var luck: int = 0
var city_reputation: Dictionary = {}  ## cityId -> 声誉，不跨世
var skills: Dictionary = {}           ## skillId -> 熟练度 0-100
var talents: Array[String] = []
var flaws: Array[String] = []
var body_parts: Dictionary = {}       ## 部位 -> 状态
var equipment: Dictionary = {}        ## 槽位 -> itemInstanceId
var inventory: Array[String] = []

## 物品实例。技术设计文档 3.3 节定义了 ITEM_INSTANCE 的字段，但没规定它存在哪里；
## 模板与实例分离的理由是同一把铁剑的耐久与词缀各不相同。MVP 内物品都归化身所有
## （掉落直接进背包，没有商店存货与地上物品），因此实例表挂在化身上，
## inventory 与 equipment 存的是这里的键。
##
## modifiers 里存的是 {affixId, target, value}，不存词缀的显示名——文案在
## affixes.json 里，存档里再抄一份的话，改了文案就得连存档一起迁移。
var item_instances: Dictionary = {}   ## instanceId -> {templateId, durability, enhancement, modifiers}
var money: int = 0

## 负债（铜币）。两个来源都落在这里：出身的初始债务（含天赋「债台高筑」），
## 以及随机转生时继承的宿主债务。之所以给债务一个一等字段而不是塞进标记里，
## 是因为它要参与界面显示、交易判定与后续委托奖励的抵扣。
var debt_copper: int = 0

## 随机转生继承的宿主遗留。技术设计文档 3.3 节只给了 hostAvatarId 一个挂点，
## 而 M3.2 的验收要求宿主带有「既有债务或亲属或待办中的至少一项」，后两项
## 在文档里连字段都没有，因此在这里补一个结构化字段承载：
##   { hostNpcId, hostName, hostCityId, kin: [{npcId, value}], pending: [{kind, text, npcId}] }
var legacy: Dictionary = {}

var dragonization: int = 0
var dragon_soul: int = 0
var known_runes: Array[String] = []

var pos_x: int = 0  ## 世界网格坐标，M6.1 地图与移动
var pos_y: int = 0


func _init() -> void:
	for attr in ALL_ATTRIBUTES:
		attributes[attr] = 10  # 普通成年基准
	for part in BODY_PARTS:
		body_parts[part] = {"injured": false, "severity": 0}


func get_attribute(attribute: String) -> int:
	return int(attributes.get(attribute, 0))


func set_attribute(attribute: String, value: int) -> void:
	attributes[attribute] = value


func get_reputation(city_id: String) -> int:
	return int(city_reputation.get(city_id, 0))


func set_reputation(city_id: String, value: int) -> void:
	city_reputation[city_id] = clampi(value, REPUTATION_MIN, REPUTATION_MAX)


## 善恶/幸运的钳制写入（M17）。档位判定按 [-100, 100] 取，跌出范围就读不到档位，
## 与 set_reputation 同一套道理。所有改这两项的落账路径都应过这里。
func set_karma(value: int) -> void:
	karma = clampi(value, HIDDEN_ATTR_MIN, HIDDEN_ATTR_MAX)


func set_luck(value: int) -> void:
	luck = clampi(value, HIDDEN_ATTR_MIN, HIDDEN_ATTR_MAX)


func to_dict() -> Dictionary:
	return {
		"avatarId": avatar_id,
		"soulId": soul_id,
		"displayName": display_name,
		"gender": gender,
		"age": age,
		"race": race,
		"backgroundId": background_id,
		"hostAvatarId": host_avatar_id,
		"attributes": attributes.duplicate(),
		"karma": karma,
		"luck": luck,
		"cityReputation": city_reputation.duplicate(),
		"skills": skills.duplicate(),
		"talents": talents.duplicate(),
		"flaws": flaws.duplicate(),
		"bodyParts": body_parts.duplicate(true),
		"equipment": equipment.duplicate(),
		"inventory": inventory.duplicate(),
		"itemInstances": item_instances.duplicate(true),
		"money": money,
		"debtCopper": debt_copper,
		"legacy": legacy.duplicate(true),
		"dragonization": dragonization,
		"dragonSoul": dragon_soul,
		"knownRunes": known_runes.duplicate(),
		"posX": pos_x,
		"posY": pos_y,
	}


static func from_dict(data: Dictionary) -> PlayerAvatar:
	var a := PlayerAvatar.new()
	a.avatar_id = str(data.get("avatarId", ""))
	a.soul_id = str(data.get("soulId", ""))
	a.display_name = str(data.get("displayName", ""))
	a.gender = str(data.get("gender", "female"))
	a.age = int(data.get("age", 20))
	a.race = str(data.get("race", "human"))
	a.background_id = str(data.get("backgroundId", ""))
	a.host_avatar_id = str(data.get("hostAvatarId", ""))
	for attr in ALL_ATTRIBUTES:
		a.attributes[attr] = int(data.get("attributes", {}).get(attr, 10))
	a.karma = clampi(int(data.get("karma", 0)), HIDDEN_ATTR_MIN, HIDDEN_ATTR_MAX)
	a.luck = clampi(int(data.get("luck", 0)), HIDDEN_ATTR_MIN, HIDDEN_ATTR_MAX)
	a.city_reputation = _int_dict(data.get("cityReputation", {}))
	a.skills = _int_dict(data.get("skills", {}))
	for t in data.get("talents", []):
		a.talents.append(str(t))
	for f in data.get("flaws", []):
		a.flaws.append(str(f))
	a.body_parts = data.get("bodyParts", {}).duplicate(true)
	if a.body_parts.is_empty():
		for part in BODY_PARTS:
			a.body_parts[part] = {"injured": false, "severity": 0}
	a.equipment = data.get("equipment", {}).duplicate()
	for item in data.get("inventory", []):
		a.inventory.append(str(item))
	a.item_instances = data.get("itemInstances", {}).duplicate(true)
	a.money = int(data.get("money", 0))
	a.debt_copper = int(data.get("debtCopper", 0))
	a.legacy = data.get("legacy", {}).duplicate(true)
	a.dragonization = int(data.get("dragonization", 0))
	a.dragon_soul = int(data.get("dragonSoul", 0))
	for r in data.get("knownRunes", []):
		a.known_runes.append(str(r))
	a.pos_x = int(data.get("posX", 0))
	a.pos_y = int(data.get("posY", 0))
	return a


## JSON 解析出来的数字都是浮点，转成字典时要把值显式还原成 int。
static func _int_dict(source: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key in source:
		out[str(key)] = int(source[key])
	return out
