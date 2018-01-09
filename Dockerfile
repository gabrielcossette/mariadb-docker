FROM mariadb

RUN head -n -1 /usr/local/bin/docker-entrypoint.sh > /usr/local/bin/docker-entrypoint-temp.sh; mv /usr/local/bin/docker-entrypoint-temp.sh /usr/local/bin/docker-entrypoint.sh

RUN { \
    echo 'echo "update user set user=admin where user=root ;" | "${mysql[@]}"'; \
    echo 'echo "FLUSH PRIVILEGES ;" | "${mysql[@]}"'; \
    echo 'exec "$@"'; \
    } >> /usr/local/bin/docker-entrypoint.sh
