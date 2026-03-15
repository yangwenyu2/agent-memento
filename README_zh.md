# 🧠 Agent Memento

**让你的 AI 每 5 分钟强行失忆一次。这正是它的精髓。**

这是一款基于时间跳动（Tick-driven）的自治生产框架，通过拥抱"失忆"，将容易发散的 LLM 从聊天机器人改造成可靠的流水线黑灯工厂。

> 灵感来自电影《记忆碎片》：如果你无法形成新的长期记忆，你必须把规矩和蓝图纹在身上。

## 解决的痛点 (The Problem)

现在所有的写代码 Agent 最终都会撞上同一堵墙：

| 传统模式（Without Memento） | Memento 模式 (With Memento) |
|----------------|--------------|
| 🧠 “我能记住整个项目几千行的细节！” | 📋 “我只信文件。我每次醒来重新完整读一遍图纸。” |
| 💀 代码到了 2000 行后爆内存死锁 (OOM) | ✅ 靠无情切片能一个通宵糊出 1.5 万行甚至 10 万行项目 |
| 🎭 运行 30 分钟后产生幻觉重构代码 | 🔬 改动的每一行必须过本地命令审核与回滚防线 |
| 🔄 为了改个 bug 输出全量文件 | 🔪 纪律严明：只能用显微镜级的手术刀切入 |

## 它是怎么工作的？(How It Works)

```text
人类 (发号施令) → 架构师机 (起草盘面) → MASTER_PLAN.md → 牛马机 (Tick Worker 执行)
                                          ↑                      |
                                          └──结果回传，验证记录──┘
```

1. **你** 在主群发一句自然语言：“我要爬昨天所有 AI 论文放到数据库”。
2. **架构师 (主 Agent Session)** 启动思考，把项目切成严丝合缝的 `[ ]` 检查清单任务。
3. **牛马机器们** 在系统的 cron 守护下，每 5 分钟醒一次。拿任务 `[ ]` -> 干活 -> 运行验证测试 -> 修改状态为 `[x]`。
4. 如果卡住 -> 标记为 `[!]` -> 发出警报，架构师去修 -> 流水线继续。
5. 你只需要泡杯茶，打开它的独立控制台 Dashboard 收菜。

## 30 秒上手 (Quick Start)

1. 初始化一套防爆的工程系统脚手架：
   ```bash
   bash skills/agent-memento/scripts/init_memento.sh MyProject
   ```

2. 让主对话里的 Architect 填好 `docs/MASTER_PLAN.md` 和 `docs/PROJECT_MAP.md`。

3. 将脉冲挂上机器系统：
   ```bash
   crontab -e
   # 加入：*/5 * * * * /path/to/MyProject/scripts/memento_tick.sh
   ```

4. 拉起实时的外接监测控制台（Dashboard）：
   ```bash
   bash skills/agent-memento/scripts/dashboard.sh
   ```

## 哲学 (Philosophy)

> "最顶级的 AI 系统，就是假设它根本什么都记不住，然后围绕这个残酷的前提搭建世界。"

Agent Memento 并不能让现在的模型变得更聪明。但它能让 AI 变得完全 **可靠 (Reliable)** ——通过给它一本永远丢不掉的物理记事本（MASTER_PLAN），要求它每次操作后的铁血三阶自证防污染清理，以及一次次把它每 5 分钟杀死并重生的纪律。

---
阅读 [SKILL.md](./SKILL.md) 了解完整的底层工作流与系统预注入 prompt。
