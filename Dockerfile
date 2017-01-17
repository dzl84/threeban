FROM ubuntu:16.04
RUN apt-get update && apt-get -y -q install tesseract-ocr tesseract-ocr-eng
WORKDIR /app
ADD . /app
CMD bundle install
	&& setup/mongodb/createdb.sh
	&& 
