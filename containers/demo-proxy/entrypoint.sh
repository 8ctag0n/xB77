#!/bin/sh
set -e

HOST_ALIAS=${HOST_ALIAS:-host.containers.internal}
HUB_PORT=${HUB_PORT:-7777}
LISTENER_PORT=${LISTENER_PORT:-7002}
MCP_PORT=${MCP_PORT:-7001}

envsubst '$HOST_ALIAS $HUB_PORT $LISTENER_PORT $MCP_PORT' \
    < /etc/nginx/templates/default.conf.template \
    > /etc/nginx/conf.d/default.conf

exec nginx -g 'daemon off;'
