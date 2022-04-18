#!/bin/bash

[ -e "evosuite-report" ] && rm -rf "evosuite-report"
if [ -e "tests" ]; then
	pushd "tests"
	ls | xargs -I {} rm -rf {}
	popd
fi
[ -e "instrumentedCode" ] && rm -rf "instrumentedCode"
[ ! -z  "$(find . -name "jacoco.*")" ] && rm jacoco.*
