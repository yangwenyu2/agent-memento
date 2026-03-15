#!/bin/bash
cd /root/.openclaw/workspace/skills/agent-memento/dashboard
npm install
nohup node server.js > dashboard.log 2>&1 &
echo $! > dashboard.pid
echo "Dashboard started on port 3777 with PID $(cat dashboard.pid)"
