#!/usr/bin/env bash

# ---- Configuration ----
readonly MAILDIR=/home/node/joplin-mailbox
readonly LOG_PREFIX="[fetch-joplin-mails]"

# include functions
readonly CURR_WD=`pwd`
cd "$(dirname "$0")";
. ./config-defaults.sh
. ./_util-functions.sh
. ./_mail-functions.sh
. ./_joplin-functions.sh
cd ${CURR_WD}

# Check to see if there is another mail processing script running right now. If so, abort
if [ `lockIsActive MAIL` == true ] ; then
    echo "$LOG_PREFIX Active lock on mail imports. Wait for expiry or remove file if no process running"
    exit 1
fi

NEW_MAIL=0

fetchMails

if [ -z "$(find "$MAILDIR/new" -prune -empty 2>/dev/null)" ]; then
    lockActivate MAIL $LOCKFILE_DURATION
    echo "$LOG_PREFIX Found mail to import."
    NEW_MAIL=1
fi

find "$MAILDIR/new" -type f -print0 | sort -z | while read -d $'\0' M
do  
    echo "$LOG_PREFIX -------------------"
    echo "$LOG_PREFIX Process $M"
    
    addNewNoteFromMailFile "$M" $MAX_THUMBNAILS
    if [[ $? -eq 0 ]]; then
        mv "$M" "$MAILDIR/cur/`basename "$M"`:2"
    else
        echo "$LOG_PREFIX Error: Mail could not be added - leaving in inbox"
    fi
done

if [[ NEW_MAIL -eq 0 ]]; then
    exit 0
fi

echo "$LOG_PREFIX Start Joplin Sync"
joplin sync
echo "$LOG_PREFIX End Sync"

lockDeactivate MAIL
