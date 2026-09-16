class_name SimNpc
extends RefCounted

## 模拟 NPC（技术设计文档 3.2 节的 SIM_NPC、《世界模拟量化规则》第 11 章）。
##
## 与「抽象人口」的区别：城市的人口维度只是一个 0–100 的指数，而这里的 NPC
## 是具象化的个体，有年龄、职业、家庭与关系。两者的数量关系是
## `模拟 NPC 数 = min(人口 × 3, 200)`（11.1 节）。
##
## 具象 NPC 的迁移与抽象人口的「净移民」项是两条独立通道，刻意不做合并：
## 前者让玩家看到具体的人搬走，后者让城市的宏观数字继续演化。合并的话，
## 一次迁移要同时改两处，任何一边漏掉都会出现「人都走光了人口还是 70」。
##
## 死亡的 NPC 直接从池里移除，不保留墓碑记录——M2 阶段没有任何东西需要读
## 死者（继承由「职位空缺由新 NPC 补上」实现），留一份只增不减的死者名单
## 会让存档无界增长。

const GENDER_MALE: String = "male"
const GENDER_FEMALE: String = "female"

var npc_id: String = ""
var city_id: String = ""
var given_name: String = ""
var family_name: String = ""
var gender: String = GENDER_MALE
var race_id: String = "human"
var age: int = 20
var lifespan: int = 80
var profession_id: String = ""
var is_named: bool = false       ## 具名 NPC：世界观第七章名录里的角色，锚定在出生城
var position_id: String = ""     ## 职位（守卫队长、大祭司等），死亡后需有人接替
var family_id: String = ""       ## 家庭分组，亲属关系由它推导
var personality_id: String = ""  ## 人格（M18）：决定谈话基调与送礼口味，见 personality.json
var faith_id: String = ""        ## 信仰（M18）：提供一句开场，见 personality.json


func display_name() -> String:
	return given_name + family_name


## 老年：不再迁移（《世界模拟量化规则》5.4 节）。
func is_elder(margin: int) -> bool:
	return age >= lifespan - margin


## 是否已达寿命上限。实际是否死亡由世界模拟统一判定，
## 因为锚点 NPC 不受寿命约束（5.1 节）。
func is_at_lifespan() -> bool:
	return age >= lifespan


func to_dict() -> Dictionary:
	return {
		"npcId": npc_id,
		"cityId": city_id,
		"givenName": given_name,
		"familyName": family_name,
		"gender": gender,
		"raceId": race_id,
		"age": age,
		"lifespan": lifespan,
		"professionId": profession_id,
		"isNamed": is_named,
		"positionId": position_id,
		"familyId": family_id,
		"personalityId": personality_id,
		"faithId": faith_id,
	}


static func from_dict(data: Dictionary) -> SimNpc:
	var n := SimNpc.new()
	n.npc_id = str(data.get("npcId", ""))
	n.city_id = str(data.get("cityId", ""))
	n.given_name = str(data.get("givenName", ""))
	n.family_name = str(data.get("familyName", ""))
	n.gender = str(data.get("gender", GENDER_MALE))
	n.race_id = str(data.get("raceId", "human"))
	n.age = int(data.get("age", 20))
	n.lifespan = int(data.get("lifespan", 80))
	n.profession_id = str(data.get("professionId", ""))
	n.is_named = bool(data.get("isNamed", false))
	n.position_id = str(data.get("positionId", ""))
	n.family_id = str(data.get("familyId", ""))
	n.personality_id = str(data.get("personalityId", ""))
	n.faith_id = str(data.get("faithId", ""))
	return n
