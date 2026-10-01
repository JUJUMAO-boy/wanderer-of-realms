class_name ReputationTitle
extends RefCounted

## 城市声誉·别称规则层（A2 / D-167）。
##
## 把 M6 的"隐藏数值声誉"升级成"哪座城怎么叫你"——身份这一维度。之前声誉
## 只有数字作用（Economy 价格因子、Quest reward 放大、Encounter 交涉），城里
## 的 NPC 从不拿它当人看：你是负一百的瘟神还是正一百的座上宾，问候一字不差。
##
## 这一步让声誉开口说话：
##   - 别称：按城声誉档位给一套"这城怎么叫你"的称呼
##   - 好感加成：声誉高的城，攀谈/送礼更受待见（favorBonus 折进好感变化）
##   - 特殊对话：开场问候按别称档位给一句话，NPC 拿你怎么叫你怎么开场
##   - 罪犯另样待遇：罪犯态 + 声誉垫底 → 城民只当你钉在告示板上的脸
##
## 档位表（阈值 + 别称 + 问候文案）在此处固定为单一来源；唯一走 balance 的
## 数值是「各档友善加分」（reputationTitle.favorBonus：{"hero":4,...}，缺某一档
## 或整段缺失时退回下方加成常量）。这样做取舍：别称是文风锚管的那层（要过
## MenuStyle 筛、本该作者手写），阈值又早已与 economy 同口径，只有"加几分"
## 是还想让数值表调节的口子。

const _SECTION: String = "reputationTitle"

## 档位键。
const BAND_HERO: String = "hero"
const BAND_WELCOME: String = "welcome"
const BAND_NEUTRAL: String = "neutral"
const BAND_WARY: String = "wary"
const BAND_OUTCAST: String = "outcast"

const BAND_ORDER: Array = [
	BAND_HERO, BAND_WELCOME, BAND_NEUTRAL, BAND_WARY, BAND_OUTCAST,
]

## 各档友善加分（favorBonus，balance 缺段时用此兜底）。单位同好感 delta。
const DEFAULT_FAVOR: Dictionary = {
	BAND_HERO: 4, BAND_WELCOME: 1, BAND_NEUTRAL: 0, BAND_WARY: -2, BAND_OUTCAST: -5,
}

## 罪犯态 + 垫底档再折一截的额外敌意。
const CRIMINAL_PENALTY: int = 3

## 档位表：单一来源。threshold 是"声誉 ≥ 此值归入该档"，从高到低判。
## title 是"这城怎么叫你"，greet 是开场问候，criminalGreet 罪犯在垫底档的光景。
const BANDS: Array = [
	{"key": BAND_HERO, "threshold": 60, "title": "这城的座上宾", "greet": "贵客登门，稀客，快请上座"},
	{"key": BAND_WELCOME, "threshold": 20, "title": "这条街说得上话的人", "greet": "老主顾，来得正好"},
	{"key": BAND_NEUTRAL, "threshold": -19, "title": "路过的外乡客", "greet": "面生得很，不过礼数到底是要到"},
	{"key": BAND_WARY, "threshold": -59, "title": "名声发臭的老鼠", "greet": "离我远点，你那张脸我认得"},
	{"key": BAND_OUTCAST, "threshold": -100, "title": "钉在告示板上的脸", "greet": "", "criminalGreet": "守卫！这个恶徒就站在这里"},
]


## 声誉 → 归入的档位键。从高阈值往低判，最小的 OUTCAST 兜底收走所有更负值。
static func band_for(reputation: int) -> String:
	for b in BANDS:
		if reputation >= int(b["threshold"]):
			return str(b["key"])
	return BAND_OUTCAST


## 档位的别称标题。未知键给中性级兜底，不让面板崩出空串。
static func title(band: String) -> String:
	for b in BANDS:
		if b["key"] == band:
			return str(b["title"])
	return str(_band(BAND_NEUTRAL)["title"])


## 某档的友善加分。优先读 balance.reputationTitle.favorBonus[band]，缺则用
## DEFAULT_FAVOR。数值走 balance、文案走本表，两处口径一致。
static func favor_bonus(band: String) -> int:
	var cfg: Dictionary = ContentLoader.get_balance_section(_SECTION)
	var map: Variant = cfg.get("favorBonus", {})
	if (map is Dictionary) and map.has(band):
		return int(map[band])
	return int(DEFAULT_FAVOR.get(band, 0))


## 开场问候。返回该档位下 NPC 拿什么叫你开场；罪犯 + 垫底档用那张告示板的脸。
static func greet(world: WorldState, city_id: String) -> String:
	if world == null or world.avatar == null or city_id.is_empty():
		return ""
	var band: String = band_for(world.avatar.get_reputation(city_id))
	var node: Dictionary = _band(band)
	if CriminalState.is_criminal(world) and band == BAND_OUTCAST:
		return str(node.get("criminalGreet", ""))
	return str(node.get("greet", ""))


## 一次给一城的身份卡片：别称档、称谓、问候、友善加分、是否罪犯被当通缉犯。
static func card(world: WorldState, city_id: String) -> Dictionary:
	if world == null or world.avatar == null or city_id.is_empty():
		return {"band": BAND_NEUTRAL, "title": title(BAND_NEUTRAL), "greet": "", "favorBonus": 0, "criminal": false}
	var band: String = band_for(world.avatar.get_reputation(city_id))
	var favor: int = favor_bonus(band)
	var criminal: bool = CriminalState.is_criminal(world) and band == BAND_OUTCAST
	if criminal:
		favor -= CRIMINAL_PENALTY
	return {
		"cityId": city_id,
		"band": band,
		"title": title(band),
		"greet": greet(world, city_id),
		"favorBonus": favor,
		"criminal": criminal,
	}


static func _band(band: String) -> Dictionary:
	for b in BANDS:
		if b["key"] == band:
			return b
	return {}