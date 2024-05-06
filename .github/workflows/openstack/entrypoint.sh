#!/bin/sh -1

echo "Hello $1\n";
time=$(date);
echo "time=$time" >> $GITHUB_OUTPUT;


