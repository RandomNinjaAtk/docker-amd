#!/usr/bin/with-contenv bash

# update pip packages
for i in $(python3 -m pip list | awk 'NR > 2 {print $1}'); do
	python3 -m pip install --no-cache-dir --upgrade $i -U
done

exit $?
