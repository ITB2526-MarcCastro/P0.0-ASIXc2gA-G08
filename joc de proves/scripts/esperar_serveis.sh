#!/usr/bin/env bash
# G08: no permet executar el joc de proves fins que TOTS els serveis
# estiguin habilitats (enabled) i en execució (active) a les quatre VMs.
# S'executa NOMÉS al router R-N08; comprova els altres equips per SSH.
set -uo pipefail

ROUTER_SERVICE_1="dnsmasq"
ROUTER_SERVICE_2="nftables"
# Reutilitzem la clau SSH ja existent d'isard (no s'incrusta cap secret).
SSH_USER="${G08_SSH_USER:-isard}"
SSH_KEY="${G08_SSH_KEY:-/home/isard/.ssh/id_ed25519}"
SSH_KNOWN_HOSTS="${G08_SSH_KNOWN_HOSTS:-/home/isard/.ssh/known_hosts}"
WEB_IP="192.168.10.10"
FTP_IP="192.168.10.11"
DB_IP="192.168.20.10"
CLIENT_IP="192.168.20.137"
WIN_IP="192.168.20.104"
INTERVAL="${G08_WAIT_INTERVAL:-15}"
LOG_FILE="${G08_WAIT_LOG:-/opt/joc-proves/logs/espera_serveis.log}"
ONCE=0

usage() {
  cat <<'HELP'
Ús: sudo ./esperar_serveis.sh [--check-once]
Per defecte, comprova cada 15 segons SENSE LÍMIT DE TEMPS.
Quan tots els serveis són enabled i active, executa automàticament
script.sh (excepte si s'utilitza --check-once).

Comprova:
  R-N08: dnsmasq, nftables
  W-N08: apache2, TCP 80 i HTTP 200
  F-N08: vsftpd, TCP 21
  B-N08: mysql, TCP 3306

Cal SSH sense contrasenya des del router a isard@W/F/B.
--check-once: una sola comprovació (0=preparat, 1=pendent).
Variables: G08_SSH_USER, G08_SSH_KEY, G08_SSH_KNOWN_HOSTS, G08_WAIT_INTERVAL, G08_WAIT_LOG.
HELP
}

case "${1:-}" in
  "") ;;
  --check-once) ONCE=1 ;;
  -h|--help) usage; exit 0 ;;
  *) usage >&2; exit 2 ;;
esac
[[ "$INTERVAL" =~ ^[1-9][0-9]*$ ]] || { echo 'Interval invàlid' >&2; exit 2; }
[[ "$SSH_USER" =~ ^[a-zA-Z_][a-zA-Z0-9_-]*$ ]] || { echo 'Usuari SSH invàlid' >&2; exit 2; }

mkdir -p "$(dirname "$LOG_FILE")" || exit 2
touch "$LOG_FILE" || { echo "No es pot escriure $LOG_FILE" >&2; exit 2; }

log() {
  printf '[%s] %s\n' "$(date '+%F %T')" "$*" | tee -a "$LOG_FILE"
}

# Un servei enabled pot NO estar funcionant. Calen TOTS DOS estats.
is_enabled() {
  case "$1" in enabled|enabled-runtime) return 0 ;; *) return 1 ;; esac
}
is_active() { [[ "$1" == "active" ]]; }

local_service() {
  local service="$1" enabled active
  enabled="$(systemctl is-enabled "$service" 2>/dev/null || true)"
  active="$(systemctl is-active "$service" 2>/dev/null || true)"
  if is_enabled "$enabled" && is_active "$active"; then
    log "OK   R-N08/$service: enabled=$enabled, active=$active"
    return 0
  fi
  log "WAIT R-N08/$service: enabled=${enabled:-desconegut}, active=${active:-desconegut}"
  return 1
}

# Comprova l'estat real de systemd A LA MÀQUINA REMOTA.
# El port obert NO equival a 'systemctl is-enabled'.
remote_service() {
  local host="$1" ip="$2" service="$3" output enabled active
  if ! output="$(ssh -n -T \
      -i "$SSH_KEY" -o IdentitiesOnly=yes \
      -o UserKnownHostsFile="$SSH_KNOWN_HOSTS" \
      -o BatchMode=yes -o ConnectTimeout=5 -o ConnectionAttempts=1 \
      -o StrictHostKeyChecking=yes -o LogLevel=ERROR \
      "$SSH_USER@$ip" \
      "systemctl is-enabled '$service' 2>/dev/null || :; systemctl is-active '$service' 2>/dev/null || :" \
      2>&1)"; then
    log "WAIT $host/$service: SSH no disponible (${output:0:180})"
    return 1
  fi
  enabled="$(printf '%s\n' "$output" | sed -n '1p')"
  active="$(printf '%s\n' "$output" | sed -n '2p')"
  if is_enabled "$enabled" && is_active "$active"; then
    log "OK   $host/$service: enabled=$enabled, active=$active"
    return 0
  fi
  log "WAIT $host/$service: enabled=${enabled:-desconegut}, active=${active:-desconegut}"
  return 1
}

