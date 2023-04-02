FROM node:19-bullseye-slim

LABEL maintainer="nick@jeffri.es"

# This docker file automatically installs joplin + email gateway and file scanning scripts and starts
# forwarding notes

RUN apt-get update && apt-get install -y \
    libsecret-1-dev \
    cron \
    poppler-utils \
    tesseract-ocr \
    getmail \
    ripmime \
    python3 \
    && rm -rf /var/lib/apt/lists/*

USER node

# Copy over the default settings directory
COPY --chown=node:node ./defaults /home/node/defaults

ENV NPM_CONFIG_PREFIX=/home/node/.npm-global
RUN npm install -g joplin
RUN /home/node/.npm-global/bin/joplin config --import-file /home/node/defaults/joplin-config.json
RUN cp -r /home/node/.config/joplin /home/node/defaults/

USER 0

RUN ln -s /home/node/.npm-global/bin/joplin /usr/bin/joplin
RUN adduser node crontab

USER node

RUN mkdir -p /home/node/joplin-mailbox/new
RUN mkdir -p /home/node/joplin-mailbox/cur
RUN mkdir -p /home/node/joplin-mailbox/tmp
RUN mkdir -p /home/node/joplin-file-scan

COPY --chown=node:node . /home/node
RUN /home/node/expose-config.sh
RUN ln -s /home/node/.config/config-defaults.sh /home/node/config-defaults.sh
RUN touch /home/node/scan.log

RUN echo "SHELL=/bin/bash" > /home/node/joplin.cron
RUN echo "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" >> /home/node/joplin.cron
RUN echo "* * * * * /home/node/fetch-joplin-mails.sh >> /home/node/scan.log 2>&1" >> /home/node/joplin.cron
RUN echo "* * * * * /home/node/import-files-to-joplin.sh /home/node/joplin-file-scan >> /home/node/scan.log 2>&1" >> /home/node/joplin.cron
RUN echo "* * * * * /home/node/expose-config.sh >> /home/node/scan.log 2>&1" >> /home/node/joplin.cron
RUN echo "# An empty line is required at the end of this file for a valid cron file."
RUN crontab -u node /home/node/joplin.cron

USER 0

EXPOSE 8967
EXPOSE 9967

CMD cron && tail -f /home/node/scan.log