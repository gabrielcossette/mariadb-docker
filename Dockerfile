FROM mariadb

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

RUN chown mysql:mysql -R /docker-entrypoint-initdb.d

COPY create_table.sql /create_table.sql
COPY update_table.sql /update_table.sql