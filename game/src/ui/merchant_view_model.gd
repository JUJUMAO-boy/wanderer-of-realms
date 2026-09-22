class_name MerchantViewModel
extends RefCounted

## 游方商人界面的视图模型（M21 表现层）。与其它视图模型同一个理由：
## "这辆车摆了什么、按什么价卖"是纯函数，能在无头环境里被验收测试钉住。
##
## 货与价由 Merchant 定死（规则层），这里只把 `Merchant.stock_for` 摊成绘制清单：
## 买侧看货车，卖侧看背包，两边的行长得一样，右列都写同一件货的价。
## 与 TradeViewModel 同构，只是少了城市六维那一大堆因子——行商不看你脚下是哪座城。
const SIDE_BUY: String = Merchant.SIDE_BUY
const SIDE_SELL: String = Merchant.SIDE_SELL

const ROW_KIND_STOCK: String = "stock"
const ROW_KIND_HELD: String = "held"

const CATEGORY_LABELS: Dictionary = {
	"weapon": "武器", "armor": "防具", "consumable": "消耗品",
}


## 版面。side 决定看货车还是看背包；cursor 是当前行。
static func build(
	merchant: Merchant,
	lookups: Dictionary,
	avatar: PlayerAvatar,
	side: String,
	cursor: int,
	money: int
) -> Dictionary:
	if merchant == null:
		return {}
	if side == SIDE_BUY:
		# 买侧只砍价格，"钱够不够"看得见；买到就移出货价，行商的下一次报价
		# 从 _quotations 里原样给（Merchant.quotations 只增不减）。
		return _build_buy(merchant, lookups, avatar, cursor, money)
	return _build_sell(merchant, lookups, avatar, cursor, money)


## 买侧：货车上的每一件。
static func _build_buy(
	merchant: Merchant, lookups: Dictionary, avatar: PlayerAvatar, cursor: int, money: int
) -> Dictionary:
	var templates: Dictionary = _lookup(lookups, "itemTemplates")
	var rows: Array = []
	var quotations: Dictionary = merchant.quotations()
	var stock: Array = merchant.stock_left()
	for entry in stock:
		var template_id: String = str(entry.get("templateId", ""))
		var template: Dictionary = _template(templates, template_id)
		var buy: int = int(quotations.get(template_id, {}).get("buyPrice", 0))
		var affordable: bool = money >= buy
		rows.append({
			"kind": ROW_KIND_STOCK,
			"templateId": template_id,
			"label": _name(template, template_id),
			"rarityLabel": _rarity(template),
			"categoryLabel": _category(template),
			"detail": AvatarViewModel.item_detail(template),
			"price": buy,
			"priceText": AvatarViewModel.money_label(buy),
			"enabled": affordable,
			"blockedReason": "" if affordable else "钱不够，先把 %s 攒出来。" % (
				AvatarViewModel.money_label(buy - money)
			),
		})
	return _finish(merchant, SIDE_BUY, rows, cursor, money, "这辆车上摆的货就在这里。买走的会空出来，卖回的行商再上车。")


## 卖侧：背包里的每一件（同名多件各占一行，点的是具体那一件）。
static func _build_sell(
	merchant: Merchant, lookups: Dictionary, avatar: PlayerAvatar, cursor: int, money: int
) -> Dictionary:
	var templates: Dictionary = _lookup(lookups, "itemTemplates")
	var rules: ItemInstance = ItemInstance.create_from_config()
	var rows: Array = []
	if avatar != null:
		var quotations: Dictionary = merchant.quotations()
		for instance_id in avatar.inventory:
			var instance: Dictionary = avatar.item_instances.get(instance_id, {})
			var template_id: String = str(instance.get("templateId", ""))
			var template: Dictionary = _template(templates, template_id)
			if template.is_empty():
				continue
			var sell: int = int(quotations.get(template_id, {}).get("sellPrice",
				maxi(1, int(float(int(template.get("price", 0))) * Merchant.SELL_RATIO))))
			var row: Dictionary = AvatarViewModel.instance_info(rules, instance, template)
			row["kind"] = ROW_KIND_HELD
			row["instanceId"] = str(instance_id)
			row["templateId"] = template_id
			row["categoryLabel"] = _category(template)
			row["price"] = sell
			row["priceText"] = AvatarViewModel.money_label(sell)
			row["enabled"] = true
			row["blockedReason"] = ""
			rows.append(row)
	return _finish(merchant, SIDE_SELL, rows, cursor, money, "行商什么都收，只是收价只有他给价的半数——压价是走货的本钱。")


