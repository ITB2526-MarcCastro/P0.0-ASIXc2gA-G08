#!/usr/bin/env bash
# Joc de proves G08 - Isard VDI (R-N08, W-N08, F-N08, B-N08, C-LIN)
# Basat en la documentacio del repositori P0.0-ASIXc2gA-G08.
# No modifica la configuracio; nomes --ftp-write crea i elimina un fitxer temporal FTP.
set -uo pipefail

VERSION="1.0"
ROLE="auto"
REMOTE=0
FTP_LOGIN=0
FTP_WRITE=0
CLIENT_IP=""
WIN_IP="${G08_WIN_IP:-192.168.20.104}"
LOG_DIR=""
NON_INTERACTIVE=0
# Mateixa identitat SSH que esperar_serveis.sh.
SSH_USER="${G08_SSH_USER:-${SSH_USER:-isard}}"
SSH_KEY="${G08_SSH_KEY:-/home/isard/.ssh/id_ed25519}"
SSH_KNOWN_HOSTS="${G08_SSH_KNOWN_HOSTS:-/home/isard/.ssh/known_hosts}"

WAN_IF="enp1s0"; VPN_IF="enp2s0"; DMZ_IF="enp3s0"; LAN_IF="enp4s0"
DMZ_GW="192.168.10.1"; LAN_GW="192.168.20.1"
WEB_IP="192.168.10.10"; FTP_IP="192.168.10.11"; DB_IP="192.168.20.10"
DNS_DOMAIN="n08.local"
FTP_USER="${FTP_USER:-}"; FTP_PASS="${FTP_PASS:-}"

usage() {
cat <<'HELP'
Joc de proves G08 (Ubuntu / Bash)

Us: ./script.sh [opcions]
  --role router|web|ftp|db|client|auto   Equip on s'executa (auto detecta IP)
  --remote                             Des del router, prova W/F/B via SSH amb clau
  --client-ip IP                       Amb --remote, inclou C-LIN si te SSH
  --ssh-user USUARI                    Usuari SSH remot (per defecte isard)
  --ftp-login                          Demana usuari i contrasenya FTP sense mostrar-los
  --ftp-write                          Prova pujada/baixada/esborrat FTP (requereix credencials)
  --log-dir DIRECTORI                  Carpeta de logs (per defecte ./logs al costat del script)
  --non-interactive                    No demana credencials
  -h, --help                           Ajuda

Resultats: logs/execucio.log, logs/errors.log i logs/resultats.csv.
IMPORTANT: les proves del tallafoc s'han de fer des dels equips d'origen.
El mode --remote necessita SSH amb clau i sudo sense contrasenya per a certes proves.
No s'escriuen contrasenyes als logs ni s'apliquen regles noves.
HELP
}

while (($#)); do
  case "$1" in
    --role) [[ $# -ge 2 ]] || { echo "Falta valor de --role" >&2; exit 2; }; ROLE="$2"; shift 2 ;;
    --remote) REMOTE=1; shift ;;
    --client-ip) [[ $# -ge 2 ]] || exit 2; CLIENT_IP="$2"; shift 2 ;;
    --ssh-user) [[ $# -ge 2 ]] || exit 2; SSH_USER="$2"; shift 2 ;;
    --ftp-login) FTP_LOGIN=1; shift ;;
    --ftp-write) FTP_WRITE=1; shift ;;
    --log-dir) [[ $# -ge 2 ]] || exit 2; LOG_DIR="$2"; shift 2 ;;
    --non-interactive) NON_INTERACTIVE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Opcio desconeguda: $1" >&2; usage; exit 2 ;;
  esac
done
case "$ROLE" in auto|router|web|ftp|db|client) ;; *) echo "Rol invalid: $ROLE" >&2; exit 2 ;; esac

# Si arriba per 'ssh ... bash -s', BASH_SOURCE pot ser buit: fer servir $PWD.
SCRIPT_PATH="${BASH_SOURCE[0]:-}"
if [[ -n "$SCRIPT_PATH" && -f "$SCRIPT_PATH" ]]; then
  SCRIPT_PATH="$(cd -- "$(dirname -- "$SCRIPT_PATH")" && pwd)/$(basename -- "$SCRIPT_PATH")"
  BASE_DIR="$(dirname -- "$SCRIPT_PATH")"
else
  SCRIPT_PATH=""
  BASE_DIR="$PWD"
fi
[[ -n "$LOG_DIR" ]] || LOG_DIR="$BASE_DIR/logs"
mkdir -p -- "$LOG_DIR" 2>/dev/null || { echo "ERROR: no es pot crear $LOG_DIR" >&2; exit 2; }
LOG_DIR="$(cd "$LOG_DIR" && pwd)"
EXEC_LOG="$LOG_DIR/execucio.log"; ERROR_LOG="$LOG_DIR/errors.log"; CSV_LOG="$LOG_DIR/resultats.csv"
touch "$EXEC_LOG" "$ERROR_LOG" "$CSV_LOG" 2>/dev/null || { echo "ERROR: no es poden escriure logs a $LOG_DIR" >&2; exit 2; }
[[ -s "$CSV_LOG" ]] || printf 'data;execucio;equip;rol;id;estat;prova;detall\n' >> "$CSV_LOG"
RUN_ID="$(date '+%Y%m%d_%H%M%S')_$$"
HOST="$(hostname -s 2>/dev/null || printf 'desconegut')"
OK=0; KO=0; AVIS=0; SKIP=0

