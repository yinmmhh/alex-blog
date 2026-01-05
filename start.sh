#!/bin/bash

FILE_PATH="/tmp/.npm"
mkdir -p "$FILE_PATH"
HTTP_PORT="${PORT:-8080}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# 1. 立即启动 HTTP 服务器
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
        catch(e) { res.end('Initializing...'); }
        return;
    }
    if (url.includes('/log')) {
        try { res.end(fs.readFileSync('/tmp/.npm/debug.log', 'utf8')); } 
        catch(e) { res.end('No log yet'); }
        return;
    }
    if (url.includes('/status')) {
        try { res.end(fs.readFileSync('/tmp/.npm/status.txt', 'utf8')); } 
        catch(e) { res.end('Starting...'); }
        return;
    }
    const file = url === '/' ? path.join(publicDir, 'index.html') : path.join(publicDir, url);
    fs.readFile(file, (err, data) => {
        res.writeHead(err ? 404 : 200);
        res.end(err ? '404' : data);
    });
}).listen(port, () => console.log('[HTTP] :' + port));
JSEOF

echo "[1] Starting HTTP..."
node "${FILE_PATH}/server.js" $HTTP_PORT "${SCRIPT_DIR}/public" &
HTTP_PID=$!
echo "[1] HTTP PID: $HTTP_PID"

# 2. 后台初始化 (不阻塞主进程)
(
    sleep 3
    LOG="${FILE_PATH}/debug.log"
    STATUS="${FILE_PATH}/status.txt"
    
    echo "Initializing..." > "$STATUS"
    echo "=== Init $(date) ===" > "$LOG"
    
    UUID=$(cat /proc/sys/kernel/random/uuid)
    echo "UUID: $UUID" >> "$LOG"
    echo "UUID: $UUID" > "$STATUS"
    
    # 复制二进制
    SB="${FILE_PATH}/sb"
    CF="${FILE_PATH}/cloudflared"
    
    echo "Copying sb..." >> "$LOG"
    echo "Copying binaries..." >> "$STATUS"
    cp "${SCRIPT_DIR}/bin/sb" "$SB" && chmod +x "$SB"
    echo "sb done" >> "$LOG"
    
    cp "${SCRIPT_DIR}/bin/cloudflared" "$CF" && chmod +x "$CF"
    echo "cf done" >> "$LOG"
    
    # sing-box 配置
    cat > "${FILE_PATH}/config.json" <<EOF
{"log":{"level":"warn"},"inbounds":[{"type":"vless","listen":"127.0.0.1","listen_port":8081,"users":[{"uuid":"$UUID"}],"transport":{"type":"ws","path":"/$UUID-vl"}}],"outbounds":[{"type":"direct"}]}
EOF
    
    # 启动 sing-box
    echo "Starting sb..." >> "$STATUS"
    "$SB" run -c "${FILE_PATH}/config.json" >> "$LOG" 2>&1 &
    sleep 2
    echo "sb started" >> "$LOG"
    
    # 启动 cloudflared
    echo "Starting argo..." >> "$STATUS"
    ARGO_LOG="${FILE_PATH}/argo.log"
    "$CF" tunnel --edge-ip-version auto --protocol http2 --no-autoupdate --url http://127.0.0.1:8081 > "$ARGO_LOG" 2>&1 &
    
    # 等待域名
    for i in {1..30}; do
        sleep 1
        DOMAIN=$(grep -oE 'https://[a-zA-Z0-9-]+\.trycloudflare\.com' "$ARGO_LOG" 2>/dev/null | head -1 | sed 's|https://||')
        if [ -n "$DOMAIN" ]; then
            echo "Domain: $DOMAIN" >> "$LOG"
            echo "vless://${UUID}@cf.090227.xyz:443?encryption=none&security=tls&sni=${DOMAIN}&type=ws&host=${DOMAIN}&path=%2F${UUID}-vl#VL" > "${FILE_PATH}/sub.txt"
            echo "Ready! $DOMAIN" > "$STATUS"
            echo "[BG] Done: $DOMAIN"
            exit 0
        fi
    done
    
    echo "Argo failed" >> "$STATUS"
    cat "$ARGO_LOG" >> "$LOG"
) &

echo "[2] Background init started"
echo "[3] Keeping HTTP alive..."

# 保持运行
while kill -0 $HTTP_PID 2>/dev/null; do
    sleep 30
done
