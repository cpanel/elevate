FROM ubuntu:jammy

RUN apt-get update

COPY entrypoint.sh /entrypoint.sh

COPY setup_terraform.sh /setup_terraform.sh

CMD [ "./setup_terraform.sh" ]

ENTRYPOINT ["/entrypoint.sh"]