clean() {
  local s="${1:-}"
  s="${s//$'\n'/ }"; s="${s//$'\r'/ }"; s="${s//|//}"
  s="${s//;/,}"; s="${s//\"/_}"
  printf '%s' "${s:0:320}"
}
record() {
  local id="$1" status="$2" title="$3" detail="${4:-}" now
  now="$(date '+%F %T')"; detail="$(clean "$detail")"; title="$(clean "$title")"
  case "$status" in
    OK) ((OK+=1));; KO) ((KO+=1));; AVIS) ((AVIS+=1));; OMITIDA) ((SKIP+=1));;
  esac
  printf '[%-7s] %-5s %-46s %s\n' "$status" "$id" "$title" "$detail"
  printf '[%s] [%s] [%s] [%s] %s: %s\n' "$now" "$RUN_ID" "$status" "$id" "$title" "$detail" >> "$EXEC_LOG"
  [[ "$status" != KO ]] || printf '[%s] [%s] [%s] [%s] %s: %s\n' "$now" "$RUN_ID" "$HOST" "$id" "$title" "$detail" >> "$ERROR_LOG"
  printf '%s;%s;%s;%s;%s;%s;%s;%s\n' "$now" "$RUN_ID" "$HOST" "$ROLE" "$id" "$status" "$title" "$detail" >> "$CSV_LOG"
  # Format facil d'importar des del router quan s'executa via SSH.
  [[ "${G08_MACHINE:-0}" != 1 ]] || printf 'G08_RESULT|%s|%s|%s|%s|%s\n' "$ROLE" "$id" "$status" "$title" "$detail"
}
has() { command -v "$1" >/dev/null 2>&1; }
skip_missing() { record "$1" OMITIDA "$2" "Falta l'ordre: $3"; }
service_test() {
  local id="$1" title="$2" svc="$3"
  if ! has systemctl; then skip_missing "$id" "$title" systemctl
  elif systemctl is-active --quiet "$svc" 2>/dev/null; then record "$id" OK "$title" "Servei $svc actiu"
  else record "$id" KO "$title" "Servei $svc no actiu"; fi
}
port_open() {
  has timeout || return 2
  timeout 5 bash -c 'exec 3<>/dev/tcp/"$1"/"$2"' _ "$1" "$2" >/dev/null 2>&1
}
port_test() {
  local id="$1" title="$2" ip="$3" port="$4" expect="$5" rc
  port_open "$ip" "$port"; rc=$?
  if ((rc==2)); then skip_missing "$id" "$title" timeout
  elif [[ "$expect" == open && "$rc" == 0 ]]; then record "$id" OK "$title" "TCP $ip:$port accessible"
  elif [[ "$expect" == closed && "$rc" != 0 ]]; then record "$id" OK "$title" "TCP $ip:$port no accessible (pot ser filtre o servei aturat)"
  elif [[ "$expect" == open ]]; then record "$id" KO "$title" "No es pot connectar a TCP $ip:$port"
  else record "$id" KO "$title" "TCP $ip:$port accessible i s'esperava restringit"; fi
}
ping_test() {
  local id="$1" title="$2" ip="$3" expect="$4" out rc
  if ! has ping; then skip_missing "$id" "$title" ping; return; fi
  out="$(ping -n -c 2 -W 2 "$ip" 2>&1)"; rc=$?
  if [[ "$expect" == yes && "$rc" == 0 ]]; then record "$id" OK "$title" "ICMP $ip respon"
  elif [[ "$expect" == no && "$rc" != 0 ]]; then record "$id" OK "$title" "Sense resposta ICMP de $ip (no prova per si sol el filtratge)"
  elif [[ "$expect" == no ]]; then record "$id" KO "$title" "ICMP $ip respon i s'esperava bloqueig"
  else record "$id" KO "$title" "ICMP $ip sense resposta; $(printf '%s' "$out" | tail -n 2 | tr '\n' ' ')"; fi
}
dns_test() {
  local id="$1" name="$2" expected="$3" out
  if ! has dig; then skip_missing "$id" "DNS $name" dig; return; fi
  out="$(dig @"$LAN_GW" "$name" A +short +time=2 +tries=1 2>/dev/null)"
  if printf '%s\n' "$out" | grep -Fxq "$expected"; then
    record "$id" OK "DNS $name" "Resol a $expected"
  else record "$id" KO "DNS $name" "Esperat $expected, obtingut: ${out:-cap resposta}"; fi
}
file_contains() {
  local id="$1" title="$2" path="$3" needle="$4"
  if [[ ! -r "$path" ]]; then record "$id" OMITIDA "$title" "No es pot llegir $path"
  elif grep -Fq -- "$needle" "$path"; then record "$id" OK "$title" "Coincideix amb la documentacio"
  else record "$id" KO "$title" "No es troba '$needle' a $path"; fi
}
# Consultes de sistema amb privilegis sense demanar contrasenya enmig de les proves.
priv_cmd() {
  if ((EUID==0)); then "$@"
  elif has sudo; then sudo -n "$@"
  else return 126; fi
}
web_test() {
  local id="$1" url="$2" body status rc
  if ! has curl; then skip_missing "$id" "Web i aplicacio PHP ($url)" curl; return; fi
  body="$(mktemp)" || { record "$id" OMITIDA "Web i aplicacio PHP" "No es pot crear fitxer temporal"; return; }
  status="$(curl --noproxy '*' -sS --connect-timeout 3 --max-time 12 -o "$body" -w '%{http_code}' "$url" 2>/dev/null)"; rc=$?
  if ((rc!=0)) || [[ "$status" != 200 ]]; then
    record "$id" KO "Web i aplicacio PHP ($url)" "curl=$rc HTTP=${status:-cap resposta}"
  elif grep -Fq 'Connectat a' "$body" && grep -Eq 'Equipaments [úu]nics:[[:space:]]*<strong>1982</strong>' "$body"; then
    record "$id" OK "Web i aplicacio PHP ($url)" "HTTP 200, connexio BBDD i 1982 equipaments"
  elif grep -Fq 'Error de connexió amb la BBDD' "$body"; then
    record "$id" KO "Web i aplicacio PHP ($url)" "HTTP 200 pero PHP informa d'error amb MySQL"
  else
    record "$id" KO "Web i aplicacio PHP ($url)" "HTTP 200, pero no s'ha verificat el contingut PHP esperat (1982)"
  fi
  rm -f -- "$body"
}
ftp_curl() {
  # La contrasenya entra per stdin de curl, no com argument de la linia d'ordres.
  local creds="${FTP_USER}:${FTP_PASS}"
  creds="${creds//\\/\\\\}"; creds="${creds//\"/\\\"}"
  printf 'user = "%s"\n' "$creds" | curl --config - "$@"
}
ftp_tests() {
  local prefix="$1" code rc tmpdir remote_file content
  if ! has curl; then skip_missing "${prefix}1" "FTP: rebuig anonymous" curl; return; fi
  code="$(curl --noproxy '*' --silent --max-time 10 --output /dev/null --write-out '%{response_code}' "ftp://$FTP_IP/" 2>/dev/null)"; rc=$?
  if [[ "$code" == 530 ]]; then record "${prefix}1" OK "FTP: usuari anonymous rebutjat" "Resposta FTP 530"
  elif ((rc==0)); then record "${prefix}1" KO "FTP: usuari anonymous rebutjat" "El servidor accepta anonymous (FTP $code)"
  else record "${prefix}1" AVIS "FTP: usuari anonymous rebutjat" "No s'ha pogut distingir autenticacio de xarxa (FTP ${code:-?}, curl=$rc)"; fi
  if [[ -z "$FTP_USER" || -z "$FTP_PASS" ]]; then
    record "${prefix}2" OMITIDA "FTP: autenticacio i llistat passiu" "Executa amb --ftp-login (no hi ha credencials)"
    ((FTP_WRITE==0)) || record "${prefix}3" OMITIDA "FTP: transferencia i integritat" "Cal --ftp-login"
    return
  fi
  if ftp_curl --noproxy '*' -sS --connect-timeout 3 --max-time 15 --ftp-pasv --output /dev/null "ftp://$FTP_IP/" 2>/dev/null; then
    record "${prefix}2" OK "FTP: autenticacio i llistat passiu" "Usuari autenticat i llistat correcte"
  else
    record "${prefix}2" KO "FTP: autenticacio i llistat passiu" "Error de login, port de dades passiu o permisos (credencials ocultes)"
    ((FTP_WRITE==0)) || record "${prefix}3" OMITIDA "FTP: transferencia i integritat" "Autenticacio fallida"
    return
  fi
  ((FTP_WRITE==1)) || return
  tmpdir="$(mktemp -d)" || { record "${prefix}3" OMITIDA "FTP: transferencia" "Sense directori temporal"; return; }
  remote_file="g08_prova_${RUN_ID}.txt"
  printf 'Prova G08 %s\n' "$RUN_ID" > "$tmpdir/origen"
  if ftp_curl --noproxy '*' -sS --connect-timeout 3 --max-time 15 --ftp-pasv --upload-file "$tmpdir/origen" "ftp://$FTP_IP/$remote_file" >/dev/null 2>&1 &&
     ftp_curl --noproxy '*' -sS --connect-timeout 3 --max-time 15 --ftp-pasv --output "$tmpdir/descarregat" "ftp://$FTP_IP/$remote_file" >/dev/null 2>&1 &&
     cmp -s "$tmpdir/origen" "$tmpdir/descarregat"; then
    record "${prefix}3" OK "FTP: pujada, baixada i integritat" "Fitxer temporal identic (cmp)"
  else
    record "${prefix}3" KO "FTP: pujada, baixada i integritat" "No s'ha pogut transferir o comparar el fitxer temporal"
  fi
  if ftp_curl --noproxy '*' -sS --max-time 12 --ftp-pasv --quote "-DELE $remote_file" --output /dev/null "ftp://$FTP_IP/" >/dev/null 2>&1; then
    record "${prefix}4" OK "FTP: neteja del fitxer temporal" "Eliminat $remote_file"
  else record "${prefix}4" AVIS "FTP: neteja del fitxer temporal" "Revisa si queda $remote_file al servidor"; fi
  rm -rf -- "$tmpdir"
}

