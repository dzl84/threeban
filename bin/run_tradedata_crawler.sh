#!/bin/bash

ROOT=`dirname $(readlink -f "$0")`
NAME=tradedata_crawler
RUNNING=`docker inspect --format="{{ .State.Running }}" $NAME`
if [ $? -eq 1 ]; then
    echo "Container $NAME does not exist. Creating..."
    docker create -it --link threebandb --name $NAME -v $ROOT/..:/code -v $ROOT/../logs:/logs ruby:2.3.4
fi

RUNNING=`docker inspect --format="{{ .State.Running }}" $NAME`
if [ "$RUNNING" == "false" ]; then
    echo "Container $NAME is not running"
    docker start $NAME
else
    echo "Container $NAME is still running, exiting"
    exit 0
fi

docker exec -i $NAME sh -c "cd /code; bundle install"

docker exec -i $NAME sh -c "RACK_ENV=production ruby /code/lib/tradedata_crawler.rb >> /logs/tradedata_crawler.log 2>&1"

docker stop $NAME