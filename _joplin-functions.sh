#!/usr/bin/env bash

#---
## Switch to given Joplin notebook
## Usage: switchToNotebook notebook
#---
function switchToNotebook {
    joplin use "$1"
    if [[ $? -ne 0 ]] ; then
        if [[ "$AUTO_CREATE_NOTEBOOK" == "true" ]]; then
            echo "$LOG_PREFIX Info: notebook $1 not found - creating automatically"
            joplin mkbook "$1"
            joplin use "$1"
        else
            echo "$LOG_PREFIX Warning: notebook $1 not found - using default $DEFAULT_NOTEBOOK instead"
            joplin use "$DEFAULT_NOTEBOOK"
            if [[ $? -ne 0 ]] ; then
                echo "$LOG_PREFIX Error: default notebook $DEFAULT_NOTEBOOK not found - creating automatically"
                joplin mkbook "$DEFAULT_NOTEBOOK"
                joplin use "$DEFAULT_NOTEBOOK"
            fi
        fi
    fi
}

#---
## Create a new Joplin note
## Usage: createNewNote unique-name
## @return the note id
#---
function createNewNote {
    joplin mknote "$1"
    local LS_OUTPUT=(`joplin ls -l "$1"`)
    echo ${LS_OUTPUT[0]}
}

#---
## Usage: setNoteTitle note-id title
#---
function setNoteTitle {
    local TITLE="$2"
    if [[ "${TITLE}x" == "x" ]] ; then
        TITLE="${DEFAULT_TITLE_PREFIX} - `date`"
    fi
    echo "$LOG_PREFIX Set title to: $TITLE"
    joplin set "$1" title "$TITLE"
}

#---
## Usage: setNoteTags note-id tags
#---
function setNoteTags {
    for T in $2 ; do
        echo "$LOG_PREFIX Add tag: $T"
        joplin tag add "$T" "$1"
    done
}

#---
## Usage: extractMailParts mail-file dest-dir
#---
function extractMailParts {
    ripmime -i ${1} --mailbox -d ${2}
}

#---
## Usage: determineMailPartType mail-part-file
#---
function determineMailPartType {
    if [[ "$1" =~ ^.*\/textfile[0-9]*$ ]] ; then
        echo "CONTENT"
    elif [[ "$1" =~ ^.*\.txt$ ]] ; then
        echo "TXT"
    elif [[ "$1" =~ ^.*\.md$ ]] ; then
        echo "TXT"
    elif [[ "$1" =~ ^.*\.pdf$ ]] ; then
        echo "PDF"
    elif [[ "$1" =~ ^.*\.jpg$ ]] ; then
        echo "IMG"
    elif [[ "$1" =~ ^.*\.jpeg$ ]] ; then
        echo "IMG"
    elif [[ "$1" =~ ^.*\.png$ ]] ; then
        echo "IMG"
    elif [[ "$1" =~ ^.*\.gif$ ]] ; then
        echo "IMG"
    else
        echo "UNKNOWN"
    fi
}

#---
## Usage: createNoteBodyFromTextParts mail-parts-dir
#---
function getNoteBodyFromTextParts {
    find "$1" -type f -print0 | sort -z | while read -d $'\0' F; do
        local T=`determineMailPartType "${F}"`
        if [[ "$T" == "CONTENT" ]] ; then
            cat ${F}
        fi
    done
}

#---
## Usage: setNoteBodyFromTextParts note-id mail-parts-dir
#---
function setNoteBodyFromTextParts {
    echo "$LOG_PREFIX Setting body"
    getNoteBodyFromTextParts "${2}" > $TEMP_APPEND_FILE
    joplin edit $1
}

#---
## Usage: attachFile note-id file
#---
function attachFile {
	echo "$LOG_PREFIX Attach file `basename "$2"`"
	joplin attach "$1" "$2"
}

#---
## Usage: attachTextFromFile note-id text-file
#---
function attachTextFromFile {
	echo "$LOG_PREFIX Add text from `basename "$2"`"
    cat "$2" > $TEMP_APPEND_FILE
    joplin edit $1
}

