FROM mariadb

RUN apt-get update && apt-get install -y patch

ADD entrypoint.patch ./

RUN patch /usr/local/bin/docker-entrypoint.sh entrypoint.patch && rm entrypoint.patch
