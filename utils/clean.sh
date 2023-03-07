#!/bin/bash
mkdir -p ./trashcan
for dir in $(find ./ -maxdepth 1 -name '*test*' -type d)
do if ! { git ls-files $dir | grep $(basename $dir) &> /dev/null;}
then 
    rm -rf ./trashcan/$dir
    echo mv $dir ./trashcan/$dir
    mv $dir ./trashcan/$dir
fi
done