#---
## Usage: addPdfThumbnails note-id pdf-file maxThumbnails
#---
function addPdfThumbnails {

    if [ $3 == 0 ]; then
        echo "$LOG_PREFIX MAX_THUMBNAILS value is 0 - skipping generation of PDF thumbnails"
        exit
    fi
    
    local TEMP_DIR=`mktemp -d`
	pdftoppm -scale-to 300 -png -l $3 "$2" "$TEMP_DIR/thumb"
	find "$TEMP_DIR" -type f -name "thumb-*.png" -print0 | sort -z | while read -d $'\0' T
	do
		echo "$LOG_PREFIX Add pdf thumbnail: $T"
		joplin attach "$1" "$T"
		rm "$T"
	done
	rmdir ${TEMP_DIR}
}

#---
## Usage: addAttachmentFromFile note-id file maxThumbnails
#---
function addAttachmentFromFile {
    
    local T=`determineMailPartType "$2"`
    local MAX_THUMBNAILS="$3"

    if [[ "$T" == "TXT" ]]; then
        attachTextFromFile "$1" "$2"
    elif [[ "$T" == "PDF" ]] ; then
        addPdfThumbnails "$1" "$2" $MAX_THUMBNAILS
        appendToBody "$1" "\r\n\r\n"
        attachFile "$1" "$2"
    elif [[ "$T" == "IMG" ]] ; then
        attachFile "$1" "$2"
        #addLastImageAsLink "$1"
    elif [[ "$T" == "UNKNOWN" ]] ; then
        attachFile "$1" "$2"
    else
        :
    fi
}

#---
## Usage: addAttachmentsFromFileParts note-id mail-parts-dir maxThumbnails
#---
function addAttachmentsFromFileParts {
    find "$2" -type f -print0 | sort -z | while read -d $'\0' F; do
        addAttachmentFromFile "$1" "$F" $3
    done
}

#---
## Usage: addPdfFulltext note-id pdf-file
#---
function addPdfFulltext {
	echo "$LOG_PREFIX Add pdf fulltext for `basename "$2"`"
	pdftotext -raw -nopgbrk "$2" "$TEMP_APPEND_FILE"

    if [[ -f $TEMP_APPEND_FILE ]]; then
        joplin edit $1
    fi
}

#---
## Usage: addImageFulltext note-id image-file
#---
function addImageFulltext {
	echo "$LOG_PREFIX Add image fulltext for `basename "$2"`"
	tesseract -l eng "$2" "$TEMP_APPEND_FILE"
    
    if [[ -f $TEMP_APPEND_FILE ]]; then
        joplin edit $1
    fi
}

#---
## Usage: addFulltextFromFile note-id file
#---
function addFulltextFromFile {
    local T=`determineMailPartType "$2"`
    if [[ "$T" == "PDF" ]] ; then
        addPdfFulltext "$1" "$2"
    elif [[ "$T" == "IMG" ]] ; then
        addImageFulltext "$1" "$2"
    else
        :
    fi
}

#---
## Usage: addFulltextFromFileParts note-id mail-parts-dir
#---
function addFulltextFromFileParts {
    find "$2" -type f -print0 | sort -z | while read -d $'\0' F; do
        addFulltextFromFile "$1" "$F"
    done
}


#---
## Usage: setCreationDate note-id filename
#---
function setCreationDateFromFilename {
	if [[ "$2" != "" ]]; then
		#local DATINT=`date -jf "%Y-%m-%d %H.%M.%S" "$2" +%s`
        # Modifying original date command since not supported by version in alpine 
        local DATINT=`date -r "$2" +%s`
   		echo "$LOG_PREFIX Set creation date $2 (${DATINT}000)"
		joplin set "$1" user_created_time ${DATINT}000
	fi
}

#---
## Usage: appendToBody note-id content
## To avoid issues with overlong note contents maxing out buffer, we use a proxy editor which appends our new content to the temporary md file that Joplin passes it 
#---
function appendToBody {
    echo -e "\n\n---\n$2" > $TEMP_APPEND_FILE
    joplin edit $1
}


