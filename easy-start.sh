#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

echo "===> FunPayCardinal Docker Easy Start"

if ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: Docker не найден. Установите Docker Desktop/Engine и повторите."
  exit 1
fi

DOCKER_CMD=(docker)
if ! docker info >/dev/null 2>&1; then
  if command -v sudo >/dev/null 2>&1 && sudo docker info >/dev/null 2>&1; then
    DOCKER_CMD=(sudo docker)
    echo "INFO: Использую sudo для Docker команд."
  else
    echo "ERROR: Docker daemon недоступен. Запустите Docker и/или проверьте права пользователя."
    exit 1
  fi
fi

mkdir -p configs logs storage plugins

if [ ! -f "configs/_main.cfg" ]; then
  echo
  echo "Не найден configs/_main.cfg."
  echo "Сейчас запустится первичная настройка (first_setup) в интерактивном режиме."
  echo "Введите свои данные (golden_key, Telegram token и т.д.)."
  echo
  "${DOCKER_CMD[@]}" compose run --rm funpaycardinal
fi

echo
echo "Запускаю контейнер в фоне..."
"${DOCKER_CMD[@]}" compose up -d --build

echo
echo "Готово. Текущий статус:"
"${DOCKER_CMD[@]}" compose ps

echo
echo "Полезные команды:"
echo "  Логи:      ${DOCKER_CMD[*]} compose logs -f funpaycardinal"
echo "  Остановить: ${DOCKER_CMD[*]} compose down"
