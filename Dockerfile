FROM python:3.14-slim-bookworm
ENV WORKDIR="/opt/backup"

# https://linuxcapable.com/how-to-install-postgresql-16-on-ubuntu-linux/
RUN apt-get update && apt-get install -y curl gpg lsb-release
RUN curl -fSsL https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor | tee /usr/share/keyrings/postgresql.gpg > /dev/null
RUN echo deb [arch=amd64,arm64,ppc64el signed-by=/usr/share/keyrings/postgresql.gpg] http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main | tee /etc/apt/sources.list.d/postgresql.list

RUN apt-get update && apt-get install -y gcc postgresql-client-16

# Remove gcc for image size
RUN apt-get remove -y curl gpg lsb-release gcc && apt-get autoremove -y

COPY requirements.txt /opt/requirements.txt
RUN pip install -r /opt/requirements.txt
RUN rm /opt/requirements.txt

# Setup cronfiles
COPY ./files/backup.sh "${WORKDIR}/backup.sh"
COPY ./files/oci.sh "${WORKDIR}/oci.sh"
COPY ./files/aws.sh "${WORKDIR}/aws.sh"
RUN chmod +x "${WORKDIR}/backup.sh" "${WORKDIR}/oci.sh" "${WORKDIR}/aws.sh"

CMD ["/opt/backup/backup.sh", ">>", "/var/log/backup.log",  "2>&1"]
