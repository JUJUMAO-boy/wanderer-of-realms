class_name Merchant
extends RefCounted

## 游方商人（M21：地图商人奇遇）。与商铺（Economy）相对的另一种买卖：
## 它不隶属于任何一座城，行商浪迹在野外，玩家野外交互撞见就能就地交易。
##
## 与 Economy 最大的分别是**没有城市上下文**。商铺的价受城市六维、名声、渠道
## 勾兑（D-43/D-44），那是"这座城"自己的一套规则；游方商人带着自己的货与自己的
## 价走天下，它的价只由货源与进货成本决定，不该被玩家脚下的城影响——否则"在
## 城外交不能比在城里划算"就说不通了（他进货便宜，才卖得起；他收的也比商铺黑）。
##
## 保持与 EncounterSystem / CitySpace 同一条口径：
##   1. **确定性、不落盘、会话态**。给定 `种子键` 派生同一份货架与同一套价，
##      测试能断言；一旦玩家离开，这位行商就"走远了"，读档回来当然不在原地。
##   2. **不绑定 WorldState 的城市六维**。但它要读写化身（钱与背包），所以
##      结算要 world / avatar 的参与——这是与 EncounterSystem 唯一不同的地方，
##      因为交易必须改玩家的资产。
##
## 货与价都在这里定死，界面（MerchantViewModel/Panel）只负责"怎么摆"。

const ERROR_NONE: String = ""
const ERROR_INVALID_ARGUMENT: String = "INVALID_ARGUMENT"
const ERROR_EMPTY_STOCK: String = "EMPTY_STOCK"
const ERROR_NOT_FOUND: String = "NOT_FOUND"
const ERROR_MONEY: String = "MONEY"

const SIDE_BUY: String = Economy.SIDE_BUY
const SIDE_SELL: String = Economy.SIDE_SELL

const STOCK_COUNT_MIN: int = 3
const STOCK_COUNT_MAX: int = 6

## 货架上只摆这些类别——武器/防具/消耗品行商都卖得动，材料与工具不合他的路数。
const STOCK_CATEGORIES: Array = ["weapon", "armor", "consumable"]

## 商人收价比例（买回库存用）。与商铺同一档：收价减半是行商压价的本事。
## 卖给你（买入价）= 基准价 × BUY_RATIO，是他进价加跑腿钱。
const BUY_RATIO: float = 1.5
const SELL_RATIO: float = 0.5

var world: WorldState = null

var _rules: Dictionary = {}

var _seed_key: String = ""
var _stock: Array = []  # [{ templateId, template }...]
var _quotations: Dictionary = {}  # templateId -> { buyPrice, sellPrice }
var _rng: DeterministicRNG = null
## M23（B/C）：商人的人格与即时估值所需的物品实例规则。
var _items: ItemInstance = null
var _fav_category: String = ""
var _rare_bias: bool = false
var _legendary_template: String = ""


static func create(p_world: WorldState, p_rules: Dictionary = {}) -> Merchant:
	var merchant := Merchant.new()
	merchant.world = p_world
	merchant._rules = p_rules if not p_rules.is_empty() else ContentLoader.get_balance_section("merchant")
	merchant._items = ItemInstance.create_from_config()
	return merchant


## 备一车货。seed_key 决定整份货架与全部报价，所以同一场行商完全可复现。
func stock_for(seed_key: String) -> Array:
	_seed_key = seed_key
	_rng = DeterministicRNG.new(str(seed_key).hash() & 0xFFFFFFFF)
	_derive_persona()
	var count: int = _rng.range_int(STOCK_COUNT_MIN, STOCK_COUNT_MAX)
	_stock = []
	_quotations = {}
	var pool: Array = _biased_pool(_tradable_pool())
	if pool.is_empty():
		return _stock
	for _i in range(count):
		var template: Dictionary = pool[_rng.next_int(pool.size())]
		var template_id: String = str(template.get("templateId", ""))
		if _already_in_stock(template_id):
			continue
		_stock.append({"templateId": template_id, "template": template})
		_quotations[template_id] = _quote(template)
	# 专属传说货：行商总带一件，没被随机抽中就补一件。
	if not _legendary_template.is_empty() and not _already_in_stock(_legendary_template):
		var legendary: Dictionary = _find_template(_legendary_template)
		if not legendary.is_empty() and STOCK_CATEGORIES.has(str(legendary.get("category", ""))):
			_stock.append({
				"templateId": _legendary_template, "template": legendary,
				"legendary": true,
			})
			_quotations[_legendary_template] = {
				"buyPrice": maxi(
					1,
					int(float(maxi(1, int(legendary.get("price", 0))))
						* float(_rules.get("legendaryBuyRatio", 2.5))),
				),
				"sellPrice": maxi(1, int(float(maxi(1, int(legendary.get("price", 0)))) * SELL_RATIO)),
			}
	return _stock


