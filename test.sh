#!/bin/bash

cmd=.build/release/xprojup
file=.build/checkouts/XcodeProjKit/

if [[ ! -f "$cmd" ]]
then
    ./build.sh
fi

exitStatus=0

# json
$cmd $file
exitStatus=$?

if [ "$exitStatus" -eq "0" ]
then
    echo "✅ "
else
    echo "🚫 $exitStatus"
fi
 
exit $exitStatus
