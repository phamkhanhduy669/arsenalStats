#!/bin/sh
set -e

printenv | sed 's/^/export /' > /etc/environment

exec "$@"