internet_test() {
  local id="$1" label="$2" code rc
  if ! has curl; then skip_missing "$id" "$label" curl; return; fi
  code="$(curl --noproxy '*' --silent --location --connect-timeout 4 --max-time 12 --output /dev/null --write-out '%{http_code}' 'https://example.com/' 2>/dev/null)"; rc=$?
  if ((rc==0)) && [[ "$code" == 200 ]]; then record "$id" OK "$label" 'HTTPS extern funciona (example.com)'
  else record "$id" KO "$label" "HTTPS extern no funciona (curl=$rc, HTTP=${code:-?})"; fi
}
router_tests() {
  local iface ip id routes fwd rules nat dhcp
  echo; echo '=== ROUTER: interfícies, routing, DNS/DHCP, tallafoc, NAT i serveis ==='
  if has ip; then
    for iface in "$DMZ_IF" "$LAN_IF"; do
      if [[ "$iface" == "$DMZ_IF" ]]; then ip="$DMZ_GW"; id="R01"; else ip="$LAN_GW"; id="R02"; fi
      if ip -o -4 addr show dev "$iface" 2>/dev/null | grep -Fq "inet $ip/24"; then
        record "$id" OK "IP de $iface" "$ip/24"
      else record "$id" KO "IP de $iface" "S'esperava $ip/24"; fi
    done
    for iface in "$WAN_IF" "$VPN_IF"; do
      if ip link show dev "$iface" >/dev/null 2>&1; then record "R03${iface}" OK "Interficie $iface present" "Detectada"
      else record "R03${iface}" KO "Interficie $iface present" "No existeix"; fi
    done
    routes="$(ip -4 route show default 2>/dev/null)"
    if grep -Eq '(^| )dev enp1s0( |$)' <<< "$routes"; then record R04 OK 'Ruta per defecte WAN' 'Passa per enp1s0'
    else record R04 KO 'Ruta per defecte WAN' "No passa per enp1s0: $routes"; fi
    if grep -Eq '(^| )dev enp2s0( |$)' <<< "$routes"; then record R05 KO 'Sense ruta default per VPN' 'Hi ha ruta default per enp2s0'
    else record R05 OK 'Sense ruta default per VPN' 'No hi ha ruta default per enp2s0'; fi
    echo; echo '--- ip -4 address ---'; ip -4 address show
    echo; echo '--- ip -4 route ---'; ip -4 route show
  else skip_missing R01 'Interficies i rutes' ip; fi
  fwd="$(cat /proc/sys/net/ipv4/ip_forward 2>/dev/null || true)"
  if [[ "$fwd" == 1 ]]; then record R06 OK 'IPv4 forwarding' 'net.ipv4.ip_forward=1'
  else record R06 KO 'IPv4 forwarding' "Valor actual: ${fwd:-desconegut}"; fi
  service_test R07 'Servei dnsmasq' dnsmasq
  service_test R08 'Servei nftables' nftables
  file_contains R09 'DHCP rang Intranet' /etc/dnsmasq.d/projecte.conf '192.168.20.100,192.168.20.200'
  file_contains R10 'DHCP gateway' /etc/dnsmasq.d/projecte.conf 'option:router,192.168.20.1'
  file_contains R11 'DHCP DNS' /etc/dnsmasq.d/projecte.conf 'option:dns-server,192.168.20.1'
  file_contains R12 'DNS sense /etc/hosts' /etc/dnsmasq.d/projecte.conf 'no-hosts'
  dns_test R13 R-N08.n08.local "$LAN_GW"
  dns_test R14 W-N08.n08.local "$WEB_IP"
  dns_test R15 F-N08.n08.local "$FTP_IP"
  dns_test R16 B-N08.n08.local "$DB_IP"
  if has nft; then
    rules="$(priv_cmd nft list chain inet filter forward 2>/dev/null)"; rc=$?
    if ((rc!=0)); then record R17 OMITIDA 'Regles de forward nftables' 'Cal root o sudo -n nft'
    else
      if grep -q 'policy drop' <<< "$rules"; then record R17 OK 'Politica forward drop' 'policy drop'
      else record R17 KO 'Politica forward drop' 'No consta policy drop'; fi
      if grep -Eq 'ip saddr 192\.168\.10\.10.*ip daddr 192\.168\.20\.10.*tcp dport 3306.*accept' <<< "$rules"; then
        record R18 OK 'Excepcio Web -> MySQL' '192.168.10.10 -> 192.168.20.10:3306'
      else record R18 KO 'Excepcio Web -> MySQL' 'No es troba la regla esperada'; fi
      if grep -Eq 'iifname "?enp4s0"? .*accept' <<< "$rules"; then record R19 OK 'LAN pot sortir' 'Regla iifname enp4s0 accept'
      else record R19 KO 'LAN pot sortir' 'No es troba regla LAN accept'; fi
      if grep -Eq 'iifname "?enp3s0"? oifname "?enp1s0"? accept' <<< "$rules"; then record R20 OK 'DMZ cap a WAN' 'Regla DMZ -> WAN accept'
      else record R20 KO 'DMZ cap a WAN' 'No es troba regla DMZ -> WAN'; fi
    fi
    nat="$(priv_cmd nft list chain ip nat postrouting 2>/dev/null)"; rc=$?
    if ((rc!=0)); then record R21 OMITIDA 'NAT masquerade' 'Cal root o sudo -n nft'
    elif grep -Eq 'oifname "?enp1s0"? masquerade' <<< "$nat"; then record R21 OK 'NAT masquerade' 'WAN enp1s0'
    else record R21 KO 'NAT masquerade' 'No es troba masquerade per WAN'; fi
    if [[ -r /etc/nftables.conf ]]; then
      if priv_cmd nft -c -f /etc/nftables.conf >/dev/null 2>&1; then record R22 OK 'Sintaxi nftables.conf' 'Validada sense aplicar canvis'
      else record R22 KO 'Sintaxi nftables.conf' 'nft -c ha fallat (o falten permisos)'; fi
    else record R22 OMITIDA 'Sintaxi nftables.conf' 'No es pot llegir /etc/nftables.conf'; fi
  else skip_missing R17 'Regles nftables i NAT' nft; fi
  ping_test R23 'Ping W-N08' "$WEB_IP" yes
  ping_test R24 'Ping F-N08' "$FTP_IP" yes
  ping_test R25 'Ping B-N08' "$DB_IP" yes
  port_test R26 'Port HTTP W-N08' "$WEB_IP" 80 open
  port_test R27 'Port FTP F-N08' "$FTP_IP" 21 open
  port_test R28 'Port MySQL B-N08 (des del router)' "$DB_IP" 3306 open
  web_test R29 "http://$WEB_IP/"
  ftp_tests R3
  internet_test R41 'Sortida HTTPS a Internet des del router'
}

