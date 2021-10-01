#! /usr/bin/with-contenv bash

START_PID="$(pgrep -f 'bash /scripts/start.bash')"

echo "Starting AMD...."
echo "To kill the autorun script, use the following command:"
echo "kill -9 ${START_PID}"

while true; do
	let i++
	bash /scripts/download.bash 2>&1 | tee "/config/logs/script_run_${i}_$(date +"%Y_%m_%d_%I_%M_%p").log" > /proc/1/fd/1 2>/proc/1/fd/2
	find "/config/logs" -type f -iname "*.log" -not -newermt "8 hours ago" -delete
	sleep "${SCRIPTINTERVAL:-15m}"
done
