# MTProxy + systemd (Ubuntu)

Краткая инструкция для первого запуска проекта на чистом сервере.

`start-mtproxy.sh` запускает контейнер через `docker run -d`, поэтому сервис в `systemd` должен быть `Type=oneshot`.

## 1. Установить Docker (Ubuntu)

```bash
sudo apt update
sudo apt install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable --now docker
docker --version
```

## 2. Клонировать репозиторий

```bash
cd ~
sudo apt install -y git
git clone https://github.com/foxweb/mtproxy.git
cd mtproxy
```

## 3. Подготовить проект

```bash
chmod +x start-mtproxy.sh
```

Важно: в `start-mtproxy.sh` не должно быть `sudo`.

## 4. Создать unit-файл

ВНИМАНИЕ! Выставьте верный путь для вашей системы, замените `/home/username/mtproxy` на свой вариант.

Вариант A (создать вручную):

```bash
sudo nano /etc/systemd/system/mtproxy.service
```

Вставьте:

```ini
[Unit]
Description=MTProxy service
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
User=root
WorkingDirectory=/home/username/mtproxy            # выставьте верный путь
ExecStart=/home/username/mtproxy/start-mtproxy.sh  # выставьте верный путь
RemainAfterExit=yes
Restart=no
ExecStop=/usr/bin/docker stop mtproto-proxy

[Install]
WantedBy=multi-user.target
```

Вариант B (скопировать из проекта):

```bash
sudo cp ~/mtproxy/mtproxy.service /etc/systemd/system/mtproxy.service
```

## 5. Включить и запустить сервис

```bash
sudo systemctl daemon-reload
sudo systemctl enable mtproxy.service
sudo systemctl restart mtproxy.service
```

## 6. Проверка

```bash
systemctl status mtproxy.service --no-pager -l
docker ps | rg mtproto-proxy
journalctl -u mtproxy.service -n 100 --no-pager
```

Для `oneshot` нормальный статус: `Active: active (exited)`.
Главный признак, что все работает: контейнер `mtproto-proxy` есть в `docker ps`.

## Лицензия

MIT. Полный текст и дополнительные дисклеймеры: `LICENSE`.
