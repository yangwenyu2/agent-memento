#!/usr/bin/env bash
# script to initialize a new Tick-Driven Project (Agent Memento v0.2)
set -euo pipefail

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <ProjectName>"
    exit 1
fi

PROJECT_NAME=$1
PROJECT_DIR="$(pwd)/projects/$PROJECT_NAME"

echo "🚀 Initializing Agent Memento Framework (v0.2) for: $PROJECT_NAME"

# Create project scaffolding
mkdir -p "$PROJECT_DIR"/{docs,src,tests,logs,scripts}

# Generate MASTER_PLAN.md template
cat << 'PLAN' > "$PROJECT_DIR/docs/MASTER_PLAN.md"
# MASTER_PLAN: $PROJECT_NAME

## Meta
- created: $(date +%Y-%m-%d)
- tick_mode: auto          <!-- auto | paused | stopped -->
- max_retries: 3           <!-- 单任务最大重试次数 -->
- max_tasks_per_tick: 1    <!-- 快任务时允许单 Tick 连续处理上限 -->
- max_diff_lines: 200      <!-- diff size guard 阈值 -->
- stale_lock_timeout: 15min <!-- [~] 僵尸锁重置阈值 -->
- circuit_breaker_threshold: 5 <!-- 连续失败多少次触发熔断 -->
- clean_strategy: git-clean <!-- git-clean | snapshot | docker -->
- clean_ignore: .memento_cleanignore
- status_max_entries: 50    <!-- TICK_STATUS.md 最大条目数，超出自动归档 -->
- status_archive_dir: logs/status_archive/
- total_ticks: 0           <!-- 自动递增的 Tick 计数器 -->
- total_tasks: 0           <!-- 自动维护 -->
- completed_tasks: 0       <!-- 自动维护 -->

---

## Phase 1: Foundation
<!-- parallel: false -->
<!-- depends: none -->

- [ ] `T-101` [MODULE:init] Setup initial file structure
  - verify: `ls package.json || ls requirements.txt && echo PASS`
  - context_files: []
  - guard_files: []
  - estimate: 5min
  - retries: 0

- [ ] `T-102` [MODULE:test] Establish unit test baseline
  - verify: `npm test || pytest || echo "Skipped" && echo PASS`
  - context_files: []
  - guard_files: []
  - estimate: 5min
  - retries: 0

PLAN

# Generate PROJECT_MAP.md
cat << 'MAP' > "$PROJECT_DIR/docs/PROJECT_MAP.md"
# PROJECT MAP: $PROJECT_NAME

> Worker 的 GPS。不读全部源码，先读地图，再按 `context_files` 精准加载。

## Architecture Overview
(Describe the high level architecture here)

## Module Registry
### [MODULE:init]
- Purpose: Project initialization files

## File Tree (auto-maintained)
src/
tests/
MAP

# Generate TICK_STATUS.md
cat << 'STATUS' > "$PROJECT_DIR/docs/TICK_STATUS.md"
# TICK STATUS LOG

STATUS

# Generate HUMAN_NOTES.md
cat << 'NOTES' > "$PROJECT_DIR/docs/HUMAN_NOTES.md"
# HUMAN NOTES

<!-- Add notes here for the Architect or the Tick Worker -->

## Active Notes

## Archive
NOTES

# Generate .memento_cleanignore
cat << 'IGNORE' > "$PROJECT_DIR/.memento_cleanignore"
node_modules/
.env
.env.local
*.sqlite
vendor/
__pycache__/
IGNORE

# Generate TICK_WORKER System Prompt
cat << 'PROMPT' > "$PROJECT_DIR/scripts/tick_worker_system_prompt.md"
# TICK WORKER PROTOCOL (MEMENTO v0.2)
You are a Memento Tick Worker—a short-lived, emotionless autonomous shell script designed to execute exactly ONE precise task from MASTER_PLAN.md before terminating.

## Your Identity & Architecture
- You wake up, read `MASTER_PLAN.md`, `PROJECT_MAP.md`, and `HUMAN_NOTES.md`.
- You identify the FIRST pending `[ ]` task respecting phase dependencies and retry limits.
- You perform surgical, robust node/python script edits.
- You MUST run the `verify` command physically.
- You must NOT say "[x] done" without an Exit Code 0 from the verify command.

