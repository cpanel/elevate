FROM ubuntu:jammy

RUN apt-get update

COPY setup_terraform.sh /setup_terraform.sh
COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/setup_terraform.sh", "/entrypoint.sh"]
