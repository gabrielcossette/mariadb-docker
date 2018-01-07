FROM mariadb

RUN sed -i '$d' /usr/local/bin/docker-entrypoint.sh

RUN { \
    echo '		"${mysql[@]}" <<-EOSQL'; \
    echo '      use mysql;'; \
    echo "      update user set user='admin' where user='root';"; \
    echo '      flush privileges;'; \
    echo '		EOSQL'; \
		echo 'exec "$@"'; \
	} >> /usr/local/bin/docker-entrypoint.sh
