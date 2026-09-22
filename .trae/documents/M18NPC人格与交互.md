# M18 NPC 人格与交互（可对话 / 送礼 / 雇佣的活NPC）

> 计划文档 · 里程碑 18
> 依据：《轮回之书-游戏设计文档》第 4/5 章 Elona 式「世界有活人」意图、《世界模拟量化规则》第 11/12 章（"关系值随互动演化"）、《技术设计文档》9.21 待续
> 交付物：把现在「静态关系图 + 只会老死的背景板 NPC」升级为「有性格/信仰、玩家可对具体 NPC 对话/送礼/雇佣、好感分档可见、玩家行为真的改写关系」的活NPC。
> 前置判定（M18 立项评估，本会话已完成）：NPC 无自主日程、无可交互对话入口、关系是生成期一次性写的静态图；怪物无装备/掉落/变体/驯服。选「NPC 人格与交互」作为 Elona 式深度突破口。

---

## 一、现状与缺口

### 1.1 现状（已核实）

- `sim_npc.gd`：只有 id/城市/性别/种族/年龄/寿命/职业/是否具名/职位/家庭组 **10 个字段**，没有任何性格/信仰/人格。
- `world_state.gd` `relations`：`npcId → [{toNpcId, type, value}]` 静态关系图，`npc_generator.link_relations` 只在建城/补池时写一次，之后**无人改写**，纯展示。
- 玩家身份与 NPC 池**完全分离**：`PlayerAvatar` 不在 relations 里，没有「玩家→NPC」的好感。`CHA` 在文档里已被定义为「交易折扣、好感、说服」，但**好感这一项整个没落地**。
- `main.gd` 城市面板 action 区只有 商铺/走私航线/委托板/城中大事，**没有人物/居民入口**；全 src 无 `talk/dialog/recruit/interact` 任何对话入口。
- 玩家现在与 NPC 能发生的全部交互 = 城市级服务（商店/铁匠/酒馆/委托/投资），无法跟任何一个具体的人说话。

### 1.2 缺口与 M18 定位

缺口是与 Elona 最刺眼的落差：「世界有一群 NPC，但你一个都不认识」。M18 不膨胀到 Elona 的全套（昼夜作息日程、婚姻生子、完整对话树、战斗随从），而是把「玩家与具体 NPC 的可交互闭环」立起来——**人格 → 好感分档 → 三种交互（交谈/送礼/雇佣）→ 玩家行为真改好感 → 跨代落盘**，让玩家第一次"认得"城里某个人。

---

## 二、范围

### 2.1 做（End-to-End 闭环）

1. **人格与信仰**：`SimNpc` 增 `personality_id`/`faith_id` 两字段；`NpcGenerator` 生成时确定性指派；序列化往返；城市面板/交互卡片展示人格一句。

2. **玩家↔NPC 好感（活关系）**：`world_state` 新增 `player_relations: Dictionary[npcId→int]`（玩家针对每个 NPC 的好感，-100~+100 钳制，跨代落盘）。档位：敌对 < -50 / 冷淡 < -15 / 中立 / 友善 > 15 / 亲密 > 50。读写统一走规则层，`CHA` 作为交互效果系数介入——把文档里「好感受 CHA 影响」这条首次落地。

3. **交互规则层 `npc_interaction_system.gd`**（静态类，纯函数 + 就地改 world/avatar，返回统一 `{ok, error, ...}`，可被无头测试钉住）：
   - `list_residents(world, city_id)` → 该城具象 NPC（含人格一句话 + 好感档位）。
   - `talk(avatar, world, npc, intent)`：intent ∈ 志向/传闻/信仰。按人格主句 + 好感档位润色的台词，小幅好感变化（+1~+3，冷淡/敌对者可能 +0 或好转），有**每NPC每周冷却**防连点。
   - `gift(avatar, world, npc, itemId)`：按人格 giftTaste 判定（偏好 +10~+、中性 +3、厌恶 -5），消耗该物品，钳制，返回档位与心情句。
   - `hire(avatar, world, npc)`：仅限可雇佣职业类别 + 好感 ≥ 友善 + 非具名锚点。按 `PL×系数/CHA` 定价扣钱，**签一项限时随行服务**（见 2.2），写纪年一条。仇恨者拒不接单。
4. **界面**：城市面板 action 区新增「居民与人物」入口 → 新视图 `VIEW_NPC`(12)：左列可滚动 NPC 名单（点选），右侧详情卡片（名/种族/年龄/职业 + 人格一句 + 好感档位条 + 心情句），底部四个动作「交谈·志向 / 交谈·传闻 / 送礼 / 雇佣」，送礼走物品选择（复用背包/物品行样式）。
5. **跨代落盘**：`player_relations` 进世界快照序列化；人格/信仰进 `SimNpc.to_dict/from_dict`；转生不丢（好感和人格随世界，不随灵魂——你上一世认识的人这一世还在，这是"认得熟人"的根基）。

