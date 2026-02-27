$ErrorActionPreference = "Stop"

$RootDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $RootDir

Write-Host "=== FunPayCardinal One-Click PaaS (Windows) ==="

function Require-Docker {
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        Write-Host ""
        Write-Host "ERROR: Docker не найден."
        Write-Host "Установите Docker Desktop: https://www.docker.com/products/docker-desktop/"
        exit 1
    }

    try {
        docker info *> $null
    } catch {
        Write-Host ""
        Write-Host "ERROR: Docker daemon недоступен."
        Write-Host "Запустите Docker Desktop и повторите."
        exit 1
    }

    try {
        docker compose version *> $null
    } catch {
        Write-Host ""
        Write-Host "ERROR: Docker Compose (v2) недоступен."
        Write-Host "Обновите Docker Desktop."
        exit 1
    }
}

function Prompt-NonEmpty([string]$Message) {
    while ($true) {
        $value = Read-Host $Message
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            return $value.Trim()
        }
    }
}

function Prompt-Secret([string]$Message) {
    while ($true) {
        $secure = Read-Host $Message -AsSecureString
        $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
        try {
            $plain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
        } finally {
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
        }
        if (-not [string]::IsNullOrWhiteSpace($plain)) {
            return $plain
        }
    }
}

function Test-GoldenKey([string]$Key) {
    return ($Key.Length -eq 32)
}

function Test-TelegramToken([string]$Token) {
    return ($Token -match '^[0-9]+:[A-Za-z0-9_-]+$')
}

function Test-BotPassword([string]$Password) {
    if ($Password.Length -lt 8) { return $false }
    if ($Password -notmatch '[A-Z]') { return $false }
    if ($Password -notmatch '[a-z]') { return $false }
    if ($Password -notmatch '[0-9]') { return $false }
    return $true
}

Require-Docker

Write-Host ""
Write-Host "[1/5] Подготавливаю папки проекта..."
New-Item -ItemType Directory -Force -Path "configs", "logs", "storage", "plugins" | Out-Null
New-Item -ItemType File -Force -Path "configs/auto_response.cfg", "configs/auto_delivery.cfg" | Out-Null

if (-not (Test-Path "configs/_main.cfg")) {
    Write-Host ""
    Write-Host "[2/5] Первый запуск: введите 3 значения."
    Write-Host "Нужны: FunPay golden_key, Telegram token, пароль для входа в бота."
    Write-Host ""

    do {
        $GoldenKey = Prompt-NonEmpty "FunPay golden_key (32 символа)"
        if (-not (Test-GoldenKey $GoldenKey)) {
            Write-Host "Неверно: golden_key должен быть ровно 32 символа."
        }
    } until (Test-GoldenKey $GoldenKey)

    do {
        $TgToken = Prompt-NonEmpty "Telegram token (формат 123:ABC...)"
        if (-not (Test-TelegramToken $TgToken)) {
            Write-Host "Неверно: токен должен быть в формате 123456:ABCDEF..."
        }
    } until (Test-TelegramToken $TgToken)

    do {
        $BotPassword = Prompt-Secret "Пароль для Telegram-бота"
        if (-not (Test-BotPassword $BotPassword)) {
            Write-Host "Пароль должен быть >=8 символов, с заглавной, строчной и цифрой."
        }
    } until (Test-BotPassword $BotPassword)

    $FpcLang = Read-Host "Язык (ru/en/uk, Enter=ru)"
    if ([string]::IsNullOrWhiteSpace($FpcLang)) { $FpcLang = "ru" }
    if ($FpcLang -notin @("ru", "en", "uk")) { $FpcLang = "ru" }

    if ([string]::IsNullOrWhiteSpace($env:FPC_USER_AGENT)) {
        $UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
    } else {
        $UserAgent = $env:FPC_USER_AGENT
    }

    Write-Host ""
    Write-Host "[3/5] Собираю образ..."
    docker compose build

    Write-Host "[4/5] Генерирую безопасный хеш пароля..."
    $SecretKeyHash = (docker compose run --rm --no-deps -e "FPC_PASSWORD=$BotPassword" --entrypoint python funpaycardinal -c "import os,bcrypt; print(bcrypt.hashpw(os.environ['FPC_PASSWORD'].encode(), bcrypt.gensalt()).decode())" | Select-Object -Last 1).Trim()

    $config = @"
[FunPay]
golden_key: $GoldenKey
user_agent: $UserAgent
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
token: $TgToken
secretKeyHash: $SecretKeyHash
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
greetingsText: Привет, `$chat_name!
greetingsCooldown: 2

[OrderConfirm]
watermark: 1
sendReply: 0
replyText: `$username, спасибо за подтверждение заказа `$order_id!

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
language: $FpcLang
"@

    Set-Content -Path "configs/_main.cfg" -Value $config -Encoding UTF8
}

Write-Host ""
Write-Host "[5/5] Запускаю сервис..."
docker compose up -d --build

Write-Host ""
Write-Host "ГОТОВО"
docker compose ps
Write-Host ""
Write-Host "Логи: docker compose logs -f funpaycardinal"
Write-Host "Остановить: docker compose down"
