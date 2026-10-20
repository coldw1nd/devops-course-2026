\# Конфигурация виртуальной машины devops-vm



\## 1. Параметры машины

\- ОЗУ: 2048 МБ

\- CPU: 2 ядра

\- Диск: 25 ГБ (динамически расширяемый)



\## 2. Сетевые интерфейсы

\- Адаптер 1 (NAT): 10.0.2.15 (обеспечивает доступ в Интернет для обновлений)

\- Адаптер 2 (Host-only): 192.168.56.101 (обеспечивает прямой доступ с хостовой системы)



\## 3. Правило проброса портов

\- Протокол: TCP

\- Порт хостовой системы: 2222

\- Порт гостевой системы: 2222 (изменено с 22 после hardening)



\## 4. Учётные записи

\- `student`: первичный пользователь, состоит в группе sudo, аутентификация по паролю.

\- `devops`: рабочий пользователь, состоит в группе sudo, аутентификация только по ключу.



\## 5. Служба SSH

\- Порт: 2222

\- Файл конфигурации: `/etc/ssh/sshd\_config.d/99-hardening.conf`

\- Ключевые директивы: `PermitRootLogin no`, `PasswordAuthentication no`, `MaxAuthTries 3`, `AllowUsers devops`.



\## 6. Правила межсетевого экрана (UFW)

\- Политики по умолчанию: `deny` (incoming), `allow` (outgoing).

\- Правила: `LIMIT` для порта 2222/tcp (SSH), `ALLOW` для 80/tcp (HTTP), `ALLOW` для 443/tcp (HTTPS).



\## 7. Снимки состояния

\- `01-clean-install`: создан после первоначальной установки ОС и обновления.

\- `02-keys-configured`: создан после настройки ключевой аутентификации для пользователя devops.

\- `03-ssh-hardened`: создан после усиления защиты SSH и настройки UFW.


## 8. Веб-сервер
- Устанавливаемый пакет: `nginx`
- Путь к конфигурации ресурса: `/etc/nginx/sites-available/devops-site`
- Каталог ресурса: `/var/www/devops-site`, владелец: `devops:devops`, права: каталоги 755, файлы 644.
- Сертификат: `/etc/ssl/certs/devops.crt` (права 644), Ключ: `/etc/ssl/private/devops.key` (права 600, владелец root).
- Команда формирования: `sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/devops.key -out /etc/ssl/certs/devops.crt -subj "/CN=devops.local" -addext "subjectAltName=DNS:devops.local"`
- Срок действия: 365 дней.