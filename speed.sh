#!/usr/bin/env bash
# Minimal Bench RU 2026 • auto-install Ookla speedtest + тесты по городам РФ

RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[1;33m' BLUE='\033[0;36m' NC='\033[0m'

exists() { command -v "$1" >/dev/null 2>&1; }

hr() { printf '%-70s\n' | tr ' ' '-'; }

header() {
    echo -e "${BLUE}Minimal Bench RU • $(date '+%Y-%m-%d %H:%M')${NC}"
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
        echo -e "${GREEN}speedtest уже установлен${NC}"
        return 0
    fi

    echo -e "${YELLOW}Установка official Ookla Speedtest CLI...${NC}"

    local arch=$(uname -m)
    local file=""
    case "$arch" in
        x86_64)          file="ookla-speedtest-1.2.0-linux-x86_64.tgz" ;;
        aarch64|arm64)   file="ookla-speedtest-1.2.0-linux-aarch64.tgz" ;;
        armv7l|armhf)    file="ookla-speedtest-1.2.0-linux-armhf.tgz" ;;
        armv6l|armel)    file="ookla-speedtest-1.2.0-linux-armel.tgz" ;;
        i386|i686)       file="ookla-speedtest-1.2.0-linux-i386.tgz" ;;
        *) echo -e "${RED}Архитектура не поддерживается: $arch${NC}"; return 1 ;;
    esac

    local url="https://install.speedtest.net/app/cli/$file"
    local tmp="st_$$.tgz"

    curl -fsL --connect-timeout 12 "$url" -o "$tmp" || { echo -e "${RED}Скачивание не удалось${NC}"; rm -f "$tmp"; return 1; }

    tar xzf "$tmp" >/dev/null 2>&1 || { echo -e "${RED}Распаковка не удалась${NC}"; rm -f "$tmp"; return 1; }

    chmod +x speedtest

    if [ -w /usr/local/bin ] 2>/dev/null; then
        mv speedtest /usr/local/bin/ 2>/dev/null && echo -e "${GREEN}→ /usr/local/bin/speedtest${NC}"
    else
        mkdir -p ~/bin 2>/dev/null
        mv speedtest ~/bin/speedtest
        echo -e "${YELLOW}→ ~/bin/speedtest${NC}"
        echo -e "${YELLOW}Добавь в PATH: export PATH=\"\$HOME/bin:\$PATH\"${NC}"
    fi

    rm -f "$tmp" *.md LICENSE* 2>/dev/null

    speedtest --accept-license --accept-gdpr >/dev/null 2>&1 || true

    exists speedtest && return 0 || { echo -e "${RED}Установка провалилась${NC}"; return 1; }
}

speed_test_ru() {
    if ! exists speedtest; then
        echo -e "${RED}speedtest не найден${NC}"
        return
    fi

    echo -e "\n${YELLOW}Тесты по городам РФ (Ookla servers):${NC}"
    printf "%-28s %-12s %-15s %-10s\n" "Город / Провайдер" "Upload" "Download" "Latency"

    local tests=(
        "4718|Beeline, Москва"
        "6562|Tele2, Москва"
        "6386|Megafon, Москва"
        "1907|MTS, Москва"
        "3682|Rostelecom, Москва"
        "6051|Tele2, СПб"
        "1905|MTS, СПб"
        "2599|Rostelecom, СПб"
        "6437|Megafon, Екатеринбург"
        "21011|Rostelecom, Екатеринбург"
        "6430|Tele2, Новосибирск"
        "3868|MTS, Новосибирск"
        "6210|Beeline, Сочи"
        "6429|Tele2, Ростов-на-Дону"
        "7403|Vladlink, Владивосток"
    )

    for t in "${tests[@]}"; do
        IFS='|' read -r id name <<< "$t"
        echo -n "."
        out=$(speedtest --server-id="$id" --progress=no --format=csv 2>/dev/null)
        if [[ -n "$out" ]]; then
            latency=$(echo "$out" | awk -F, '{print $3/1000 " ms"}')
            download=$(echo "$out" | awk -F, '{printf "%.1f", $6/1000000}')
            upload=$(echo "$out" | awk -F, '{printf "%.1f", $7/1000000}')
            printf "\n%-28s %-12s %-15s %-10s\n" " $name" "${upload} Mbps" "${download} Mbps" "$latency"
        fi
    done
    echo ""
}

# ──────────────────────────────────────────────

clear
header
sysinfo
hr
io_test
hr

install_speedtest
speed_test_ru

hr
echo -e "Готово ${GREEN}✓${NC}"