web_role_tests() {
  echo; echo '=== W-N08: Apache/PHP i segmentacio DMZ ==='
  service_test W01 'Apache actiu' apache2
  if has php; then
    if php -m 2>/dev/null | grep -iq '^mysqli$'; then record W02 OK 'PHP amb mysqli' 'Modul mysqli disponible'
    else record W02 KO 'PHP amb mysqli' 'Falta modul mysqli'; fi
  else skip_missing W02 'PHP amb mysqli' php; fi
  web_test W03 'http://127.0.0.1/'
  port_test W04 'Excepcio W-N08 -> B-N08:3306' "$DB_IP" 3306 open
  ping_test W05 'ICMP W-N08 -> B-N08 restringit' "$DB_IP" no
  internet_test W07 'Sortida HTTPS DMZ (W-N08)'
  port_test W06 'Acces W-N08 -> B-N08:22 restringit' "$DB_IP" 22 closed
}
ftp_role_tests() {
  echo; echo '=== F-N08: vsftpd i segmentacio DMZ ==='
  service_test F01 'vsftpd actiu' vsftpd
  port_test F02 'FTP local TCP 21' 127.0.0.1 21 open
  file_contains F03 'FTP anonymous desactivat' /etc/vsftpd.conf 'anonymous_enable=NO'
  file_contains F04 'FTP usuaris locals' /etc/vsftpd.conf 'local_enable=YES'
  file_contains F05 'FTP mode passiu min' /etc/vsftpd.conf 'pasv_min_port=40000'
  file_contains F06 'FTP mode passiu max' /etc/vsftpd.conf 'pasv_max_port=40100'
  file_contains F07 'FTP chroot usuaris locals' /etc/vsftpd.conf 'chroot_local_user=YES'
  port_test F08 'F-N08 -> B-N08:3306 restringit' "$DB_IP" 3306 closed
  internet_test F10 'Sortida HTTPS DMZ (F-N08)'
  ping_test F09 'ICMP F-N08 -> B-N08 restringit' "$DB_IP" no
}
db_role_tests() {
  local count total cmd output
  echo; echo '=== B-N08: MySQL, dades i accés des de LAN ==='
  service_test B01 'MySQL actiu' mysql
  port_test B02 'MySQL local TCP 3306' 127.0.0.1 3306 open
  if ! has mysql; then skip_missing B03 'Recompte de registres MySQL' mysql
  else
    cmd='SELECT COUNT(*),COUNT(DISTINCT register_id) FROM equipaments.equipaments;'
  if [[ -f "$HOME/.mylogin.cnf" ]]; then
    output="$(mysql --login-path=go8 -N -B -e "$cmd" 2>/dev/null)"; rc=$?
  elif [[ -n "${MYSQL_USER:-}" ]]; then
    output="$(mysql -N -B -u "$MYSQL_USER" -e "$cmd" 2>/dev/null)"; rc=$?
  else
    output="$(priv_cmd mysql -N -B -e "$cmd" 2>/dev/null)"; rc=$?
  fi
    if ((rc!=0)); then record B03 OMITIDA 'Recompte de registres MySQL' 'No es pot autenticar via socket; prova amb sudo o MYSQL_USER i MYSQL_PWD'
    else
      read -r total count <<< "$output"
      if [[ "$total" == 2710 && "$count" == 1982 ]]; then
        record B03 OK 'Recompte MySQL' '2710 files i 1982 equipaments unics'
      else record B03 KO 'Recompte MySQL' "Obtinguts: files=${total:-?}, unics=${count:-?}; esperats 2710 i 1982"; fi
    fi
  fi
  ping_test B04 'Ping B-N08 -> W-N08' "$WEB_IP" yes
  ping_test B05 'Ping B-N08 -> F-N08' "$FTP_IP" yes
  web_test B06 "http://$WEB_IP/"
}
client_role_tests() {
  local ips routes dns
  echo; echo '=== C-LIN: DHCP, gateway, DNS, aplicacio, FTP i segmentacio ==='
  if has ip; then
    ips="$(ip -o -4 addr show scope global 2>/dev/null | awk '{print $4}')"
    if awk -v ips="$ips" 'BEGIN { n=split(ips,a," "); for(i=1;i<=n;i++) { split(a[i],p,"/"); split(p[1],q,"."); if(q[1]==192&&q[2]==168&&q[3]==20&&q[4]>=100&&q[4]<=200) exit 0; } exit 1 }'; then
      record C01 OK 'IP client dins rang DHCP' '192.168.20.100-200'
    else record C01 KO 'IP client dins rang DHCP' "Adreces actuals: ${ips:-cap}"; fi
    routes="$(ip -4 route show default 2>/dev/null)"
    if grep -Fq "via $LAN_GW" <<< "$routes"; then record C02 OK 'Gateway DHCP' "$LAN_GW"
    else record C02 KO 'Gateway DHCP' "Ruta default: ${routes:-cap}"; fi
  else skip_missing C01 'IP i gateway DHCP' ip; fi
  if has nmcli; then
    dns="$(nmcli -g IP4.DNS device show 2>/dev/null)"
  elif has resolvectl; then dns="$(resolvectl dns 2>/dev/null)"
  else dns=""; fi
  if [[ -z "$dns" ]]; then record C03 OMITIDA 'DNS rebut al client' 'No es pot llegir DNS DHCP (nmcli/resolvectl)'
  elif grep -Fq "$LAN_GW" <<< "$dns"; then record C03 OK 'DNS rebut al client' "$LAN_GW"
  else record C03 KO 'DNS rebut al client' "No apareix $LAN_GW al DNS configurat"; fi
  ping_test C04 'Ping gateway LAN' "$LAN_GW" yes
  ping_test C05 'Ping W-N08' "$WEB_IP" yes
  ping_test C06 'Ping F-N08' "$FTP_IP" yes
  ping_test C07 'Ping B-N08' "$DB_IP" yes
  dns_test C08 W-N08.n08.local "$WEB_IP"
  dns_test C09 F-N08.n08.local "$FTP_IP"
  dns_test C10 B-N08.n08.local "$DB_IP"
  web_test C11 "http://$WEB_IP/"
  internet_test C31 'Sortida HTTPS Intranet (C-LIN)'
  ftp_tests C2
  # Segons manual-usuari, el client no hauria de poder accedir directament a MySQL.
  # Pero B-N08 i C-LIN comparteixen subxarxa: el router no filtra aquest trafic.
  port_open "$DB_IP" 3306; rc=$?
  if ((rc==2)); then skip_missing C30 'Acces directe client -> MySQL' timeout
  elif ((rc==0)); then record C30 AVIS 'Acces directe client -> MySQL' 'TCP 3306 accessible: contradiccio amb manual-usuari; revisar filtratge local de B-N08'
  else record C30 OK 'Acces directe client -> MySQL' 'TCP 3306 no accessible'; fi
}