## The Iron Discipline (Strict)
1. **Surgical Edits Only**: No massive file rewrites.
2. **Evidence-based Audit**: Do not hallucinate success. No Exit 0 = FAILED.
3. **No Silent Ghosting**: Record failures and traceback logs into `TICK_STATUS.md`.
4. **Boundary Adherence**: ONLY edit files listed in `context_files`. DO NOT touch `guard_files`. NEVER alter the internal structure of `MASTER_PLAN.md` (only update task checkboxes and `retries`).
5. **Output Contracts**: When a task completes, document ANY newly exported interfaces or architectural decisions under an "- **Outputs**:" bullet in `TICK_STATUS.md`.
PROMPT

# Generate Dashboard script
cat << DASHBOARD > "$PROJECT_DIR/scripts/dashboard.sh"
#!/usr/bin/env bash
cd "\$(dirname "\$0")/../dashboard"
npm start -- --project-dir "\$(dirname "\$0")/.." --port 3777
DASHBOARD

chmod +x "$PROJECT_DIR/scripts/dashboard.sh"

# Generate Tick Worker script
ENGINE_SCRIPT="$PROJECT_DIR/scripts/memento_tick.sh"
cat << ENGINE > "$ENGINE_SCRIPT"
#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="\$(cd "\$(dirname "\$0")/.." && pwd)"
PLAN="\$PROJECT_DIR/docs/MASTER_PLAN.md"
STATUS="\$PROJECT_DIR/docs/TICK_STATUS.md"
LOG_DIR="\$PROJECT_DIR/logs"
TIMESTAMP=\$(date +%Y-%m-%dT%H:%M:%S)
TICK_LOG="\$LOG_DIR/tick_\${TIMESTAMP}.log"
LOCK_FILE="\$PROJECT_DIR/.memento.lock"
LOCK_FD=200

acquire_lock() {
 exec \$LOCK_FD>"\$LOCK_FILE"
 if ! flock -n \$LOCK_FD; then
 echo "[\$TIMESTAMP] Tick skipped: another worker running" >> "\$STATUS"
 exit 0
 fi
}

release_lock() {
 flock -u \$LOCK_FD
}

# 检查 tick_mode
TICK_MODE=\$(grep -oP 'tick_mode:\s*\K\w+' "\$PLAN" || echo "stopped")
if [[ "\$TICK_MODE" != "auto" ]]; then
  echo "[\$TIMESTAMP] Tick skipped: mode=\$TICK_MODE" >> "\$STATUS"
  exit 0
fi

echo "[\$TIMESTAMP] Waking up tick worker for \$PROJECT_DIR..." >> "\$TICK_LOG"

acquire_lock

# Call the LLM
openclaw agent --local --json --session-id "memento-\$(basename "\$PROJECT_DIR")" \
  --system-prompt-file "$PROJECT_DIR/scripts/tick_worker_system_prompt.md" \
  --prompt "Read $PLAN, locate the first executable task following the phase dependence and task retries logic, complete it, and update the tick status in $STATUS. Then perform the Verify step and act strictly based on the exit code. If failed, rollback using git checkout and increment retries in the plan." \
  --context-files "$PLAN" "$PROJECT_DIR/docs/PROJECT_MAP.md" "$PROJECT_DIR/docs/HUMAN_NOTES.md" \
  2>&1 | tee -a "\$TICK_LOG"

release_lock

# 后处理：三阶段防爆清理
cd "\$PROJECT_DIR"
if [[ -n \$(git status --porcelain) ]]; then
  echo "[\$TIMESTAMP] WARNING: Dirty workspace detected. Running 3-phase cleanup." >> "\$STATUS"

  # Phase 1: 恢复已追踪文件
  git checkout -- .

  # Phase 2: 清理未追踪文件（排除保护列表）
  if [[ -f ".memento_cleanignore" ]]; then
    git clean -fd --exclude-from=.memento_cleanignore
  else
    git clean -fd
  fi

  # Phase 3: 兜底——如果还是脏的，紧急 stash
  if [[ -n \$(git status --porcelain) ]]; then
    git stash --include-untracked -m "memento-emergency-stash-\$TIMESTAMP"
    echo "[\$TIMESTAMP] CRITICAL: Emergency stash created. Manual inspection required." >> "\$STATUS"
  fi
