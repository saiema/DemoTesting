#!/bin/bash

#Utility functions (debug, error, append, and appendPaths)
#These functions can be used for several scripts, take care about name clashing
#******************************************************************************
#Defined constants:
#DEBUG : used by debug function, although it can be used by user defined functions (it follows a C convention for boolean values)
#
#Defined functions:
#debug
#arguments: 1, the message to print
#it will print the message only if DEBUG is true (non 0 value)
#
#error
#arguments: 2, the message to print and a related error code (int)
#it will print the message and exit using the provided error code
#
#append
#arguments: 3 + Result, two strings and a separator, the last argument is a result (must be just a name, do not use $)
#if any of the strings is empty it will output the other one; otherwise it will result ${string1}${separator}${string2}
#
#appendPaths
#arguments: 3 + Result, two paths and a boolean stating if the path should end with a path separator, the last argument is a result (must be just a name, do not use $)
#similar to append but using `/` as a path separator


DEBUG=0

#Prints message (in green)
#msg	: the message to print
function infoMessage() {
	local msg="$1"
	tput setaf 2
	echo -e "INFO:$msg"
	tput sgr0
}

#Prints message (in blue) if DEBUG != 0
#msg	: the message to print
function debug() {
	local msg="$1"
	tput setaf 4
	[[ "$DEBUG" -ne "0" ]] && echo -e "DEBUG:$msg"
	tput sgr0
}

#Prints a warning message (in yellow)
function warning() {
	local msg="$1"
	tput setaf 3
	echo -e "WARNING:$msg"
	tput sgr0
}

#Prints an error message (in red) and then exits with a provided exit code
#msg	   : the message to print
#ecode	   : the exit code
function error() {
	local msg="$1"
	local ecode="$2"
	tput setaf 1
	echo -e "ERROR:$msg"
	tput sgr0
	exit $ecode
}

#Appends two strings with a provided separator
#a		      :	first string
#b		      :	second string
#separator	      :	separator to use
#result(R)	      :	where to store the result
function append() {
	local a="$1"
	local b="$2"
	local separator="$3"
	if [ -z "$a" ]; then
		eval "$4='$b'"
	elif [ -z "$b" ]; then
		eval "$4='$a'"
	else
		eval "$4='${a}${separator}${b}'"
	fi
}

#Appends two paths
#a		            : first path
#b		            : second path
#endWithPathSep		    : if the resulting path should be ended with a path separator or not (0: false, >0: true)
#result(R)	      	    : where to store the result
function appendPaths() {
	local first=$(echo "$1" | sed "s|\/$||g" )
	local second=$(echo "$2" | sed "s|\/$||g" )
	local endWithPathSep="$3"
	local path=""
	if [ -z "$first" ]; then
		path="$second"
	elif [ -z "$second" ]; then
		path="$first"
	else
		append "$first" "$second" "/" path
	fi
	path=$(echo "$path" | sed "s|\/$||g" )
	if [[ "$endWithPathSep" -ne "0" ]]; then
		path="$path/"	
	fi
	eval "$4='${path}'"
}

#Prepends a given path (treated as directory) to a list of paths
#paths			: the list of paths
#pathToPrepend		: the path to prepend
#separator		: path separator
#result(R)		: the list of paths with the path prepended
function prependDirectoryToPaths() {
	local paths="$1"
	local pathToPrepend="$2"
	local separator="$3"
	local resultPaths=""
	for path in $(echo ${paths} | sed "s|${separator}| |g"); do
		local newPath=""
		appendPaths "$pathToPrepend" "$path" "0" newPath
		if [ -z "$resultPaths" ]; then
			resultPaths="$newPath"
		else
			resultPaths="${resultPaths}${separator}${newPath}"
		fi
	done
	eval "$4='$resultPaths'"
}
