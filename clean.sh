#!/bin/bash

source runEvoSuite_configuration.sh

testsFolder="$1"

[ -e "evosuite-report" ] && rm -rf "evosuite-report"
if [ -z "$testsFolder" ] || $(echo "$testsFolder" | egrep -q "^[[:space:]]$"); then
    [ -e "evosuite-tests" ] && rm -rf "evosuite-tests"
else
    if [ -e "$testsFolder" ]; then
	    pushd "$testsFolder"
	    ls | xargs -I {} rm -rf {}
	    popd
    fi
fi
[ -e "instrumentedCode" ] && rm -rf "instrumentedCode"
[ ! -z  "$(find . -name "jacoco.*")" ] && rm jacoco.*
[ -e "$EVOSUITE_LOG" ] && rm "$EVOSUITE_LOG"