## 商人的随机人格（M23, B）。由 seed 派生，见 _derive_persona。
func persona() -> Dictionary:
	return {
		"favCategory": _fav_category,
		"favCategoryLabel": _fav_label(),
		"rareBias": _rare_bias,
		"sellMultiplier": _effective_sell_ratio(_fav_category),
	}


func rng() -> DeterministicRNG:
	return _rng


## 货架当前的报价表（templateId -> { buyPrice, sellPrice }）。买走的货会在
## 别的字段里登记，_quotations 原样保留——同一件货，行商从不临时改口。
func quotations() -> Dictionary:
	return _quotations


## 剩余在售的货（数组元素是 stock 里的 { templateId, template }）。买走的就移出，
## 卖回的行商再上架，所以"这一件还在不在"由调用方从 _stock 里查。
func stock_left() -> Array:
	return _stock


## 取某一签的报价。买价（商人开给你的价）与收价（他还你的价）各一支。
func quote_for(template_id: String) -> Dictionary:
	return _quotations.get(template_id, {})


## 这份货架里还剩多少件（买走后会减少）。
func stock_count() -> int:
	return _stock.size()


## 把一件货从货架标成"已卖给你"。返回是否找到并移除。
func buy_off_stock(template_id: String) -> bool:
	for i in range(_stock.size()):
		if str(_stock[i].get("templateId", "")) == template_id:
			_stock.remove_at(i)
			return true
	return false


## 卖回一件货给行商：重新进货架（用新的报价）。这件不会是空的——枚举用，
## 调用方要先确认它确实还在 _quotations 里。
func add_to_stock(template_id: String) -> void:
	if not _quotations.has(template_id):
		return
	var template: Dictionary = _find_template(template_id)
	if template.is_empty():
		return
	_stock.append({"templateId": template_id, "template": template})


## 从可交易货池里抽一车。货池只取武器/防具/消耗品（行商卖得动的）；
## 标了 blackMarketOnly 的货（如「改头换面」斗篷，M-B D-137）只进黑市，行商不拉。
func _tradable_pool() -> Array:
	var pool: Array = []
	for template in ContentLoader.get_items():
		if STOCK_CATEGORIES.has(str(template.get("category", ""))) \
			and not bool(template.get("blackMarketOnly", false)):
			pool.append(template)
	return pool


func _find_template(template_id: String) -> Dictionary:
	for item in ContentLoader.get_items():
		if str(item.get("templateId", "")) == template_id:
			return item
	return {}


## 报一个价。卖给你（买入价）= 基准价 × BUY_RATIO；收价 = 基准价 × SELL_RATIO。
## 行商不该问城市：他的价是"进货成本 + 跑腿钱"，跟你在哪座城没半点关系。
func _quote(template: Dictionary) -> Dictionary:
	var base: int = maxi(1, int(template.get("price", 0)))
	@warning_ignore("integer_division")
	var buy: int = maxi(1, int(float(base) * float(_rules.get("buyRatio", BUY_RATIO))))
	@warning_ignore("integer_division")
	var sell: int = maxi(1, int(float(base) * SELL_RATIO))
	return {"buyPrice": buy, "sellPrice": sell}


func _already_in_stock(template_id: String) -> bool:
	for entry in _stock:
		if str(entry.get("templateId", "")) == template_id:
			return true
	return false


