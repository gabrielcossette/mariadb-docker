FROM mariadb

ADD docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

ADD https://raw.githubusercontent.com/phpmyadmin/phpmyadmin/master/sql/create_tables.sql /docker-entrypoint-initdb.d/create_tables.sql

RUN chmod 777 /docker-entrypoint-initdb.d/create_tables.sql
