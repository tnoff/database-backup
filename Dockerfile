FROM ubuntu:24.04

RUN apt-get update && apt-get install -y python3-dev python3-virtualenv postgresql-client

RUN virtualenv /opt/venv/
RUN /opt/venv/bin/pip install oci-cli

ENV WORKDIR="/opt/backup"

# Setup cronfiles
COPY ./files/backup.sh "${WORKDIR}/backup.sh"
RUN chmod +x "${WORKDIR}/backup.sh"

CMD ["/opt/backup/backup.sh", ">>", "/var/log/backup.log",  "2>&1"]
