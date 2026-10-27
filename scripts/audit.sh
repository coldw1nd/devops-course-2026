#!/usr/bin/env bash
set -uo pipefail
PASS=0; FAIL=0

check() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "$actual" == "$expected" ]]; then
        echo "  [OK] $desc"; ((PASS++))
    else
        echo "  [FAIL] $desc (ожидалось: '$expected', получено: '$actual')"; ((FAIL++))
    fi
}

echo "Аудит конфигурации: $(hostname -f), $(date '+%Y-%m-%d %H:%M')"

echo "[1] Служба SSH"
check "Вход от имени root запрещён" "no" "$(sudo sshd -T | awk '/^permitrootlogin/{print $2}')"
check "Парольная аутентификация отключена" "no" "$(sudo sshd -T | awk '/^passwordauthentication/{print $2}')"
check "Порт SSH нестандартный (не 22)" "2222" "$(sudo sshd -T | awk '/^port/{print $2}')"
check "MaxAuthTries = 3" "3" "$(sudo sshd -T | awk '/^maxauthtries/{print $2}')"

echo "[2] Межсетевой экран"
check "Межсетевой экран активен" "active" "$(sudo ufw status | awk '/^Status:/{print $2}')"
check "Политика incoming: deny" "deny" "$(sudo ufw status verbose | grep 'Default:' | awk '/deny \(incoming\)/{print "deny"}')"

echo "[3] Учётные записи"
awk -F: '$3>=1000 && $3<65534 {printf "  %s (uid=%s)\n", $1, $3}' /etc/passwd

echo "[4] Веб-сервер"
check "Служба nginx активна" "active" "$(systemctl is-active nginx)"
check "Конфигурация nginx синтаксически корректна" "nginx: the configuration file /etc/nginx/nginx.conf syntax is ok" "$(sudo nginx -t 2>&1 | head -n 1)"

# Проверка сертификата (перенаправляем вывод в /dev/null, оставляем только код возврата)
check "Сертификат истекает не ранее чем через 30 дней" "0" "$(openssl x509 -checkend 2592000 -noout -in /etc/ssl/certs/devops.crt >/dev/null 2>&1; echo $?)"

# Проверка прав (разбита на простые строки, чтобы избежать ошибок синтаксиса)
WW_COUNT=$(find /var/www/devops-site -perm -o+w 2>/dev/null | wc -l)
KEY_PERM=$(sudo stat -c '%a' /etc/ssl/private/devops.key 2>/dev/null)
if [[ "$WW_COUNT" -eq 0 && "$KEY_PERM" == "600" ]]; then
    PERM_CHECK="0"
else
    PERM_CHECK="1"
fi
check "Нет world-writable файлов и ключ имеет права 600" "0" "$PERM_CHECK"

echo "Пройдено: $PASS, не пройдено: $FAIL"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
echo "[6] Контрольная работа № 2"
REDIS_CONTAINER=$(docker compose --project-directory ~/kr2 ps -q redis)
check "Контейнер redis healthy" "healthy" "$(docker inspect -f '{{.State.Health.Status}}' $REDIS_CONTAINER 2>/dev/null || echo 'unknown')"
check "Порт 8002 опубликован только на 127.0.0.1" "127.0.0.1:8002" "$(docker compose --project-directory ~/kr2 port app 8002 2>/dev/null || echo 'none')"
check "Права файла ~/kr2/.env равны 600" "600" "$(stat -c '%a' ~/kr2/.env)"

if openssl x509 -checkend 2592000 -noout -in /etc/ssl/certs/kr2.crt > /dev/null; then CERT_OK="0"; else CERT_OK="1"; fi
check "Сертификат kr2.crt действителен > 30 дней" "0" "$CERT_OK"

if [ -L /etc/nginx/sites-enabled/kr2 ]; then LINK_OK="true"; else LINK_OK="false"; fi
check "Ресурс kr2 активирован в nginx" "true" "$LINK_OK"