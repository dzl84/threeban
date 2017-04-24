#!/bin/bash

ROOT=`dirname $(readlink -f "$0")`
NAME=disclosure_downloader
RUNNING=`docker inspect --format="{{ .State.Running }}" $NAME`
if [ $? -eq 1 ]; then
    echo "Container $NAME does not exist. Creating..."
    docker create -it --link threebandb --name $NAME -v $ROOT/..:/code -v $ROOT/../logs:/logs -v $ROOT/../data/disclosures:/data ruby:2.3.4
fi

RUNNING=`docker inspect --format="{{ .State.Running }}" $NAME`
if [ "$RUNNING" == "false" ]; then
    echo "Container $NAME is not running"
    docker start $NAME
fi

docker exec -i $NAME sh -c "cd /code; bundle install"

docker exec -i $NAME sh -c "RACK_ENV=production ruby /code/lib/disclosure_crawler.rb --action download >> /logs/disclosure_downloader.log 2>&1"
