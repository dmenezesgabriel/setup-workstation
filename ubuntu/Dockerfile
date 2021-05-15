FROM ubuntu:20.04

COPY ./setup_workstation.sh /

RUN [ "chmod", "+x", "./setup_workstation.sh" ]

RUN echo "Updating"

RUN apt-get -qq update && \
      apt-get -qq -y install --no-install-recommends sudo

RUN useradd -m docker && echo "docker:docker" | chpasswd && adduser docker sudo

USER docker

WORKDIR /home/docker








