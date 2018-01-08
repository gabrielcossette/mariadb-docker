FROM mariadb

RUN head -n -1 /usr/local/bin/docker-entrypoint.sh > /usr/local/bin/docker-entrypoint.sh

RUN echo $'echo "update user set user='admin' where user='root' ;" | "${mysql[@]}"\n\
echo 'FLUSH PRIVILEGES ;' | "${mysql[@]}"\n\
exec "$@"' >> /usr/local/bin/docker-entrypoint.sh
