#!/usr/bin/with-contenv bash

echo "Starting Script...."
processstartid="$(pgrep -f /config/scripts/start.bash)"
echo "To kill script, use the following command:"
echo "kill -9 $processstartid"
for (( ; ; )); do
    let i++
    bash /config/scripts/download.bash 2>&1 | tee "/config/logs/script_run_${i}_$(date +"%Y_%m_%d_%I_%M_%p").log" > /proc/1/fd/1 2>/proc/1/fd/2
    if [ -f "/config/logs/log-cleanup" ]; then
        rm "/config/logs/log-cleanup"
    fi
    touch -d "8 hours ago" "/config/logs/log-cleanup"
    if find "/config/logs" -type f -iname "*.log" -not -newer "/config/logs/log-cleanup" | read; then
        find "/config/logs" -type f -iname "*.log" -not -newer "/config/logs/log-cleanup" -delete
    fi
    if [ -f "/config/logs/log-cleanup" ]; then
        rm "/config/logs/log-cleanup"
    fi
    sleep 15m
done

exit 0