windows_tests() {
    local ps encoded tmp marker id status title
    local failed=0
    local -A seen=()

    ps=$(cat <<'POWERSHELL'
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Check($id, $title, $test) {
    try {
        if (& $test) {
            Write-Output "WIN_RESULT|$id|OK|$title"
        } else {
            Write-Output "WIN_RESULT|$id|KO|$title"
        }
    } catch {
        Write-Output "WIN_RESULT|$id|KO|$title"
    }
}

function PingHost($ip) {
    Test-Connection -ComputerName $ip -Count 1 -Quiet
}

function DNSCheck($name, $ip) {
    $result = Resolve-DnsName -Name $name -Type A -DnsOnly
    return ($result.IPAddress -contains $ip)
}

function TCPCheck($ip, $port) {
    $tcp = New-Object System.Net.Sockets.TcpClient
    try {
        $async = $tcp.BeginConnect($ip, $port, $null, $null)
        if (!$async.AsyncWaitHandle.WaitOne(3000)) {
            return $false
        }
        $tcp.EndConnect($async)
        return $tcp.Connected
    } catch {
        return $false
    } finally {
        $tcp.Close()
    }
}

function FTPCheck($user, $pass, $anonymous) {
    $req = [System.Net.FtpWebRequest]::Create(
        'ftp://192.168.10.11/'
    )
    $req.Method = 'NLST'
    $req.Credentials = New-Object System.Net.NetworkCredential($user, $pass)
    $req.UsePassive = $true
    $req.KeepAlive = $false
    $req.Proxy = $null
    $req.Timeout = 8000
    $req.ReadWriteTimeout = 8000

    try {
        $response = $req.GetResponse()
        $reader = New-Object System.IO.StreamReader($response.GetResponseStream())
        $null = $reader.ReadToEnd()
        $reader.Close()
        $response.Close()
        return (!$anonymous)
    } catch [System.Net.WebException] {
        $response = $_.Exception.Response
        if ($response) {
            $code = [int]$response.StatusCode
            $response.Close()
            return ($anonymous -and $code -eq 530)
        }
        return $false
    }
}

$ftpUser = [Text.Encoding]::UTF8.GetString(
    [Convert]::FromBase64String([Console]::ReadLine())
)
$ftpPass = [Text.Encoding]::UTF8.GetString(
    [Convert]::FromBase64String([Console]::ReadLine())
)

$cfg = Get-NetIPConfiguration |
    Where-Object { $_.IPv4DefaultGateway } |
    Select-Object -First 1

Check CW01 'IP dins del rang DHCP' {
    $ip = $cfg.IPv4Address.IPAddress
    $ip -match '^192\.168\.20\.(\d+)$' -and
    [int]$Matches[1] -ge 100 -and
    [int]$Matches[1] -le 200
}

Check CW02 'Porta enllac correcta' {
    $cfg.IPv4DefaultGateway.NextHop -eq '192.168.20.1'
}

Check CW03 'Servidor DNS correcte' {
    $cfg.DNSServer.ServerAddresses -contains '192.168.20.1'
}

Check CW04 'DHCP activat' {
    (Get-NetIPInterface -InterfaceIndex $cfg.InterfaceIndex -AddressFamily IPv4).Dhcp -eq 'Enabled'
}

Check CW05 'Ping al router' {
    PingHost '192.168.20.1'
}

Check CW06 'Ping W-N08' {
    PingHost '192.168.10.10'
}

Check CW07 'Ping F-N08' {
    PingHost '192.168.10.11'
}

Check CW08 'Ping B-N08' {
    PingHost '192.168.20.10'
}

Check CW09 'DNS W-N08' {
    DNSCheck 'W-N08.n08.local' '192.168.10.10'
}

Check CW10 'DNS F-N08' {
    DNSCheck 'F-N08.n08.local' '192.168.10.11'
}

Check CW11 'DNS B-N08' {
    DNSCheck 'B-N08.n08.local' '192.168.20.10'
}

Check CW12 'Acces web Apache PHP' {
    $script:web = Invoke-WebRequest `
        -Uri 'http://192.168.10.10/' `
        -UseBasicParsing -TimeoutSec 10

    $script:web.StatusCode -eq 200
}

Check CW13 'Comprovacio 1982 equipaments' {
    $script:web.Content -match '(?<!\d)1[., ]?982(?!\d)'
}

Check CW14 'FTP anonymous rebutjat' {
    FTPCheck 'anonymous' 'test@example.com' $true
}

if ($ftpUser -and $ftpPass) {
    Check CW15 'FTP autenticacio i llistat passiu' {
        FTPCheck $ftpUser $ftpPass $false
    }
} else {
    Write-Output 'WIN_RESULT|CW15|OMITIDA|Falten credencials FTP'
}

Check CW16 'Acces directe MySQL bloquejat' {
    !(TCPCheck '192.168.20.10' 3306)
}

Check CW17 'Sortida HTTPS a Internet' {
    $response = Invoke-WebRequest `
        -Uri 'https://example.com/' `
        -UseBasicParsing -TimeoutSec 10

    $response.StatusCode -eq 200
}
POWERSHELL
)

    local loader

    encoded=$(printf '%s' "$ps" |
        iconv -f UTF-8 -t UTF-16LE |
        base64 -w0) || return 1

    loader=$(printf '%s' \
        '$code=[Text.Encoding]::Unicode.GetString([Convert]::FromBase64String([Console]::ReadLine())); & ([ScriptBlock]::Create($code))' |
        iconv -f UTF-8 -t UTF-16LE |
        base64 -w0) || return 1

    tmp=$(mktemp) || return 1

    if ! {
        printf '%s\n' "$encoded"
        printf '%s' "$FTP_USER" | base64 -w0
        printf '\n'
        printf '%s' "$FTP_PASS" | base64 -w0
        printf '\n'
    } | timeout 180 ssh -T \
        -i "$SSH_KEY" \
        -o IdentitiesOnly=yes \
        -o UserKnownHostsFile="$SSH_KNOWN_HOSTS" \
        -o BatchMode=yes \
        -o ConnectTimeout=5 \
        -o StrictHostKeyChecking=yes \
        "$SSH_USER@$WIN_IP" \
        "powershell.exe -NoProfile -NonInteractive -EncodedCommand $loader" \
        >"$tmp"; then
        failed=1
    fi

    while IFS='|' read -r marker id status title; do
        [[ "$marker" == WIN_RESULT ]] || continue
        [[ "$id" =~ ^CW(0[1-9]|1[0-7])$ ]] || continue
        [[ -z "${seen[$id]:-}" ]] || continue

        case "$status" in
            OK|KO|OMITIDA)
                seen[$id]=1
                record "$id" "$status" "[windows] $title" "C-WIN $WIN_IP"
                [[ "$status" == OK ]] || failed=1
                ;;
        esac
    done < <(tr -d '\r' < "$tmp")

    for id in CW{01..17}; do
        if [[ -z "${seen[$id]:-}" ]]; then
            record "$id" KO "[windows] Prova sense resultat" "Revisar SSH o PowerShell"
            failed=1
        fi
    done

    rm -f "$tmp"
    return "$failed"
}

