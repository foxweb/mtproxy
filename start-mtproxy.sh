#!/usr/bin/env -S LC_ALL=C.UTF-8 LANG=C.UTF-8 bash
# Shebang выше задаёт локаль до старта bash — иначе при несуществующем en_US.UTF-8
# в окружении появляется: warning: setlocale: LC_ALL: cannot change locale (en_US.UTF-8)

set -euo pipefail

# Цвета для вывода
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

CONTAINER_NAME="${CONTAINER_NAME:-mtproto-proxy}"
PORT="${PORT:-443}"
FAKE_DOMAIN="${FAKE_DOMAIN:-ya.ru}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${MTCONFIG_FILE:-${SCRIPT_DIR}/mtproto_config.txt}"

REGEN_SECRET=0
SHOW_LINK_ONLY=0

usage() {
  echo "Usage: $0 [--regen-secret] [--show-link]"
}

info() { echo -e "${GREEN}$*${NC}"; }
warn() { echo -e "${YELLOW}$*${NC}"; }
err() { echo -e "${RED}$*${NC}" >&2; }

on_error() {
  err "❌ Ошибка на строке $1"
}
trap 'on_error $LINENO' ERR

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    err "Не найдена команда: $1"
    exit 1
  }
}

is_port_busy() {
  local check_port="$1"
  ss -tuln | grep -q ":${check_port} "
}

container_is_running() {
  docker ps --filter "name=^${CONTAINER_NAME}$" --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"
}

validate_secret() {
  local s="$1"
  [[ "${s}" =~ ^ee[0-9a-f]{30}$ ]]
}

load_existing_secret() {
  if [ -f "${CONFIG_FILE}" ]; then
    grep "^SECRET=" "${CONFIG_FILE}" | head -n 1 | cut -d '=' -f2-
  fi
}

generate_secret() {
  local domain_hex domain_len needed random_hex
  domain_hex=$(echo -n "$FAKE_DOMAIN" | xxd -ps | tr -d '\n')
  domain_len=${#domain_hex}
  needed=$((30 - domain_len))
  random_hex=$(openssl rand -hex 15 | cut -c1-"$needed")
  echo "ee${domain_hex}${random_hex}"
}

pick_free_port() {
  local candidate
  for candidate in "$PORT" 8443 8444 8445; do
    if ! is_port_busy "$candidate"; then
      PORT="$candidate"
      return 0
    fi
  done
  return 1
}

fetch_public_ip() {
  local ip
  for endpoint in ifconfig.me ifconfig.co icanhazip.com; do
    ip=$(curl -4 -fsS --max-time 5 "$endpoint" || true)
    if [ -n "${ip}" ]; then
      echo "${ip}"
      return 0
    fi
  done
  return 1
}

save_config_atomically() {
  local server_ip="$1"
  local link="$2"
  local tmp_file
  tmp_file="$(mktemp "${SCRIPT_DIR}/.mtproto_config.tmp.XXXXXX")"
  cat > "${tmp_file}" << EOF
SERVER=${server_ip}
PORT=${PORT}
SECRET=${SECRET}
DOMAIN=${FAKE_DOMAIN}
LINK=${link}
EOF
  mv "${tmp_file}" "${CONFIG_FILE}"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --regen-secret)
      REGEN_SECRET=1
      shift
      ;;
    --show-link)
      SHOW_LINK_ONLY=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      err "Неизвестный аргумент: $1"
      usage
      exit 1
      ;;
  esac
done

if [ "${SHOW_LINK_ONLY}" -eq 1 ]; then
  if [ ! -f "${CONFIG_FILE}" ]; then
    err "Файл конфигурации не найден: ${CONFIG_FILE}"
    exit 1
  fi
  grep -o '^LINK=.*' "${CONFIG_FILE}" | cut -d= -f2-
  exit 0
fi

for bin in docker ss curl openssl xxd grep cut mktemp mv; do
  require_cmd "$bin"
done

echo "🚀 Запуск MTProto прокси с Fake TLS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "📌 Используем домен: ${BLUE}${FAKE_DOMAIN}${NC}"

EXISTING_SECRET="$(load_existing_secret || true)"
if [ "${REGEN_SECRET}" -eq 0 ] && [ -n "${EXISTING_SECRET}" ] && validate_secret "${EXISTING_SECRET}"; then
  SECRET="${EXISTING_SECRET}"
  info "🔑 Используем существующий секрет из ${CONFIG_FILE}"
else
  if [ "${REGEN_SECRET}" -eq 1 ]; then
    warn "🔁 Принудительная генерация нового секрета (--regen-secret)"
  elif [ -n "${EXISTING_SECRET}" ]; then
    warn "⚠️ Найден невалидный SECRET в ${CONFIG_FILE}, генерируем новый"
  fi
  SECRET="$(generate_secret)"
  info "🔑 Новый секрет сгенерирован"
fi

if ! pick_free_port; then
  err "Все порты заняты: 443, 8443, 8444, 8445"
  exit 1
fi
echo "🔌 Используем порт: ${PORT}"

echo -n "🛑 Остановка старого контейнера... "
docker stop "${CONTAINER_NAME}" >/dev/null 2>&1 || true
docker rm "${CONTAINER_NAME}" >/dev/null 2>&1 || true
echo -e "${GREEN}готово${NC}"

echo -n "📦 Запуск контейнера... "
docker run -d \
  --name "${CONTAINER_NAME}" \
  --restart unless-stopped \
  -p "${PORT}:443" \
  -e SECRET="${SECRET}" \
  telegrammessenger/proxy >/dev/null
echo -e "${GREEN}готово${NC}"

sleep 2
if ! container_is_running; then
  err "❌ Контейнер не запущен"
  docker logs "${CONTAINER_NAME}" || true
  exit 1
fi

SERVER_IP="$(fetch_public_ip || true)"
if [ -z "${SERVER_IP}" ]; then
  warn "Не удалось определить внешний IP автоматически. Укажите сервер вручную."
  SERVER_IP="YOUR_SERVER_IP"
fi

LINK="tg://proxy?server=${SERVER_IP}&port=${PORT}&secret=${SECRET}"
save_config_atomically "${SERVER_IP}" "${LINK}"

echo -e "${GREEN}✅ УСПЕШНО${NC}"
echo ""
echo "📊 ИНФОРМАЦИЯ ДЛЯ ПОДКЛЮЧЕНИЯ:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🌐 Сервер: ${SERVER_IP}"
echo "🔌 Порт: ${PORT}"
echo "🔑 Секрет: ${SECRET}"
echo "🌐 Fake TLS домен: ${FAKE_DOMAIN}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔗 Ссылка для Telegram:"
echo -e "${GREEN}${LINK}${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Конфигурация сохранена в ${CONFIG_FILE}"
echo ""
echo "📋 Логи контейнера:"
docker logs --tail 5 "${CONTAINER_NAME}" || true
