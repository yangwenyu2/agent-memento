<div align="center">

<img src="./assets/banner.png" alt="Agent Memento Banner" width="100%">

# 🧠 Agent Memento

**面向大模型的“记碎式”自动化生产兵工厂**

*“不要去造一个企图记住一切的 AI，我们要造一个让 AI 每 5 分钟醒来重新精读图纸的系统。”*

[![OpenClaw Skill](https://img.shields.io/badge/OpenClaw-Skill-blue.svg)](https://github.com/openclaw/openclaw)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

[English](./README.md) | [简体中文](./README_zh.md)

</div>

---

## ⚡ The "Aha!" Problem：聊天框造不出航空母舰

当你让 AI 智能体在一个无限延长的聊天框里造一个庞大的项目，前 10 分钟的代码如魔法般美妙。但当代码规模超过 2000 行后，魔法变成了梦魇：
- **上下文失忆症 (Context Amnesia)**：它忘了自己一小时前定义的接口，开始凭空捏造 API。
- **“看起来挺好”幻觉 (The "LGTM" Delusion)**：它自信满满地说“我修好了 Bug”，但代码根本跑不通。
- **OOM 核爆 (The OOM Nuke)**：为了修一个错字，它试图在一次对话里直接重写整个 3000 行的文件，最终算爆显存导致进程宿主（Gateway）崩溃死机。

**结论：持续不断的冗长对话，是对长线工程的最致命毒药。**

## 💡 The Solution：记忆碎片执行法 (Memento Execution)

灵感来自诺兰电影《记忆碎片》(Memento)。我们彻底抛弃并摧毁了“全知全能的超级 Agent”。
我们用一支**无情、失忆、极短命的 Tick Worker（滴答工人）军队**来取代它。它们活着的唯一目的，就是读同一张实体图纸，去敲下一颗钉子，物理验证，然后赴死（休眠）。

### ⚙️ 它是怎么工作的？(双态智能分离)
1. 📂 **大脑外置 (The Externalized Brain)**：Agent 不再依赖 Chat 上下文环境作为回忆池。项目的进度全部剥离下放到物理环境中的 `MASTER_PLAN.md` 里。记忆变成了实体。
2. 🏛️ **架构师态 (The Architect)**：人类和主控 AI 在普通的 Session 里天马行空地讨论架构，做出调整，然后将大叙事切分为最细颗粒度的 `[ ]` 复选框存入大纲。
3. 🔨 **泥瓦匠态 (The Tick Worker)**：Cron 每 5 分钟在后台唤醒一个干干净净、没有上下文的新 Agent：
   - 它会冷酷地读取 `MASTER_PLAN.md`。
   - 自上而下扫描，找到**第一个还没打钩的 `[ ]`**。
   - 聚拢 100% 的推理力，只修这一个微小模块。
   - **铁血防爆纪律**：只允许使用外科手术级别的代码替换（sed 或 AST），绝不覆写全文引起 OOM。
   - **铁血防幻觉纪律**：必须跑脚本（`npm test` / `curl`）在控制台拿到成功的 `Exit 0` 退出码。拿不到，死也不许给自己打 `[x]` 勾。
   - 任务结束，沉睡。

### 🕹️ 可观探测流 (无 Prompt 干预法)
厌倦了对着聊天框大吼大叫“你刚才写偏了！重写！”？ 
有了 Memento 机制，干预这个黑盒不再需要 Prompt。你只需要像修改备忘录一样静静地把 `MASTER_PLAN.md` 里的勾去掉或加一句需求。下一个被唤醒的 Tick Worker 会立即遵从这套崭新的宇宙法则，像变道的湍流般顺着你的新图纸奔涌。

---

## 🚀 极速部署 (One-Line Scaffold)

在 OpenClaw 生态里撕毁聊天窗流派，用一行代码平地拉起属于你的 Memento 自动化兵工厂：

```bash
cd ~/.openclaw/workspace
bash skills/agent-memento/scripts/init_memento.sh 你的大项目名称
```

它会自动为你完成积木铺设：
1. 注入 `projects/你的项目/docs/MASTER_PLAN.md`（你的全图景大纲图纸）。
2. 构建 `TICK_STATUS.md`（如果 Worker 被奇葩 Bug 阻断卡死，死前会在这里把原因写下来给你看）。
3. 生成一个**开箱即用、装满军规般 System Prompt 的唤醒脚本**： `scripts/你的项目_tick.sh`。

你只需要在 `MASTER_PLAN.md` 里填好你想造什么，然后挂到 crontab 里：
```bash
# 加入 crontab
*/5 * * * * bash /root/.openclaw/workspace/scripts/你的项目_tick.sh
```

**然后去睡觉。醒来验收一栋每一块砖都被测试验证过的高塔。**
