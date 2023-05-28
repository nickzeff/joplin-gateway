#!/usr/bin/env bash

#---
## Check if lockfile exists, and if it has expired yet
## Usage: lockIsActive lockfile-identifier
#---
function lockIsActive {
    
    local FILE="/tmp/jg-lockfile-$1"

    if [ ! -f $FILE ]; then
        echo false
        exit 1
    fi

    local LOCK_EXPIRES=`cat $FILE`

    if [[ ! $LOCK_EXPIRES =~ ^[0-9]{14}$ ]]; then
        echo true
        exit 0
    fi

    if [ $LOCK_EXPIRES -lt `date +"%Y%m%d%H%M%S"` ]; then
        echo false
        exit 1
    fi

    echo true
}

#---
## Generate current lock file with provided duration
## Usage: lockActivate lockfile-prefix duration
#---
function lockActivate {
    local FILE="/tmp/jg-lockfile-$1"
    local DURATION=$2
    local NOW=`date +"%Y%m%d%H%M%S"`
    echo $((NOW + DURATION))>$FILE
}

#---
## Remove lock file so future processes can proceed
## Usage: lockDeactivate lockfile-prefix
#---
function lockDeactivate {
    local FILE="/tmp/jg-lockfile-$1"
    rm -f $FILE
}