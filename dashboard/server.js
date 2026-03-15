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

// Mount the actual user project directory as a static preview path
app.use('/preview', express.static(PROJECT_DIR));


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

    const sessionName = `memento-dashboard-${path.basename(PROJECT_DIR)}`;
    
    // Instead of passing everything via a fragile bash command line string, we rely on the JS process.env
    const planData = fs.existsSync(PLAN_PATH) ? fs.readFileSync(PLAN_PATH, 'utf-8') : '';
    
    const prompt = `You are the Architect of a Memento autonomous project. You reside in the Dashboard. The user is talking to you to steer the project. Here is the current MASTER_PLAN.md state:\n\n${planData}\n\nUser Command: ${message}`;
    
    const env = { ...process.env, ARCHITECT_PROMPT: prompt };
    
    
    const cmdFiles = path.join(require('os').tmpdir(), 'arch_prompt_' + Date.now() + '.txt');
    fs.writeFileSync(cmdFiles, prompt);
    const cmd = `openclaw agent --local --json --session-id "${sessionName}" -m "$(cat ${cmdFiles})" 2>/dev/null || echo '{"payloads":[{"text":"Bridge Error"}]}'`;

    
    exec(cmd, { timeout: 120000, env }, (error, stdout, stderr) => {
        if (error) {
            console.error("OpenClaw error:", error);
            // sometimes it throws error but still outputs stdout
            if (!stdout.trim()) {
                return res.json({ reply: `【系统异常】执行桥接通信失败：${error.message}`, color: '#ff8a8a' });
            }
        }
        
        try {
            // Because plugins dump arbitrary un-capturable garbage to stdout even in JSON mode,
            // we will find ALL substring blocks that look like JSON and try to parse them until we find payloads.
            let reply = '【系统】模型执行完毕，但是没有收到有效的回应。';

            // Find anything that starts with { and ends with }
            const jsonMatches = stdout.match(/\{[\s\S]*?\}/g) || [];
            
            // Iterate from the back (usually the answer is at the end)
            for (let i = jsonMatches.length - 1; i >= 0; i--) {
                try {
                    const parsed = JSON.parse(jsonMatches[i]);
                    // Check if it's the actual agent response payload
                    if (parsed.payloads && Array.isArray(parsed.payloads) && parsed.payloads.length > 0) {
                        reply = parsed.payloads[0].text || reply;
                        break;
                    }
                } catch(e) {
                    // Not valid JSON, continue
                }
            }

            // Fallback: If we still didn't find "payloads", try to just rip out the string around the usual structure
            if (reply.includes('但是没有收到有效的回应') && stdout.includes('"text":')) {
                const textMatch = stdout.match(/"text"\s*:\s*"([^"\\]*(?:\\.[^"\\]*)*)"/);
                if (textMatch) {
                    reply = JSON.parse('"' + textMatch[1] + '"'); // unescape
                }
            }

            res.json({ reply: reply, color: '#8ad7ff' });
        } catch (e) {
            
            console.error("Parse JSON error finally:", e, "\nSTDOUT:", stdout);
            res.json({ reply: '【系统】模型回答无法解析。\n' + stdout.substring(0, 100), color: '#ff8a8a' });
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
