#!/bin/bash

start_time=$(date +%s)


SETUP_TEMP_PATH=~/temp/setup
arg1=foo
arg2=bar

function_name () {
   echo "Parameter #1 is $1"
}

function_name "$arg1" "$arg2"

mkdir -p $SETUP_TEMP_PATH

end_time=$(date +%s)

elapsed_time=$((end_time - start_time))

echo "Elapsed time: $elapsed_time seconds"