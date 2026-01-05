#!/bin/bash

# 配置
FILE_PATH="/tmp/.npm"
mkdir -p "$FILE_PATH"
HTTP_PORT="${PORT:-8080}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "[启动] 端口: $HTTP_PORT"

# HTTP 服务器 (立即启动)
cat > "${FILE_PATH}/server.js" <<'JSEOF'
const http = require('http');
const fs = require('fs');
const path = require('path');
const port = process.argv[2] || 8080;
const publicDir = process.argv[3] || './public';

http.createServer((req, res) => {
    const url = req.url.split('?')[0];
    if (url.includes('health')) { res.end('OK'); return; }
    if (url.includes('/sub')) {
        try { res.end(fs.readFileSync('/tmp/.npm/sub.txt', 'utf8')); } 
        catch(e) { res.end('Loading...'); }
        return;
    }
    if (url.includes('/log')) {
        try { res.end(fs.readFileSync('/tmp/.npm/debug.log', 'utf8')); } 
        catch(e) { res.end('No log'); }
        return;
    }
    const file = url === '/' ? path.join(publicDir, 'index.html') : path.join(publicDir, url);
    fs.readFile(file, (err, data) => {
        res.writeHead(err ? 404 : 200);
        res.end(err ? '404' : data);
    });
}).listen(port, () => console.log('[HTTP] :' + port));
JSEOF

node "${FILE_PATH}/server.js" $HTTP_PORT "${SCRIPT_DIR}/public" &
HTTP_PID=$!
echo "[HTTP] Started (PID: $HTTP_PID)"

# 调试日志
LOG="${FILE_PATH}/debug.log"
echo "=== Debug ===" > "$LOG"
echo "Time: $(date)" >> "$LOG"
echo "Arch: $(uname -m)" >> "$LOG"

# UUID
UUID=$(cat /proc/sys/kernel/random/uuid)
echo "[UUID] $UUID"

# 复制二进制文件到 /tmp (可写)
SB="${FILE_PATH}/sb"
CF="${FILE_PATH}/cloudflared"

if [ ! -x "$SB" ]; then
    echo "[复制] sb -> /tmp"
    cp "${SCRIPT_DIR}/bin/sb" "$SB" 2>> "$LOG"
    chmod +x "$SB" 2>> "$LOG"
fi

if [ ! -x "$CF" ]; then
    echo "[复制] cloudflared -> /tmp"
    cp "${SCRIPT_DIR}/bin/cloudflared" "$CF" 2>> "$LOG"
    chmod +x "$CF" 2>> "$LOG"
fi

echo "SB: $(ls -la $SB 2>&1)" >> "$LOG"
echo "CF: $(ls -la $CF 2>&1)" >> "$LOG"

# sing-box 配置
cat > "${FILE_PATH}/config.json" <<EOF
{"log":{"level":"warn"},"inbounds":[{"type":"vless","listen":"127.0.0.1","listen_port":8081,"users":[{"uuid":"$UUID"}],"transport":{"type":"ws","path":"/$UUID-vl"}}],"outbounds":[{"type":"direct"}]}
EOF

# 启动 sing-box
echo "[SB] Starting..."
"$SB" run -c "${FILE_PATH}/config.json" >> "$LOG" 2>&1 &
SB_PID=$!
sleep 2

if kill -0 $SB_PID 2>/dev/null; then
    echo "[SB] Running (PID: $SB_PID)"
else
    echo "[SB] Failed!"
    echo "SB failed to start!" >> "$LOG"
fi

# 启动 cloudflared
ARGO_LOG="${FILE_PATH}/argo.log"
echo "[Argo] Starting..."

"$CF" tunnel --edge-ip-version auto --protocol http2 --no-autoupdate --url http://127.0.0.1:8081 > "$ARGO_LOG" 2>&1 &
CF_PID=$!

# 等待域名
for i in {1..30}; do
    sleep 1
    
    if ! kill -0 $CF_PID 2>/dev/null; then
        echo "[Argo] Died at $i"
        cat "$ARGO_LOG" >> "$LOG"
        break
    fi
    
    DOMAIN=$(grep -oE 'https://[a-zA-Z0-9-]+\.trycloudflare\.com' "$ARGO_LOG" 2>/dev/null | head -1 | sed 's|https://||')
    if [ -n "$DOMAIN" ]; then
        echo "[Argo] $DOMAIN"
        echo "vless://${UUID}@cf.090227.xyz:443?encryption=none&security=tls&sni=${DOMAIN}&type=ws&host=${DOMAIN}&path=%2F${UUID}-vl#VL" > "${FILE_PATH}/sub.txt"
        echo "[OK] Done!"
        break
    fi
done

[ -z "$DOMAIN" ] && { echo "No domain" >> "$LOG"; cat "$ARGO_LOG" >> "$LOG"; }

# 保持运行
echo "[Main] Keeping alive..."
while kill -0 $HTTP_PID 2>/dev/null; do sleep 30; done
