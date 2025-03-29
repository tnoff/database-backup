FROM python:3.13-slim-bookworm
ENV WORKDIR="/opt/backup"

RUN apt-get update && apt-get install -y gcc postgresql-client

# Remove gcc for image size
RUN apt-get remove -y gcc && apt-get autoremove -y

COPY requirements.txt /opt/requirements.txt
RUN pip install -r /opt/requirements.txt
RUN rm /opt/requirements.txt

# Setup cronfiles
COPY ./files/backup.sh "${WORKDIR}/backup.sh"
COPY ./files/oci.sh "${WORKDIR}/oci.sh"
COPY ./files/aws.sh "${WORKDIR}/aws.sh"
RUN chmod +x "${WORKDIR}/backup.sh" "${WORKDIR}/oci.sh" "${WORKDIR}/aws.sh"

CMD ["/opt/backup/backup.sh", ">>", "/var/log/backup.log",  "2>&1"]
