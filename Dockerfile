FROM mariadb

RUN apt-get install -y patch

ADD entrypoint.patch ./

RUN patch /usr/local/bin/docker-entrypoint.sh entrypoint.patch && rm entrypoint.patch
