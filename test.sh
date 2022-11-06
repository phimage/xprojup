#!/bin/bash

cmd=.build/release/xprojup
file=.build/checkouts/XcodeProjKit/

if [[ ! -f "$cmd" ]]
then
    ./build.sh
fi

exitStatus=0

# 
$cmd $file
status=$?

if [ "$status" -eq "0" ]
then
    echo "✅ "
else
    echo "🚫 $status"
    exitStatus=1
fi

# recursive
$cmd --recursive $file/Tests/ok/
status=$?

if [ "$status" -eq "0" ]
then
    echo "✅ "
else
    echo "🚫 $status"
    exitStatus=1
fi

exit $exitStatus
