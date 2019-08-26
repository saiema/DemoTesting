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
classnameAsPath=$(echo "$classname" | sed 's;\.;/;g')
budget="10"  #Time budget for evosuite (in seconds)
seed="42"
evoCriterion="branch:weakmutation"
#
#Constants
CURRENT_DIR=$(pwd)
#JUNIT AND EVOSUITE
EVOSUITE_JAR="${CURRENT_DIR}/tools/evosuite/evosuite-1.0.6.jar"
JUNIT="${CURRENT_DIR}/tools/junit-4.12.jar"
HAMCREST="${CURRENT_DIR}/tools/org.hamcrest.core_1.3.0.v201303031735.jar"
TESTING_JARS_ES="${CURRENT_DIR}/tools/evosuite/evosuite-standalone-runtime-1.0.6.jar"
ES_JUNIT_SUFFIX="ESTest"	#EvoSuite test suffix
#JACOCO
JACOCO_AGENT="JaCoCoRS/jacocoagent.jar"
JACOCO_CLI="JaCoCoRS/jacococli.jar"
JACOCO_REPORT="JaCoCoRS/JaCoCoRS.sh"
#
########################################################################

#Runs evosuite for the given arguments:
#class 			: class for which to generate tests
#project classpath 	: classpath to project related code and libraries
#output dir		: where tests will be placed
#criterion 		: the criteria that evosuite will use to evolve the test suite (weakmutation, strongmutation, branch, etc)
#budget 		: the time budget (in seconds) for evosuite
#seed 			: the seed to be used for the random generator
function evosuite() {
	echo "Running EvoSuite..."
	#-base_dir $outputDir 
	local class="$1"
	local projectCP="$2"
	local outputDir="$3"
	local criterion="$4"
	local budget="$5"
	local seed="$6"
	java -jar $EVOSUITE_JAR -class $class -projectCP $projectCP -Dtest_dir="$outputDir" -criterion $criterion -Djunit_suffix="$ES_JUNIT_SUFFIX" -Dsearch_budget=$budget -seed $seed
}

#Compiles evosuite generated tests
#target		: class to compile
#root folder	: folder to where the tests where saved
#classpath	: required classpath
#exitCode(R)	: where to return the exit code
function compileEvosuiteTests() {
	echo "Compiling EvoSuite tests..."
	local target="$1"
	local rootFolder="$2"
	local classpath="$3"
	pushd $rootFolder
	local exitCode=""
	javac -cp "$classpath:$JUNIT:$TESTING_JARS_ES" "$target"
	exitCode="$?"
	popd
	eval "$4=$exitCode"	
}

function getTestsFrom() {
	local from="$1"
	local es_tests=""
	local backupIFS="$IFS"
	IFS='
'
	[ -e "${from}" ] && for x in `find "${from}" | awk "/${ES_JUNIT_SUFFIX}\.java/"`; do
		testClass=$(echo $x | sed "s|${from}||g" | sed "s|\.java||g" | sed "s|\/|.|g") 
		if [ -z "$es_tests" ] ; then
			es_tests="$testClass"
		else
			es_tests="${es_tests} $testClass"
		fi		
		echo $testClass
	done
	
	local all_tests="$es_tests"
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



function prepareTestsForJacoco() {
	echo "Preparing tests for JaCoCo..."
	local from="$1"
	find "$from" | awk '/\.java/' | xargs -I {} grep -l "separateClassLoader = true," {} | xargs -I {} sed -i "s|separateClassLoader = true,|separateClassLoader = false,|g" {}
	[[ "$?" -ne "0" ]] && exit 503
}

#MAIN
#TIMES
evosuiteTime=""
############################################################################################################
#TEST GENERATION


START=$(date +%s.%N)
evosuite "$classname" "${CURRENT_DIR}/$binDir" "${CURRENT_DIR}/$testDir" "$evoCriterion" "$budget" "$seed"
ecode="$?"
[[ "$ecode" -ne "0" ]] && exit 201
END=$(date +%s.%N)
evosuiteTime=$(echo "$END - $START" | bc)
echo "EvoSuite took $evosuiteTime"

prepareTestsForJacoco "${CURRENT_DIR}/$testDir"
compileEvosuiteTests "$classnameAsPath${ES_JUNIT_SUFFIX}.java" "${CURRENT_DIR}/${testDir}" "${CURRENT_DIR}/${binDir}:${CURRENT_DIR}/${testDir}" ecode
[[ "$ecode" -ne "0" ]] && exit 301

tests=""
getTestsFrom "${CURRENT_DIR}/$testDir" tests

#COVERAGE
jacoco "${CURRENT_DIR}/$binDir" "${CURRENT_DIR}/$testDir" "${CURRENT_DIR}/$sourceDir" "$tests" "$classname"