### 2.2 做但控制边界（雇佣深度 = 战斗随从）

用户决定雇佣深度为**战斗随从/宠物**——雇下来的 NPC 在野外遭遇战斗中作为**队友**真的上场跟着打。这是 M18 里接入面最大的一块，但不改动 combat 的既有判定框架，只复用它的多单元能力：

- **随从进战斗**：`combat.start` 已支持任意 `side` 的多单元；把雇来的 NPC 构造成一个 `side=player`、`auto=true` 的「AI 盟友单元」注入本场遭遇的战斗规格。玩家手动控制的单元是 `controlled=manual`（英雄），随从是 `controlled=auto`，复用 `auto_action`（就近攻击/走近）驱动即可，可视化走既有战斗网格与先攻排序。
- **随从属性**：从雇主的职业类别 + 基础属性推导一套够用的战斗规格（护甲/武器/技能由职业决定，PL 随好感与人物成长小幅缩放），由规则层 `follower_combat_spec(avatar, world, hire)` 产出，不落盘、每场现算。
- **胜负口径**：玩家战败判定**只看英雄单元**是否倒地/阵亡，随从阵亡不判负（贴合 Elona「同伴可死、不连带 game over」），随从在这场死亡则本场后解雇/记为战殁并写纪年。
- **战斗中交互**：随从倒地后沿用既有 `downed_choice` 只有英雄能判别；随从自己不提供搜身/俘虏选项（就地放走或由英雄补刀）。随从不抢英雄的结算/战利品选择权。
- **限时契约**：一次只雇一名（换雇需先解约），契约期 `balance.npcInteraction.hireMonths`（6 月）内此次雇佣持续有效，期满自动解除并写纪年；月结算 `WorldSim.apply_state_change` 落账（与 M12 月贡同轨）。

> 仍不做：宠物驯化、随从成长树/装备自定义、随从独立背包——那些单独立里程碑。M18 让随从「上场一起打、会倒地会战死、契约有期」，Elona 的"带个人在身边"感已经立住。

### 2.3 不做（本轮不膨胀）

- 宠物驯化、随从成长树/装备自定义、随从独立背包、随从 AI 智能策略（就用就近攻击的默认 auto_action）。
- 成人向婚恋、生儿育女、NPC←NPC 关系的自动演化（保留生成期静态图，本轮只新增"玩家侧活关系"）。
- 完整树形对话（adventure 式多选项长对话）——用「人格一句 + 档位润色」的轻量台词池取代。
- NPC 昼夜作息日程、个体迁移事件重做（留给后续"自主日程"里程碑）。
- 不改 combat 的判定框架本体（胜负/加算/技能语义不动），只在事件接入时注入 `auto` 盟友单元 + 按「英雄是否倒地」收口战败判定。

---

## 三、数据与配置

### 3.1 新 `game/data/personality.json`

人格池，供生成器指派 + 交互取台词/偏好：

```json
{
  "personalities": [
    { "personalityId": "p_brusque", "displayName": "刻薄", "greeting": "……有话快说。",
      "talkLines": {"ambition": "……你这辈子没什么本事，就别来烦我。", "rumor": "街上都在传索恩港那批赃货又被查了。", "faith": "神？我只看银子。"},
      "toneByAffinity": {"friendly": "……你倒还有点意思。", "hostile": "离我远点。"},
      "giftTaste": {"love": ["gem", "wine"], "hate": ["herb"]},
      "affinityTalk": 1 },
    { "personalityId": "p_cheery", "displayName": "爽朗", ... }
  ],
  "faiths": [
    { "faithId": "f_market", "displayName": "商神", "greetingBless": "愿商神照看你的买卖。" },
    { "faithId": "f_none", "displayName": "无信者", ... }
  ]
}
```

- `giftTaste.love/hate` 用物品 **category**（珠宝/酒/草药…）判定，通吃所有具体 id，避免每物品配一张偏好表。
- 每条人格给 `affinityTalk`（一次交谈的基础好感增量），收到 `balance` 里按档位缩放即可，无需每人一套曲线。

### 3.2 `game/data/professions.json` 增业务主数据

给职业类别补一个可雇佣标记（沿用现有 `category` 语义，不新增schema）：

- 已有 category：`military / commerce / production / knowledge / gray`。可雇佣 = `military|gray`（护卫/打手）与 `commerce`（行商）、`knowledge`（顾问）。
- 具体是否可雇佣由规则层按 category 判定，不一一改职业表（少动数据）。

### 3.3 `game/data/balance.json` 增 `npcInteraction` 配置段

