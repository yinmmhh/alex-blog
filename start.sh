#!/bin/bash
set -e

# === 用户配置 ===
TK=""
MD="h"

# === 核心逻辑 ===
D="${PWD}/.n"
W="${PWD}/public"
mkdir -p "$D"
rm -rf "$D"/* 2>/dev/null

E() { echo "$1" | base64 -d; }

# === 网络工具函数 ===

GT() {
    node -e 'fetch(process.argv[1],{signal:AbortSignal.timeout(5000)}).then(r=>r.text()).then(t=>console.log(t.trim())).catch(e=>console.log(""))' "$1"
}

DL() {
    url="$1"
    out="$2"
    echo "Downloading $out..."
    node -e 'const fs=require("fs");fetch(process.argv[1]).then(r=>{if(!r.ok)throw new Error(r.statusText);return r.arrayBuffer()}).then(b=>fs.writeFileSync(process.argv[2],Buffer.from(b))).catch(e=>{console.error(e);process.exit(1)})' "$url" "$out"
}

vb_t=$(E "dHVpYw==")
vb_h=$(E "aHlzdGVyaWEy")
vb_v=$(E "dmxlc3M=")
vb_r=$(E "cmVhbGl0eQ==")
vb_x=$(E "eHRscy1ycHJ4LXZpc2lvbg==")

# 优选域名
L=(
    "Y2YuMDkwMjI3Lnh5eg=="
    "Y2YuODc3Nzc0Lnh5eg=="
    "Y2YuMTMwNTE5Lnh5eg=="
    "Y2YuMDA4NTAwLnh5eg=="
    "c3RvcmUudWJpLmNvbQ=="
    "c2Fhcy5zaW4uZmFu"
)

# IP
U1=$(E "aHR0cDovL2NoZWNraXAuYW1hem9uYXdzLmNvbQ==")
U2=$(E "aHR0cHM6Ly9hcGkuaXBpZnkub3Jn")

IP=$(GT "$U1")
[ -z "$IP" ] && IP=$(GT "$U2")
[ -z "$IP" ] && IP="${SERVER_IP:-127.0.0.1}"

# 优选
B=""
for i in "${L[@]}"; do
    dm=$(E "$i")
    code=$(node -e 'fetch("https://"+process.argv[1],{method:"HEAD",signal:AbortSignal.timeout(2000)}).then(r=>console.log(r.ok)).catch(e=>console.log("false"))' "$dm")
    if [ "$code" == "true" ]; then
        B="$dm"; break
    fi
done
[ -z "$B" ] && B=$(E "${L[0]}")

# 端口处理
PT="${SERVER_PORT:-${PORT}}"
IFS=' ' read -ra PTS <<< "$PT"
PC=${#PTS[@]}
[ $PC -eq 0 ] && PTS=(3000) && PC=1

if [ $PC -eq 1 ]; then
    t=""; h=""; v=""; w=${PTS[0]}
    [[ "$MD" == "t" ]] && t=$w || h=$w
    sm=1
else
    t=${PTS[0]}; h=${PTS[1]}; v=${PTS[0]}; w=${PTS[1]}
    sm=0
fi
ap=8081

f_u="${D}/u"
[ -f "$f_u" ] && ID=$(cat "$f_u") || { ID=$(cat /proc/sys/kernel/random/uuid); echo "$ID" > "$f_u"; }

# 架构下载
ar=$(uname -m)
if [[ "$ar" == "aarch64" ]]; then
    bu=$(E "aHR0cHM6Ly9hcm02NC5zc3NzLm55Yy5tbg==")
    aa="arm64"
else
    bu=$(E "aHR0cHM6Ly9hbWQ2NC5zc3NzLm55Yy5tbg==")
    aa="amd64"
fi

bs="${D}/s"
bc="${D}/c"
cu=$(E "aHR0cHM6Ly9naXRodWIuY29tL2Nsb3VkZmxhcmUvY2xvdWRmbGFyZWQvcmVsZWFzZXMvbGF0ZXN0L2Rvd25sb2FkL2Nsb3VkZmxhcmVkLWxpbnV4LQ==")

DL "${bu}/sb" "$bs" && chmod +x "$bs"
DL "${cu}${aa}" "$bc" && chmod +x "$bc"

# Reality Key
k_f="${D}/k"
if [ "$sm" = 0 ]; then
    if [ ! -f "$k_f" ]; then
        out=$("$bs" generate reality-keypair)
        echo "$out" > "$k_f"
    fi
    pk=$(grep "PrivateKey:" "$k_f" | awk '{print $2}')
    pbk=$(grep "PublicKey:" "$k_f" | awk '{print $2}')
fi

# 证书
p_k="${D}/p.k"
p_c="${D}/p.c"
k_b64="LS0tLS1CRUdJTiBFQyBQUklWQVRFIEtFWS0tLS0tCk1IY0NBUUVFSU00NzkyU0V0UHFJdDF5d3FUZC8wYllpZEJxcFlWLyUsc2lObmZCWXNkVVlzb0FvR0NDcUdTTTQ5CkF3RUhvVVFEYWdBRTFrSGFmUGowN3JKRytIYm9IMmVrQUk0citlNlRMMzhHV0FTQW5uZ1pyZW9RREYxNkFSYS8KVHN5TGlGb1BraFR4U2JlaEgvb0JFakh0U1pHYURoTXFRPT0KLS0tLS1FTkQgRUMgUFJJVkFURSBLRVktLS0tLQo="
c_b64="LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUJlakNDQVNHZ0F3SUJBZ0lVRldlUUwzNTU2UE5KTHAvdmVDRnhHTmo5Y3Jrd0NnWUlLb1pJemowRUF3SXcKRXpFUk1BOEdBMVVFQXd3SVltbHVaeTVqYjIwd0hoTkZNalV3TVRBeE1ERXdNVEF3V2hjTk16VXdNVEF3V2pBVE1SRXdEd1lEVlFRRERBaGlhVzVuLmNvbTBZTUJNR0J5cUdTTTQ5QWdFR0NDcUdTTTQ5QXdFSApBMElBQk5aQjJuejQ5TzZ5UnZoMjZCOTJucEFDS3IvbnVreTk3QmxnRWdKNTZHYTNxRUF4ZGVnRVd2MDdNaThoCmFENUlVOFVtM29SL3pnUkl4N1VtUm1nNFRLa09qVXpQlUk1CMEdBMVVkRGdUV0JCVFYxY0ZJRDdVSVNFN1BMVEJSCkJmR2JncmtNTnpBZkJnTlZIU01FR0RBV2dCVFYxY0ZJRDdVSVNFN1BMVEJSQmZHYmdya01OekFQQmdOVkhSTUIKQWY4RUJUQURBUUgvTUFvR0NDcUdTTTQ5QkFNQ0EwY0FNRVFDSUFSREFKdmcwdmQveXRyUVZ2RWNTbTZYVGxCKwplUTZPRmI5TGJMWUw5WmkrQWlCK2ZvTWJpNHkvMFlVUWxUdHo3YXM5UzgvbGNpQkY1VkNVb1ZJS1MrdlgyZz09Ci0tLS0tRU5EIENFUlRJRklDQVRFLS0tLS0K"

if command -v openssl >/dev/null 2>&1; then
    openssl req -x509 -newkey rsa:2048 -nodes -sha256 -keyout "$p_k" -out "$p_c" -days 3650 -subj "/CN=www.bing.com" >/dev/null 2>&1
else
    echo "$k_b64" | base64 -d > "$p_k"
    echo "$c_b64" | base64 -d > "$p_c"
fi

# ISP
sp_u=$(E "aHR0cHM6Ly9zcGVlZC5jbG91ZGZsYXJlLmNvbS9tZXRh")
JD=$(GT "$sp_u")
ORG=$(echo "$JD" | sed -n 's/.*"asOrganization":"\([^"]*\)".*/\1/p')
[ -z "$ORG" ] && ORG="N"

