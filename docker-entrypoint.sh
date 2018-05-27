#!/bin/bash
set -eo pipefail
shopt -s nullglob

# if command starts with an option, prepend mysqld
if [ "${1:0:1}" = '-' ]; then
	set -- mysqld "$@"
fi

# skip setup if they want an option that stops mysqld
wantHelp=
for arg; do
	case "$arg" in
		-'?'|--help|--print-defaults|-V|--version)
			wantHelp=1
			break
			;;
	esac
done

# usage: file_env VAR [DEFAULT]
#    ie: file_env 'XYZ_DB_PASSWORD' 'example'
# (will allow for "$XYZ_DB_PASSWORD_FILE" to fill in the value of
#  "$XYZ_DB_PASSWORD" from a file, especially for Docker's secrets feature)
file_env() {
	local var="$1"
	local fileVar="${var}_FILE"
	local def="${2:-}"
	if [ "${!var:-}" ] && [ "${!fileVar:-}" ]; then
		echo >&2 "error: both $var and $fileVar are set (but are exclusive)"
		exit 1
	fi
	local val="$def"
	if [ "${!var:-}" ]; then
		val="${!var}"
	elif [ "${!fileVar:-}" ]; then
		val="$(< "${!fileVar}")"
	fi
	export "$var"="$val"
	unset "$fileVar"
}

file_env 'MYSQL_ROOT_PASSWORD'
file_env 'MYSQL_PASSWORD_USER1'
file_env 'MYSQL_PASSWORD_USER2'
file_env 'MYSQL_PASSWORD_USER3'
file_env 'MYSQL_USER_USER1'
file_env 'MYSQL_USER_USER2'
file_env 'MYSQL_USER_USER3'
file_env 'MYSQL_SECRET_USER1'
file_env 'MYSQL_SECRET_USER2'
file_env 'MYSQL_SECRET_USER3'
file_env 'MYSQL_PASSWORD_WP'
file_env 'MYSQL_PASSWORD_PYDIO'
file_env 'MYSQL_PASSWORD_PMA'

_check_config() {
	toRun=( "$@" --verbose --help --log-bin-index="$(mktemp -u)" )
	if ! errors="$("${toRun[@]}" 2>&1 >/dev/null)"; then
		cat >&2 <<-EOM

			ERROR: mysqld failed while attempting to check config
			command was: "${toRun[*]}"

			$errors
		EOM
		exit 1
	fi
}

# Fetch value from server config
# We use mysqld --verbose --help instead of my_print_defaults because the
# latter only show values present in config files, and not server defaults
_get_config() {
	local conf="$1"; shift
	"$@" --verbose --help --log-bin-index="$(mktemp -u)" 2>/dev/null | awk '$1 == "'"$conf"'" { print $2; exit }'
}

# allow the container to be started with `--user`
if [ "$1" = 'mysqld' -a -z "$wantHelp" -a "$(id -u)" = '0' ]; then
	_check_config "$@"
	DATADIR="$(_get_config 'datadir' "$@")"
	mkdir -p "$DATADIR"
	chown -R mysql:mysql "$DATADIR"
	exec gosu mysql "$BASH_SOURCE" "$@"
fi