static func _finish(
	merchant: Merchant, side: String, rows: Array, cursor: int, money: int, hint: String
) -> Dictionary:
	cursor = clampi(cursor, 0, maxi(0, rows.size() - 1))
	var selected: Dictionary = rows[cursor] if not rows.is_empty() else {}
	var blocked: String = ""
	if rows.is_empty():
		if side == SIDE_BUY:
			blocked = "货都卖光了，这辆车空了。"
		else:
			blocked = "你身上没什么可卖的。"
	elif not bool(selected.get("enabled", true)):
		blocked = str(selected.get("blockedReason", ""))
	var deal_price: int = int(selected.get("price", 0))
	var money_after: int = money - deal_price if side == SIDE_BUY else money + deal_price
	return {
		"side": side,
		"sideLabel": "买入" if side == SIDE_BUY else "卖出",
		"otherSide": SIDE_SELL if side == SIDE_BUY else SIDE_BUY,
		"rows": rows,
		"rowCount": rows.size(),
		"cursor": cursor,
		"selected": _detail(selected),
		"money": money,
		"moneyLabel": AvatarViewModel.money_label(money),
		"moneyAfterLabel": AvatarViewModel.money_label(money_after),
		"dealSummary": "回车成交：%s %s（%s），身上 %s → %s。" % [
			"买入" if side == SIDE_BUY else "卖出",
			str(selected.get("label", "")),
			AvatarViewModel.money_label(deal_price),
			AvatarViewModel.money_label(money),
			AvatarViewModel.money_label(money_after),
		],
		"canTrade": blocked.is_empty() and not selected.is_empty(),
		"blockedReason": blocked,
		"hint": hint,
	}


## 右列：这件货是谁、多少钱。
static func _detail(selected: Dictionary) -> Dictionary:
	if selected.is_empty():
		return {}
	return {
		"templateId": str(selected.get("templateId", "")),
		"label": str(selected.get("label", "")),
		"rarityLabel": str(selected.get("rarityLabel", "")),
		"categoryLabel": str(selected.get("categoryLabel", "")),
		"detail": str(selected.get("detail", "")),
		"effectText": "",
		"side": str(selected.get("kind", "")),
		"sideLabel": "买入" if str(selected.get("kind", "")) == ROW_KIND_STOCK else "卖出",
		"kind": str(selected.get("kind", "")),
		"instanceId": str(selected.get("instanceId", "")),
		"price": int(selected.get("price", 0)),
		"dealText": AvatarViewModel.money_label(int(selected.get("price", 0))),
	}


static func _template(templates: Dictionary, template_id: String) -> Dictionary:
	var value: Variant = templates.get(template_id, null)
	return value if value is Dictionary else {}


static func _name(template: Dictionary, template_id: String) -> String:
	return str(template.get("displayName", template_id))


static func _rarity(template: Dictionary) -> String:
	return str(AvatarViewModel.RARITY_LABELS.get(str(template.get("rarity", "")), "—"))


static func _category(template: Dictionary) -> String:
	return str(CATEGORY_LABELS.get(str(template.get("category", "")), "杂项"))


static func _lookup(lookups: Dictionary, key: String) -> Dictionary:
	var value: Variant = lookups.get(key, null)
	return value if value is Dictionary else {}