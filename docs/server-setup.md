# Конфигурация виртуальной машины devops-vm



## 1. Параметры машины

- ОЗУ: 2048 МБ

- CPU: 2 ядра

- Диск: 25 ГБ (динамически расширяемый)



## 2. Сетевые интерфейсы

- Адаптер 1 (NAT): 10.0.2.15 (обеспечивает доступ в Интернет для обновлений)

- Адаптер 2 (Host-only): 192.168.56.101 (обеспечивает прямой доступ с хостовой системы)



## 3. Правило проброса портов

- Протокол: TCP

- Порт хостовой системы: 2222

- Порт гостевой системы: 2222 (изменено с 22 после hardening)



## 4. Учётные записи

- `student`: первичный пользователь, состоит в группе sudo, аутентификация по паролю.

- `devops`: рабочий пользователь, состоит в группе sudo, аутентификация только по ключу.



## 5. Служба SSH

- Порт: 2222

- Файл конфигурации: `/etc/ssh/sshd\_config.d/99-hardening.conf`

- Ключевые директивы: `PermitRootLogin no`, `PasswordAuthentication no`, `MaxAuthTries 3`, `AllowUsers devops`.



## 6. Правила межсетевого экрана (UFW)

- Политики по умолчанию: `deny` (incoming), `allow` (outgoing).

- Правила: `LIMIT` для порта 2222/tcp (SSH), `ALLOW` для 80/tcp (HTTP), `ALLOW` для 443/tcp (HTTPS).



## 7. Снимки состояния

- `01-clean-install`: создан после первоначальной установки ОС и обновления.

- `02-keys-configured`: создан после настройки ключевой аутентификации для пользователя devops.

- `03-ssh-hardened`: создан после усиления защиты SSH и настройки UFW.


## 8. Веб-сервер
- Устанавливаемый пакет: `nginx`
- Путь к конфигурации ресурса: `/etc/nginx/sites-available/devops-site`
- Каталог ресурса: `/var/www/devops-site`, владелец: `devops:devops`, права: каталоги 755, файлы 644.
- Сертификат: `/etc/ssl/certs/devops.crt` (права 644), Ключ: `/etc/ssl/private/devops.key` (права 600, владелец root).
- Команда формирования: `sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/devops.key -out /etc/ssl/certs/devops.crt -subj "/CN=devops.local" -addext "subjectAltName=DNS:devops.local"`
- Срок действия: 365 дней.


## 9. Контейнеризация
- Способ установки Docker Engine: официальный репозиторий Docker (download.docker.com), пакет `docker.io` не использовался.
- Версия Docker Engine: 29.9.1.
- Плагин Compose: v5.6.0.
- Участники группы docker: `devops`.
- Расположение проекта на сервере: `~/app`.
- Расположение файла `.env`: `~/app/.env`, права `600`, в репозитории отсутствует (хранится только шаблон `.env.example`).
- Публикуемые порты: `127.0.0.1:5000` (только локальный интерфейс). Порт СУБД 5432 не публикуется.
- Обратный прокси: блок `location /app/` в `/etc/nginx/sites-available/devops-site` направляет запросы на `http://127.0.0.1:5000/` с пробросом заголовков Host, X-Real-IP, X-Forwarded-For и X-Forwarded-Proto.


## 10. Ansible

**Расположение проекта:** `~/devops-course-2026/ansible` в WSL.

**Узлы:**
- Управляющий: WSL (Ubuntu) на хостовой Windows 11 системе
- Управляемый: VM `devops-vm` на VirtualBox, сеть Host-only

**Inventory:**
- `inventory/bootstrap.ini` — первичный запуск от пользователя `student` с `--ask-pass --ask-become-pass`
- `inventory/prod.ini` — последующие запуски от `devops` по ключу `~/.ssh/devops_vm`

**Роли:**
- `base` — проверка ОС, базовые пакеты, Docker Engine из официального репозитория
- `ssh` — пользователь `devops`, SSH-ключ, sudo NOPASSWD, hardening SSH, UFW
- `nginx` — reverse proxy на контейнер приложения
- `app` — загрузка образа GHCR, запуск контейнера, health-check

**GHCR-образ:**
- Адрес: `ghcr.io/coldw1nd/devops-ci-app`
- Текущий SHA: `5ede5ebefa66279722eaa1d91ba764b886d5db96` (обновляется при смене версии)
- Порт контейнера: 5000 (привязан к 127.0.0.1)
- Health endpoint: `/health`

**Команды:**
```bash
# Первичная настройка
ansible-playbook -i inventory/bootstrap.ini site.yml --ask-pass --ask-become-pass

# Повторный запуск (идемпотентный)
ansible-playbook site.yml

# Read-only аудит
ansible-playbook verify.yml
```

Пароли и закрытый ключ в документ не включены.

