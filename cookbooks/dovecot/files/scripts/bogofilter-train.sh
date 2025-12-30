#!/bin/sh

case $1 in
	[sS]*)
		FLAG="-s"
		;;
	[hH]*)
		FLAG="-n"
		;;
	[rR]*)
		FLAG="-Ns"
		;;
	*)
		exit 1
		;;
esac

cat | bogofilter -l ${FLAG}