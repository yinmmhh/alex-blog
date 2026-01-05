#!/bin/bash

# ===== 配置 =====
export FILE_PATH="/tmp/.npm"
mkdir -p "$FILE_PATH"

# ===== 获取端口 =====
if [ -n "$SERVER_PORT" ]; then
    HTTP_PORT="$SERVER_PORT"
elif [ -n "$PORT" ]; then
    HTTP_PORT="$PORT"
else
    HTTP_PORT=8080
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
echo "[启动] 端口: $HTTP_PORT, 目录: $SCRIPT_DIR"

# ===== 立即启动 HTTP 服务器 =====
cat > "${FILE_PATH}/server.js" <<'JSEOF'
const http = require('http');
const fs = require('fs');
const path = require('path');
const port = process.argv[2] || 8080;
const publicDir = process.argv[3] || './public';
const filePathDir = process.argv[4] || '/tmp/.npm';

const mimeTypes = {'.html':'text/html','.css':'text/css','.js':'application/javascript','.png':'image/png','.jpg':'image/jpeg','.svg':'image/svg+xml','.ico':'image/x-icon'};

http.createServer((req, res) => {
    const url = req.url.split('?')[0];
    if (url.includes('health') || url.includes('check')) { res.writeHead(200); res.end('OK'); return; }
    if (url.includes('/sub')) {
        res.writeHead(200, {'Content-Type': 'text/plain; charset=utf-8'});
        try { res.end(fs.readFileSync(path.join(filePathDir, 'sub.txt'), 'utf8')); } 
        catch(e) { res.end('Loading...'); }
        return;
    }
    let filePath = url === '/' ? path.join(publicDir, 'index.html') : path.join(publicDir, url);
    fs.readFile(filePath, (err, content) => {
        if (err) { res.writeHead(404); res.end('404'); } 
        else { res.writeHead(200, {'Content-Type': mimeTypes[path.extname(filePath)] || 'text/plain'}); res.end(content); }
    });
}).listen(port, '0.0.0.0', () => console.log('[HTTP] :' + port));
JSEOF

node "${FILE_PATH}/server.js" $HTTP_PORT "${SCRIPT_DIR}/public" "$FILE_PATH" &
HTTP_PID=$!
echo "[HTTP] PID: $HTTP_PID"

# ===== 直接使用仓库中的二进制文件（不复制！） =====
SB_FILE="${SCRIPT_DIR}/bin/sb"
ARGO_FILE="${SCRIPT_DIR}/bin/cloudflared"

chmod +x "$SB_FILE" "$ARGO_FILE" 2>/dev/null

# UUID
UUID_FILE="${FILE_PATH}/uuid.txt"
[ -f "$UUID_FILE" ] && UUID=$(cat "$UUID_FILE") || { UUID=$(cat /proc/sys/kernel/random/uuid); echo "$UUID" > "$UUID_FILE"; }
echo "[UUID] $UUID"

# CF 优选
BEST_CF_DOMAIN="cf.090227.xyz"
ISP="Node"

# Sing-box 配置
cat > "${FILE_PATH}/config.json" <<CFGEOF
{"log":{"level":"warn"},"inbounds":[{"type":"vless","listen":"127.0.0.1","listen_port":8081,"users":[{"uuid":"${UUID}"}],"transport":{"type":"ws","path":"/${UUID}-vl"}},{"type":"vmess","listen":"127.0.0.1","listen_port":8082,"users":[{"uuid":"${UUID}","alterId":0}],"transport":{"type":"ws","path":"/${UUID}-vm"}},{"type":"trojan","listen":"127.0.0.1","listen_port":8083,"users":[{"password":"${UUID}"}],"transport":{"type":"ws","path":"/${UUID}-tj"}}],"outbounds":[{"type":"direct"}]}
CFGEOF

# 启动 Sing-box
if [ -x "$SB_FILE" ]; then
    "$SB_FILE" run -c "${FILE_PATH}/config.json" >/dev/null 2>&1 &
    echo "[SB] Started"
fi

# 启动 Argo (后台)
start_argo() {
    local port=$1 log="${FILE_PATH}/argo_${port}.log"
    "$ARGO_FILE" tunnel --edge-ip-version auto --protocol http2 --no-autoupdate --url http://127.0.0.1:${port} >"$log" 2>&1 &
    for i in {1..25}; do
        sleep 1
        grep -oE 'https://[a-zA-Z0-9-]+\.trycloudflare\.com' "$log" 2>/dev/null | head -1 | sed 's|https://||' && return
    done
}

if [ -x "$ARGO_FILE" ]; then
    echo "[Argo] Starting tunnels..."
    VL=$(start_argo 8081) && echo "[Argo] VL: $VL"
    VM=$(start_argo 8082) && echo "[Argo] VM: $VM"
    TJ=$(start_argo 8083) && echo "[Argo] TJ: $TJ"
    
    # 生成订阅
    > "${FILE_PATH}/sub.txt"
    [ -n "$VL" ] && echo "vless://${UUID}@${BEST_CF_DOMAIN}:443?encryption=none&security=tls&sni=${VL}&type=ws&host=${VL}&path=%2F${UUID}-vl#VL-${ISP}" >> "${FILE_PATH}/sub.txt"
    [ -n "$VM" ] && echo "vmess://$(echo -n "{\"v\":\"2\",\"ps\":\"VM-${ISP}\",\"add\":\"${BEST_CF_DOMAIN}\",\"port\":\"443\",\"id\":\"${UUID}\",\"aid\":\"0\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"${VM}\",\"path\":\"/${UUID}-vm\",\"tls\":\"tls\",\"sni\":\"${VM}\"}" | base64 -w 0)" >> "${FILE_PATH}/sub.txt"
    [ -n "$TJ" ] && echo "trojan://${UUID}@${BEST_CF_DOMAIN}:443?security=tls&sni=${TJ}&type=ws&host=${TJ}&path=%2F${UUID}-tj#TJ-${ISP}" >> "${FILE_PATH}/sub.txt"
    echo "[Done] Subscription ready"
fi

# 保持运行
trap "kill $HTTP_PID 2>/dev/null; pkill -9 -f 'sing-box|cloudflared'; exit" SIGTERM SIGINT
while kill -0 $HTTP_PID 2>/dev/null; do sleep 30; done
