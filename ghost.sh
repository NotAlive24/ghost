#!/bin/bash

VPN_CONFIG=""		  # Use openVPN, don't use THM\'s VPN, download from openVPN page.
			  # If it had password create a text file and add it's path to "auth-user-pass\"
			  # The text file should have username in first line and password second line.
TOR_SERVICE="tor"
USER_AGENT_LIST="/usr/share/ghostcloak/user_agents.txt"  # Create a file at that path or anywhere you want
USER_AGENT_INTERVAL=60    # it's in seconds dumbass
MAC_INTERVAL=5            # look it's minutes
VPN_TOR_LOOPS=3           # 0 for infinite do this I recommand that
DEADMAN=false
EXPECTED_VPN_IP=""
CURRENT_LOOP=1

# Logging function
log() {
    echo "[$(date +%T)] $1"	#credits to google
}

# Check required tools
for cmd in openvpn curl ip macchanger sudo; do
    if ! command -v $cmd &>/dev/null; then
        echo "Error: $cmd not found. Please install it."	#I can't believe how I did this
        exit 1
    fi
done

# Dynamic VPN interface detection (first tun device found)
get_vpn_iface() {
    ip -o link show | awk -F': ' '{print $2}' | grep '^tun' | head -n1
}

# Load a random User-Agent
# This took my life force
randomize_user_agent() {
    if [[ -f "$USER_AGENT_LIST" ]]; then
        UA=$(shuf -n 1 "$USER_AGENT_LIST")
    else
        UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36"
    fi
    export USER_AGENT="$UA"
    log "New User-Agent: $USER_AGENT"
}

# Randomize MAC address on primary iface (exclude common virtuals and loopback)
# This was pretty easy (google)
randomize_mac() {
    IFACE=$(ip -o link show | awk -F': ' '$2 !~ /^(lo|vir|docker|wl)/ {print $2}' | head -n1)
    if [ -z "$IFACE" ]; then
        log "No valid network interface found for MAC spoofing."
        return 1
    fi
    log "Spoofing MAC on $IFACE..."
    sudo ip link set dev "$IFACE" down
    sudo macchanger -r "$IFACE"
    sudo ip link set dev "$IFACE" up
}

# Randomize Hostname
# Struggled for an hour
# Change this according to your /etc/hosts file
randomize_hostname() {
    NEW_HOST="ghost-$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 6)"
    sudo sed -i "/127.0.1.1/d" /etc/hosts
    echo "127.0.1.1       $NEW_HOST" | sudo tee -a /etc/hosts > /dev/null
    sudo hostnamectl set-hostname "$NEW_HOST"
    log "Hostname set to $NEW_HOST"
}

# Start VPN and wait for interface
start_vpn() {
    log "Starting VPN..."
    sudo pkill openvpn 2>/dev/null
    sudo openvpn --config "$VPN_CONFIG" --daemon
    for i in {1..15}; do
        VPN_IFACE=$(get_vpn_iface)
        if [[ -n "$VPN_IFACE" ]]; then
            log "VPN interface $VPN_IFACE is up."
            return 0
        fi
        sleep 1
    done
    log "Failed to detect VPN interface."
    return 1
}

# Stop VPN
stop_vpn() {
    log "Stopping VPN..."
    sudo pkill openvpn 2>/dev/null
    sleep 2
}

# Start Tor
start_tor() {
    log "Starting Tor..."
    sudo systemctl start "$TOR_SERVICE"
    sleep 2
}

# Stop Tor
stop_tor() {
    log "Stopping Tor..."
    sudo systemctl stop "$TOR_SERVICE"
}

# Enable killswitch (drop all traffic except VPN interface)
enable_killswitch() {
    VPN_IFACE=$(get_vpn_iface)
    if [[ -z "$VPN_IFACE" ]]; then
        log "Cannot enable killswitch, VPN interface not found."
        return 1
    fi
    log "Enabling kill switch on all interfaces except $VPN_IFACE..."
    sudo iptables -I OUTPUT ! -o "$VPN_IFACE" -j DROP
}

# Disable killswitch
disable_killswitch() {
    VPN_IFACE=$(get_vpn_iface)
    if [[ -z "$VPN_IFACE" ]]; then
        log "VPN interface not found, skipping killswitch removal."
        return 1
    fi
    log "Disabling kill switch..."
    sudo iptables -D OUTPUT ! -o "$VPN_IFACE" -j DROP 2>/dev/null || true
}

