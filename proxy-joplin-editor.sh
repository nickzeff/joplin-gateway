#!/usr/bin/env bash

if [[ "${1}x" == "x" ]] ; then
    echo "Usage: `basename $0` file"
    exit 1
fi

if [[ ! -f $1 ]]; then
    echo "Parameter is not an existing file name"
    exit 1
fi

# include functions
readonly CURR_WD=`pwd`
cd "$(dirname "$0")";
. ./config-defaults.sh
cd ${CURR_WD}

if [[ ! -f $TEMP_APPEND_FILE ]]; then
    echo "File with content to append not found"
    exit 1
fi

# Append 2 x newlines ahead of new content.
# This will prevent conflicts with the note title which takes up the first two lines
echo >> $1
echo >> $1

# Append the content of our reserved file to the existing file, location of which was provided by Joplin
cat $TEMP_APPEND_FILE >> $1

rm $TEMP_APPEND_FILE