class_name StealGate
extends RefCounted

## 偷窃通道规则层（M-B 收口，9.32 节 D-136）。
##
## 罪犯被商铺拒卖之后的另一条进项——趁夜黑在城里对居民下手。它不碰交易本身，
## 也不是一条新的货架渠道：成/败直接改化身自己的钱与善恶/声誉，当场落账，
## 与 Economy 玩家侧"即时结清"同一套口径（物价只读城市状态，偷窃也不改城）。
##
## 概率完全落在这一个纯函数上：
##    总概率(%) = base + Weather.night_steal_modifier(karma, luck, hour)
##                 + (dex - 10) * dexPerPoint - city.security * securityPerPoint
## 其中 Weather.night_steal_modifier(M25 交付、此前一直无调用方)返回 ±50 的"百分点点位"，
## 设计关死了"夜比昼恒高 20、业力越恶越好偷、幸运越足越好偷"。DEX 是毒手，治安是压桌的哨。
##
## 后果：成也落 karma(偷是罪的底色)，败还被逮现行落该城声誉。数值全走 balance.steal。

const _SECTION: String = "steal"

## 无化身/无城刺探时的空概率。它表示"偷不了的场合"，由调用方转成"这里下不了手"。
const NO_TARGET_PCT: int = 0
const _PCT_DEN: int = 100


## 一次扒窃的真实成功率（越界钳在 [minPct, maxPct]）。hour ∈ 0..23，直接喂给
## Weather.night_steal_modifier。目标城不存在或没挂化身时返回空（调用方判断"下得了手吗"）。
static func success_pct(world: WorldState, city_id: String, hour: int) -> Dictionary:
	if world == null or world.avatar == null:
		return {}
	var city: City = null if world == null else world.get_city(city_id)
	if city == null:
		return {}
	var cfg: Dictionary = ContentLoader.get_balance_section(_SECTION)
	var base: float = float(cfg.get("basePct", 40))
	var night: int = Weather.night_steal_modifier(world.avatar.karma, world.avatar.luck, hour)
	var dex_bonus: float = float(world.avatar.get_attribute(PlayerAvatar.ATTR_DEXTERITY) - 10) \
		* float(cfg.get("dexPerPoint", 1.0))
	var security_penalty: float = float(city.security) * float(cfg.get("securityPerPoint", 0.25))
	var total: float = base + float(night) + dex_bonus - security_penalty
	var clamped: int = clampi(int(round(total)), int(cfg.get("minPct", 5)), int(cfg.get("maxPct", 95)))
	return {
		"ok": true,
		"cityId": city.city_id,
		"basePct": int(round(base)),
		"nightModifier": night,
		"dexterityBonus": int(round(dex_bonus)),
		"securityPenalty": int(round(security_penalty)),
		"totalPct": clamped,
	}


## 试一次手。rng 决定成败（同一种子同结果，可复现），hour 进概率。
##
## 返回语义：
##   - {ok:false, reason}：下不了手（无化身/无城/概率钳到 0 以下）。
##   - {ok:true, outcome:"success", copper, karmaDelta, totalPct}：得手。
##   - {ok:true, outcome:"caught", reputationLoss, karmaDelta, totalPct, reason}：被逮现行。
##
## 成败都不把概率写回存档（下一手重新算），因此这里零状态、零落盘键。
static func attempt(world: WorldState, city_id: String, rng: DeterministicRNG, hour: int) -> Dictionary:
	if world == null or world.avatar == null:
		return {"ok": false, "reason": "还没有化身，下不了手"}
	var city: City = null if world == null else world.get_city(city_id)
	if city == null:
		return {"ok": false, "reason": "这座城市不存在"}
	if rng == null:
		return {"ok": false, "reason": "缺随机源"}
	var pct: Dictionary = success_pct(world, city_id, hour)
	if not bool(pct.get("ok", false)):
		return {"ok": false, "reason": "这里没有可下手的对象"}
	var total: int = int(pct.get("totalPct", 0))
	if total <= 0:
		return {"ok": false, "reason": "这地方太索然，下不去手"}
	var avatar: PlayerAvatar = world.avatar
	var cfg: Dictionary = ContentLoader.get_balance_section(_SECTION)

	# 千分位掷骰：next_int(10000) ∈ [0, 10000)，< pct*100 才算得手。
	var roll: int = rng.next_int(10000)
	if roll < total * _PCT_DEN:
		var copper: int = _copper_gain(city, cfg, rng)
		var karma_cost: int = int(cfg.get("karmaOnSuccess", 2))
		avatar.money += copper
		avatar.set_karma(avatar.karma - karma_cost)
		return {
			"ok": true,
			"outcome": "success",
			"copper": copper,
			"karmaDelta": -karma_cost,
			"totalPct": total,
			"money": avatar.money,
		}

	var rep_loss: int = int(cfg.get("repOnCaught", 8))
	var caught_karma: int = int(cfg.get("karmaOnCaught", 2))
	avatar.set_reputation(city_id, avatar.get_reputation(city_id) - rep_loss)
	avatar.set_karma(avatar.karma - caught_karma)
	return {
		"ok": true,
		"outcome": "caught",
		"reputationLoss": rep_loss,
		"karmaDelta": -caught_karma,
		"totalPct": total,
		"reputation": avatar.get_reputation(city_id),
		"reason": "被逮个正着",
	}


## 得手的铜钱：在 [copperMin, copperMax] 里掷，再按城财富缩放（富城油水多）。
## 缩放是个线性映射到「该城财富在全区间的相对位置」，钳在 1.0 倍附近，防零财富城一分不给。
static func _copper_gain(city: City, cfg: Dictionary, rng: DeterministicRNG) -> int:
	var lo: int = int(cfg.get("copperMin", 20))
	var hi: int = int(cfg.get("copperMax", 80))
	var base: int = lo + rng.next_int(maxi(1, hi - lo + 1))
	var wealth_span: float = float(city.wealth) / 100.0
	var scaled: int = int(round(float(base) * maxf(0.5, wealth_span)))
	return maxi(1, scaled)