## 按 seed 派生这份货架的人格（M23, B）：抽一个偏好类别（喜好类收价更高，
## 见 _effective_sell_ratio）、掷是否偏收稀有货、并定下专属传说货模板。
func _derive_persona() -> void:
	var weights: Dictionary = _rules.get("favCategoryWeights", {})
	var cats: Array = []
	var cum: Array = []
	var total: int = 0
	for c in STOCK_CATEGORIES:
		var w: int = maxi(0, int(weights.get(c, 1)))
		cats.append(c)
		total += w
		cum.append(total)
	if total > 0:
		var roll: int = _rng.next_int(total)
		for i in range(cum.size()):
			if roll < int(cum[i]):
				_fav_category = str(cats[i])
				break
	_rare_bias = _rng.next_int(10000) < int(_rules.get("rareBiasChanceBp", 0))
	_legendary_template = str(_rules.get("legendaryTemplateId", ""))


## 把货池按人格做偏置：喜好类多放一份（被抽中的概率更高）；若偏收稀有，
## 再垫一只稀有以上的模板进池。同一车货可能重叠，确定仍可复现。
func _biased_pool(pool: Array) -> Array:
	var arr: Array = []
	arr.append_array(pool)
	if not _fav_category.is_empty():
		for template in pool:
			if str(template.get("category", "")) == _fav_category:
				arr.append(template)
	if _rare_bias:
		for template in pool:
			if _rarity_rank(template) >= _rarity_rank_min("rare"):
				arr.append(template)
				break
	return arr


static func _rarity_rank_min(rarity: String) -> int:
	return _rarity_rank({"rarity": rarity})


static func _rarity_rank(template: Dictionary) -> int:
	var order: Array = ["common", "fine", "rare", "epic", "legendary", "dragonforged"]
	return order.find(str(template.get("rarity", "common")))


func _fav_label() -> String:
	match _fav_category:
		"weapon": return "武器"
		"armor": return "防具"
		"consumable": return "消耗品"
	return _fav_category


## --- M23 C：商人收价接入即时估值 ---
## 抽一个不绑城市的静态估值（词缀+强化可复现于 Economy 同一口径），而不是给
## Economy.get_price 传"中性城市"沉淀——五因子强绑 City，伪造哨站会污染字段。
## 一件实例的"现值" = （模板价 + 词缀/强化折价）× 耐久比 × 有效收价比例。

## 实例的弹性市值（模板价 + 词缀/强化折价）。与 Economy.get_price 用同一套
## ItemInstance.price_bonus，不重复造公式。
static func instance_base(instance: Dictionary, items: ItemInstance) -> int:
	var tpl_price: int = maxi(0, int(items.template_of(str(instance.get("templateId", ""))).get("price", 0)))
	return tpl_price + items.price_bonus(instance)


## 耐久折价系数：剩多少耐久就按比例折多少（满耐久 1、损坏趋近 0）。
static func durability_factor(instance: Dictionary, items: ItemInstance) -> float:
	return clampf(
		float(items.durability(instance)) / float(maxi(1, items.durability_max())),
		0.0, 1.0,
	)


## 这件货的实际收价比例：基准 sellRatio，商人喜好这类时再乘 favSellMultiplier。
func _effective_sell_ratio(category: String) -> float:
	var ratio: float = float(_rules.get("sellRatio", SELL_RATIO))
	if category == _fav_category:
		ratio *= float(_rules.get("favSellMultiplier", 1.0))
	return ratio


## 商人收一件实例的价（M23, C）。卖侧按它结算，词缀/强化/耐久/喜好都进价。
func buy_back_value(instance: Dictionary) -> int:
	var items: ItemInstance = _items if _items != null else ItemInstance.create_from_config()
	var base: int = Merchant.instance_base(instance, items)
	var category: String = str(items.template_of(str(instance.get("templateId", ""))).get("category", ""))
	var ratio: float = _effective_sell_ratio(category)
	return maxi(1, roundi(float(base) * Merchant.durability_factor(instance, items) * ratio))