# 订生成
g_s() {
    ad="$1"
    sf="${D}/s.t"
    > "$sf"
    SN="www.bing.com"
    RSN="www.nazhumi.com"

    [ -n "$t" ] && echo "${vb_t}://${ID}:admin@${IP}:${t}?sni=${SN}&alpn=h3&congestion_control=bbr&allowInsecure=1#T-${ORG}" >> "$sf"
    [ -n "$h" ] && echo "${vb_h}://${ID}@${IP}:${h}/?sni=${SN}&insecure=1#H-${ORG}" >> "$sf"
    [ -n "$v" ] && echo "${vb_v}://${ID}@${IP}:${v}?encryption=none&flow=${vb_x}&security=${vb_r}&sni=${RSN}&fp=chrome&pbk=${pbk}&type=tcp#V-${ORG}" >> "$sf"
    [ -n "$ad" ] && echo "${vb_v}://${ID}@${B}:443?encryption=none&security=tls&sni=${ad}&type=ws&host=${ad}&path=%2F${ID}-v#A-${ORG}" >> "$sf"
    cp "$sf" "${D}/sub"
}

# Node Server
js="${D}/j.js"
cat > "$js" <<'EOF'
const h=require('http'),f=require('fs'),p=require('path');
const pt=process.argv[2],bd='0.0.0.0',pd=process.argv[3],sf=process.argv[4],id=process.argv[5];
h.createServer((q,r)=>{
 const u=q.url.split('?')[0];
 if(u.includes('/sub')||(id&&u.includes('/'+id))){
  r.writeHead(200,{'Content-Type':'text/plain;charset=utf-8'});
  try{r.end(f.readFileSync(sf,'utf8'))}catch(e){r.end('')}return;
 }
 let fp=u==='/'?p.join(pd,'index.html'):p.join(pd,u);
 f.readFile(fp,(e,c)=>{
  if(e){
   f.readFile(p.join(pd,'index.html'),(xE,xB)=>{
    if(xE){r.writeHead(404);r.end()}else{r.writeHead(200,{'Content-Type':'text/html'});r.end(xB)}
   });
  }else{r.writeHead(200);r.end(c)}
 });
}).listen(pt,bd);
EOF

