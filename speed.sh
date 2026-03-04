#!/usr/bin/env bash
# Minimal Bench RU fix 2026 • тесты по реальным российским серверам

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
    if dd if=/dev/zero of="$f" bs=1M count=1024 conv=fdatasync status=none 2>/dev/null; then
        sync
        local res=$(dd if="$f" of=/dev/null bs=1M count=1024 status=none 2>&1 | awk '{print $1 " " $2}')
        echo "${res:-ошибка}"
    else
        echo "${RED}ошибка записи (нет места/прав?)${NC}"
    fi
    rm -f "$f" 2>/dev/null
}

speed_test_ru() {
    if ! exists speedtest; then
        echo -e "${RED}speedtest не найден. Установи: curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | bash && apt install speedtest${NC}"
        return
    fi

    echo -e "\n${YELLOW}Тесты к российским серверам (Ookla):${NC}"
    printf "%-28s %-10s %-15s %-10s\n" "Провайдер / Город" "Upload" "Download" "Пинг"

    local servers=(
        "4718|Beeline Москва"
        "6562|Tele2 Москва"
        "6386|Megafon Москва"
        "1907|MTS Москва"
        "3682|Rostelecom Москва"
        "6051|Tele2 СПб"
        "1905|MTS СПб"
        "2599|Rostelecom СПб"
        "6437|Megafon Екатеринбург"
        "6430|Tele2 Новосибирск"
        "3868|MTS Новосибирск"
        "6210|Beeline Сочи"
        "7403|Vladlink Владивосток"
    )

    for s in "${servers[@]}"; do
        IFS='|' read -r id name <<< "$s"
        echo -n "."
        out=$(speedtest --server-id="$id" --progress=no --format=csv --accept-license --accept-gdpr 2>/dev/null)
        if [[ -n "$out" ]]; then
            ping=$(echo "$out" | cut -d, -f3 | awk '{printf "%.1f ms", $1/1000}')
            dl=$(echo "$out" | cut -d, -f6 | awk '{printf "%.1f Mbps", $1/1e6}')
            ul=$(echo "$out" | cut -d, -f7 | awk '{printf "%.1f Mbps", $1/1e6}')
            printf "\n%-28s %-10s %-15s %-10s\n" " $name" "$ul" "$dl" "$ping"
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
speed_test_ru
hr
echo -e "Готово ${GREEN}✓${NC}"
