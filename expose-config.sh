#!/usr/bin/env bash

if [ ! -d /home/node/.config/getmail ]; then
    echo "`date`: Re-creating getmail default configuration"
    mkdir -p /home/node/.config/getmail
    cp /home/node/defaults/getmailrc /home/node/.config/getmail/
fi

if [ ! -f /home/node/.config/config-defaults.sh ]; then
    echo "`date`: Re-creating config-defaults.sh"
    cp /home/node/defaults/config-defaults.sh /home/node/.config
fi

if [ ! -d /home/node/.config/joplin ]; then
    echo "`date`: Re-creating default joplin configuration"
    cp -r /home/node/defaults/joplin /home/node/.config/
fi