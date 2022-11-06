#!/bin/bash
mode=release
bin=.build/$mode/xprojup

rm -f $bin

swift build -c $mode

$bin --help