if [ "$1" = 'mysqld' -a -z "$wantHelp" ]; then
	# still need to check config, container may have started with --user
	_check_config "$@"
	# Get config
	DATADIR="$(_get_config 'datadir' "$@")"

	if [ ! -d "$DATADIR/mysql" ]; then
		if [ -z "$MYSQL_ROOT_PASSWORD" -a -z "$MYSQL_ALLOW_EMPTY_PASSWORD" -a -z "$MYSQL_RANDOM_ROOT_PASSWORD" ]; then
			echo >&2 'error: database is uninitialized and password option is not specified '
			echo >&2 '  You need to specify one of MYSQL_ROOT_PASSWORD, MYSQL_ALLOW_EMPTY_PASSWORD and MYSQL_RANDOM_ROOT_PASSWORD'
			exit 1
		fi

		mkdir -p "$DATADIR"

		echo 'Initializing database'
		mysql_install_db --datadir="$DATADIR" --rpm
		echo 'Database initialized'

		SOCKET="$(_get_config 'socket' "$@")"
		"$@" --skip-networking --socket="${SOCKET}" &
		pid="$!"

		mysql=( mysql --protocol=socket -uroot -hlocalhost --socket="${SOCKET}" )

		for i in {30..0}; do
			if echo 'SELECT 1' | "${mysql[@]}" &> /dev/null; then
				break
			fi
			echo 'MySQL init process in progress...'
			sleep 1
		done
		if [ "$i" = 0 ]; then
			echo >&2 'MySQL init process failed.'
			exit 1
		fi

		if [ -z "$MYSQL_INITDB_SKIP_TZINFO" ]; then
			# sed is for https://bugs.mysql.com/bug.php?id=20545
			mysql_tzinfo_to_sql /usr/share/zoneinfo | sed 's/Local time zone must be set--see zic manual page/FCTY/' | "${mysql[@]}" mysql
		fi

		if [ ! -z "$MYSQL_RANDOM_ROOT_PASSWORD" ]; then
			export MYSQL_ROOT_PASSWORD="$(pwgen -1 32)"
			echo "GENERATED ROOT PASSWORD: $MYSQL_ROOT_PASSWORD"
		fi

		rootCreate=
		# default root to listen for connections from anywhere
		if [ ! -z "$MYSQL_ROOT_HOST" -a "$MYSQL_ROOT_HOST" != 'localhost' ]; then
			# no, we don't care if read finds a terminating character in this heredoc
			# https://unix.stackexchange.com/questions/265149/why-is-set-o-errexit-breaking-this-read-heredoc-expression/265151#265151
			read -r -d '' rootCreate <<-EOSQL || true
				CREATE USER 'root'@'${MYSQL_ROOT_HOST}' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}' ;
				GRANT ALL ON *.* TO 'root'@'${MYSQL_ROOT_HOST}' WITH GRANT OPTION ;
			EOSQL
		fi

		"${mysql[@]}" <<-EOSQL
			-- What's done in this file shouldn't be replicated
			--  or products like mysql-fabric won't work
			SET @@SESSION.SQL_LOG_BIN=0;

			DELETE FROM mysql.user WHERE user NOT IN ('mysql.sys', 'mysqlxsys', 'root') OR host NOT IN ('localhost') ;
			SET PASSWORD FOR 'root'@'localhost'=PASSWORD('${MYSQL_ROOT_PASSWORD}') ;
			GRANT ALL ON *.* TO 'root'@'localhost' WITH GRANT OPTION ;
			${rootCreate}
			DROP DATABASE IF EXISTS test ;
			FLUSH PRIVILEGES ;
		EOSQL

		if [ ! -z "$MYSQL_ROOT_PASSWORD" ]; then
			mysql+=( -p"${MYSQL_ROOT_PASSWORD}" )
		fi


		if [ "$MYSQL_DATABASE_PYDIO" ]; then
			echo "CREATE DATABASE IF NOT EXISTS \`$MYSQL_DATABASE_PYDIO\` ;" | "${mysql[@]}"
		fi

		if [ "$MYSQL_DATABASE_PMA" ]; then
			echo "CREATE DATABASE IF NOT EXISTS \`$MYSQL_DATABASE_PMA\` ;" | "${mysql[@]}"
		fi
		
		if [ "$MYSQL_USER_USER1" -a "$MYSQL_PASSWORD_USER1" ]; then
			echo "CREATE USER '$MYSQL_USER_USER1'@'%' IDENTIFIED BY '$MYSQL_PASSWORD_USER1' ;" | "${mysql[@]}"
			echo "GRANT ALL ON *.* TO '$MYSQL_USER_USER1'@'%' WITH GRANT OPTION ;" | "${mysql[@]}"
			echo 'FLUSH PRIVILEGES ;' | "${mysql[@]}"
		fi

		if [ "$MYSQL_USER_USER2" -a "$MYSQL_PASSWORD_USER2" ]; then
			echo "CREATE USER '$MYSQL_USER_USER2'@'%' IDENTIFIED BY '$MYSQL_PASSWORD_USER2' ;" | "${mysql[@]}"
			echo "GRANT ALL ON *.* TO '$MYSQL_USER_USER2'@'%' WITH GRANT OPTION ;" | "${mysql[@]}"
			echo 'FLUSH PRIVILEGES ;' | "${mysql[@]}"
		fi

		if [ "$MYSQL_USER_USER3" -a "$MYSQL_PASSWORD_USER3" ]; then
			echo "CREATE USER '$MYSQL_USER_USER3'@'%' IDENTIFIED BY '$MYSQL_PASSWORD_USER3' ;" | "${mysql[@]}"
			echo "GRANT ALL ON *.* TO '$MYSQL_USER_USER3'@'%' WITH GRANT OPTION ;" | "${mysql[@]}"
			echo 'FLUSH PRIVILEGES ;' | "${mysql[@]}"
		fi

		if [ "$MYSQL_USER_WP" -a "$MYSQL_PASSWORD_WP" ]; then
			echo "CREATE USER '$MYSQL_USER_WP'@'%' IDENTIFIED BY '$MYSQL_PASSWORD_WP' ;" | "${mysql[@]}"

			if [ "$MYSQL_DATABASE_WP" ]; then
				echo "GRANT ALL ON \`$MYSQL_DATABASE_WP\`.* TO '$MYSQL_USER_WP'@'%' ;" | "${mysql[@]}"
			fi
			
			echo 'FLUSH PRIVILEGES ;' | "${mysql[@]}"
		fi		

		if [ "$MYSQL_USER_PYDIO" -a "$MYSQL_PASSWORD_PYDIO" ]; then
			echo "CREATE USER '$MYSQL_USER_PYDIO'@'%' IDENTIFIED BY '$MYSQL_PASSWORD_PYDIO' ;" | "${mysql[@]}"

			if [ "$MYSQL_DATABASE_PYDIO" ]; then
				echo "GRANT ALL ON \`$MYSQL_DATABASE_PYDIO\`.* TO '$MYSQL_USER_PYDIO'@'%' ;" | "${mysql[@]}"
			fi
			
			echo 'FLUSH PRIVILEGES ;' | "${mysql[@]}"
		fi

		if [ "$MYSQL_USER_PMA" -a "$MYSQL_PASSWORD_PMA" ]; then
			echo "CREATE USER '$MYSQL_USER_PMA'@'%' IDENTIFIED BY '$MYSQL_PASSWORD_PMA' ;" | "${mysql[@]}"

			if [ "$MYSQL_DATABASE_PMA" ]; then
				echo "GRANT ALL ON \`$MYSQL_DATABASE_PMA\`.* TO '$MYSQL_USER_PMA'@'%' ;" | "${mysql[@]}"
			fi
			
			echo 'FLUSH PRIVILEGES ;' | "${mysql[@]}"
		fi

		cp /create_table.sql /docker-entrypoint-initdb.d/create_table_modif.sql
		sed -i -e "s/username1/$MYSQL_USER_USER1/g" /docker-entrypoint-initdb.d/create_table_modif.sql
		sed -i -e "s/username2/$MYSQL_USER_USER2/g" /docker-entrypoint-initdb.d/create_table_modif.sql
		sed -i -e "s/username3/$MYSQL_USER_USER3/g" /docker-entrypoint-initdb.d/create_table_modif.sql
		sed -i -e "s/SECRETUSER1/$MYSQL_SECRET_USER1/g" /docker-entrypoint-initdb.d/create_table_modif.sql
		sed -i -e "s/SECRETUSER2/$MYSQL_SECRET_USER2/g" /docker-entrypoint-initdb.d/create_table_modif.sql
		sed -i -e "s/SECRETUSER3/$MYSQL_SECRET_USER3/g" /docker-entrypoint-initdb.d/create_table_modif.sql

		echo
		for f in /docker-entrypoint-initdb.d/*; do
			case "$f" in
				*.sh)     echo "$0: running $f"; . "$f" ;;
				*.sql)    echo "$0: running $f"; "${mysql[@]}" < "$f"; echo ;;
				*.sql.gz) echo "$0: running $f"; gunzip -c "$f" | "${mysql[@]}"; echo ;;
				*)        echo "$0: ignoring $f" ;;
			esac
			echo
		done

		if ! kill -s TERM "$pid" || ! wait "$pid"; then
			echo >&2 'MySQL init process failed.'
			exit 1
		fi

		echo
		echo 'MySQL init process done. Ready for start up.'
		echo
	
	else

		SOCKET="$(_get_config 'socket' "$@")"
		"$@" --skip-networking --socket="${SOCKET}" &
		pid="$!"

		mysql=( mysql --protocol=socket -uroot -hlocalhost --socket="${SOCKET}" -p"${MYSQL_ROOT_PASSWORD}")

		for i in {30..0}; do
			if echo 'SELECT 1' | "${mysql[@]}" &> /dev/null; then
				break
			fi
			echo 'MySQL init process in progress...'
			sleep 1
		done
		if [ "$i" = 0 ]; then
			echo >&2 'MySQL init process failed.'
			exit 1
		fi

		mysql -hlocalhost -uroot -p"${MYSQL_ROOT_PASSWORD}" -e "ALTER USER '$MYSQL_USER_USER1'@'%' IDENTIFIED BY '${MYSQL_PASSWORD_USER1}';"
		mysql -hlocalhost -uroot -p"${MYSQL_ROOT_PASSWORD}" -e "ALTER USER '$MYSQL_USER_USER2'@'%' IDENTIFIED BY '${MYSQL_PASSWORD_USER2}';"
		mysql -hlocalhost -uroot -p"${MYSQL_ROOT_PASSWORD}" -e "ALTER USER '$MYSQL_USER_USER3'@'%' IDENTIFIED BY '${MYSQL_PASSWORD_USER3}';"
		mysql -hlocalhost -uroot -p"${MYSQL_ROOT_PASSWORD}" -e "ALTER USER '$MYSQL_USER_WP'@'%' IDENTIFIED BY '${MYSQL_PASSWORD_WP}';"
		mysql -hlocalhost -uroot -p"${MYSQL_ROOT_PASSWORD}" -e "ALTER USER '$MYSQL_USER_PYDIO'@'%' IDENTIFIED BY '${MYSQL_PASSWORD_PYDIO}';"
		mysql -hlocalhost -uroot -p"${MYSQL_ROOT_PASSWORD}" -e "ALTER USER '$MYSQL_USER_PMA'@'%' IDENTIFIED BY '${MYSQL_PASSWORD_PMA}';"
		
		cp /update_table /update_table_modif
		sed -i -e "s/username1/$MYSQL_USER_USER1/g" /update_table_modif.sql
		sed -i -e "s/username2/$MYSQL_USER_USER2/g" /update_table_modif.sql
		sed -i -e "s/username3/$MYSQL_USER_USER3/g" /update_table_modif.sql
		sed -i -e "s/SECRETUSER1/$MYSQL_SECRET_USER1/g" /update_table_modif.sql
		sed -i -e "s/SECRETUSER2/$MYSQL_SECRET_USER2/g" /update_table_modif.sql
		sed -i -e "s/SECRETUSER3/$MYSQL_SECRET_USER3/g" /update_table_modif.sql
		mysql -hlocalhost -uroot -p"${MYSQL_ROOT_PASSWORD}" < /update_table_modif.sql
		
		if ! kill -s TERM "$pid" || ! wait "$pid"; then
			echo >&2 'MySQL init process failed.'
			exit 1
		fi
	fi
fi

exec "$@"
