#!/bin/bash

ROOT=`dirname $(readlink -f "$0")`
docker run -it --link threebandb -v $ROOT/..:/code --rm mongo:3.2 /code/setup/mongodb/createdb.sh
