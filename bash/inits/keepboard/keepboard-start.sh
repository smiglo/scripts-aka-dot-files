#!/bin/sh
DIR="$( cd "$( dirname "$0" )" && pwd )"
cd $DIR
java -jar keepboard.jar 2>/dev/null

