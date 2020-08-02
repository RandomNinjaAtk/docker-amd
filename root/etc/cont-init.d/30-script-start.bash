#!/usr/bin/with-contenv bash

if [ "$AUTOSTART" = "true" ]; then
	echo "Automatic Start Enabled, starting..."
	bash /config/scripts/start.bash
else
	echo "Automatic Start Disabled, manually run using this command:"
	echo "bash /config/scripts/start.bash"
fi

exit $?
