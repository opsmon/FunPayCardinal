#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

echo "=== FunPayCardinal One-Click PaaS (Linux VM) ==="

if [[ "$(id -u)" -eq 0 ]]; then
  SUDO=()
else
  SUDO=(sudo)
fi

install_docker_if_needed() {
  if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    return
  fi

  echo
  echo "[1/6] Устанавливаю Docker и Docker Compose..."
  "${SUDO[@]}" apt-get update
  if ! "${SUDO[@]}" apt-get install -y docker.io docker-compose-plugin; then
    "${SUDO[@]}" apt-get install -y docker.io docker-compose-v2
  fi
  "${SUDO[@]}" systemctl enable --now docker
}

resolve_docker_cmd() {
  if docker info >/dev/null 2>&1; then
    DOCKER_CMD=(docker)
    return
  fi

  if command -v sudo >/dev/null 2>&1 && sudo docker info >/dev/null 2>&1; then
    DOCKER_CMD=(sudo docker)
    return
  fi

  echo "ERROR: Docker daemon недоступен. Проверьте, что Docker установлен и запущен."
  exit 1
}

prompt_non_empty() {
  local prompt="$1"
  local value=""
  while [[ -z "$value" ]]; do
    read -r -p "$prompt" value
  done
  printf "%s" "$value"
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

validate_golden_key() {
  local key="$1"
  [[ ${#key} -eq 32 ]]
}

validate_token() {
  local token="$1"
  [[ "$token" =~ ^[0-9]+:[A-Za-z0-9_-]+$ ]]
}

validate_password() {
  local password="$1"
  [[ ${#password} -ge 8 ]] && [[ "$password" =~ [A-Z] ]] && [[ "$password" =~ [a-z] ]] && [[ "$password" =~ [0-9] ]]
}

build_user_agent() {
  if [[ -n "${FPC_USER_AGENT:-}" ]]; then
    printf "%s" "$FPC_USER_AGENT"
    return
  fi

  local os_name arch platform
  os_name="$(uname -s 2>/dev/null || echo Linux)"
  arch="$(uname -m 2>/dev/null || echo x86_64)"

  case "$os_name" in
    Linux)
      case "$arch" in
        x86_64|amd64) platform="X11; Linux x86_64" ;;
        aarch64|arm64) platform="X11; Linux aarch64" ;;
        *) platform="X11; Linux x86_64" ;;
      esac
      ;;
    Darwin)
      case "$arch" in
        arm64|aarch64) platform="Macintosh; Intel Mac OS X 10_15_7" ;;
        *) platform="Macintosh; Intel Mac OS X 10_15_7" ;;
      esac
      ;;
    MINGW*|MSYS*|CYGWIN*|Windows_NT)
      platform="Windows NT 10.0; Win64; x64"
      ;;
    *)
      platform="X11; Linux x86_64"
      ;;
  esac

  printf "Mozilla/5.0 (%s) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36" "$platform"
}

install_docker_if_needed
resolve_docker_cmd

echo
echo "[2/6] Подготавливаю папки проекта..."
mkdir -p configs logs storage plugins
touch configs/auto_response.cfg configs/auto_delivery.cfg

if [[ ! -f configs/_main.cfg ]]; then
  echo
  echo "[3/6] Первый запуск: введите 3 значения."
  echo "Нужны: FunPay golden_key, Telegram bot token, пароль для входа в бота."
  echo

  GOLDEN_KEY=""
  while true; do
    GOLDEN_KEY="$(prompt_non_empty "FunPay golden_key (32 символа): ")"
    if validate_golden_key "$GOLDEN_KEY"; then
      break
    fi
    echo "Неверно: golden_key должен быть ровно 32 символа."
  done

  TG_TOKEN=""
  while true; do
    TG_TOKEN="$(prompt_non_empty "Telegram token (формат 123:ABC...): ")"
    if validate_token "$TG_TOKEN"; then
      break
    fi
    echo "Неверно: токен должен быть в формате 123456:ABCDEF..."
  done

  BOT_PASSWORD=""
  while true; do
    BOT_PASSWORD="$(prompt_secret "Пароль для Telegram-бота: ")"
    if validate_password "$BOT_PASSWORD"; then
      break
    fi
    echo "Пароль должен быть >=8 символов, с заглавной, строчной и цифрой."
  done

  read -r -p "Язык (ru/en/uk, Enter=ru): " FPC_LANG
  FPC_LANG="${FPC_LANG:-ru}"
  if [[ "$FPC_LANG" != "ru" && "$FPC_LANG" != "en" && "$FPC_LANG" != "uk" ]]; then
    FPC_LANG="ru"
  fi

  USER_AGENT="$(build_user_agent)"
  echo "User-Agent выбран автоматически: $USER_AGENT"

  echo
  echo "[4/6] Собираю образ..."
  "${DOCKER_CMD[@]}" compose build

  echo "[5/6] Генерирую безопасный хеш пароля..."
  SECRET_KEY_HASH="$("${DOCKER_CMD[@]}" compose run --rm --no-deps \
    -e FPC_PASSWORD="$BOT_PASSWORD" \
    --entrypoint python funpaycardinal \
    -c 'import os,bcrypt; print(bcrypt.hashpw(os.environ["FPC_PASSWORD"].encode(), bcrypt.gensalt()).decode())')"

  cat > configs/_main.cfg <<EOF
[FunPay]
golden_key: $GOLDEN_KEY
user_agent: $USER_AGENT
autoRaise: 0
autoResponse: 0
autoDelivery: 0
multiDelivery: 0
autoRestore: 0
autoDisable: 0
oldMsgGetMode: 0
keepSentMessagesUnread: 0
locale: ru

[Telegram]
enabled: 1
token: $TG_TOKEN
secretKeyHash: $SECRET_KEY_HASH
blockLogin: 0

[BlockList]
blockDelivery: 0
blockResponse: 0
blockNewMessageNotification: 0
blockNewOrderNotification: 0
blockCommandNotification: 0

[NewMessageView]
includeMyMessages: 1
includeFPMessages: 1
includeBotMessages: 0
notifyOnlyMyMessages: 0
notifyOnlyFPMessages: 0
notifyOnlyBotMessages: 0
showImageName: 1

[Greetings]
ignoreSystemMessages: 0
onlyNewChats: 0
sendGreetings: 0
greetingsText: Привет, \$chat_name!
greetingsCooldown: 2

[OrderConfirm]
watermark: 1
sendReply: 0
replyText: \$username, спасибо за подтверждение заказа \$order_id!

[ReviewReply]
star1Reply: 0
star2Reply: 0
star3Reply: 0
star4Reply: 0
star5Reply: 0
star1ReplyText:
star2ReplyText:
star3ReplyText:
star4ReplyText:
star5ReplyText:

[Proxy]
enable: 0
ip:
port:
login:
password:
check: 0

[Other]
watermark: bird
requestsDelay: 4
language: $FPC_LANG
EOF
fi

echo
echo "[6/6] Запускаю сервис..."
"${DOCKER_CMD[@]}" compose up -d --build

echo
echo "ГОТОВО"
echo "Статус:"
"${DOCKER_CMD[@]}" compose ps
echo
echo "Логи:"
echo "  ${DOCKER_CMD[*]} compose logs -f funpaycardinal"
echo "Остановить:"
echo "  ${DOCKER_CMD[*]} compose down"
