#!/bin/bash

ROOT=`dirname $(readlink -f "$0")`
DBNAME=threebandb
RUNNING=`docker inspect --format="{{ .State.Running }}" $DBNAME`
if [ $? -eq 1 ]; then
    echo "Container $DBNAME does not exist. Creating..."
    docker run -idt --name $DBNAME -p 27017:27017 mongo:3.2
fi

if [ "$RUNNING" == "false" ]; then
    echo "Container $DBNAME is not running"
    docker start $DBNAME
fi

echo "Container $DBNAME already running"
