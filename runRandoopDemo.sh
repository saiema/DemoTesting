#!/bin/bash

set -x #Comment to disable debug output of this script

#Arguments
example="$1"
if [ "$example" == "bad" ]; then
	classname="motivating.queue.BadQueue"
	testDir="tests/queuebest/bad/"
elif [ "$example" == "normal" ]; then
	classname="motivating.queue.Queue"
	testDir="tests/queuebest/normal/"
elif [ "$example" == "good" ]; then
	classname="motivating.queue.GoodQueue"
	testDir="tests/queuebest/good/"
elif [ "$example" == "goodWithRep" ]; then
	classname="motivating.queue.GoodQueueWithRep"
	testDir="tests/queuebest/goodWithRep/"
else 
	echo "Bad option: $example"
	exit -1
fi
sourceDir="benchmarks/src/"
binDir="benchmarks/bin/"
budget="30"	#Time budget for randoop (in seconds)
seed="42"
#
#Constants
CURRENT_DIR=$(pwd)
#JUNIT AND RANDOOP
RANDOOP_JAR="${CURRENT_DIR}/tools/randoop/randoop-all-4.0.4.jar"
JUNIT="${CURRENT_DIR}/tools/junit-4.12.jar"
HAMCREST="${CURRENT_DIR}/tools/org.hamcrest.core_1.3.0.v201303031735.jar"
TESTING_JARS_RD="${CURRENT_DIR}/tools/randoop/randoop-4.0.4.jar"
RP_TESTS_PER_FILE=500 #How many tests per file will be generated (this does not affect the total tests)
RP_TESTS_MAXSIZE=30   #How many method calls (statements) at most will be used per test (not counting assertions and debug messages)
#JACOCO
JACOCO_AGENT="JaCoCoRS/jacocoagent.jar"
JACOCO_CLI="JaCoCoRS/jacococli.jar"
JACOCO_REPORT="JaCoCoRS/JaCoCoRS.sh"
#
#########################################################################


#Runs randoop for the given arguments:
#class			: class for which to generate tests
#project classpath	: classpath to project related code and libraries
#output dir		: where tests will be placed
#budget			: the time bugdet (in seconds) for randoop
#seed			: the seed to be used for the random generator
function randoop() {
	echo "Running Randoop..."
	local class="$1"
	local projectCP="$2"
	local outputDir="$3"
	local budget="$4"
	local seed="$5"
	local options="--flaky-test-behavior=DISCARD --time-limit=$budget --randomseed=$seed --junit-output-dir=$outputDir --testsperfile=$RP_TESTS_PER_FILE --maxsize=$RP_TESTS_MAXSIZE"
	java -Xmx3000m -cp $projectCP:$RANDOOP_JAR randoop.main.Main gentests --testclass="$class" $options
}

#Compiles randoop regression tests
#root folder	: folder where tests are
#classpath	: required classpath
#exitCode(R)	: where to return the exit code
function compileRandoopTests() {
	echo "Compiling Randoop tests..."
	local rootFolder="$1"
	local classpath="$2"
	pushd $rootFolder
	local exitCode=""
	javac -cp "$classpath:$JUNIT:$TESTING_JARS_RD:$TESTING_JARS_ES" *.java
	exitCode="$?"
	popd
	eval "$3=$exitCode"
}

function getTestsFrom() {
	local from="$1"
	local rp_tests=""
	local backupIFS="$IFS"
	IFS='
'
	if [ -e "${from}" ] && [ -e "${from}RegressionTest.java" ] ; then
		for x in `find "${from}" | awk "/RegressionTest[0-9]+\.java/"`; do
			testClass=$(echo $x | sed "s|${from}||g" | sed "s|\.java||g" | sed "s|\/|.|g")
			if [ -z "$rp_tests" ] ; then
				rp_tests="$testClass"
			else
				rp_tests="${rp_tests} $testClass"
			fi		
			echo $testClass
		done
	fi
	
	local all_tests="$rp_tests"
	eval "$2='$all_tests'"
	IFS="$backupIFS"
}

#Runs jacoco for coverage, and generates a report
#classpath	: the classpath to use
#testpath	: the classpath to tests
#sourcefiles	: the source files of classes to cover
#tests		: tests to run
#classToAnalyze	: the class to analyze
function jacoco() {
	echo "Running JaCoCo..."
	local classpath="$1"
	local testpath="$2"
	local sourcefiles="$3"
	local tests="$4"
	local classToAnalyze="$5"
	local classToAnalyzeAsPath=$(echo "$classToAnalyze" | sed 's|\.|/|g')
	java -javaagent:"$JACOCO_AGENT" -cp "$classpath:$testpath:$JUNIT:$HAMCREST:$TESTING_JARS_ES:$TESTING_JARS_RD" org.junit.runner.JUnitCore $tests
	[[ "$?" -ne "0" ]] && exit 501
	java -jar "$JACOCO_CLI" report "jacoco.exec" --classfiles "${classpath}${classToAnalyzeAsPath}.class" --sourcefiles "${sourcefiles}${classToAnalyzeAsPath}.java" --xml "jacoco.report.xml"
	[[ "$?" -ne "0" ]] && exit 502
	sed -i 's;<!DOCTYPE report PUBLIC "-//JACOCO//DTD Report 1.1//EN" "report.dtd">;;g' "jacoco.report.xml"
	$JACOCO_REPORT "jacoco.report.xml" --class "$classToAnalyze" >"jacoco.report.resumed"
}

#MAIN
#TIMES
randoopTime=""
############################################################################################################
#TEST GENERATION


START=$(date +%s.%N)
randoop "$classname" "${CURRENT_DIR}/$binDir" "${CURRENT_DIR}/$testDir" "$budget" "$seed"
ecode="$?"
[[ "$ecode" -ne "0" ]] && exit 202
END=$(date +%s.%N)
randoopTime=$(echo "$END - $START" | bc)
echo "Randoop took $randoopTime"

############################################################################################################

#TEST COMPILATION
compileRandoopTests "${CURRENT_DIR}/${testDir}" "${CURRENT_DIR}/${binDir}:${CURRENT_DIR}/${testDir}" ecode
[[ "$ecode" -ne "0" ]] && exit 302
############################################################################################################

tests=""
getTestsFrom "${CURRENT_DIR}/$testDir" tests

#COVERAGE
jacoco "${CURRENT_DIR}/$binDir" "${CURRENT_DIR}/$testDir" "${CURRENT_DIR}/$sourceDir" "$tests" "$classname"
