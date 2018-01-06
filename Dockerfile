FROM mariadb

RUN sed -i "s/'root'/'asd'/g" /usr/local/bin/docker-entrypoint.sh
