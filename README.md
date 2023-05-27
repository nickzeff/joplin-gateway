# joplin-gateway

## Overview
Simple (bash-based) mail gateway and file scan for the open source note taking and to-do application
[Joplin](https://joplin.cozic.net/).

It is **significantly** based on the original joplin-mail-gateway here: https://github.com/manolitto/joplin-mail-gateway. Many thanks should be directed to manolitto for investing the time to build the original version.

I have pre-built an (admittedly sizeable) image which runs on arm64 architectures, so you can run it on your raspberry pi (like I do). Grab [nickzeff/joplin-gateway:latest](https://hub.docker.com/repository/docker/nickzeff/joplin-gateway/general) from docker hub.

## Major Changes

The key changes are:

- The base image has been updated to a more recent version, and so have the included packages (such as getmail). 
- Code has been refactored to suit being containerised. It is strongly recommended to run everything as a container, since I have not substantially tested it as standalone code.
- The system now supports a scheduled filescan of a "hot folder" and a pop request to a provider of your choice. Cron has been set up for checks every minute, but locks are in place to prevent overlapping scripts
- Bash limitations throwing errors when building longer notes have been overcome by making changes outside Joplin in the filesystem rather than through string expansion. 

## First Run

I use a combination of docker-compose and Portainer for my "production" image/container administration. I make reference to these below, but please adapt to your toolset of choice.

In order to ensure you have persistence in regards to configuration and content storage, you should ensure you have appropriate volumes mapped. To illustrate this, here is the relevant section of my _docker-compose.yml_.

```
  joplin-gateway:
    image: nickzeff/joplin-gateway:latest
    container_name: joplin-gateway
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Asia/Singapore
    volumes:
      - /path/to/config-dir:/home/node/.config
      - /path/to/hot-folder:/home/node/joplin-file-scan
    ports:
      - 8967:8967
      - 9967:9967
    restart: unless-stopped
```

Here are some notes on the above:

- If you have mapped directories to your host as above and your config directory does not contain anything, a scheduled script will create initial versions of global config, Joplin config and getmail config for you. You will still need to edit these to get everything to work (see below).
- For my hot folder, I mapped a location on my local server which syncs with a directory on my OneDrive. What this ultimately means is that I can "send" files from other applications to a specific folder on my OneDrive and they will be imported into Joplin. Handy for mobile apps which support this function.  
- Those ports only need to be exposed if you are syncing via OneDrive (which I was previously). The initial sync requires you to browse to an auth page served by the Joplin app, which then enables you to link your OneDrive account. I had way too many problems with OneDrive sync, but this info may help you.

## Global Config

Head into the config folder you mapped and update as per guidance below.

You can find the global config in _config-defaults.sh_

Some of these will be familiar if you have used the original [joplin-mail-gateway](https://joplin.cozic.net/). Hopefully most of the config is self-explanatory, but as an extra bit of info see below.

```
DEFAULT_TITLE_PREFIX="New Note"
DEFAULT_NOTEBOOK="Inbox"

# Whether to create the default notebook if it doesn't exist. 
AUTO_CREATE_NOTEBOOK=false 

# Seconds until mail or file lock expires 
LOCKFILE_DURATION=600

# Maximum number of thumbnails to generate from a PDF. Set to a very high number if you really like lots of thumbnails (I don't). Value of 0 means no thumbnails.
MAX_THUMBNAILS=1

# ---------- Advanced Configuration ------

# Please don't change this. I will probably hide it in the next version
TEMP_APPEND_FILE="/tmp/jg-temporary-content"
```

**Process Locks**

Regarding process locks. Separately from the joplin sync lock, I have also built in separate locks for the mail poll and the file scan scripts respectively. This is quite handy, since you have have checks every minute for new stuff to import, but still avoid having multiple scripts overlapping and causing chaos if the import process is taking a while.

If everything is working correctly, a lock is generated if the scripts find anything to import. It is automatically cleared once the import is complete (the import includes the Joplin after the import).

However, in case the script falling over before it gets a chance to remove the lock, the lock automatically expires LOCK_DURATION seconds after the lock was initially created.

## Joplin config

You should go into _./joplin/joplin-config.json_ and update the relevant items for your sync.

An explanation of the config is outside the scope of this README, and you can read the [official documentation](https://joplinapp.org/terminal/#commands) (look under the config command for a list of settings you can potentially edit or insert into the json).

I would generally recommend you touch as little as possible in this file if everything is working, but the following is required for sync to work:

| Configuration Key | Notes |
| --- | --- |
| sync.target       | This is the key one for you to update and defines where your sync target is. Read the Joplin config for more information. You will need to update this and potentially add one or more key/value pairs which help define usernames and passwords for your chosen cloud. <br> <br>For example, I use<br><br>sync.target = 10 (Joplin Cloud)<br>sync.10.username = < my Joplin Cloud username ><br>sync.10.password = < my Joplin Cloud password>|

The following is for your information only:

| Configuration Key | Notes |
| --- | --- |
| editor | Do not change this value, or you will experience unexpected behaviours when running the scripts |
| sync.wipeOutFailSafe | Strongly recommend keeping this as true, to prevent potential data loss |
| sync.resourceDownloadMode | This is an undocumented setting which is used by the desktop application and I have made use of it here, with a value of _auto_. This seems to work for the terminal app, namely preventing it from downloading images and other attachments. This saves you quite a bit of disk space. |

## Getmail config

Due to an annoying bug with getmail which seems to have been around for a while, the original approach manolitto used for calling getmail does not work. Even more recent versions available through backport repos do not work. What this means is that configuration of getmail is now done through the separate file _./getmail/getmailrc_

You can of course [wade through the extensive getmail documentation](https://getmail6.org/configuration.html#rcfile) to learn more, but the key section to update is of course

```
[retriever]
type = SimplePOP3SSLRetriever
server = pop.gmail.com
username = username-goes-here
password = password-goes-here
port = 995
```

Careful to preserve the spaces around the "=" signs. Seems to be picky.

You can check out some of the other settings while you're in here, including options to throttle the mail checks via _max_messages_per_session_ or delete emails after downloading via _delete_.

**A note on gmail**

Google doesn't really like this non-MFA, single factor authentication approach to POPping its mail server. It has a point. I personally set up a separate, dedicated gmail account to be my gateway. You should [check out Google's related FAQ here](https://support.google.com/accounts/answer/6010255?fl=1) if you're getting authentication errors, even if you added your correct username and password.

## Troubleshooting

I will try to expand this section if required, but if you are experiencing difficulties, here are some extra hints.

- Most information relating to the mail and file scan activities can be found in scan.log which is surfaced by the container as the main CMD. This means you should be able to see issues if you go to the container log in Portainer, for example.
- If you are having issues with locks (whether Joplin sync lock, mail poll lock or file scan lock) then you can always head into the container via the console and remove the lock files in _\tmp_. Caution is advised. Sometimes these things just take time.

## Todo

- Provide better documentation
- Slim down the image - this is reduced slightly in latest version by using alpine... but not much
