FROM ubuntu:20.04

RUN apt update

COPY setup_terraform.sh /setup_terraform.sh
COPY entrypoint.sh /entrypoint.sh
COPY env /env
COPY main.tf /main.tf
COPY variables.tf /variables.tf

RUN /setup_terraform.sh

ENTRYPOINT ["/entrypoint.sh"]