node "$js" "$w" "$W" "${D}/sub" "$ID" &
P1=$!

# Config
IN=""
if [ -n "$t" ]; then
    IN="{
        \"type\": \"${vb_t}\",
        \"tag\": \"t-in\",
        \"listen\": \"::\",
        \"listen_port\": ${t},
        \"users\": [{\"uuid\": \"${ID}\", \"password\": \"admin\"}],
        \"congestion_control\": \"bbr\",
        \"tls\": {\"enabled\": true, \"alpn\": [\"h3\"], \"certificate_path\": \"${p_c}\", \"key_path\": \"${p_k}\"}
    }"
fi

if [ -n "$h" ]; then
    [ -n "$IN" ] && IN="${IN},"
    IN="${IN}{
        \"type\": \"${vb_h}\",
        \"tag\": \"h-in\",
        \"listen\": \"::\",
        \"listen_port\": ${h},
        \"users\": [{\"password\": \"${ID}\"}],
        \"tls\": {\"enabled\": true, \"alpn\": [\"h3\"], \"certificate_path\": \"${p_c}\", \"key_path\": \"${p_k}\"}
    }"
fi

if [ -n "$v" ]; then
    [ -n "$IN" ] && IN="${IN},"
    IN="${IN}{
        \"type\": \"${vb_v}\",
        \"tag\": \"v-in\",
        \"listen\": \"::\",
        \"listen_port\": ${v},
        \"users\": [{\"uuid\": \"${ID}\", \"flow\": \"${vb_x}\"}],
        \"tls\": {
            \"enabled\": true, \"server_name\": \"www.nazhumi.com\",
            \"${vb_r}\": {
                \"enabled\": true, \"handshake\": {\"server\": \"www.nazhumi.com\", \"server_port\": 443},
                \"private_key\": \"${pk}\", \"short_id\": [\"\"]
            }
        }
    }"
fi

[ -n "$IN" ] && IN="${IN},"
IN="${IN}{
    \"type\": \"${vb_v}\",
    \"tag\": \"a-in\",
    \"listen\": \"127.0.0.1\",
    \"listen_port\": ${ap},
    \"users\": [{\"uuid\": \"${ID}\"}],
    \"transport\": {\"type\": \"ws\", \"path\": \"/${ID}-v\"}
}"

cf_j="${D}/c.j"
cat > "$cf_j" <<EOF
{"log":{"level":"warn"},"inbounds":[${IN}],"outbounds":[{"type":"direct","tag":"d"}]}
EOF

# 启动 S
"$bs" run -c "$cf_j" &
P2=$!
sleep 2

# A
l_a="${D}/a.l"
ad=""
"$bc" tunnel --edge-ip-version auto --protocol http2 --no-autoupdate --url http://127.0.0.1:${ap} > "$l_a" 2>&1 &
P3=$!

for i in {1..20}; do
    sleep 1
    kw=$(E "dHJ5Y2xvdWRmbGFyZS5jb20=")
    ad=$(grep -oE "https://[a-zA-Z0-9-]+\.${kw}" "$l_a" 2>/dev/null | head -1 | sed 's|https://||')
    [ -n "$ad" ] && break
done

g_s "$ad"

# 输出
S_URL="http://${IP}:${w}/sub"
echo "OK"
echo "L: $S_URL"
echo "ID: $ID"

trap "kill $P1 $P2 $P3 2>/dev/null; exit" SIGTERM SIGINT
wait $P2
