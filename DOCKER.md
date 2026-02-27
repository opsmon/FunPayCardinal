# Docker guide for FunPayCardinal

Ниже инструкция, как полностью запустить FunPayCardinal в Docker и не потерять данные между перезапусками.

## 1. Что уже добавлено в репозиторий

- `Dockerfile` - собирает образ на базе `python:3.11-slim`.
- `docker-compose.yml` - сервис с авто-рестартом и volume для данных.
- `.dockerignore` - исключает лишние и чувствительные файлы из контекста сборки.

## 2. Требования

- Docker Engine 24+ (или совместимая версия).
- Docker Compose V2 (`docker compose`).

Проверка:

```bash
docker --version
docker compose version
```

## 3. Подготовка проекта

В корне репозитория (`FunPayCardinal`) создайте каталоги для персистентных данных:

```bash
mkdir -p configs logs storage plugins
```

Важно:
- `configs` - конфиги, включая `configs/_main.cfg`.
- `storage` - кеш, товары, служебные данные.
- `logs` - логи.
- `plugins` - пользовательские плагины.

Без этих volume данные теряются при удалении контейнера.

## 4. Сборка образа

```bash
docker compose build
```

## 5. Первый запуск (интерактивный first_setup)

Если `configs/_main.cfg` еще не создан, приложение запускает интерактивный мастер в консоли.

Запуск:

```bash
docker compose run --rm funpaycardinal
```

Что происходит:
- Контейнер стартует.
- В консоли появятся вопросы `first_setup()` (golden_key, Telegram token, пароль и т.д.).
- По завершении будет создан `configs/_main.cfg` в локальной папке проекта.

После этого можно переходить на обычный фоновый запуск.

## 6. Обычный запуск (в фоне)

```bash
docker compose up -d
```

Проверка состояния:

```bash
docker compose ps
```

Логи:

```bash
docker compose logs -f funpaycardinal
```

Остановка:

```bash
docker compose down
```

## 7. Обновление после изменений в репозитории

```bash
docker compose down
docker compose build --no-cache
docker compose up -d
```

Данные в `configs/logs/storage/plugins` сохранятся.

## 8. Быстрый run-вариант без compose (опционально)

Сборка:

```bash
docker build -t funpaycardinal:local .
```

Запуск:

```bash
docker run -d \
  --name funpaycardinal \
  --restart unless-stopped \
  -v "$(pwd)/configs:/app/configs" \
  -v "$(pwd)/logs:/app/logs" \
  -v "$(pwd)/storage:/app/storage" \
  -v "$(pwd)/plugins:/app/plugins" \
  -e TZ=Europe/Moscow \
  funpaycardinal:local
```

## 9. Резервное копирование

Достаточно бэкапить каталоги:

- `configs/`
- `storage/`
- `plugins/`

`logs/` обычно можно не бэкапить.

## 10. Типовые проблемы

1. Контейнер сразу завершается.
   Причина: не пройден `first_setup` и нет `configs/_main.cfg`.
   Решение: выполнить интерактивный запуск `docker compose run --rm funpaycardinal`.

2. Ошибки записи в volume.
   Причина: права на директории хоста.
   Решение: выдать права на запись текущему пользователю для `configs logs storage plugins`.

3. Не обновились зависимости/код.
   Причина: старый слой образа.
   Решение: `docker compose build --no-cache` и затем `docker compose up -d`.

4. Ввели неправильные `golden_key` / `Telegram token` / пароль.
   Признак: в логах ошибки `Unauthorized`, `401`, бот не инициализируется.
   Решение:
   `docker compose down`
   `rm -f configs/_main.cfg`
   затем запустить настройку заново:
   `docker compose run --rm funpaycardinal`
