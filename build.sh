#!/bin/bash 

set -xe

cd bin/
gcc -no-pie -disable-std -nostdlib -ggdb ../src/*.s ../src/util/vector.s -c
cd ../test

./build.sh
