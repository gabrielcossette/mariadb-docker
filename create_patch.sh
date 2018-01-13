#!/bin/bash

wget https://github.com/docker-library/mariadb/raw/master/10.3/docker-entrypoint.sh -O docker-entrypoint.sh

diff -Naur docker-entrypoint.sh entrypoint_modif > entrypoint.patch
