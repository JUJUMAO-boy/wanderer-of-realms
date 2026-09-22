class_name Weather
extends RefCounted

## 昼夜·天候规则层（M25/M-A）。
##
## 天候挂在"世界种子 + 当天"上派生：每个当天都确定性命中一条天候，转世/读档
## 后完全一致、不落盘。每条天候带一个窗口天数（windowDays），按窗口占比轮转。
## 保证永远有一条"晴和"兜底（enemyMult=1、movementCost=0），配置再缺也不至于卡死。
##
## 夜间偷窃修正只在这里把"接口"立起来：接善恶(karma)与幸运(luck)，返回对偷窃的
## 概率修正(bp)。它现在没有调用方——那是 M-B 的偷窃通道要接的——但定义与测试
## 都锁在这，避免"白天偷和黑夜偷一样"这种后来才发现的错。

const CLEAR_ID: String = "clear"
## 夜晚区间：19:00 起，到次日 06:59 止。
const NIGHT_START: int = 19
const NIGHT_END: int = 7
const STEAL_CLAMP: int = 50


## 由世界种子与当天确定性命中一条天候。rules 为天候数组（weathers.json）。
static func entry_at(world_seed: int, day: int, rules: Array) -> Dictionary:
	if rules.is_empty():
		return _clear_fallback()
	var total: int = 0
	for w in rules:
		if w is Dictionary:
			total += maxi(1, int(w.get("windowDays", 1)))
	if total <= 0:
		return _clear_fallback()
	var r: int = (int(str([world_seed, day]).hash()) & 0xFFFFFFFF) % total
	for w in rules:
		if not (w is Dictionary):
			continue
		var days: int = maxi(1, int((w as Dictionary).get("windowDays", 1)))
		if r < days:
			return (w as Dictionary).duplicate()
		r -= days
	return _clear_fallback()


## 此刻是不是夜里（19:00–06:59）。hour ∈ 0..23。
static func is_night(hour: int) -> bool:
	return hour >= NIGHT_START or hour < NIGHT_END


## 天候对遭遇敌的强度倍率，钳到 ≥ 1。
static func enemy_mult(entry: Dictionary) -> float:
	return clampf(float(entry.get("enemyMult", 1.0)), 1.0, 999.0)


## 天候带来的户外移动额外代价，钳到 ≥ 0。
static func movement_cost(entry: Dictionary) -> int:
	return maxi(0, int(entry.get("movementCost", 0)))


## 夜间偷窃修正接口（交付 M-B）。返回对偷窃概率的 bp 修正，钳到 ±50。
## 设计保证了"同样属性的善恶与幸运下，夜里总比白天好偷整整 +20"——
## 白天有暴露之虞，夜里那份冷不叫暴露。night 与 day 的差恒等于 20。
static func night_steal_modifier(karma: int, luck: int, hour: int) -> int:
	var base: int = 10 if is_night(hour) else -10
	var karma_term: int = clampi(int(-clampi(karma, -100, 100) / 3), -30, 30)
	var luck_term: int = clampi(int(clampi(luck, -100, 100) / 5), -20, 20)
	return clampi(base + karma_term + luck_term, -STEAL_CLAMP, STEAL_CLAMP)


static func _clear_fallback() -> Dictionary:
	return {
		"id": CLEAR_ID,
		"label": "晴和",
		"windowDays": 4,
		"movementCost": 0,
		"enemyMult": 1.0,
		"desc": "",
	}