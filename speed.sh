#!/usr/bin/env bash

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;36m'; NC='\033[0m'

exists() { command -v "$1" &>/dev/null; }

hr() { printf '%-70s\n' | tr ' ' '-'; }

header() {
    echo -e "${BLUE}Minimal Bench  •  $(date '+%Y-%m-%d %H:%M')${NC}"
    hr
}

sysinfo() {
    local cpu mem disk

    cpu=$(awk -F: '/model name/{print $2}' /proc/cpuinfo | head -1 | xargs)
    cores=$(grep -c ^processor /proc/cpuinfo)
    freq=$(awk '/cpu MHz/{print $4; exit}' /proc/cpuinfo)

    mem=$(free -h | awk '/Mem:/ {print $2 " total, " $3 " used"}')
    disk=$(df -h / | awk 'NR==2 {print $2 " total, " $3 " used"}')

    echo -e "CPU : ${YELLOW}${cpu}${NC}"
    echo -e "    ${cores} cores @ ${freq} MHz"
    echo -e "RAM : ${YELLOW}${mem}${NC}"
    echo -e "Disk: ${YELLOW}${disk}${NC}"
}

io_test() {
    local tmpfile=benchio_$$
    echo -n "Disk I/O ... "
    dd if=/dev/zero of=${tmpfile} bs=1M count=1024 conv=fdatasync 2>&1 |
        tail -1 | awk '{print $NF " " $(NF-1)}' | sed 's/(//;s/)//'
    rm -f ${tmpfile}
}

speedtest_mini() {
    if ! exists speedtest; then
        echo -e "${RED}speedtest-cli not found${NC}"
        return 1
    fi

    echo -e "\nSpeedtest (speedtest.net):"
    speedtest --progress=no --format=csv |
        awk -F, '{
            gsub(/"/,"",$1); gsub(/"/,"",$2);
            printf "Ping   : %s ms\nDownload: %.2f Mbit/s\nUpload  : %.2f Mbit/s\n",
                   $3/1000, $6/1000000, $7/1000000
        }'
}

main() {
    clear
    header
    sysinfo
    hr
    io_test
    hr
    speedtest_mini
    hr
    echo -e "Done.   ${GREEN}✓${NC}"
}

# -----------------------

! exists wget && { echo -e "${RED}wget not found${NC}"; exit 1; }

main