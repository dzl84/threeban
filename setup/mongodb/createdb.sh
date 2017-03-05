#!/usr/bin/env bash

ROOT=`dirname $(readlink -f "$0")`
HOST='threebandb'
DB='trade'
VERSION=`mongo $HOST/$DB --eval "db.schema.findOne({}).schema_version" | tail -n +3 | egrep -v "^>|^bye"`

if [[ $VERSION =~ ^([0-9]+)$ ]]; then
    echo "Current schema version: $VERSION."
else
    echo "Database $DB has not been created yet."
    VERSION=0
fi

VERSION=`expr $VERSION + 1`
while [ -e $ROOT/createdb_$VERSION.js ]
do
    result=`mongo $HOST/$DB < $ROOT/createdb_$VERSION.js`
    if [ $? == 1 ]; then 
        echo "Failed to execute createdb_$VERSION.js."
        printf "Result: $result"
        break
    fi
    echo "Successfully applied createddb_$VERSION.js."
    VERSION=`expr $VERSION + 1`
done
LATEST=`expr $VERSION - 1`
echo "The latest schema version is $LATEST."

