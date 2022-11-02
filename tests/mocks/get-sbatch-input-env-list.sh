#!/usr/bin/env bash
# This script parses the man page of sbatch
# to get all the names of the environment variables
# that affect the execution.
# Ideally to be executed with
# ssh <horeka-host> bash < this-script.sh


function get_line_from_content() {
    CONTENT=$1
    man sbatch | grep -n "$CONTENT" | cut -d: -f1


}

function get_relevant_lines_from_sbatch_manual() {

    local START=$(get_line_from_content "INPUT ENVIRONMENT VARIABLES")
    local END=$(get_line_from_content "OUTPUT ENVIRONMENT VARIABLES")

    man sbatch | head -n $((END-1)) | tail -n +$((START+1)) | grep -E '^\s+(SBATCH|SLURM)'

}


function sanitize_whitespace() {
   # To be used in a pipe
   # Converts all groups of whitespaces to a single SPC
   # Removes also leading whitespace
   sed -E 's/\s+/ /g' | sed -E 's/\s+//'
}


function get_first_word() {
   # To be used in a pipe
   cut -d' ' -f1
}

function get_additional_spellings() {
  # To be used in a pipe
  grep 'or SLURM' | cut -d' ' -f4
}


function remove_equals_at_end() {
    # In some cases, an '=SOMETHING' is appended
    sed 's/=.*//'

}

function get_all_env_var_names() {

get_relevant_lines_from_sbatch_manual | sanitize_whitespace | get_first_word | remove_equals_at_end
get_relevant_lines_from_sbatch_manual | sanitize_whitespace | get_additional_spellings | remove_equals_at_end

}

get_all_env_var_names
