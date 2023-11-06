#!/bin/bash

ls -1 apps > sites/apps.txt;
if [ ! -f sites/common_site_config.json ]; then
  echo "{}" > sites/common_site_config.json;
fi
bench set-config -g db_host $DB_HOST;
bench set-config -gp db_port $DB_PORT;
bench set-config -g redis_cache "redis://$REDIS_CACHE";
bench set-config -g redis_queue "redis://$REDIS_QUEUE";
bench set-config -g redis_socketio "redis://$REDIS_SOCKETIO";
bench set-config -gp socketio_port $SOCKETIO_PORT;