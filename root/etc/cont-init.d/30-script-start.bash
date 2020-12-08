#!/usr/bin/with-contenv bash

if [ "$AUTOSTART" = "true" ]; then
	echo "Automatic Start Enabled, starting..."
	bash /scripts/start.bash
else
	echo "Automatic Start Disabled, manually run using this command:"
	echo "bash /scripts/start.bash"
fi

exit $?
