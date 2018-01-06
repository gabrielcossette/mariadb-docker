FROM mariadb

RUN sed -i "s/'root'/'admin'/g" /usr/local/bin/docker-entrypoint.sh
