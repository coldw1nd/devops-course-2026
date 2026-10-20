#!/usr/bin/env bash
# Доставка статического ресурса на devops-vm
set -euo pipefail

REMOTE="devops"
REMOTE_DIR="/var/www/devops-site"
SITE_URL="https://devops.local"
CA_CERT="${HOME}/devops.crt"
# Определяем корень репозитория, чтобы скрипт работал из любой папки
LOCAL_DIR="$(git rev-parse --show-toplevel)/site/"

DRY_RUN=""
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN="--dry-run"
fi

# Требование 4: Проверка наличия index.html
if [[ ! -f "${LOCAL_DIR}index.html" ]]; then
    echo "Ошибка: файл site/index.html отсутствует!" >&2
    exit 1
fi

# Требование 5: Проверка на незафиксированные изменения
if [[ -n "$(git status --porcelain)" ]]; then
    echo "Ошибка: в репозитории есть незафиксированные изменения!" >&2
    exit 1
fi

# Требование 3 и 8: Синхронизация (один SSH-сеанс благодаря rsync)
# BatchMode=yes гарантирует, что скрипт не будет ждать ввода пароля (Требование 9)
rsync -avz --delete --chmod=D755,F644 $DRY_RUN -e "ssh -o BatchMode=yes -o ConnectTimeout=5" "${LOCAL_DIR}" "${REMOTE}:${REMOTE_DIR}/"

# Требование 4: Если dry-run, завершаемся успешно до проверки
if [[ -n "$DRY_RUN" ]]; then
    echo "Деплой в режиме dry-run завершен."
    exit 0
fi

# Требование 6: Проверка доступности ресурса (curl -f завершится с ошибкой, если не 2xx)
if ! curl -sf --cacert "$CA_CERT" "$SITE_URL" > /dev/null; then
    echo "Ошибка: ресурс $SITE_URL недоступен после деплоя!" >&2
    exit 1
fi

# Требование 7: Успешное завершение с хешем коммита
COMMIT_HASH=$(git rev-parse --short HEAD)
echo "Деплой успешно завершен. Доставлен коммит: $COMMIT_HASH"
exit 0