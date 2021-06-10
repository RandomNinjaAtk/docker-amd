#! /usr/bin/with-contenv bash

# Create directories
mkdir -p /config/{cache,logs,deemix/xdg/deemix}

# Set directory ownership
chown -R abc:abc /config
chown -R abc:abc /scripts
chmod 0777 -R /scripts
chmod 0777 -R /config

if [[ ${AUTOSTART} == true ]]; then
	bash /scripts/start.bash
else
	echo "Automatic Start disabled, start manually with:"
	echo "bash /scripts/start.bash"
fi
