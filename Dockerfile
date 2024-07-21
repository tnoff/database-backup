FROM sjc.ocir.io/tnoff/discord:latest

RUN apt-get install -y cron

RUN /opt/discord-venv/bin/pip install oci-cli

ENV WORKDIR="/opt/backup"

# Setup cronfiles
COPY ./files/backup.sh "${WORKDIR}/backup.sh"
COPY ./files/cron/backup-cron /etc/cron.d/backup-cron
RUN chmod +x "${WORKDIR}/backup.sh"
RUN chmod 0644 /etc/cron.d/backup-cron
RUN crontab /etc/cron.d/backup-cron
RUN touch /var/log/cron.log

CMD ["cron", "-f"]
