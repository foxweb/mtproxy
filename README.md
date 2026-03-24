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

## 3. Быстрый запуск без сервиса (для ленивых)

Если автозапуск не нужен, можно запустить прокси вручную одной командой:

```bash
cd ~/mtproxy
sudo ./start-mtproxy.sh
```

Ссылка `tg://...` будет в выводе скрипта и в файле:

```bash
grep -o '^LINK=.*' ./mtproto_config.txt | cut -d= -f2-
```

Секрет сохраняется в `./mtproto_config.txt` (в папке проекта) и при следующих запусках переиспользуется.

Повторный запуск:

```bash
cd ~/mtproxy
sudo ./start-mtproxy.sh
```

Принудительно сгенерировать новый секрет:

```bash
cd ~/mtproxy
sudo ./start-mtproxy.sh --regen-secret
```

Показать только ссылку без перезапуска контейнера:

```bash
cd ~/mtproxy
./start-mtproxy.sh --show-link
```

Опционально можно задать переменные окружения:

```bash
FAKE_DOMAIN=google.com PORT=443 ./start-mtproxy.sh
```

## 4. Установка в качестве сервиса (демона)

Шаблон `mtproxy.service.in` содержит плейсхолдер `@REPO@`. Скрипт подставляет **абсолютный путь к каталогу репозитория** (где лежит `start-mtproxy.sh`) и записывает готовый unit в `/etc/systemd/system/mtproxy.service`.

```bash
cd ~/mtproxy
sudo ./install-mtproxy-service.sh
```

Вручную (эквивалентно скрипту):

```bash
cd ~/mtproxy
sed "s#@REPO@#$(pwd)#g" mtproxy.service.in | sudo tee /etc/systemd/system/mtproxy.service
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
docker ps | grep mtproto-proxy
journalctl -u mtproxy.service -n 100 --no-pager
```

Для `oneshot` нормальный статус: `Active: active (exited)`.
Главный признак, что все работает: контейнер `mtproto-proxy` есть в `docker ps`.

## 7. Как получить ссылку на прокси (`tg://...`)

Самый простой способ:

```bash
./start-mtproxy.sh --show-link
```

Скрипт также сохраняет данные в файл:

Из сохраненного файла:

```bash
cat ./mtproto_config.txt
grep -o '^LINK=.*' ./mtproto_config.txt | cut -d= -f2-
```

## Лицензия

MIT. Полный текст и дополнительные дисклеймеры: [LICENSE](LICENSE).

## Благодарности

За основу проекта взят пост на Хабре: [Настраиваем MTProto прокси с Fake TLS за 5 минут](https://habr.com/ru/articles/1010942/).

Спасибо автору публикации за понятный материал и исходную идею.
