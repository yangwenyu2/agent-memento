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
- clean_strategy: git-clean <!-- git-clean | snapshot | docker -->
- clean_ignore: .memento_cleanignore

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
  --system-prompt "You are a Memento Tick Worker. Follow the Tick Worker discipline strictly. Exit code 0 is mandatory for [x]. Use precision tools. Only write to TICK_STATUS.md, never rewrite MASTER_PLAN.md structure." \
  --prompt "Read \$PLAN, locate the first executable task following the phase dependence and task retries logic, complete it, and update the tick status in \$STATUS. Then perform the Verify step and act strictly based on the exit code. If failed, rollback using git checkout and increment retries in the plan." \
  --context-files "\$PLAN" "\$PROJECT_DIR/docs/PROJECT_MAP.md" "\$PROJECT_DIR/docs/HUMAN_NOTES.md" \
  2>&1 | tee -a "\$TICK_LOG"

release_lock

# 后处理：防爆与三阶段清理
cd "\$PROJECT_DIR"
if [[ -n \$(git status --porcelain) ]]; then
  echo "[\$TIMESTAMP] WARNING: Uncommitted changes detected after tick. Auto-cleaning (Phase 1 & 2)." >> "\$STATUS"
  git checkout -- .
  git clean -fd --exclude-from=.memento_cleanignore || true
fi

if [[ -n \$(git status --porcelain) ]]; then
  echo "[\$TIMESTAMP] CRITICAL: Workspace still dirty after cleanup. Emergency Stash (Phase 3)." >> "\$STATUS"
  git stash --include-untracked -m "memento-emergency-stash-\$TIMESTAMP" || true
fi
ENGINE

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
