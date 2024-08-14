FROM ubuntu:24.04

RUN apt-get update && apt-get install -y virtualenv cron postgresql-client

RUN virutalenv /opt/venv/
RUN /opt/venv/bin/pip install oci-cli

ENV WORKDIR="/opt/backup"

# Setup cronfiles
COPY ./files/backup.sh "${WORKDIR}/backup.sh"
COPY ./files/cron/backup-cron /etc/cron.d/backup-cron
RUN chmod +x "${WORKDIR}/backup.sh"
RUN chmod 0644 /etc/cron.d/backup-cron
RUN crontab /etc/cron.d/backup-cron
RUN touch /var/log/cron.log

CMD ["cron", "-f"]
