#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

validate_password() {
  local password="$1"
  [[ ${#password} -ge 8 ]] && [[ "$password" =~ [A-Z] ]] && [[ "$password" =~ [a-z] ]] && [[ "$password" =~ [0-9] ]]
}

prompt_secret() {
  local prompt="$1"
  local value=""
  while [[ -z "$value" ]]; do
    read -r -s -p "$prompt" value
    echo
  done
  printf "%s" "$value"
}

reset_password() {
  local new_password new_hash

  if [ ! -f "configs/_main.cfg" ]; then
    echo "ERROR: Не найден configs/_main.cfg. Сначала выполните обычный запуск."
    exit 1
  fi

  echo "===> Сброс Telegram-пароля"
  while true; do
    new_password="$(prompt_secret "Новый пароль для Telegram-бота: ")"
    if validate_password "$new_password"; then
      break
    fi
    echo "Пароль должен быть >=8 символов, с заглавной, строчной и цифрой."
  done

  echo "Генерирую новый хеш пароля..."
  new_hash="$("${DOCKER_CMD[@]}" compose run --rm --no-deps \
    -e FPC_PASSWORD="$new_password" \
    --entrypoint python funpaycardinal \
    -c 'import os,bcrypt; print(bcrypt.hashpw(os.environ["FPC_PASSWORD"].encode(), bcrypt.gensalt()).decode())')"

  sed -i.bak "s|^secretKeyHash: .*|secretKeyHash: ${new_hash}|" configs/_main.cfg
  rm -f configs/_main.cfg.bak

  echo "Перезапускаю сервис..."
  "${DOCKER_CMD[@]}" compose up -d funpaycardinal
  "${DOCKER_CMD[@]}" compose restart funpaycardinal

  echo
  echo "Готово. Новый пароль применен."
  echo "Теперь отправьте этот пароль вашему Telegram-боту одним сообщением."
}

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

if [ "${1:-}" = "--reset-password" ]; then
  reset_password
  exit 0
fi

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
