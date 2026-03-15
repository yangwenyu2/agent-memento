const express = require('express');
const cors = require('cors');
const chokidar = require('chokidar');
const path = require('path');
const fs = require('fs');
const { WebSocketServer } = require('ws');
const { exec } = require('child_process');
const minimist = require('minimist');

const argv = minimist(process.argv.slice(2));
const PROJECT_DIR = argv['project-dir'] ? path.resolve(argv['project-dir']) : path.resolve('../projects/demo');
const PORT = argv['port'] || 3777;

const app = express();
app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// File paths
const PLAN_PATH = path.join(PROJECT_DIR, 'docs', 'MASTER_PLAN.md');
const STATUS_PATH = path.join(PROJECT_DIR, 'docs', 'TICK_STATUS.md');
const NOTES_PATH = path.join(PROJECT_DIR, 'docs', 'HUMAN_NOTES.md');
const MAP_PATH = path.join(PROJECT_DIR, 'docs', 'PROJECT_MAP.md');
const LOGS_DIR = path.join(PROJECT_DIR, 'logs');

// Ensure files exist
const ensureFiles = () => {
    [PLAN_PATH, STATUS_PATH, NOTES_PATH, MAP_PATH].forEach(f => {
        if (!fs.existsSync(f)) {
            fs.mkdirSync(path.dirname(f), { recursive: true });
            fs.writeFileSync(f, '');
        }
    });
};
ensureFiles();

// REST API
app.get('/api/plan', (req, res) => {
    res.json({ content: fs.readFileSync(PLAN_PATH, 'utf-8') });
});
app.get('/api/status', (req, res) => {
    res.json({ content: fs.readFileSync(STATUS_PATH, 'utf-8') });
});
app.get('/api/notes', (req, res) => {
    res.json({ content: fs.readFileSync(NOTES_PATH, 'utf-8') });
});
app.get('/api/map', (req, res) => {
    res.json({ content: fs.readFileSync(MAP_PATH, 'utf-8') });
});

// Update Tick Mode
app.post('/api/plan/control', (req, res) => {
    const { mode } = req.body;
    let content = fs.readFileSync(PLAN_PATH, 'utf-8');
    content = content.replace(/tick_mode:\s*\w+/, `tick_mode: ${mode}`);
    fs.writeFileSync(PLAN_PATH, content);
    res.json({ success: true, mode });
});

// Add Note
app.post('/api/notes', (req, res) => {
    const { target, text } = req.body;
    const now = new Date().toISOString().replace('Z', '');
    const entry = `\n### [NOTE] ${now} → ${target}\n${text}\n`;
    
    let content = fs.readFileSync(NOTES_PATH, 'utf-8');
    if (content.includes('## Active Notes')) {
        content = content.replace('## Active Notes', `## Active Notes\n${entry}`);
    } else {
        content += entry;
    }
    fs.writeFileSync(NOTES_PATH, content);
    res.json({ success: true });
});

// Chat to LLM via OpenClaw
app.post('/api/chat', (req, res) => {
    const message = req.body.message || '';
    if (!message) return res.status(400).json({ error: 'empty message' });

    // Escape message for bash
    const escapedMessage = JSON.stringify(message);
    const sessionName = `memento-dashboard-${path.basename(PROJECT_DIR)}`;
    
    // Command to invoke OpenClaw
    const cmd = `bash -lc "openclaw agent --local --json --session-id ${sessionName} -m ${escapedMessage} 2>/dev/null | sed -n '/^{/,$p'"`;
    
    exec(cmd, { timeout: 120000 }, (error, stdout, stderr) => {
        if (error) {
            console.error("OpenClaw error:", error);
            return res.json({ reply: `【错误】无法唤醒模型：${error.message}`, color: '#ff8a8a' });
        }
        
        try {
            const payload = JSON.parse(stdout.trim() || '{}');
            const texts = payload.payloads || [];
            let reply = texts[0]?.text || '【系统】模型已执行，但无文本输出。';
            res.json({ reply, color: '#8ad7ff' });
        } catch (e) {
            console.error("Parse JSON error:", e, stdout);
            res.json({ reply: '【系统】解析模型回传数据失败。', color: '#ff8a8a' });
        }
    });
});

// Create Server & WSS
const server = app.listen(PORT, '0.0.0.0', () => {
    console.log(`🧠 Agent Memento Dashboard running at http://0.0.0.0:${PORT}`);
    console.log(`📁 Watching project directory: ${PROJECT_DIR}`);
});

const wss = new WebSocketServer({ server, path: '/ws/events' });

wss.on('connection', (ws) => {
    ws.send(JSON.stringify({ type: 'connected' }));
});

const broadcast = (data) => {
    wss.clients.forEach(client => {
        if (client.readyState === 1) { // OPEN
            client.send(JSON.stringify(data));
        }
    });
};

// Watch file changes
const watcher = chokidar.watch([PLAN_PATH, STATUS_PATH, NOTES_PATH, MAP_PATH], {
    persistent: true,
    ignoreInitial: true,
    awaitWriteFinish: { stabilityThreshold: 500, pollInterval: 100 }
});

watcher.on('change', (filePath) => {
    const basename = path.basename(filePath);
    let type = 'unknown';
    if (basename === 'MASTER_PLAN.md') type = 'plan_updated';
    else if (basename === 'TICK_STATUS.md') type = 'status_updated';
    else if (basename === 'HUMAN_NOTES.md') type = 'notes_updated';
    else if (basename === 'PROJECT_MAP.md') type = 'map_updated';

    broadcast({ type, file: basename });
});
