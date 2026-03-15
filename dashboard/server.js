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
    
    
    const tmpOut = path.join(require('os').tmpdir(), 'arch_out_' + Date.now() + '.json');
    const cmdFiles = path.join(require('os').tmpdir(), 'arch_prompt_' + Date.now() + '.txt');
    fs.writeFileSync(cmdFiles, prompt);
    
    // Run it, and write all stdout to tmpOut
    const cmd = `openclaw agent --local --json --session-id "${sessionName}" -m "\$(cat ${cmdFiles})" > ${tmpOut} 2>&1`;

    exec(cmd, { timeout: 120000, env }, (error, stdout, stderr) => {
        try {
            const d = fs.readFileSync(tmpOut, 'utf8');
            let p = null;

            // Simple robust regex: look for "payloads": [ { "text": "..." } ]
            const m = d.match(/"text"\s*:\s*"((?:[^"\\]|\\.)*)"/);
            if (m) {
                // unescape it
                const unescaped = JSON.parse('"' + m[1] + '"');
                p = { payloads: [{ text: unescaped }] };
            } else {
                throw new Error('Could not find text payload via regex.');
            } 
            
            // cleanup
            fs.unlinkSync(tmpOut);
            fs.unlinkSync(cmdFiles);

            res.json({ reply: p.payloads[0].text, color: '#8ad7ff' });
        } catch (e) {
            console.error("Parse Error:", e.message);
            // let's try to grab whatever raw text from the error
            let rawLines = [];
            try { rawLines = fs.readFileSync(tmpOut, 'utf8').split('\n').slice(-10); } catch(x){}
            res.json({ reply: '【系统桥接失败】\n' + rawLines.join('\n').substring(0,200), color: '#ff8a8a' });
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
