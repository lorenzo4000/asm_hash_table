#!/bin/bash 

set -xe

cd src/

for f in *.s 
do
	gcc -no-pie -disable-std -nostdlib -ggdb ../../bin/*.o  $f -o ../bin/$f.out
done

for f in *.cpp
do
	g++ -no-pie -ggdb ../../bin/*.o  $f -o ../bin/$f.out
done
