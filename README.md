# 🧠 Agent Memento

**Your AI agent forgets everything every 5 minutes. That's the point.**

A tick-driven autonomous execution framework that turns any LLM into a 
reliable production factory — by embracing amnesia instead of fighting it.

> Inspired by the film *Memento*: if you can't form new memories, 
> tattoo the instructions on your body.

## The Problem

Every AI coding agent hits the same wall:

| Without Memento | With Memento |
|----------------|--------------|
| 🧠 "I'll remember the whole project" | 📋 "I'll read the blueprint fresh each time" |
| 💀 OOM at 2000 lines | ✅ Built a 15,000-line app overnight |
| 🎭 Hallucinates after 30 min | 🔬 Every change verified by real tests |
| 🔄 Rewrites your files from scratch | 🔪 Surgical edits only, always |

## How It Works

```text
You (chat) → Architect (plans) → MASTER_PLAN.md → Tick Workers (execute)
                                        ↑                    |
                                        └── results ─────────┘
```

1. **You** describe what you want in natural language
2. **The Architect** (your main AI session) breaks it into a checklist
3. **Tick Workers** wake up every 5 minutes via cron, pick the next `[ ]`, do the work, run tests, and check it off `[x]`
4. If stuck → flag it `[!]` → Architect adjusts → loop continues
5. You check the Dashboard when you feel like it. Or don't.

## Quick Start (30 Seconds)

1. Initialize project scaffolding:
   ```bash
   bash skills/agent-memento/scripts/init_memento.sh MyProject
   ```

2. Have your Architect (main session LLM) draft the `MASTER_PLAN.md` and `PROJECT_MAP.md`

3. Wire it to crontab:
   ```bash
   crontab -e
   # Add: */5 * * * * /path/to/MyProject/scripts/memento_tick.sh
   ```

4. Monitor via real-time Mission Control Dashboard:
   ```bash
   bash skills/agent-memento/scripts/dashboard.sh
   ```

## How is this different?

| Feature | Agent Memento | AutoGPT / CrewAI | Cursor / Copilot | Devin |
|---|---|---|---|---|
| Memory model | Stateless ticks | In-memory loop | Session context | Persistent agent |
| Fails at scale? | No (by design) | Yes (OOM/drift) | Yes (context limit) | Unclear |
| Verification | Mandatory per task | Optional | None | Internal |
| Human oversight | Async dashboard | Real-time babysitting | Inline | Web UI |
| Runs overnight? | ✅ | ❌ | ❌ | ✅ |
| Fully local? | ✅ | ❌ | ❌ | ❌ |

## Philosophy

> "The best AI system is one that assumes it will forget everything, and builds the world around that assumption."

Agent Memento doesn't make AI smarter. It makes AI *reliable* — by giving it a notebook it can't lose, a checklist it must follow, and a reset switch every 5 minutes.

## Documentation
- See [SKILL.md](./SKILL.md) for full technical architecture and execution rules.
- Contains Node/Express based real-time monitoring WebUI hooks (`/dashboard`).

