#!/bin/bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="${REPO_ROOT}/mtproxy.service.in"
TARGET="/etc/systemd/system/mtproxy.service"

if [ ! -f "${TEMPLATE}" ]; then
  echo "Не найден шаблон: ${TEMPLATE}" >&2
  exit 1
fi

# Подстановка абсолютного пути к репозиторию (# — разделитель, чтобы пути с / не ломали sed)
sed "s#@REPO@#${REPO_ROOT}#g" "${TEMPLATE}" | sudo tee "${TARGET}" >/dev/null

echo "Установлено: ${TARGET}"
echo "Репозиторий: ${REPO_ROOT}"
echo ""
echo "Дальше:"
echo "  sudo systemctl daemon-reload"
echo "  sudo systemctl enable mtproxy.service"
echo "  sudo systemctl restart mtproxy.service"
