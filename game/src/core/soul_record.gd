class_name SoulRecord
extends RefCounted

## 灵魂记录。跨世携带的核心数据，体积小但语义最重。
##
## 与化身的关系：化身是"这一世的身体"，转生时销毁；灵魂记录是"你自己"，
## 转生时保留并替换绑定对象。存档拆成 world.json 与 soul.json 两个文件，
## 转生只重写 soul.json 与化身重建，world.json 不加不减。

var soul_id: String = ""
var reincarnation_count: int = 0
var last_retention: float = 0.0  ## 上次结算的记忆保留率，0.0-0.6
var inherited_skills: Dictionary = {}
var inherited_attr_bonus: Dictionary = {}
var karma_carry: int = 0
var luck_carry: int = 0
var legacy_clues: Array = []
var anchor_relations: Array = []
var main_quest_progress: Dictionary = {}
var dragonization_carry: int = 0
var known_runes: Array[String] = []
var life_archives: Array = []


func to_dict() -> Dictionary:
	return {
		"soulId": soul_id,
		"reincarnationCount": reincarnation_count,
		"lastRetention": last_retention,
		"inheritedSkills": inherited_skills.duplicate(),
		"inheritedAttrBonus": inherited_attr_bonus.duplicate(),
		"karmaCarry": karma_carry,
		"luckCarry": luck_carry,
		"legacyClues": legacy_clues.duplicate(true),
		"anchorRelations": anchor_relations.duplicate(true),
		"mainQuestProgress": main_quest_progress.duplicate(true),
		"dragonizationCarry": dragonization_carry,
		"knownRunes": known_runes.duplicate(),
		"lifeArchives": life_archives.duplicate(true),
	}


static func from_dict(data: Dictionary) -> SoulRecord:
	var s := SoulRecord.new()
	s.soul_id = str(data.get("soulId", ""))
	s.reincarnation_count = int(data.get("reincarnationCount", 0))
	s.last_retention = float(data.get("lastRetention", 0.0))
	s.inherited_skills = _int_dict(data.get("inheritedSkills", {}))
	s.inherited_attr_bonus = _int_dict(data.get("inheritedAttrBonus", {}))
	s.karma_carry = int(data.get("karmaCarry", 0))
	s.luck_carry = int(data.get("luckCarry", 0))
	s.legacy_clues = data.get("legacyClues", []).duplicate(true)
	s.anchor_relations = data.get("anchorRelations", []).duplicate(true)
	s.main_quest_progress = data.get("mainQuestProgress", {}).duplicate(true)
	s.dragonization_carry = int(data.get("dragonizationCarry", 0))
	for r in data.get("knownRunes", []):
		s.known_runes.append(str(r))
	s.life_archives = data.get("lifeArchives", []).duplicate(true)
	return s


static func _int_dict(source: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key in source:
		out[str(key)] = int(source[key])
	return out
