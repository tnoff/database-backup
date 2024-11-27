FROM ubuntu:24.04
ENV WORKDIR="/opt/backup"

RUN apt-get update && apt-get install -y python3-dev python3-virtualenv postgresql-client

RUN virtualenv /opt/venv/
COPY requirements.txt /opt/requirements.txt
RUN /opt/venv/bin/pip install -r /opt/requirements.txt

# Setup cronfiles
COPY ./files/backup.sh "${WORKDIR}/backup.sh"

RUN chmod +x "${WORKDIR}/backup.sh"

CMD ["/opt/backup/backup.sh", ">>", "/var/log/backup.log",  "2>&1"]
