#!/usr/bin/env bash
# Minimal Bench 2026 • auto-installs Ookla speedtest (binary: speedtest)

RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[1;33m' BLUE='\033[0;36m' NC='\033[0m'

exists() { command -v "$1" >/dev/null 2>&1; }

hr() { printf '%-70s\n' | tr ' ' '-'; }

header() {
    echo -e "${BLUE}Minimal Bench • $(date '+%Y-%m-%d %H:%M')${NC}"
    hr
}

sysinfo() {
    local cpu=$(awk -F: '/model name/{print $2}' /proc/cpuinfo | head -1 | sed 's/^[ \t]*//;s/[ \t]*$//')
    [ -z "$cpu" ] && cpu="Unknown"
    echo -e "CPU : ${YELLOW}${cpu}${NC}"
    echo -e "    $(nproc) cores @ $(awk '/cpu MHz/{printf "%.0f MHz\n", $4; exit}' /proc/cpuinfo || echo "n/a")"
    echo -e "RAM : ${YELLOW}$(free -h | awk '/Mem:/{print $2 " total, " $3 " used"}')${NC}"
    echo -e "Disk: ${YELLOW}$(df -h / | awk 'NR==2{print $2 " total, " $3 " used"}')${NC}"
}

io_test() {
    local f=benchio_$$
    echo -n "Disk I/O (1GB write) ... "
    dd if=/dev/zero of="$f" bs=1M count=1024 conv=fdatasync status=none 2>&1 | tail -1 |
        awk '{printf "%s %s\n", $(NF-1), $NF}' | sed 's/(//;s/)//'
    rm -f "$f" 2>/dev/null || true
}

install_speedtest() {
    if exists speedtest; then
        echo -e "${GREEN}speedtest уже есть${NC}"
        return 0
    fi

    echo -e "${YELLOW}Качаем official Ookla Speedtest CLI (файл speedtest-cli в архиве)...${NC}"

    local arch=$(uname -m)
    local file=""
    case "$arch" in
        x86_64)          file="ookla-speedtest-1.2.0-linux-x86_64.tgz" ;;
        aarch64|arm64)   file="ookla-speedtest-1.2.0-linux-aarch64.tgz" ;;
        armv7l|armv7|armhf) file="ookla-speedtest-1.2.0-linux-armhf.tgz" ;;
        armv6l|armel)    file="ookla-speedtest-1.2.0-linux-armel.tgz" ;;
        i386|i686)       file="ookla-speedtest-1.2.0-linux-i386.tgz" ;;
        *) echo -e "${RED}Архитектура не поддерживается: $arch${NC}"; return 1 ;;
    esac

    local url="https://install.speedtest.net/app/cli/$file"
    local tmp="st_$$.tgz"

    if ! curl -fsL --connect-timeout 12 "$url" -o "$tmp"; then
        echo -e "${RED}Не скачалось с https://install.speedtest.net${NC}"
        rm -f "$tmp" 2>/dev/null
        return 1
    fi

    tar xzf "$tmp" >/dev/null 2>&1 || { echo -e "${RED}Ошибка распаковки${NC}"; rm -f "$tmp"; return 1; }

    # В архиве бинарник называется speedtest (не speedtest-cli)
    if [ ! -f speedtest ]; then
        echo -e "${RED}В архиве нет файла speedtest${NC}"
        rm -f "$tmp" *.md LICENSE* 2>/dev/null
        return 1
    fi

    chmod +x speedtest

    if [ -w /usr/local/bin ] 2>/dev/null; then
        mv speedtest /usr/local/bin/ 2>/dev/null && echo -e "${GREEN}Установлен → /usr/local/bin/speedtest${NC}"
    else
        mkdir -p ~/bin 2>/dev/null
        mv speedtest ~/bin/speedtest
        echo -e "${YELLOW}Установлен → ~/bin/speedtest${NC}"
        echo -e "${YELLOW}Добавь в PATH один раз:${NC}  echo 'export PATH=\"\$HOME/bin:\$PATH\"' >> ~/.bashrc && source ~/.bashrc"
    fi

    rm -f "$tmp" *.md LICENSE* 2>/dev/null

    # Принимаем лицензию молча (один раз)
    speedtest --accept-license --accept-gdpr >/dev/null 2>&1 || true

    exists speedtest && return 0 || { echo -e "${RED}Не получилось запустить${NC}"; return 1; }
}

run_speedtest() {
    if ! exists speedtest; then
        echo -e "${RED}speedtest не установлен / не найден в PATH${NC}"
        return
    fi

    echo -e "\nSpeedtest (Ookla official):"
    speedtest --progress=no 2>/dev/null | awk '
        /Server:/ {printf "Сервер: %s\n", substr($0, index($0,$2))}
        /ISP:/    {printf "Провайдер: %s\n", substr($0, index($0,$2))}
        /Latency:/{printf "Пинг:   %s\n", $2 " " $3}
        /Download:/{printf "Скачивание: %.2f Mbit/s\n", $2}
        /Upload:/  {printf "Загрузка:   %.2f Mbit/s\n", $2}
    ' || echo -e "${YELLOW}Тест не удался (сеть / лицензия?)${NC}"
}

# ──────────────────────────────────────────────

clear
header
sysinfo
hr
io_test
hr

install_speedtest
run_speedtest

hr
echo -e "Готово ${GREEN}✓${NC}"
