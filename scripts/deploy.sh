#!/usr/bin/env bash
set -e

REMOTE="devops@127.0.0.1"
SSH_PORT="2222"
SSH_KEY="~/.ssh/devops_vm"
REMOTE_DIR="/var/www/devops-site"
SITE_URL="https://devops.local"
CA_CERT="${HOME}/devops.crt"
LOCAL_DIR="$(pwd)/site/"

DRY_RUN=0
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=1
fi

echo "=== Проверка наличия index.html ==="
if [ ! -f "${LOCAL_DIR}index.html" ]; then
    echo "Ошибка: Файл site/index.html не найден!" >&2
    exit 1
fi

echo "=== Проверка незафиксированных изменений ==="
if [ -n "$(git status --porcelain)" ]; then
    echo "Ошибка: Есть незафиксированные изменения. Сделайте коммит." >&2
    exit 1
fi

if [ "$DRY_RUN" -eq 1 ]; then
    echo "=== Режим DRY-RUN ==="
    echo "Будут скопированы файлы:"
    ls -la "${LOCAL_DIR}"
    echo "Скрипт завершен без изменений на сервере."
    exit 0
fi

echo "=== Синхронизация файлов (scp) ==="
scp -P 2222 -i "$HOME/.ssh/devops_vm" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -r "${LOCAL_DIR}"* devops@127.0.0.1:${REMOTE_DIR}/

echo "=== Установка прав ==="
ssh -p 2222 -i "$HOME/.ssh/devops_vm" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null devops@127.0.0.1 "sudo chmod 755 ${REMOTE_DIR} && sudo chmod 644 ${REMOTE_DIR}/*"

echo "=== Проверка доступности сайта ==="
if curl.exe --cacert "${CA_CERT}" -f -s -o /dev/null "${SITE_URL}"; then
    echo "Успех: Сайт доступен по адресу ${SITE_URL}"
    echo "Коммит: $(git rev-parse --short HEAD)"
    exit 0
else
    echo "Ошибка: Сайт недоступен!" >&2
    exit 1
fi