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

#From a {key, value} config file, this function will return a string with all parsed configurations.
#This function can result in an error call 
#config file                    : The configuration file
#key,value separator            : Which symbol is used to relate keys with values (can't use or contain spaces)
#separator replacement          : What symbol to use as key, value separator in the resulting string (can be space)
#comment symbol                 : What symbol to use as comments, line starting with this symbol will be ignored (can't be or contains spaces)
#comment secondary symbol       : A secondary symbol to use as comments, line starting with this symbol will be also ignored (can't be or contains spaces)
#symbol to prepend in result    : A symbol to prepend for each parsed key, value pair in the result (can't be or contains spaces)
#result(R)                      : Where to store the result
function parseFromConfigFile() {
    local cfile="$1"
    local kvSep="$2"
    local kvSepRep="$3"
    local ignSym="$4"
    local ignSymSnd="$5"
    local prependSym="$6"
    local result=""
    [ ! -e "$cfile" ] && error "Config file $cfile does not exist" 1
    [ -z "$kvSep" ] || $(echo "$kvSep" | egrep -q "[[:space:]]") && error "key,value separator is empty or contains only spaces" 2
    [ -z "$ignSym" ] || $(echo "$ignSym" | egrep -q "[[:space:]]") && error "Comment symbol is empty or contains only spaces" 3
    [ -z "$ignSymSnd" ] || $(echo "$ignSymSnd" | egrep -q "[[:space:]]") && error "Comment secondary symbol is empty or contains only spaces" 4
    [ -z "$prependSym" ] || $(echo "$prependSym" | egrep -q "[[:space:]]") && error "key,value separator is empty or contains only spaces" 5
    #TODO: complete implementation
}

#Appends two strings with a provided separator
#a		      :	first string
#b		      :	second string
#separator	  :	separator to use
#result(R)	  :	where to store the result
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
#endWithPathSep		: if the resulting path should be ended with a path separator or not (0: false, >0: true)
#result(R)	      	: where to store the result
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
#pathToPrepend  : the path to prepend
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

#Checks whether getopt works
#result(R)  : where to store the result, 0 for success, 1 for failure.
function checkGetopt() {
    local ecode=0
    getopt --test > /dev/null
    if [[ $? -ne 4 ]]; then
        ecode=1
    fi
    eval "$1='$ecode'"
}