remote_run() {
  local remote_role="$1" ip="$2" tmp rc line rrole rid status title detail
  if [[ -z "$SCRIPT_PATH" || ! -f "$SCRIPT_PATH" ]]; then
    record "SSH-$remote_role" OMITIDA "Proves remotes $remote_role" 'Script no disponible com a fitxer local'
    return
  fi
  if ! has ssh; then skip_missing "SSH-$remote_role" "Proves remotes $remote_role" ssh; return; fi
  tmp="$(mktemp)" || return
  # El fitxer s'envia per stdin; no cal instal·lar-lo a la VM remota.
  if [[ ! -r "$SSH_KEY" || ! -f "$SSH_KNOWN_HOSTS" ]]; then
    record "SSH-$remote_role" OMITIDA "Proves remotes $remote_role" "Falta clau SSH o known_hosts: $SSH_KEY / $SSH_KNOWN_HOSTS"
    rm -f "$tmp"; return
  fi
{
  if [[ "$remote_role" == "client" ]]; then
    printf 'export FTP_USER=%q\n' "${FTP_USER:-}"
    printf 'export FTP_PASS=%q\n' "${FTP_PASS:-}"
  fi
  cat "$SCRIPT_PATH"
} | ssh -T -i "$SSH_KEY" -o IdentitiesOnly=yes \
  -o UserKnownHostsFile="$SSH_KNOWN_HOSTS" \
  -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=yes \
  "$SSH_USER@$ip" env G08_MACHINE=1 bash -s -- --role "$remote_role" --non-interactive --log-dir './logs-g08' \
  > "$tmp" 2>/dev/null
rc=$?
  if ! grep -q '^G08_RESULT|' "$tmp"; then
    record "SSH-$remote_role" OMITIDA "Proves remotes $remote_role" "SSH no interactiu a $ip fallit (codi $rc); executar manualment a la VM"
    rm -f "$tmp"; return
  fi
  record "SSH-$remote_role" OK "Execucio remota $remote_role" "Proves rebudes de $ip (sortida $rc)"
  while IFS='|' read -r marker rrole rid status title detail; do
    [[ "$marker" == G08_RESULT ]] || continue
    case "$status" in OK|KO|AVIS|OMITIDA) record "$rid" "$status" "[$rrole] $title" "$detail" ;; esac
  done < "$tmp"
  rm -f "$tmp"
  return "$rc"
}
if [[ "$ROLE" == auto ]]; then
  if has ip && ip -o -4 addr show 2>/dev/null | grep -Fq "inet $DMZ_GW/24"; then ROLE=router
  elif has ip && ip -o -4 addr show 2>/dev/null | grep -Fq "inet $WEB_IP/24"; then ROLE=web
  elif has ip && ip -o -4 addr show 2>/dev/null | grep -Fq "inet $FTP_IP/24"; then ROLE=ftp
  elif has ip && ip -o -4 addr show 2>/dev/null | grep -Fq "inet $DB_IP/24"; then ROLE=db
  else ROLE=client; fi
