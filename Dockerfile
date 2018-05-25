FROM mariadb

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

COPY create_tables.sql /docker-entrypoint-initdb.d/create_tables.sql
RUN chmod 777 /docker-entrypoint-initdb.d/create_tables.sql

COPY update_tables.sql /update_tables.sql
RUN chmod 777 /update_tables.sql
