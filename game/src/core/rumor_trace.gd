class_name RumorTrace
extends RefCounted

## 传闻真假传播链（第三阶段 C2 / D-166）。
##
## 把 A1 的口碑（rumors.json + Rumors 纯规则）从「静止的一条口风」做成「会动、会
## 传播、会腐烂的流言」：一场流传必然随时间走完三档——**扩散 → 变质 → 被辟谣**，
## 然后换一批新的接着传。玩家在这座城待得越久，听到的不是同一条复读，而是同一场
## 流言如何由实到讹、再由讹被压下去的音量起落。
##
## 铁则一致：能派生就不落盘。这一局这座城此刻流传的是哪条、走到的第几档，全部由
## 场景有没有 DerivedRNG 决定——(世界种子 ⊕ 城 ⊕ 月份) 确定性推出，**不写进存档**，
## 同世界种子下读档回到同城同月，听到的还是同一条同一档（与 C4 势力漂移同一条口径）。
##
## 流言本体（rumor）由 Rumors 纯规则按城抽（subject 匹配城名，reliability 加权），
## 跨月固定不变——变的是**传播档**，不是换内容：同一件事从谁嘴里传、传成什么样、
## 有没有被按下，才是 C2 要的那条时间轴。真假口径沿用 A1 铁则，绝不外露 category。

## 传播三档：一场流言的正常寿命。
const STAGE_SPREAD: int = 0   ## 扩散：还拴着出处，正从一个人嘴上长到十个人嘴里
const STAGE_MUTATE: int = 1   ## 变质：传得越远越走样，细节开始对不上
const STAGE_DENIED: int = 2   ## 被辟谣：有人按下来了，话头断了，只剩余音

const STAGE_COUNT: int = 3

## 各档在界面上怎么自称。
const STAGE_LABELS: Array = ["传开了", "传变了味", "被人压下了"]

## 每档的台词前缀（正文之前先点上这档的调子）。
const STAGE_PREFIX: Array = [
	"市井里又在传：",
	"话传得变了样，现在是：",
	"这话被人按住了，只剩个尾巴：",
]


## 一座城当前在传的是哪条流言（跨月稳定）。subject 匹配城名；该城没有流言表给空
## 字典（不造无中生有的风声）。注意：不走 Rumors.pick 的回退——那会把别城的谣言
## 兜底进来，违背"无中生不造"。
static func rumor_for_city(city_name: String, base_seed: int) -> Dictionary:
	if city_name.is_empty():
		return {}
	var city_rumors: Array = []
	for entry in Rumors.pool():
		if str(entry.get("subject", "")) == city_name:
			city_rumors.append(entry)
	if city_rumors.is_empty():
		return {}
	var rng: DeterministicRNG = _rng_for(city_name, base_seed)
	var roll: int = rng.next_int(city_rumors.size())
	return (city_rumors[roll] as Dictionary).duplicate(true)


## 这一场流言当下走到了第几档。月份只参与「走了多久」，城决定「从哪一档起头」，
## 档位轮转线性推进、不落盘、同种子可复现。
static func stage_for(city_name: String, month: int, base_seed: int) -> int:
	var offset: int = _stage_offset(city_name, base_seed)
	return posmod(maxi(0, month) + offset, STAGE_COUNT)


## 流言整幅画面：本体 + 当前档 + 渲染字面 + 是否已被按下（辟谣）。
static func state_for(city_name: String, month: int, base_seed: int) -> Dictionary:
	var rumor: Dictionary = rumor_for_city(city_name, base_seed)
	if rumor.is_empty():
		return {}
	var stage: int = stage_for(city_name, month, base_seed)
	return {
		"rumor": rumor,
		"stage": stage,
		"stageLabel": str(STAGE_LABELS[stage]),
		"line": line(rumor, stage),
		"debunked": stage == STAGE_DENIED,
	}


## 流言在该档下的渲染字面。只给正文与出处，绝不外露真假口径；先点档位前缀，
## 出处缀沿用 Rumors.line 的口径（"%s（%s说）"）。
static func line(rumor: Dictionary, stage: int) -> String:
	if rumor.is_empty():
		return ""
	var phrase: String = str(rumor.get("text", ""))
	var origin: String = str(rumor.get("origin", ""))
	var body: String = phrase
	if stage == STAGE_MUTATE:
		body = "%s——传的人已经加了自己的注脚。" % phrase
	elif stage == STAGE_DENIED:
		body = "%s……可这话没人再接了。" % phrase
	if origin.is_empty():
		return "%s%s" % [str(STAGE_PREFIX[stage]), body]
	return "%s%s（%s说）" % [str(STAGE_PREFIX[stage]), body, origin]


## 该城流言用到的确定性 RNG。同世界同种子可复现（C4 同款派生）。
static func _rng_for(city_name: String, base_seed: int) -> DeterministicRNG:
	var seed: int = (base_seed ^ (city_name.hash() * 37) ^ 0x9E3779B9) & 0xFFFFFFFF
	return DeterministicRNG.new(seed)


## 该城流言的起头档位偏移（0..2）。同城同世界恒为同一偏移。
static func _stage_offset(city_name: String, base_seed: int) -> int:
	return _rng_for(city_name, base_seed).next_int(STAGE_COUNT)