fi
if ((FTP_LOGIN==1)); then
  if ((NON_INTERACTIVE==1)) || [[ ! -t 0 ]]; then
    echo 'AVIS: --ftp-login requereix terminal; no es demanaran credencials.' >&2
  else
    [[ -n "$FTP_USER" ]] || read -r -p 'Usuari FTP: ' FTP_USER
    if [[ -z "$FTP_PASS" ]]; then read -r -s -p 'Contrasenya FTP: ' FTP_PASS; echo; fi
  fi
fi

printf '\n============================================================\n'
printf ' JOC DE PROVES G08 v%s | equip=%s | rol=%s\n' "$VERSION" "$HOST" "$ROLE"
printf ' Execucio: %s | %s\n' "$RUN_ID" "$(date '+%F %T')"
printf '============================================================\n'
printf '[%s] INICI %s %s\n' "$(date '+%F %T')" "$RUN_ID" "$ROLE" >> "$EXEC_LOG"
case "$ROLE" in
router)
  router_tests
  if ((REMOTE==1)) && [[ -n "$CLIENT_IP" ]]; then
    remote_ko=$KO
    remote_avis=$AVIS
    remote_skip=$SKIP
    remote_failed=0

    remote_run web "$WEB_IP" || remote_failed=1
    remote_run ftp "$FTP_IP" || remote_failed=1
    remote_run db "$DB_IP" || remote_failed=1
    remote_run client "$CLIENT_IP" || remote_failed=1
    windows_tests || remote_failed=1

    if ((remote_failed==0 && KO==remote_ko && AVIS==remote_avis && SKIP==remote_skip)); then
      record R40 OK 'Validacio de proves remotes' 'W-N08, F-N08, B-N08, C-LINUX i C-WIN comprovats correctament'
    else
      record R40 AVIS 'Validacio de proves remotes' 'Hi ha errors, avisos o proves remotes omeses'
    fi
  else
    record R40 AVIS 'Limitacio de les proves del router' 'Falten les proves remotes o la IP del client'
  fi
  ;;
  web) web_role_tests ;;
  ftp) ftp_role_tests ;;
  db) db_role_tests ;;
  client) client_role_tests ;;
esac
printf '\n============================================================\n'
printf ' RESULTAT: OK=%s | KO=%s | AVIS=%s | OMITIDES=%s\n' "$OK" "$KO" "$AVIS" "$SKIP"
printf ' Logs: %s\n' "$LOG_DIR"
printf '   execucio.log | errors.log | resultats.csv\n'
printf '============================================================\n'
printf '[%s] FINAL %s OK=%s KO=%s AVIS=%s OMITIDES=%s\n' "$(date '+%F %T')" "$RUN_ID" "$OK" "$KO" "$AVIS" "$SKIP" >> "$EXEC_LOG"
((KO==0)) || exit 1
exit 0
