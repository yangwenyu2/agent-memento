# Agent Memento (Tick-Driven Autonomous Execution)

“Don't build AI that tries to remember everything. Build systems that make AI read the blueprint anew every 5 minutes.”
（不要去造一个企图记住一切的 AI，去造一个让 AI 每 5 分钟醒来重新精读图纸的系统。）

本技能是对目前阻碍生成式 AI 编写复杂、相互交织、长期的大型系统三大绝症（上下文发散遗忘、长对话幻觉重构、全局推演资源爆炸）的一种工业化拔本解题思路。

## 理念基石 (The "Aha" Moment)

当我们在聊天框里让大模型“写一个游戏”时，开头总是美好的。但随着代码超过 2000 行，模型开始：
- **失忆症 (Amnesia)**：忘记了自己定义的接口，开始凭空捏造。
- **幻觉重构 (Hallucination)**：自信满满地输出一堆根本没有跑过的“完美”代码。
- **上下文核爆 (Resource Overload)**：为了修一个小 Bug，强行覆盖整个 5000 行的文件，直到内存耗尽 (OOM)、网关崩溃。

**核心痛点：聊天框根本装不下航母，长程对话是工程的毒药。**

Agent Memento（源自电影《记忆碎片》）彻底颠覆了这个范式：
**把“全知全能的超级 Agent”全部撕碎，降级为无数个“只有 5 分钟记忆的、无情的 Tick 机器”。**

### The Methodology：双态智能与外部状态机
1. **状态剥离（物理外置大脑）**：Agent 不在内存池中记忆项目历史，长线记忆与当前状态全部下放至物理文件（`MASTER_PLAN.md` 验证清单）。
2. **架构师态（The Architect）**：你与大模型在主 Session 里天马行空，分析竞品，反思崩溃，然后把宏大叙事翻译成 `MASTER_PLAN.md` 里的每一个 `[ ]`。
3. **泥瓦匠态（The Tick Worker）**：Cron 脚本每隔几分钟自动唤醒一个全新的、绝对专注的短命进程。它不在乎架构，只寻找清单里**第一个未打钩的 `[ ]`**，用 100% 的算力把它修好，**执行物理验证（测试不通过绝不打勾）**，然后安心赴死（离线）。
4. **低能耗的方向纠缠 (Observable Steering)**：干预这种全自动流水线，再也不需要对着 AI 吼叫“你刚才写偏了！”人类监督者只需要像修改剧本一样去修改大纲，下一个 Tick 周期，自动化的洪流就会瞬间改道。

## 系统化实施方法 (How to Deploy)

当用户说要启动 Memento 流水线时，按以下启动协议（Scaffolding）铺展环境。

### ① 快速一键拉起 (Quick Start Tools)
本技能附带了一个标准化构建脚本 `scripts/init_memento.sh`。对于全新工程，瞬间铺设：
- `MASTER_PLAN.md`（作为真理大纲与指针池的主卧）
- `TICK_STATUS.md`（供 Worker 无法通过验证时记录断点、异常的离线黑匣子）
- `xxxx_tick.sh` (自带“防止重写几千行文件、必须外科手术刀级修改”系统戒严词的专用原子化唤醒脚本)

### ② 铁血纪律 (The Execution Sandbox)
作为一个被 Memento 唤醒的 Tick Worker，你必须对自己狠一点：
1. **防爆底线 (Surgical Edits Only)**：当需要修改几千行的文件时，严禁输出“完整文件并要求覆写”。必须通过精准定位工具修改，哪怕用 `sed`，否则必将导致崩溃。
2. **拒绝脑内验算 (Evidence-based Audit)**：不要相信你的“我觉得这行了”，必须用脚本跑 `node file.js` 或验证 DOM 返回。没有冰冷的控制台 `Exit Code 0`，你休想在 `[ ]` 上画一个 `x`。 
3. **不要静默空转 (No Silent Ghosting)**：如果卡在了一个奇葩 Bug 上，绝不要沉默退出。把死亡原因写进 `TICK_STATUS.md` 中，让架构师在睡醒后进行抢救。