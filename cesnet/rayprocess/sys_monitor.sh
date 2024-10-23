#!/bin/bash

# Název souboru, do kterého budou zapsána data
SYS_LOG_FILE="system_usage.log"

# Interval měření v sekundách
INTERVAL=5

# Záznam záhlaví tabulky
echo -e "Time\t\t\tPercent\tCores\tRAM" > $SYS_LOG_FILE

log_message "sys monitor running"

# Nekonečný cyklus pro opakované zaznamenávání
while true
do
    # Aktuální čas
    TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

    # Využití CPU v procentech (použijeme příkaz 'top' a zpracujeme pomocí grep a awk)
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')

    # Počet CPU jader (lze získat příkazem 'nproc')
    CPU_CORES=$(nproc)

    # Využití RAM (získáme pomocí 'free' a zpracujeme pomocí awk)
    RAM_USAGE=$(free -m | awk '/Mem:/ { printf "%d/%dMB (%.2f%%)", $3, $2, $3*100/$2 }')

    # Zapsání výsledků do logu ve formátu tabulky
    echo -e "$TIMESTAMP\t$CPU_USAGE\t$CPU_CORES\t$RAM_USAGE" >> $SYS_LOG_FILE

    # Pauza na daný interval
    sleep $INTERVAL
done