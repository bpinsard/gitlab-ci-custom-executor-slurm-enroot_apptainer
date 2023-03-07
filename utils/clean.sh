#!/bin/bash
mkdir -p ./trashcan
for dir in $(find ./ -maxdepth 1 -name '*test*' -type d)
do if ! { git ls-files $dir | grep $(basename $dir) &> /dev/null;}
then 
    echo $dir ./trashcan
    mv $dir ./trashcan
fi
done