```json
"npcInteraction": {
  "affMin": -100, "affMax": 100,
  "bandHostile": -50, "bandCold": -15, "bandFriendly": 15, "bandClose": 50,
  "talkCooldownMonths": 1,
  "talkDelta": {"hostile": 0, "cold": 1, "neutral": 2, "friendly": 3, "close": 2},
  "giftDelta": {"love": 12, "neutral": 3, "hate": -5},
  "giftChaFactor": 2,
  "hireMonths": 6,
  "hirePricePLFactor": 20, "hirePriceChaDiv": 30,
  "hireMinAffinity": 15,
  "hireEffects": {"military": ["ravel_safety"], "gray": ["ravel_safety"], "commerce": ["trade_margin"], "knowledge": ["skill_growth"]}
}
```

---

## 四、规则层设计

### 4.1 `game/src/core/npc_interaction_system.gd`（新，`class_name NpcInteractionSystem`）

静态类，全部就地改 world/avatar 并返回 `{ok, error, ...}`，可无头钉测：

| 方法 | 签名要点 | 职责 |
|------|----------|------|
| `affinity(world, npc_id)` / `set_affinity` | 读写 `world.player_relations`，clamp | 好感读写统一入口，档位由 band 判定 |
| `band(value) -> String` | -100~100 | 敌对/冷淡/中立/友善/亲密 |
| `resident_card(avatar, world, npc)` | → `{npc, name, raceName, age, professionName, personalityId, personalityLine, faith, affinity, band, hireable, hireCost}` | 详情卡片一次成型 |
| `talk(avatar, world, npc, intent) -> {ok, line, band, affDelta}` | 冷却 + 档位 + 人格主句 | 说一句，扣冷却，小幅好感 |
| `gift(avatar, world, npc, item_id) -> {ok, line, band, affDelta}` | 消耗物品 + taste 判定 + CHA 缩放 | 送礼改好感 |
| `hire(avatar, world, npc) -> {ok, effect, cost, error}` | 资格/好感/价格/扣钱 | 签限时随从契约，写 `world.active_hires` |
| `follower_combat_spec(avatar, world, hire) -> Dictionary` | 由职业/好感推导 | 产出一个 `side=player, controlled=auto` 的战斗单元规格，供遭遇注入 |

- 冷却：`npc_id + intent` 记在 `world.npc_talk_cooldowns`（npcId→dict[intent→month]），月度推进判断「是否到点」，逾 `talkCooldownMonths` 恢复。
- 好感守则：`giftDelta` × CHA 系数（CHA 越高，同一份礼越讨喜）；`band` 反向作用于 `talkDelta`（敌对者不理你，亲密者陪你多聊）。

### 4.2 活关系的落账路径

- 好感/冷却/雇佣都进 `world_state`（`player_relations`、`npc_talk_cooldowns`、`active_hires`），进 `to_dict/from_dict` 跨代落盘。转生不丢（随世界，不随灵魂）。
- 雇佣的月末结算复用 `WorldSim.apply_state_change` 消费 `counsel/guard/merc` 效果产生差分（与 M12 建筑月贡、M17 事件落账同轨）。

### 4.3 CHA 首次落地

- 交易折扣与说服**本轮不动**，只落「好感受影响」这一条：Gift 效果、部分 hire 价格随 CHA 缩放，呼应文档「CHA：交易折扣、好感、说服」，并把这一点写进技术设计 9.21。

### 4.4 战斗随从接入（本里程碑改动面最大的一块）

战斗侧**不改判定框架**，只做两件最小接入：

1. **`combat.gd` 增 `controlled` 标记**：`_build_unit` 读 `spec.get("controlled","manual")` 存进单元；英雄单元是 `manual`，随从/敌人是 `auto`。新增公开 `is_auto(unit_id)`，主循环据此判断「当前单位该等玩家输入还是交给 `auto_action`」。既有胜负判定**收口为只看英雄单元**（`RESULT_PLAYER` 由玩家操控的那一个是否倒地/阵亡决定），随从阵亡不判负。
2. **遭遇注入**：`main.gd`（及可复用的遭遇装配处）在 `world.active_hires` 存在 `combat=true` 的随从时，把 `NpcInteractionSystem.follower_combat_spec(...)` 的单元追加进 `encounter.units`。主战斗循环（`_unhandled_input` / 自动驱动）里：`controlled=auto` 的单位到轮时 `submit_action` 前调用 `combat.auto_action` 驱动，玩家无感推进。随从倒地走既有 `downed_choice`（放走/补刀，由英雄操作），战殁则战斗结束后解除契约并写纪年。

- 复用既有战斗视图/网格/先攻排序，随从就是多一个玩家侧单元，视觉上照 `side` 着色即可。

---

## 五、界面

