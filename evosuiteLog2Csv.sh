#!/bin/bash

# Extracts information from an evosuite.log file

source utils.sh
#set -x
DEBUG=0

#CONSTANTS
SEPARATOR=","
COLUMNS="CLASS${SEPARATOR}RUN_ID${SEPARATOR}SEED${SEPARATOR}CRITERIONS${SEPARATOR}TIME${SEPARATOR}GENERATIONS${SEPARATOR}STATEMENTS${SEPARATOR}GOALS${SEPARATOR}COVERED_GOALS${SEPARATOR}TESTS${SEPARATOR}COVERAGE${SEPARATOR}COVERAGE(AVG)${SEPARATOR}MSCORE"
GEXP_NOT_FOUND="N/A"
CLASS_GEXP="Generating tests for class \K.+"
SEED_GEXP="Using seed \K[[:digit:]]+"
GOALS_GEXP="Total number of goals: \K[[:digit:]]+"
COVERED_GOALS_GEXP="Number of covered goals: \K[[:digit:]]+"
TIME_GEXP="Search finished after \K[[:digit:]]+s(?= and [[:digit:]]+ generations, [[:digit:]]+ statements, best individual has fitness: .*$)"
GENERATIONS_GEXP="Search finished after [[:digit:]]+s and \K[[:digit:]]+(?= generations, [[:digit:]]+ statements, best individual has fitness: .*$)"
STATEMENTS_GEXP="Search finished after [[:digit:]]+s and [[:digit:]]+ generations, \K[[:digit:]]+(?= statements, best individual has fitness: .*$)"
CRITERION_GEXP="Coverage analysis for criterion \K[[:upper:]]+"
CRITERION_COVERAGE_GEXP="Coverage of criterion [[:upper:]]+: \K[[:digit:]]+%"
TESTS_GEXP="Generated \K[[:digit:]]+(?= tests with total length [[:digit:]]+)"
AVERAGE_COVERAGE_GEXP="Resulting test suite's coverage: \K[[:digit:]]+%(?= \(average coverage for all fitness functions\))"
MSCORE_GEXP="Resulting test suite's mutation score: \K[[:digit:]]+%"

#Given a log file, and regular expression, and a not found value
#This function will return either the value associated with the regular expression, or the not found value
#Example: getValue "log" "Following this is the value \K[[:digit:]]+" "N/A" will return:
#if log has a line with "Following this is the value 42", it will return 42
#if not, it will return "N/A"
#Arguments
#ilogFile       : the log file where to look for expressions
#gexpt          : the regular expression to look
#notFoundValue  : the value to return when the regular expresion has no matches
#result(R)      : where to store the result
function getValue() {
    local ilogFile="$1"
    local gexp="$2"
    local notFoundValue="$3"
    local foundExpression=$(grep -oP "$gexp" "$ilogFile")
    debug "Searching values from ${ilogFile} using ${gexp} regex and ${notFoundValue} as not-found-value\nRaw result: ${foundExpression}"
    if [ -z "$foundExpression" ]; then
        debug "returning not-found-value"
        foundExpression="$notFoundValue"
    else
        local result=""
        for match in $foundExpression; do
            debug "match found: $match"
            append "$result" "$match" "-" result
        done
        debug "returning $result"
        foundExpression="$result"
    fi
    eval "$4='$foundExpression'"
}

logFile="$1"
csvFile="$2"
runID="$3"
logFileExists=$(test -e "$logFile" ; echo "$?")
csvFileExists=$(test -e "$csvFile" ; echo "$?")

infoMessage "Parsing values from ${logFile}(${logFileExists}) into ${csvFile}(${csvFileExists}) using runID ${runID} ..."

[[ "$logFileExists" -ne "0" ]] && error "Log File ${logFile} does not exist" 101


getValue "$logFile" "$CLASS_GEXP" "$GEXP_NOT_FOUND" class
getValue "$logFile" "$SEED_GEXP" "$GEXP_NOT_FOUND" seed
getValue "$logFile" "$GOALS_GEXP" "$GEXP_NOT_FOUND" goals
getValue "$logFile" "$COVERED_GOALS_GEXP" "$GEXP_NOT_FOUND" cgoals
getValue "$logFile" "$TIME_GEXP" "$GEXP_NOT_FOUND" time
getValue "$logFile" "$GENERATIONS_GEXP" "$GEXP_NOT_FOUND" gens
getValue "$logFile" "$STATEMENTS_GEXP" "$GEXP_NOT_FOUND" stmts
getValue "$logFile" "$CRITERION_GEXP" "$GEXP_NOT_FOUND" crits
getValue "$logFile" "$CRITERION_COVERAGE_GEXP" "$GEXP_NOT_FOUND" cov
getValue "$logFile" "$TESTS_GEXP" "$GEXP_NOT_FOUND" tests
getValue "$logFile" "$AVERAGE_COVERAGE_GEXP" "$GEXP_NOT_FOUND" covAvg
getValue "$logFile" "$MSCORE_GEXP" "$GEXP_NOT_FOUND" mscore

debug "Parsed values:\nclass: ${class}\nseed: ${seed}\ngoals: ${goals}\ncovered goals: ${cgoals}\ntime: ${time}\ngeneration: ${gens}\nstatements: ${stmts}\ncriterions: ${crits}\ncriterions coverage: ${cov}\ngenerated tests: ${tests}\ncoverage (average): ${covAvg}\nmutation score: ${mscore}"

if [[ "$csvFileExists" -ne "0" ]]; then
    debug "Writting columns to csv file ${csvFile}\n${COLUMNS}\n"
    printf "%s\n" "$COLUMNS" >> "$csvFile"
fi

caseData="${class}${SEPARATOR}${runID}${SEPARATOR}${seed}${SEPARATOR}${crits}${SEPARATOR}${time}${SEPARATOR}${gens}${SEPARATOR}${stmts}${SEPARATOR}${goals}${SEPARATOR}${cgoals}${SEPARATOR}${tests}${SEPARATOR}${cov}${SEPARATOR}${covAvg}${SEPARATOR}${mscore}"

debug "Writting case data to csv file ${csvFile}\n${caseData}\n"
printf "%s\n" "$caseData" >> "$csvFile"
