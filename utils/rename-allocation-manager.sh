#!/usr/bin/env bash
# Allocation manager is a bad name.
# Replacing it with "custom executor queue".


function get_wrong_lines(){
    # to be used in a pipe
    git grep -iE 'allocation.*manager'
}

function get_all_files() {
   get_wrong_lines | cut -d: -f1 | uniq
}

function check(){
    [ $(get_all_files | wc -l ) -eq 0 ]
}


function correct(){
    local OPT=$1
    shift
    sed $OPT -E 's/allocation([ _]+)manager/custom\1executor\1queue/g;
            s/Allocation([ _]+)manager/Custom\1executor\1queue/g;
            s/ALLOCATION([ _]+)MANAGER/CUSTOM\1EXECUTOR\1QUEUE/g' "$@"
}


function check_pipe(){
    # to be used in a pipe
    grep -iE 'allocation.*manager'
}

function correct_file_names(){

    git ls-files | grep -iE 'allocation.*manager'


}


## To be used as follows. For a preliminary check:
#
# $ source ./utils/rename-allocation-manager.sh
# $ get_wrong_lines | correct  | check_pipe | wc -l
#
## This should return 0.
## The real thing:
#
# $ correct -i $(get_all_files)
#
## This now should return an empty list:
#
# $ get_all_files
#
## Then, change file names by hand.