- 城市 action 区加「居民与人物」入口（与商铺/委托并列，M18 内点击 `_enter_residents(city_id)`）。
- 新视图 `VIEW_NPC = 12`：
  - 左列：该城可交互 NPC 名单（具名/锚点标星，普通居民一列），点选高亮，↑↓ 换选。
  - 右栏：详情卡片（名·种族·年龄·职业 + 人格一句 + 好感档位条 [敌对/…/亲密] + 当前心情句）。
  - 底部动作：`交谈·志向 / 交谈·传闻 / 送礼 / 雇佣`。送礼弹出物品选择（复用背包行样式，只列可送 item_category 适合者或任意持有物）。
  - 键位：↑↓ 选人，回车 选动作，G 送礼选物，ESC/T 返回城市。HINT 文案照既有风格补。
- 复用一个 `VIEW_NPC` 做「列表 + 详情 + 动作」三态，不另开第二个常驻面板。

---

## 六、测试（`test_suite.gd` 增补）

全量从 2137 出发，新增约 30+ 断言：

1. **生成指派**：发电机确定性给 `personality_id`/`faith_id`；同一 RNG 种子两批结果一致。
2. **序列化**：`SimNpc` 人格/信仰、`player_relations`、`active_hires` 存读往返一致。
3. **好感钳制与档位**：越界 ±120 被钳回 ±100；五档边界含/不含。
4. **交谈**：不同人格产出不同 line；档位影响 tone 后缀；有冷却（同 NPC+intent 冷却期内再次 talk 返回 cooldown 错误）；冷却到期恢复。
5. **送礼**：love 类 +Δ、中立 +3、hate -Δ，物品被消耗；CHA 缩放生效；敌对 NPC 拒收或激怒。
6. **雇佣**：可雇佣类别/好感门槛/价格/扣钱；仇恨或非雇佣类拒绝；一次性限签一名（换签先解约）；雇佣写纪年；契约期到自动解除。
7. **战斗随从**：`follower_combat_spec` 产出合法战斗单元（side=player, controlled=auto）；随从在战斗中照 `auto_action` 行动正常推进回合；英雄倒地判负、随从倒地/阵亡**不**判负；随从战殁后契约解除并写纪年。
8. **UI 视图模型**：`resident_card` / 名单 build 在带/无好感两种状态下形状一致、命中可测。

---

## 七、文件改动清单

| 文件 | 动作 |
|------|------|
| `game/data/personality.json` | 新增（人格池 + 信仰池） |
| `game/data/balance.json` | `npcInteraction` 配置段 |
| `game/src/core/sim_npc.gd` | +`personality_id`/`faith_id`，to_dict/from_dict |
| `game/src/core/npc_generator.gd` | 生成时确定性指派人格/信仰 |
| `game/src/core/world_state.gd` | +`player_relations`/`npc_talk_cooldowns`/`active_hires` 与序列化 |
| `game/src/core/world_sim.gd` | 雇佣月结算差分消费 + 冷却恢复 + active_hires 过期 |
| `game/src/core/npc_interaction_system.gd` | **新增规则层**（含 `follower_combat_spec`） |
| `game/src/core/combat.gd` | `_build_unit` 加 `controlled`/`is_auto`；胜负收口为只看英雄单元 |
| `game/src/ui/npc_interaction_view_model.gd` | 列表/详情/动作三态 build |
| `game/scenes/main.gd` | `VIEW_NPC` 视图、`_enter_residents`、分发五处、会话字段、HINT |
| `game/src/autoload/content_loader.gd` | `PERSONALITY_FILE` 加载 + 闭环校验（id 唯一、giftTaste 引用合法职业/物品类别） |
| `game/tests/test_suite.gd` | 新增 8 个左右测试函数 |
| `README.md` / `轮回之书-技术设计文档.md` | 里程碑 18 + 9.21 节（D-94 ~ D-9x） |

---

## 八、实现顺序

1. `personality.json` + `balance.json` + `content_loader` 加载校验。
2. `SimNpc` 人格/信仰字段 + `NpcGenerator` 指派 + 序列化 + 测试。
3. `world_state` 好感/冷却/雇佣存储 + 序列化 + 测试。
4. `NpcInteractionSystem`：affinity/band/talk/gift/hire + `follower_combat_spec` + 测试。
5. `combat.gd`：`controlled`/`is_auto` + 胜负收口只看英雄 + 随从战殁解约 + 测试。
6. `world_sim` 契约月结算与冷却恢复 + 测试。
7. `npc_interaction_view_model` + main.gd 接线（VIEW_NPC 全分发五处 + 城市入口 + 战斗 auto 驱动随从）。
8. 全量测试绿 → 文档（README + 9.21 节）→ Git 提交 → 询问推送。