#!/bin/bash

bin=.build/apple/Products/Release/xprojup

rm -f $bin

swift build -c release --arch arm64 --arch x86_64

$bin --help