tcp_port() {
  local host="$1" ip="$2" port="$3"
  if timeout 5 bash -c 'exec 3<>/dev/tcp/"$1"/"$2"' _ "$ip" "$port" 2>/dev/null; then
    log "OK   $host: TCP $ip:$port accessible"
    return 0
  fi
  log "WAIT $host: TCP $ip:$port encara no accessible"
  return 1
}

windows_service() {
    if timeout 15 ssh -n -T \
        -i "$SSH_KEY" \
        -o IdentitiesOnly=yes \
        -o UserKnownHostsFile="$SSH_KNOWN_HOSTS" \
        -o BatchMode=yes \
        -o ConnectTimeout=5 \
        -o StrictHostKeyChecking=yes \
        "$SSH_USER@$WIN_IP" \
        'powershell.exe -NoProfile -NonInteractive -Command "if ((Get-Service sshd).Status -eq 4 -and (Get-Service sshd).StartType -eq 2) { exit 0 } else { exit 1 }"' \
        >/dev/null 2>&1; then

        log "OK C-WIN/sshd: automatic i actiu"
        return 0
    fi

    log "WAIT C-WIN: SSH encara no disponible"
    return 1
}

http_web() {
  local code
  code="$(curl --noproxy '*' -sS --connect-timeout 3 --max-time 8 \
      -o /dev/null -w '%{http_code}' "http://$WEB_IP/" 2>/dev/null || true)"
  if [[ "$code" == 200 ]]; then
    log "OK   W-N08: HTTP 200"
    return 0
  fi
  log "WAIT W-N08: HTTP ${code:-sense resposta} (s'espera 200)"
  return 1
}

# Si no existeix la clau, no té sentit esperar indefinidament.
if [[ ! -r "$SSH_KEY" ]]; then
  log "ERROR: no es pot llegir la clau SSH $SSH_KEY. Comprova el camí al router."
  exit 2
fi
if [[ ! -f "$SSH_KNOWN_HOSTS" ]]; then
  log "ERROR: falta $SSH_KNOWN_HOSTS. Verifica primer les empremtes dels servidors amb SSH interactiu."
  exit 2
fi
for cmd in systemctl ssh timeout curl sed tee; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    log "ERROR: falta l'ordre '$cmd'. Instal·la-la abans d'iniciar l'espera."
    exit 2
  fi
done

log "Inici de l'espera: tots els serveis han de ser enabled i active."
log "Comprovació contínua cada ${INTERVAL}s; no hi ha timeout global."
attempt=0
while :; do
  attempt=$((attempt + 1))
  log "----- Intent $attempt -----"
  pending=0

  local_service "$ROUTER_SERVICE_1" || pending=$((pending + 1))
  local_service "$ROUTER_SERVICE_2" || pending=$((pending + 1))

  remote_service W-N08 "$WEB_IP" apache2 || pending=$((pending + 1))
  remote_service F-N08 "$FTP_IP" vsftpd || pending=$((pending + 1))
  remote_service B-N08 "$DB_IP" mysql || pending=$((pending + 1))
  remote_service C-LINUX "$CLIENT_IP" ssh || pending=$((pending + 1))
  windows_service || pending=$((pending + 1))
# Verificació addicional: no només enabled/active, sinó servei accessible.
  tcp_port W-N08 "$WEB_IP" 80 || pending=$((pending + 1))
  tcp_port F-N08 "$FTP_IP" 21 || pending=$((pending + 1))
  tcp_port B-N08 "$DB_IP" 3306 || pending=$((pending + 1))
  tcp_port C-LINUX "$CLIENT_IP" 22 || pending=$((pending + 1))
  tcp_port C-WIN "$WIN_IP" 22 || pending=$((pending + 1))
  http_web || pending=$((pending + 1))

  if ((pending == 0)); then
    log "PREPARAT: tots els serveis enabled + active i els ports accessibles."
    if ((ONCE == 1)); then
      log "Mode --check-once: comprovació correcta, sense executar el joc de proves."
      exit 0
    fi
    SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
    GAME_SCRIPT="$SCRIPT_DIR/script.sh"
    if [[ ! -f "$GAME_SCRIPT" ]]; then
      log "ERROR: no existeix $GAME_SCRIPT; no es pot iniciar el joc de proves."
      exit 2
    fi
    if ! bash -n "$GAME_SCRIPT"; then
      log "ERROR: $GAME_SCRIPT té errors de sintaxi."
      exit 2
    fi
    log "Iniciant joc de proves: $GAME_SCRIPT --role router --remote --non-interactive"
    export G08_SSH_KEY="$SSH_KEY" G08_SSH_KNOWN_HOSTS="$SSH_KNOWN_HOSTS"
    export G08_WIN_IP="$WIN_IP"
    exec bash "$GAME_SCRIPT" --role router --remote --non-interactive --ssh-user "$SSH_USER" --client-ip "$CLIENT_IP"
  fi

  log "PENDENT: $pending comprovacions. El joc de proves NO s'executarà encara."
  ((ONCE == 0)) || exit 1
  sleep "$INTERVAL"
done
