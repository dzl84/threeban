#!/bin/bash

docker run -it --link threebandb -v ~/projects/threeban:/code --rm ruby:2.2.0 sh -c "cd /code; bundle install; ruby /code/lib/company_crawler.rb"
