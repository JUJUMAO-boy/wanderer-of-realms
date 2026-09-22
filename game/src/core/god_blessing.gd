class_name GodBlessing
extends RefCounted

## 神系恩惠规则层（M25/M-A）。
##
## 神是在库里躺着、玩家祈祷才被触及的。本类只回答三件事：此刻你对某位神
## 有多虔诚（devotion，由善恶派生、不落盘）、够不够某档恩惠的门槛、这一次
## 祈祷会给你什么。全部是纯函数，可无头钉测。
##
## 虔诚是关键派生：善恶（karma，±100）乘神性的极性，折成 0..100 的 devotion。
## 神不落存档，转世/读档后会自动重算，"越虔诚越接近那位的脾气"。

const KARMA_MIN: int = -100
const KARMA_MAX: int = 100
const DEV_BASE: int = 50  ## 善恶为零时的中立虔诚


## 善恶 → 对某位神的虔诚（0..100）。极性由神 id 的散列位决定：
## 一半神亲善行（善越深越虔诚），另一半神被"反差"吸引（恶越深越靠近）。
static func devotion_of(god: Dictionary, karma: int) -> int:
	var k: int = clampi(karma, KARMA_MIN, KARMA_MAX)
	var sigil: String = str(god.get("sigil", str(god.get("id", ""))))
	var polarity: int = -1 if (sigil.hash() & 1) == 0 else 1
	var delta: int = int((float(k) * float(polarity)) / 2.0)
	return clampi(DEV_BASE + delta, 0, 100)


## 足够哪一档恩惠：0 表示连一档都不够，1..N 对应 blessings[i-1]。
static func blessing_tier(god: Dictionary, devotion: int) -> int:
	var blessings: Array = god.get("blessings", [])
	if blessings.is_empty():
		return 0
	var d: int = clampi(devotion, 0, 100)
	var tier: int = 0
	for b in blessings:
		if not (b is Dictionary):
			continue
		if d >= int((b as Dictionary).get("threshold", 1 << 30)):
			tier += 1
	return tier


## 结算一次祈祷。返回 {tier, effect, cost, penalty, ok}，纯确定性。
## 善行过浅（karma ≤ -60）会被神当面罚——连恩惠都压住，只给神罚文案。
static func pray_result(god: Dictionary, karma: int, rng_seed: int) -> Dictionary:
	var devotion: int = devotion_of(god, karma)
	var tier: int = blessing_tier(god, devotion)
	var blessings: Array = god.get("blessings", [])
	var cursed: bool = karma <= -60
	var ok: bool = (not cursed) and tier >= 1
	return {
		"tier": tier,
		"effect": str(blessings[tier - 1].get("effect", "")) if ok and tier >= 1 else "",
		"cost": str(god.get("cost", "")),
		"penalty": str(god.get("penalty", "")),
		"ok": ok,
		"cursed": cursed,
		"devotion": devotion,
	}