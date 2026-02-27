# Docker запуск для совсем новичка (Windows)

## Кратко: что такое Docker и зачем он нужен

Docker — это способ запускать программу в "коробке" (контейнере), где уже есть все нужные библиотеки и настройки.

Почему это удобно:
- не нужно вручную ставить Python и зависимости;
- меньше ошибок "у меня не запускается";
- легко перенести на другой ПК/сервер;
- обновление и перезапуск делаются парой команд.

Для вас это значит: запускаете один скрипт, вводите свои данные, и бот работает.

## Полный путь с нуля

1. Установить Git:
https://git-scm.com/download/win

2. Установить Docker Desktop:
https://www.docker.com/products/docker-desktop/

3. Запустить Docker Desktop и дождаться статуса `Engine running`.

4. Открыть `PowerShell` и выполнить:

```powershell
cd $HOME
git clone https://github.com/sidor0912/FunPayCardinal.git
cd .\FunPayCardinal
.\paas-one-click.bat
```

5. Ввести только:
- `golden_key` FunPay
- `Telegram token`
- пароль для Telegram-бота

Скрипт сделает остальное сам: создаст конфиг, соберет образ и запустит контейнер.

## Альтернатива через PowerShell

Если нужно вручную:

```powershell
.\paas-one-click.ps1
```

Если PowerShell блокирует запуск:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\paas-one-click.ps1
```

## После запуска

Проверить статус:

```powershell
docker compose ps
```

Логи:

```powershell
docker compose logs -f funpaycardinal
```

Остановить:

```powershell
docker compose down
```

## Если что-то не работает

1. Ошибка `git not found`:
   Git не установлен или PowerShell перезапустить после установки.

2. Ошибка `docker not found`:
   Docker Desktop не установлен или не добавлен в PATH.

3. Ошибка `Docker daemon недоступен`:
   Docker Desktop не запущен.

4. Нужно обновить после `git pull`:

```powershell
cd $HOME\FunPayCardinal
git pull
docker compose down
docker compose up -d --build
```

## Если ввели данные неправильно

Признак: в логах есть ошибки `Unauthorized`, `401` или бот не работает как ожидалось.

1. Остановить контейнер:

```powershell
docker compose down
```

2. Удалить неверный конфиг:

```powershell
Remove-Item .\configs\_main.cfg
```

3. Запустить настройку заново:

```powershell
.\paas-one-click.bat
```

4. Проверить логи:

```powershell
docker compose logs -f funpaycardinal
```

## FAQ (частые вопросы)

1. Как безопасно поменять пароль для входа в Telegram-бота?

Откройте `Git Bash` в папке проекта и выполните:

```powershell
cd $HOME\FunPayCardinal
bash ./easy-start.sh --reset-password
```

Команда сама:
- запросит новый пароль;
- сгенерирует корректный `bcrypt`-хеш;
- обновит `secretKeyHash` в `configs/_main.cfg`;
- перезапустит контейнер.

2. Почему нельзя править `secretKeyHash` руками?

Потому что это хеш с символами `$`. При ручной замене через shell его легко сломать, и бот перестает принимать пароль.

3. Как понять, что пароль принят?

После отправки пароля боту в логе исчезают сообщения про неавторизованный доступ, и создается файл `storage/cache/tg_authorized_users.json`.

---

# Docker запуск для совсем новичка (Linux VM)

## Полный путь с нуля (Ubuntu/Debian)

1. Подключиться к ВМ и выполнить:

```bash
sudo apt update
sudo apt install -y git
cd ~
git clone https://github.com/sidor0912/FunPayCardinal.git
cd FunPayCardinal
```

2. Запустить one-click скрипт:

```bash
bash paas-one-click.sh
```

3. Ввести только:
- `golden_key` FunPay
- `Telegram token`
- пароль для Telegram-бота

Скрипт сам:
- установит Docker и Compose (если их нет);
- создаст нужные папки;
- создаст `configs/_main.cfg`;
- соберет и запустит контейнер.

## После запуска

Проверить статус:

```bash
docker compose ps
```

Логи:

```bash
docker compose logs -f funpaycardinal
```

Остановить:

```bash
docker compose down
```

## Если что-то не работает

1. Скрипт просит пароль `sudo`:
   это нормально, он ставит Docker/Compose.

2. Docker daemon не запущен:

```bash
sudo systemctl start docker
```

3. Нужно обновить после `git pull`:

```bash
cd ~/FunPayCardinal
git pull
docker compose down
docker compose up -d --build
```

## Если ввели данные неправильно

Признак: в логах `Unauthorized`, `401` или бот не отвечает корректно.

1. Остановить контейнер:

```bash
docker compose down
```

2. Удалить неверный конфиг:

```bash
rm -f configs/_main.cfg
```

3. Запустить настройку заново:

```bash
bash paas-one-click.sh
```

4. Проверить логи:

```bash
docker compose logs -f funpaycardinal
```

## FAQ (частые вопросы)

1. Как безопасно поменять пароль для входа в Telegram-бота?

```bash
cd ~/FunPayCardinal
bash ./easy-start.sh --reset-password
```

Команда сама:
- запросит новый пароль;
- сгенерирует корректный `bcrypt`-хеш;
- обновит `secretKeyHash` в `configs/_main.cfg`;
- перезапустит контейнер.

2. Почему нельзя править `secretKeyHash` руками?

Потому что это хеш с символами `$`. При ручной замене через shell его легко сломать, и бот перестает принимать пароль.

3. Как понять, что пароль принят?

После отправки пароля боту в логе исчезают сообщения про неавторизованный доступ, и создается файл `storage/cache/tg_authorized_users.json`.
