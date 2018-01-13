FROM mariadb

ADD entrypoint.patch ./

RUN patch /usr/local/bin/docker-entrypoint.sh entrypoint.patch && rm entrypoint.patch
