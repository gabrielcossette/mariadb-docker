FROM mariadb

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

COPY create_table.sql /create_table.sql
RUN chmod 777 /create_table.sql

COPY update_table.sql /update_table.sql
RUN chmod 777 /update_table.sql
