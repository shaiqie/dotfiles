#!/bin/bash

if [ "$1" = "--probe" ]; then
    command -v pamtester >/dev/null 2>&1
    echo $?
    exit 0
fi

echo "$1" | pamtester login "$USER" authenticate >/dev/null 2>&1
echo $?
