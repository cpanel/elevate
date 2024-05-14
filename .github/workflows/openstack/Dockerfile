FROM ubuntu:20.04

RUN apt update

COPY setup_terraform.sh /setup_terraform.sh
COPY entrypoint.sh /entrypoint.sh

COPY terraform /terraform/

RUN /setup_terraform.sh

ENTRYPOINT ["/entrypoint.sh"]