fi

# 日志轮转
MAX_ENTRIES=\$(grep -oP 'status_max_entries:\s*\K\d+' "\$PLAN" || echo "50")
CURRENT_ENTRIES=\$(grep -c '^\## \[' "\$STATUS" || true)
if [[ \$CURRENT_ENTRIES -gt \$MAX_ENTRIES ]]; then
  ARCHIVE_DIR="\$PROJECT_DIR/logs/status_archive"
  mkdir -p "\$ARCHIVE_DIR"
  mv "\$STATUS" "\$ARCHIVE_DIR/TICK_STATUS_\$(date +%Y%m%d_%H%M%S).md"
  echo "# TICK STATUS LOG" > "\$STATUS"
  echo "" >> "\$STATUS"
  echo "<!-- Rotated at \$TIMESTAMP. Previous entries archived. -->" >> "\$STATUS"
fi

# 告警检测
BLOCKED_COUNT=\$(grep -c '\[!\]' "\$PLAN" || true)
CIRCUIT_BROKEN=\$(grep -c 'CIRCUIT BREAKER' "\$STATUS" || true)

if [[ \$BLOCKED_COUNT -gt 0 || \$CIRCUIT_BROKEN -gt 0 ]]; then
  cat > "\$PROJECT_DIR/.memento_alert" << EOF_INNER
timestamp: \$TIMESTAMP
blocked_tasks: \$BLOCKED_COUNT
circuit_breaker: \$([[ \$CIRCUIT_BROKEN -gt 0 ]] && echo "TRIGGERED" || echo "OK")
message: Pipeline needs attention. \$BLOCKED_COUNT task(s) blocked.
EOF_INNER
fi

# 如果一切正常且之前有告警，清除告警
if [[ \$BLOCKED_COUNT -eq 0 && \$CIRCUIT_BROKEN -eq 0 && -f "\$PROJECT_DIR/.memento_alert" ]]; then
  rm -f "\$PROJECT_DIR/.memento_alert"
fi
ENGINE

# 轮转/归档 TICK_STATUS.md
ENTRY_COUNT=$(grep -c "^## \[" "\$STATUS" || true)
if [ "\$ENTRY_COUNT" -gt 50 ]; then
  ARCHIVE_FILE="\$LOG_DIR/tick_status_archive_\$(date +%Y-%m-%d).md"
  mkdir -p "\$LOG_DIR"
  echo "--- Archived at \$TIMESTAMP ---" >> "\$ARCHIVE_FILE"
  cat "\$STATUS" >> "\$ARCHIVE_FILE"
  echo "# TICK STATUS LOG" > "\$STATUS"
  echo "[\$TIMESTAMP] TICK_STATUS.md rolled over to \$ARCHIVE_FILE." >> "\$STATUS"
fi

# 唤醒 Architect 巡检告警机制
BLOCKED_COUNT=$(grep -c '\[!\]' "\$PLAN" || true)
if [ "\$BLOCKED_COUNT" -gt 0 ]; then
  echo "\$TIMESTAMP: ARCHITECT_NEEDED — blocked=\$BLOCKED_COUNT" > "\$PROJECT_DIR/.memento_alert"
fi

# 增加总 Tick 数
sed -i 's/total_ticks: [0-9]*/total_ticks: '$((\$(grep -oP 'total_ticks: \K[0-9]+' "\$PLAN" || echo 0) + 1))'/' "\$PLAN"

chmod +x "$ENGINE_SCRIPT"

# Initialize git repository
cd "$PROJECT_DIR"
if [ ! -d .git ]; then
    git init
    # Add openclaw specific ignores if needed
    cat << 'GITIGNORE' > .gitignore
logs/
.memento.lock
node_modules/
__pycache__/
.env
GITIGNORE
    git add .
    git commit -m "chore: memento framework init"
fi

echo "✅ Project '$PROJECT_NAME' scaffolded successfully at $PROJECT_DIR."
echo "✅ Engineering plan injected: $PROJECT_DIR/docs/MASTER_PLAN.md"
echo "✅ Tick Engine erected at: $ENGINE_SCRIPT"
echo "💡 To begin autonomous execution, run or hook cron to: $ENGINE_SCRIPT"
