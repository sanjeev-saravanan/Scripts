#!/bin/bash

# Define thresholds
CPU_THRESHOLD=80
MEMORY_THRESHOLD=80
DISK_THRESHOLD=90
PROCESS_THRESHOLD=100
LOG_FILE="$HOME/system_health.log"
CHECK_INTERVAL=10  # Seconds between checks
PID_FILE="$HOME/system_health.pid"  # Store PID for easy stopping

# Ensure log file directory is writable
[ -w "$(dirname "$LOG_FILE")" ] || { echo "Error: Cannot write to $LOG_FILE" >&2; exit 1; }

# Function to log and report alerts
log_alert() {
  local message="$1"
  local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
  # Print to console in red (redirected to log in background)
  printf "\033[31m%s: %s\033[0m\n" "$timestamp" "$message"
  # Append to log file
  printf "%s: %s\n" "$timestamp" "$message" >> "$LOG_FILE"
}

# Check CPU usage
check_cpu() {
  local cpu=$(awk '/^cpu / {u=$2+$4; t=$2+$4+$5; if(t>0) print u*100/t}' /proc/stat)
  [ -z "$cpu" ] && cpu=0
  if (( $(echo "$cpu > $CPU_THRESHOLD" | bc -l) )); then
    log_alert "High CPU usage detected: ${cpu}%"
  fi
  echo "$cpu"
}

# Check memory usage
check_memory() {
  local mem=$(free | awk '/Mem/ {printf("%.2f", $3/$2 * 100)}')
  [ -z "$mem" ] && mem=0
  if (( $(echo "$mem > $MEMORY_THRESHOLD" | bc -l) )); then
    log_alert "High memory usage detected: ${mem}%"
  fi
  echo "$mem"
}

# Check disk space
check_disk() {
  local disk=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')
  [ -z "$disk" ] && disk=0
  if [ "$disk" -gt "$DISK_THRESHOLD" ]; then
    log_alert "Low disk space detected: ${disk}% used"
  fi
  echo "$disk"
}

# Check running processes
check_processes() {
  local proc=$(ps -e | wc -l)
  [ -z "$proc" ] && proc=0
  local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
  printf "%s: Number of running processes: %d\n" "$timestamp" "$proc" >> "$LOG_FILE"
  if [ "$proc" -gt "$PROCESS_THRESHOLD" ]; then
    log_alert "High process count detected: ${proc}"
  fi
  echo "$proc"
}

# Function to start monitoring in background
start_monitoring() {
  if [ -f "$PID_FILE" ] && ps -p "$(cat "$PID_FILE")" > /dev/null; then
    echo "Monitoring already running with PID $(cat "$PID_FILE")"
    exit 1
  fi
  # Redirect output to log file when in background
  echo "$TIMESTAMP: Starting real-time system monitoring" >> "$LOG_FILE"
  while true; do
    CPU_USAGE=$(check_cpu)
    MEMORY_USAGE=$(check_memory)
    DISK_USAGE=$(check_disk)
    RUNNING_PROCESSES=$(check_processes)
    if [ -n "$(tail -n 4 "$LOG_FILE" | grep -E 'High|Low')" ]; then
      printf "System Status: CPU: %.2f%% | Memory: %.2f%% | Disk: %d%% | Processes: %d\n" \
        "$CPU_USAGE" "$MEMORY_USAGE" "$DISK_USAGE" "$RUNNING_PROCESSES" >> "$LOG_FILE"
    fi
    sleep "$CHECK_INTERVAL"
  done &
  # Save PID to file
  echo $! > "$PID_FILE"
  echo "Started monitoring in background with PID $(cat "$PID_FILE")"
}

# Function to stop monitoring
stop_monitoring() {
  if [ ! -f "$PID_FILE" ] || ! ps -p "$(cat "$PID_FILE")" > /dev/null; then
    echo "No monitoring process found"
    exit 1
  fi
  PID=$(cat "$PID_FILE")
  kill "$PID"
  rm "$PID_FILE"
  echo "$TIMESTAMP: Stopped real-time system monitoring" >> "$LOG_FILE"
  echo "Stopped monitoring process with PID $PID"
}

# Handle start/stop commands
case "$1" in
  stop)
    stop_monitoring
    ;;
  *)
    start_monitoring
    ;;
esac
