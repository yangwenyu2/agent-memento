<div align="center">

<img src="./assets/banner.png" alt="Agent Memento Banner" width="100%">

# 🧠 Agent Memento

**Tick-Driven Autonomous Production Factory for LLMs**

*“Don't build AI that tries to remember everything. Build systems that make AI read the blueprint anew every 5 minutes.”*

[![OpenClaw Skill](https://img.shields.io/badge/OpenClaw-Skill-blue.svg)](https://github.com/openclaw/openclaw)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

[English](./README.md) | [简体中文](./README_zh.md)

</div>

---

## ⚡ The "Aha!" Problem: Chat Windows Can't Build Aircraft Carriers

You ask an AI Agent to build a massive project. The first 10 minutes are magic. But by line 2,000, the magic rots into a nightmare:
- **Context Amnesia:** The AI forgets the architecture it designed an hour ago and hallucinates non-existent APIs.
- **The "LGTM" Delusion:** The AI confidently tells you "I fixed the bug," but the code doesn't even compile.
- **The OOM Nuke:** To fix a typo in a 3,000-line file, the AI tries to rewrite the *entire file* in one message, blowing up the context window, causing Out-Of-Memory (OOM) crashes, and taking down your entire gateway.

**Continuous chatbots are engineering poison for long-term generation.**

## 💡 The Solution: Memento Execution 

Inspired by the movie *Memento*, we destroy the omniscient, memory-heavy persistent Agent.
We replace it with an army of **ruthless, amnesiac, short-lived Tick Workers** that live only to read a physical blueprint, hammer exactly one nail, verify it, and die.

### ⚙️ How Memento Works (The Dual-Mode Intelligence)
1. 📂 **The Externalized Brain (`MASTER_PLAN.md`)**: The Agent’s memory isn’t the chat history—it’s a physical Markdown file. The project is hierarchically decomposed. The state is tangible.
2. 🏛️ **The Architect (You + Chat AI)**: In a normal session, you design the macro-architecture, pivot strategies, and write the checklists into the `MASTER_PLAN`.
3. 🔨 **The Tick Worker (Cron / Watchdog)**: Every 5 minutes, a background script wakes up a fresh, context-free Agent. 
   - It reads the `MASTER_PLAN`.
   - It scans top-to-bottom for the VERY FIRST unchecked `[ ]` task.
   - It focuses 100% of its compute on that *single* micro-task.
   - **Crucial Rule (Anti-OOM):** It uses surgical edits (like `sed` or AST tools) instead of rewriting entire files.
   - **Ironclad Proof (Anti-Hallucination):** It executes physical tests (e.g., `npm test`, `curl`, `puppeteer`). If it doesn't get a strict `Exit 0`, it is **forbidden** from checking off the `[x]`.
   - It goes back to sleep.

### 🕹️ Observable Steering (Zero-Prompt Intervention)
Tired of yelling at your AI in the chat, *"No! You wrote it wrong again!"*? 
With Agent Memento, you steer the entire autonomous process simply by editing the text file. Want to pivot the app's entire UI? Just silently change the checkboxes in `MASTER_PLAN.md`. The next Tick Worker will instantly adapt to the new reality like a river changing course.

---

## 🚀 Quick Start (One-Line Scaffold)

Instantly tear down the Chatbot paradigm and spin up an autonomous Memento factory for your next huge repo inside OpenClaw:

```bash
cd ~/.openclaw/workspace
bash skills/agent-memento/scripts/init_memento.sh MyHugeProject
```

This automagically injects:
1. `projects/MyHugeProject/docs/MASTER_PLAN.md` (Your physical canvas for global architecture).
2. `TICK_STATUS.md` (The asynchronous Black Box where dying Workers report their blockers).
3. A **ready-to-deploy background worker script** at `scripts/MyHugeProject_tick.sh` loaded with the draconian anti-hallucination system prompts.

Write out your plan in `MASTER_PLAN.md`, then unleash the cron:
```bash
# Add to crontab
*/5 * * * * bash /root/.openclaw/workspace/scripts/MyHugeProject_tick.sh
```

**Wake up to a finished project, built brick by verified brick.**

---

## 🛠 Prerequisites
- OpenClaw CLI properly installed.
- (Optional but Recommended) A testing harness (Jest, PyTest, etc.) so the worker can strictly adhere to the Evidence-based standard.

## 📜 License
MIT License.
