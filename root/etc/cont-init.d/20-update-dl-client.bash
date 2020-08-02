#!/usr/bin/with-contenv bash

# update from git
UPDATE_DLCLIENT="TRUE"
if [[ "${UPDATE_DLCLIENT}" == "TRUE" ]]; then
    git -C ${PathToDLClient} reset --hard HEAD && \
    git -C ${PathToDLClient} pull origin main
    pip3 install -r /root/scripts/deemix/requirements.txt --upgrade --user
fi

exit $?
