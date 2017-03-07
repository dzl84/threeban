#!/bin/bash

docker run -it --link threebandb -v ~/projects/threeban:/code --rm ruby:2.2.0 sh -c "cd /code; bundle install; RACK_ENV=production ruby /code/lib/tradedata_crawler.rb"
