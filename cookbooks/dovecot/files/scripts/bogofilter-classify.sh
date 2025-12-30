#!/bin/sh

cat | bogofilter --spamicity-formats="%0.4f, %0.4f, %0.4f" -p -u -e -l