## Usage: addNewNoteFromMailFile mail-file [maxThumbnails]
function addNewNoteFromMailFile {

    local FILE="$1"
    local NOTE_NAME=`basename "$FILE"`
    local SUBJECT=`getMailSubject "$FILE"`
    local TITLE=`getTitleFromSubject "$SUBJECT"`
    local TAGS=`getTagsFromSubject "$SUBJECT"`
    local NOTEBOOK=`getNotebookFromSubject "$SUBJECT" "$DEFAULT_NOTEBOOK"`

    local MAX_THUMBNAILS="$2"
    if [[ "${MAX_THUMBNAILS}x" == "x" ]] ; then
        MAX_THUMBNAILS=100
    fi

    switchToNotebook "${NOTEBOOK}"
    echo "$LOG_PREFIX Create new note with name '${NOTE_NAME}' in '${NOTEBOOK}'"
    local NOTE_ID=`createNewNote "${NOTE_NAME}"`
    echo "$LOG_PREFIX New note created - ID is: $NOTE_ID"

    setNoteTitle "$NOTE_ID" "$TITLE"
    setNoteTags "$NOTE_ID" "$TAGS"

    local TEMP_DIR=`mktemp -d`
    echo "$LOG_PREFIX Using temp dir: $TEMP_DIR"

    extractMailParts "${FILE}" "${TEMP_DIR}"
    setNoteBodyFromTextParts "$NOTE_ID" "${TEMP_DIR}"
    addAttachmentsFromFileParts "$NOTE_ID" "${TEMP_DIR}" $MAX_THUMBNAILS
    addFulltextFromFileParts "$NOTE_ID" "${TEMP_DIR}"

    echo "$LOG_PREFIX Removing temp dir: $TEMP_DIR"
    rm -r ${TEMP_DIR}

}


## Usage: getCreationDateFromFilename filename
function getCreationDateFromFilename {
    echo -n "$1" | python3 -c 'import sys,re; s=sys.stdin.read(); s=re.search("^(\d\d\d\d-\d\d-\d\d)(?:\s(\d\d.\d\d.\d\d)\s)?",s); print() if (s is None) else print(s.group(1)+" 00.00.00") if (s.group(2) is None) else print(s.group(1)+" "+s.group(2));'
}

## Usage: getTitleFromFilename filename
function getTitleFromFilename {
    echo -n "$1" | python3 -c 'import sys,re; s=sys.stdin.read(); s=re.search("^(?:\d\d\d\d-\d\d-\d\d(?:\s\d\d.\d\d.\d\d)?\s?-?\s?)?(.+?)(?:\[\s*\w+(?:\s+\w+)*\s*\])?(?:\.\w+)*?$",s); print(s.group(1)) if s else print();'
}

## Usage: getNotebookFromFilename filename default-notebook
function getNotebookFromFilename {
    # todo
    echo "$2"
}

## Usage: getTagsFromFilename filename
function getTagsFromFilename {
    echo -n "$1" | python3 -c 'import sys,re; s=sys.stdin.read(); s=re.search("^.*\[\s*(\w+(?:\s+\w+)*)\s*\](?:\.\w+)*?$",s); print(s.group(1)) if s else print();'
}




## Usage: addNewNoteFromGenericFile notebook file [maxThumbnails]
function addNewNoteFromGenericFile {

    local FILE="$2"
    local FILE_NAME=`basename "$FILE"`

    local MAX_THUMBNAILS="$3"
    if [[ "${MAX_THUMBNAILS}x" == "x" ]] ; then
        MAX_THUMBNAILS=100
    fi

    if [[ "$FILE_NAME" =~ ^\..*$ ]] ; then
        echo "$LOG_PREFIX Ignore hidden file $FILE_NAME"
        return 1
    fi

    local TITLE=`getTitleFromFilename "$FILE_NAME"`
    local TAGS=`getTagsFromFilename "$FILE_NAME"`
    local NOTEBOOK="$1"
    if [[ "${NOTEBOOK}x" == "x" ]]; then
        NOTEBOOK="$DEFAULT_NOTEBOOK"
    fi

    switchToNotebook "${NOTEBOOK}"
    echo "$LOG_PREFIX Create new note with name '${FILE_NAME}' in '${NOTEBOOK}'"
    local NOTE_ID=`createNewNote "${FILE_NAME}"`
    echo "$LOG_PREFIX New note created - ID is: $NOTE_ID"

    setNoteTitle "$NOTE_ID" "$TITLE"
    setNoteTags "$NOTE_ID" "$TAGS"
    setCreationDateFromFilename "$NOTE_ID" "$FILE"

    addAttachmentFromFile "$NOTE_ID" "$FILE" $MAX_THUMBNAILS
    addFulltextFromFile "$NOTE_ID" "$FILE"

}