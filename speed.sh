#!/usr/bin/env bash
# Minimal Bench 2026 • auto-installs official speedtest by Ookla

RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[1;33m' BLUE='\033[0;36m' NC='\033[0m'

exists() { command -v "$1" &>/dev/null; }

hr() { printf '%-70s\n' | tr ' ' '-'; }

header() {
    echo -e "${BLUE}Minimal Bench • $(date '+%Y-%m-%d %H:%M')${NC}"
    hr
}

sysinfo() {
    echo -e "CPU : ${YELLOW}$(awk -F: '/model name/{print $2}' /proc/cpuinfo | head -1 | xargs)${NC}"
    echo -e "    $(nproc) cores @ $(awk '/cpu MHz/{printf "%.0f MHz\n", $4; exit}' /proc/cpuinfo)"
    echo -e "RAM : ${YELLOW}$(free -h | awk '/Mem:/{print $2 " total, " $3 " used"}')${NC}"
    echo -e "Disk: ${YELLOW}$(df -h / | awk 'NR==2{print $2 " total, " $3 " used"}')${NC}"
}

io_test() {
    local f=bench_io_$$
    echo -n "Disk I/O (1 GB write) ... "
    dd if=/dev/zero of="$f" bs=1M count=1024 conv=fdatasync status=none 2>&1 | tail -1 |
        awk '{printf "%s %s\n", $(NF-1), $NF}' | sed 's/(//;s/)//'
    rm -f "$f"
}

install_speedtest() {
    if exists speedtest; then return 0; fi

    echo -e "${YELLOW}Installing official Ookla Speedtest CLI...${NC}"

    local arch=$(uname -m)
    local url_base="https://install.speedtest.net/app/cli"
    local tgz=""

    case "$arch" in
        x86_64)          tgz="ookla-speedtest-1.2.0-linux-x86_64.tgz" ;;
        aarch64|arm64)   tgz="ookla-speedtest-1.2.0-linux-aarch64.tgz" ;;
        armv7l|armhf)    tgz="ookla-speedtest-1.2.0-linux-armhf.tgz"   ;;
        armv6l)          tgz="ookla-speedtest-1.2.0-linux-armel.tgz"   ;;
        *) echo -e "${RED}Unsupported arch: $arch${NC}"; return 1 ;;
    esac

    local url="$url_base/$tgz"

    if ! curl -fsSL --connect-timeout 8 "$url" -o speedtest.tgz; then
        echo -e "${RED}Download failed. Trying fallback...${NC}"
        if ! curl -fsSL "https://dl.lamp.sh/files/$tgz" -o speedtest.tgz; then
            echo -e "${RED}Cannot download speedtest binary${NC}"
            return 1
        fi
    fi

    tar -xzf speedtest.tgz >/dev/null 2>&1 || { echo -e "${RED}Extraction failed${NC}"; rm -f speedtest.tgz; return 1; }
    chmod +x speedtest
    mv speedtest /usr/local/bin/ 2>/dev/null || mv speedtest ~/bin/ || { echo -e "${YELLOW}Moved to ~/bin (add to PATH if needed)${NC}"; }
    rm -f speedtest.tgz

    if exists speedtest; then
        echo -e "${GREEN}Speedtest installed successfully${NC}"
        speedtest --accept-license --accept-gdpr >/dev/null 2>&1 || true
        return 0
    else
        echo -e "${RED}Installation failed${NC}"
        return 1
    fi
}

speed_test() {
    if ! exists speedtest; then
        echo -e "${RED}speedtest not available${NC}"
        return 1
    fi

    echo -e "\nSpeedtest.net:"
    speedtest --progress=no --format=simple 2>/dev/null | awk '{
        printf "Ping    : %s ms\nDownload: %s Mbit/s\nUpload  : %s Mbit/s\n", $1, $2, $3
    }' || echo -e "${YELLOW}Speedtest failed (check network)${NC}"
}

# ────────────────────────────────────────────────

! exists curl && { echo -e "${RED}curl required${NC}"; exit 1; }

clear
header
sysinfo
hr
io_test
hr

install_speedtest && speed_test

hr
echo -e "Done ${GREEN}✓${NC}"
