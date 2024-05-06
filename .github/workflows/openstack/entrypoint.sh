#!/bin/sh

echo "Hello $1\n";
time$(date);
echo "time=$time" >> $GITHUB_OUTPUT;


