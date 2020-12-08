#!/usr/bin/with-contenv bash

# create scripts directory if missing

# create cache directory if missing
if [ ! -d "/config/cache" ]; then
	mkdir -p "/config/cache"
fi

# create logs directory if missing
if [ ! -d "/config/logs" ]; then
	mkdir -p "/config/logs"
fi

# create deemix directory
if [ ! -d "/config/deemix" ]; then
	mkdir -p "/config/deemix/xdg/deemix"
fi

# set permissions
chown -R abc:abc "/config"
chown -R abc:abc "/scripts"
chmod 0777 -R "/scripts"
chmod 0777 -R "/config"

echo "Complete..."

exit $?
