# M29 副本 BOSS 与修正词条（M-D 纵深）

> 承接路线图 M-D：副本最下层 BOSS（书名号标记）、进最下层公告+撤退机会、击杀掉宝石宝箱/尸体/全部装备；修正词条每层叠深；主题决定怪物池与掉落偏向。

## 目标

把 M21/M23 的临时副本从"一层层刷怪捡宝箱"补出**终点**与**深度**：
1. 最深处有一头《书名号》BOSS，进去先公告、给撤退机会，击杀掉宝石/尸体/全装备三件套。
2. 大地图遗构上的 0–2 条修正词条（WorldSeen.words）从纯文案变成**每层叠深的真实规则**。
3. 主题（小镇哨站 / 宝藏房）决定怪物池类别与掉落偏向。

## 实现步骤

### 1. 修正词条规则层 `dungeon_modifiers.gd`（新建）

纯函数，不落盘，可无头测试。

- `apply(words: Array, depth: int, rules: Dictionary) -> Dictionary`
  - 输入：遗构词条数组（`[{id,label,desc}]`）、当前层深、`balance.dungeon` 段。
  - 输出：`{ enemyCountMult, enemyStrengthMult, treasureCountMult, lootRarityBias, monsterCategory }`。
  - "每层叠深"：每条词条的效果按 `1.0 + depth * depthScale` 放大（`depthScale` 走 balance），深度 0 时为 1×（词条在第一层就已生效，但深度越大越凶）。
  - 四条词条的效果（主题统一，理由记在技术设计 D-138）：
    - `locked`（加了锁的）：treasureCountMult ↓（宝箱少），lootRarityBias ↑（好物锁得深）。
    - `stirred`（吵醒过的东西）：enemyCountMult ↑、enemyStrengthMult ↑，lootRarityBias ↑。
    - `misaligned`（塌错方向的地脉）：enemyStrengthMult ↑（更凶），treasureCountMult ↑（地脉乱了掉出更多东西）。
    - `swallowed`（吞了别的世界的账）：lootRarityBias ↑↑，enemyCountMult ↓（异世界来客少而精）。
  - 无词条时全部退到 1× / 0 偏置。

### 2. BOSS 规则层 `dungeon_boss.gd`（新建）

纯函数。

- `is_boss_floor(depth: int, max_depth: int) -> bool`：`depth == max_depth - 1`。
- `boss_spec(rules: Dictionary, depth: int, rng: DeterministicRNG, modifiers: Dictionary) -> Dictionary`
  - 从 `balance.dungeon.boss.templates`（monsterId 数组）里按 rng 抽一只作为基底。
  - 名字包书名号：`《%s》`。
  - 数值按 `balance.dungeon.boss.statMult`（hp/attack/armor/magicResist）放大；再叠 modifier 的 enemyStrengthMult。
  - threatLevel 取该怪 TL + 2（BOSS 比同层怪高一档，掉落更好）。
  - 单只，unitId = `dungeon-{seq}-boss`。
- `boss_loot(rules: Dictionary, rng: DeterministicRNG, modifiers: Dictionary) -> Array`
  - 三件必掉：宝石（`boss.gemTemplateId`）、尸体材料（`boss.corpseTemplateId`）、一件保底稀有以上装备（从 weapon/armor 里按 lootRarityBias 抽）。
  - 返回 templateId 数组，供 `_resolve_dungeon_combat` 直接入包。

### 3. 数据

- `balance.json` 的 `dungeon` 段新增：
  - `boss`: `{ templates: ["mon_elemental_dragon", "mon_death_knight", "mon_lich"], statMult: {hp:2.0, attack:1.5, armor:1.3, magicResist:1.3}, gemTemplateId, corpseTemplateId, equipmentRarityFloor: "rare" }`
  - `modifiers`: `{ depthScale: 0.1, locked: {treasureCountMult:0.6, lootRarityBias:0.3}, stirred: {...}, misaligned: {...}, swallowed: {...} }`
  - 主题段 `themes` 每条加 `monsterCategory`（outpost→humanoid、treasure_room→beast）与 `lootCategoryBias`（outpost→armor、treasure_room→consumable）。
- `items.json` 新增：`material_gem`（宝石，category:material，price 高）、`material_boss_corpse`（BOSS 尸体，category:material）。

### 4. `main.gd` 接线

- 新增状态：`var _dungeon_words: Array = []`、`var _dungeon_modifiers: Dictionary = {}`、`var _dungeon_boss_floor: bool = false`。
- `_trigger_visible_dungeon(node)`：把 `node.words` 存进 `_dungeon_words`。
- `_enter_dungeon` / `_dungeon_descend`：
  - 用 `DungeonModifiers.apply(_dungeon_words, _dungeon_depth, rules)` 算 `_dungeon_modifiers`。
  - 把 modifier 的 enemyCountMult / treasureCountMult 并入 `Dungeon.layout` 的 opts（覆盖 theme 的倍率，二者相乘：`layout_enemyMult = theme.enemyMult * modifier.enemyCountMult`）。
  - 若 `DungeonBoss.is_boss_floor`：`_dungeon_boss_floor = true`，_status 公告"最深处沉睡着一头《…》，按 ESC 可撤退，按回车下潜迎战"。
  - BOSS 层只摆一只 BOSS（替代普通敌人）：layout 的 enemies 仍由 Dungeon 生成（至少一只），但 `_dungeon_pick_enemy` 时检测到 boss_floor 就改走 `_start_boss_combat`。
- `_start_dungeon_combat`：若 `_dungeon_boss_floor`，用 `DungeonBoss.boss_spec` 构造对手（单只），sessionId 带 `-boss`。
- `_resolve_dungeon_combat`：若 BOSS 战且玩家胜，调 `DungeonBoss.boss_loot` 把三件套入包，_status 写"你击败了《…》，它的财宝散落一地"；并 `_dungeon_boss_floor = false`、清 `_dungeon.enemies`（BOSS 倒下副本通关）。
- `_dungeon_roll_loot`：按 modifier.lootRarityBias 与 theme.lootCategoryBias 加权抽宝箱内容（稀有度上移、主题类别优先）。
- `_dungeon_monster_spec`：若 theme.monsterCategory 非空，怪物池只取该 category（池空退回全池）。

### 5. 测试

- `DungeonModifiers.apply`：无词条→全 1×；单条词条方向正确；depth 放大。
- `DungeonBoss.is_boss_floor`：边界正确。
- `DungeonBoss.boss_spec`：名字带《》、数值放大、单只。
- `DungeonBoss.boss_loot`：三件套非空、模板存在于 items.json。
- main 流程无头：进 BOSS 层公告、撤退不改状态、击败 BOSS 三件套入包。

## 关键取舍（写进技术设计 9.33 节 D-138/D-139）

- **D-138 修正词条为什么每层叠深而不是只在副本入口生效一次**：词条是"这座遗构的脾气"，深度越深越接近它的核心，脾气越烈；入口标一次就固定会让浅层和深层体验一样平。叠深用线性 `depthScale`（0.1/层），20 层封顶 3×，不会把数值炸穿。
- **D-139 BOSS 为什么复用怪物模板放大而不是新建 BOSS 表**：现有 monsters.json 已有 TL 20 元素龙，放大 2× HP 已是副本终点的体量；新建 BOSS 表要再维护一套数值，且"书名号"本就是 Elona 式对精英怪的标记——同一只怪加《》就是 BOSS。