# Get current external IP with fallbacks
get_current_ip() {
    IP=""
    for service in "ifconfig.me" "api.myip.com" "ipinfo.io/ip"; do
        IP=$(curl -sf --max-time 5 "$service")
        if [[ "$IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "$IP"
            return 0
        fi
    done
    return 1
}

# Dead-man's switch VPN check
# Don't change anything
check_vpn() {
    VPN_IFACE=$(get_vpn_iface)
    if [[ -z "$VPN_IFACE" ]]; then
        log "[DEADMAN] VPN interface missing!"
        sudo iptables -I OUTPUT -j DROP
        log "[DEADMAN] Traffic killed."
        cleanup
        exit 1
    fi

    CURRENT_IP=$(get_current_ip)
    if [[ "$CURRENT_IP" != "$EXPECTED_VPN_IP" ]]; then
        log "[DEADMAN] VPN IP mismatch! Expected $EXPECTED_VPN_IP, got $CURRENT_IP"
        sudo iptables -I OUTPUT -j DROP
        log "[DEADMAN] Traffic killed."
        cleanup
        exit 1
    fi
}

# Cleanup on exit
# Saviour, remove this then you will get caught
cleanup() {
    log "Cleaning up..."
    disable_killswitch
    stop_tor
    stop_vpn
    randomize_mac
    sudo hostnamectl set-hostname "kali"
    sudo sed -i '/127.0.1.1.*ghost-/d' /etc/hosts
    sudo resolvectl flush-caches 2>/dev/null || sudo /etc/init.d/networking restart
    log "Cleanup complete."
}

# Handle CTRL+C
trap cleanup INT

# Interactive Setup
# accedently found how to enter 3 line dash (3 time equal to sign gives that)
echo "=== Ghostcloak+ Interactive Setup ==="

read -rp "User-Agent rotation interval in seconds (default 60): " uai
USER_AGENT_INTERVAL=${uai:-60}

read -rp "MAC randomization interval in minutes (default 5): " maci
MAC_INTERVAL=${maci:-5}

read -rp "VPN <-> Tor loops (0 for infinite, default 3): " loops
VPN_TOR_LOOPS=${loops:-3}

read -rp "Enable dead-man's switch? (y/N): " dms
[[ "$dms" =~ ^([yY][eE][sS]|[yY])$ ]] && DEADMAN=true

if [ "$DEADMAN" = true ]; then
    log "Starting VPN temporarily to detect VPN IP for dead-man switch..."
    start_vpn || { log "VPN failed to start during dead-man IP detection"; exit 1; }
    sleep 5
    EXPECTED_VPN_IP=$(get_current_ip)
    if [[ -z "$EXPECTED_VPN_IP" ]]; then
        log "Failed to detect VPN IP for dead-man's switch. Exiting."
        stop_vpn
        exit 1
    fi
    log "Detected VPN IP: $EXPECTED_VPN_IP"
    stop_vpn
fi

# Check user_agents.txt existence upfront
if [[ ! -f "$USER_AGENT_LIST" ]]; then
    log "Warning: User-Agent list file not found at $USER_AGENT_LIST"
    log "You should create it with a list of User-Agent strings, one per line."
fi

# Summary of the setting
echo ""
echo "Settings summary:"
echo "User-Agent rotation interval: $USER_AGENT_INTERVAL seconds"
echo "MAC randomization interval: $MAC_INTERVAL minutes"
echo "VPN <-> Tor loops: $VPN_TOR_LOOPS"
echo "Dead-man's switch: $DEADMAN"
[ "$DEADMAN" = true ] && echo "Expected VPN IP: $EXPECTED_VPN_IP"
echo ""

read -rp "Start Ghostcloak+ with these settings? (Y/n): " confirm
[[ "$confirm" =~ ^([nN])$ ]] && exit 0

log "Starting Ghostcloak+ with User-Agent interval=${USER_AGENT_INTERVAL}s, MAC interval=${MAC_INTERVAL}m, loops=$VPN_TOR_LOOPS, deadman=$DEADMAN"

enable_killswitch
randomize_user_agent
randomize_mac
randomize_hostname

# Timers for MAC and User-Agent rotation
LAST_MAC_CHANGE=$(date +%s)
LAST_UA_CHANGE=$(date +%s)

while [[ $VPN_TOR_LOOPS -eq 0 || $CURRENT_LOOP -le $VPN_TOR_LOOPS ]]; do
    log "===== LOOP $CURRENT_LOOP / $VPN_TOR_LOOPS ====="

    start_vpn || { log "[!] VPN failed to start. Exiting."; cleanup; exit 1; }
    sleep 5

    VPN_IP=$(get_current_ip)
    log "VPN IP: $VPN_IP"

    if [ "$DEADMAN" = true ] && [ "$VPN_IP" != "$EXPECTED_VPN_IP" ]; then
        log "[DEADMAN] VPN IP mismatch after start!"
        sudo iptables -I OUTPUT -j DROP
        log "[DEADMAN] Dead-man switch triggered. Exiting."
        cleanup
        exit 1
    fi

    start_tor

    while true; do
        NOW=$(date +%s)

        # Rotate User-Agent
        if (( NOW - LAST_UA_CHANGE >= USER_AGENT_INTERVAL )); then
            randomize_user_agent
            LAST_UA_CHANGE=$NOW
        fi

        # Rotate MAC every MAC_INTERVAL minutes only when VPN and Tor are stopped (so in between loops)
        if (( NOW - LAST_MAC_CHANGE >= MAC_INTERVAL * 60 )); then
            log "MAC randomization interval reached, will randomize after stopping VPN & Tor."
            break
        fi

        # Check dead-man's switch periodically
        if [ "$DEADMAN" = true ]; then
            check_vpn
        fi

        sleep 5
    done

    stop_tor
    stop_vpn

    randomize_mac
    LAST_MAC_CHANGE=$(date +%s)

    ((CURRENT_LOOP++))
done

cleanup
