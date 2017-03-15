#!/bin/bash

ROOT=`dirname $(readlink -f "$0")`
DBNAME=company_crawler
RUNNING=`docker inspect --format="{{ .State.Running }}" $DBNAME`
if [ $? -eq 1 ]; then
    echo "Container $DBNAME does not exist. Creating..."
    docker create -it --link threebandb --name $DBNAME -v $ROOT/..:/code -v $ROOT/../logs:/logs ruby:2.2.0
fi

RUNNING=`docker inspect --format="{{ .State.Running }}" $DBNAME`
if [ "$RUNNING" == "false" ]; then
    echo "Container $DBNAME is not running"
    docker start $DBNAME
fi

docker exec -it $DBNAME sh -c "cd /code; bundle install"

docker exec -it $DBNAME sh -c "RACK_ENV=production ruby /code/lib/company_crawler.rb >> /logs/company_crawler.log 2>&1"
