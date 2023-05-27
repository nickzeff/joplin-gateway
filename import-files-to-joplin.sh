#!/usr/bin/env bash

if [[ "${1}x" == "x" ]] ; then
    echo "Usage: `basename $0` file|directory [notebook]"
    exit 1
fi

readonly LOG_PREFIX="[import-files-to-joplin]"

# include functions
readonly CURR_WD=`pwd`
cd "$(dirname "$0")";
. ./config-defaults.sh
. ./_util-functions.sh
. ./_mail-functions.sh
. ./_joplin-functions.sh
cd ${CURR_WD}


# Check to see if there is another mail processing script running right now. If so, abort
if [ `lockIsActive FILES` == true ] ; then
    echo "$LOG_PREFIX Active lock on file imports. Wait for expiry or remove file if no process running"
    exit 1
fi

NEW_FILES=0

# if optional notebook name was given, use it, otherwise use default
if [[ "${2}x" == "x" ]] ; then
    NOTEBOOK=$DEFAULT_NOTEBOOK  
else
    NOTEBOOK="$2"
fi

if [[ -d $1 ]]; then
    TEMP_DIR=`mktemp -d`

    if [ -z "$(find $1 -prune -empty 2>/dev/null)" ]; then
        lockActivate FILES $LOCKFILE_DURATION
        echo "$LOG_PREFIX Found files to import =============================="
        NEW_FILES=1
    fi

    find "$1" -maxdepth 1 -type f -print0 | sort -z | while read -d $'\0' F; do
        F_BASEFILE=`basename "$F"`
        TEMP_FILE="${TEMP_DIR}/${F_BASEFILE}"
        mv "$F" "$TEMP_FILE" 
        addNewNoteFromGenericFile "$NOTEBOOK" "$TEMP_FILE"
    done
    rm -r ${TEMP_DIR} #NCJ 20230325 - remove temp dir after adding new note(s)

elif [[ -f $1 ]]; then
    lockActivate FILES $LOCKFILE_DURATION
    echo "$LOG_PREFIX Found files to import =============================="
    NEW_FILES=1
    TEMP_DIR=`mktemp -d`
    F_BASEFILE=`basename "$1"`
    TEMP_FILE="${TEMP_DIR}/${F_BASEFILE}"
    mv "$1" "$TEMP_FILE"
    addNewNoteFromGenericFile "$NOTEBOOK" "$TEMP_FILE" $MAX_THUMBNAILS
    rm -r ${TEMP_DIR} #NCJ 20230325 - remove temp dir after adding new note

else
    echo "Usage: `basename $0` file|directory [notebook]"
    exit 1
fi

if [[ $NEW_FILES -eq 0 ]]; then
    exit 0
fi

echo "$LOG_PREFIX -------------------"
echo "$LOG_PREFIX Start Joplin Sync"

joplin sync

echo "$LOG_PREFIX End: `date`"

lockDeactivate FILES