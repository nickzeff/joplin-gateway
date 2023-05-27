FROM node:20-alpine

LABEL maintainer="nick@jeffri.es"

# This docker file automatically installs joplin + email gateway and file scanning scripts and starts
# forwarding notes

# Install packages from alpine repos

RUN apk update

RUN apk add --update --no-cache \
    bash nodejs npm poppler-utils tesseract-ocr ripmime curl

RUN apk add --update --no-cache --repository http://dl-cdn.alpinelinux.org/alpine/edge/main/ \
    python3

RUN apk add --update --no-cache --repository http://dl-cdn.alpinelinux.org/alpine/edge/testing/ \
    getmail6

RUN python3 -m ensurepip --upgrade

# crond needs root on alpine, so install replacement yacron instead which will allow to be run as node user
RUN python3 -m venv yacronenv
RUN . yacronenv/bin/activate
RUN python3 -m pip install yacron

USER node

# Copy over the default settings directory and install Joplin
COPY --chown=node:node ./defaults /home/node/defaults

ENV NPM_CONFIG_PREFIX=/home/node/.npm-global
RUN npm install -g joplin

# Import our default Joplin settings, and then place a snapshot of the config directory in our defaults dir
# If user maps /home/node/.config to an empty host directory (usually on first installation), we will copy the config back 
RUN /home/node/.npm-global/bin/joplin config --import-file /home/node/defaults/joplin-config.json
RUN cp -r /home/node/.config/joplin /home/node/defaults/

# Set up the getmail mailbox dirs
RUN mkdir -p /home/node/joplin-mailbox/new
RUN mkdir -p /home/node/joplin-mailbox/cur
RUN mkdir -p /home/node/joplin-mailbox/tmp
RUN mkdir -p /home/node/joplin-file-scan

# Copy all the scripts and config files over
# Run our file checker script expose-config.sh once, which will ensure .config directory is set up fresh 
COPY --chown=node:node . /home/node
RUN /home/node/expose-config.sh
RUN ln -s /home/node/.config/config-defaults.sh /home/node/config-defaults.sh

USER 0

# Link joplin so can be called via single command, and expose ports which may be used for sync provider first time setup
RUN ln -s /home/node/.npm-global/bin/joplin /usr/bin/joplin
EXPOSE 8967
EXPOSE 9967

USER node

CMD yacron -c /home/node/crontab.yaml