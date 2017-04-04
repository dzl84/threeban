#!/bin/bash

ROOT=`dirname $(readlink -f "$0")`
NAME=disclosure_crawler
RUNNING=`docker inspect --format="{{ .State.Running }}" $NAME`
if [ $? -eq 1 ]; then
    echo "Container $NAME does not exist. Creating..."
    docker create -it --link threebandb --name $NAME -v $ROOT/..:/code -v $ROOT/../logs:/logs ruby:2.3.0
fi

RUNNING=`docker inspect --format="{{ .State.Running }}" $NAME`
if [ "$RUNNING" == "false" ]; then
    echo "Container $NAME is not running"
    docker start $NAME
else
    echo "Container $NAME is already running, exiting"
    exit 0
fi

echo "Running job"
docker exec -i $NAME sh -c "cd /code; bundle install"
docker exec -i $NAME sh -c "RACK_ENV=production ruby /code/lib/disclosure_crawler.rb --action crawl-list >> /logs/disclosure_crawler.log 2>&1"

echo "Stopping container $NAME"
docker stop $NAME