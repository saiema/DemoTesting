#!/bin/bash

source utils.sh
DEBUG=1

#set -x #Comment to disable debug output of this script (this is a full verbosity mode; you should use the debug functionality from utils.sh instead)

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
	error "Bad option: $example" -1
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
USE_OFFLINE_INSTRUMENTATION=1 #0 : do not use offline instrumentation; 1 : use offline instrumentation
OFFLINE_EXEC_FILE_LOCATION="jacoco.exec"
OFFLINE_INSTR_DIR_LOCATION="instrumentedCode"
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
	infoMessage "Running EvoSuite..."
	#-base_dir $outputDir 
	local class="$1"
	local projectCP="$2"
	local outputDir="$3"
	local criterion="$4"
	local budget="$5"
	local seed="$6"
	debug "Running cmd: java -jar $EVOSUITE_JAR -class $class -projectCP $projectCP -Dtest_dir=$outputDir -criterion $criterion -Djunit_suffix=$ES_JUNIT_SUFFIX -Dsearch_budget=$budget -seed $seed"
	java -jar $EVOSUITE_JAR -class $class -projectCP $projectCP -Dtest_dir="$outputDir" -criterion $criterion -Djunit_suffix="$ES_JUNIT_SUFFIX" -Dsearch_budget=$budget -seed $seed
}

#Compiles evosuite generated tests
#target		: class to compile
#root folder	: folder to where the tests where saved
#classpath	: required classpath
#exitCode(R)	: where to return the exit code
function compileEvosuiteTests() {
	infoMessage "Compiling EvoSuite tests..."
	local target="$1"
	local rootFolder="$2"
	local classpath="$3"
	pushd $rootFolder
	local exitCode=""
	debug "Running cmd: javac -cp $classpath:$JUNIT:$TESTING_JARS_ES $target"
	javac -cp "$classpath:$JUNIT:$TESTING_JARS_ES" "$target"
	exitCode="$?"
	debug "Exit code: $exitCode"
	popd
	eval "$4='$exitCode'"	
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
		debug "Test found: $testClass"
	done
	debug "EvoSuite tests: ${es_tests}"
	local all_tests="$es_tests"
	eval "$2='$all_tests'"
	IFS="$backupIFS"
}

#Runs jacoco for coverage, and generates a report
#classpath	: the classpath to use
#testpath	: the classpath to tests
#sourcefiles	: the source files of classes to cover
#classfiles	: where the class files are located (e.g.: bin/ classes/ build/)
#tests		: tests to run
#classToAnalyze	: the class to analyze
function jacoco() {
	infoMessage "Running JaCoCo..."
	local classpath="$1"
	local testpath="$2"
	local sourcefiles="$3"
	local classfiles="$4"
	local tests="$5"
	local classToAnalyze="$6"
	local classToAnalyzeAsPath=$(echo "$classToAnalyze" | sed 's|\.|/|g')
	local fullPathToClassToAnalize=""
	local fullPathToSourceOfClassToAnalize=""
	appendPaths "$classfiles" "${classToAnalyzeAsPath}.class" 0 fullPathToClassToAnalize
	appendPaths "$sourcefiles" "${classToAnalyzeAsPath}.java" 0 fullPathToSourceOfClassToAnalize
	if [[ "$USE_OFFLINE_INSTRUMENTATION" -eq "1" ]]; then
		infoMessage "Using offline instrumentation approach"
		local classToAnalizePackage=$(dirname "${classToAnalyzeAsPath}.java")
		local instrumentationDestination=""
		appendPaths "$OFFLINE_INSTR_DIR_LOCATION" "$classToAnalizePackage" "0" instrumentationDestination
		debug "Running cmd: java -jar $JACOCO_CLI instrument $fullPathToClassToAnalize --dest $instrumentationDestination"
		java -jar "$JACOCO_CLI" instrument "$fullPathToClassToAnalize" --dest "$instrumentationDestination"
		exitCode="$?"
		debug "Exit code: $exitCode"
		if [[ "$exitCode" -ne "0" ]]; then
			error "JaCoCo instrumentation failed (${exitCode})" 501
		fi
		debug "Deactivating original file $fullPathToClassToAnalize"
		mv "$fullPathToClassToAnalize" "${fullPathToClassToAnalize}.bak"
		exitCode="$?"
		if [[ "$exitCode" -ne "0" ]]; then
			error "Deactivating original file failed (${exitCode})" 502
		fi
		debug "Running tests with instrumented class"
		debug "Running cmd: java -cp $classpath:$testpath:$JUNIT:$HAMCREST:$TESTING_JARS_ES:$JACOCO_AGENT -Djacoco-agent.destfile=${OFFLINE_EXEC_FILE_LOCATION} org.junit.runner.JUnitCore $tests"
		java -cp "$classpath:$testpath:$JUNIT:$HAMCREST:$TESTING_JARS_ES:$JACOCO_AGENT:$OFFLINE_INSTR_DIR_LOCATION" -Djacoco-agent.destfile=${OFFLINE_EXEC_FILE_LOCATION} org.junit.runner.JUnitCore $tests
		exitCode="$?"
		debug "Restoring original file $fullPathToClassToAnalize"
		mv "${fullPathToClassToAnalize}.bak" "$fullPathToClassToAnalize"
		exitCodeMv="$?"
		if [[ "$exitCodeMv" -ne "0" ]]; then
			error "Restoring original file failed (${exitCodeMv}) tests may have also failed if the following is not 0 ($exitCode)" 503
		fi
		if [[ "$exitCode" -ne "0" ]]; then
			error "Failed to run tests with instrumented class (${exitCode})" 504
		fi
	else
		infoMessage "Using Java Agent approach"
		debug "Running cmd: java -javaagent: $JACOCO_AGENT -cp $classpath:$testpath:$JUNIT:$HAMCREST:$TESTING_JARS_ES org.junit.runner.JUnitCore $tests"
		java -javaagent:"$JACOCO_AGENT" -cp "$classpath:$testpath:$JUNIT:$HAMCREST:$TESTING_JARS_ES" org.junit.runner.JUnitCore $tests
		exitCode="$?"
		if [[ "$exitCode" -ne "0" ]]; then
		 error "Failed to run tests with JaCoCo agent (${exitCode})" 501
		fi
	fi
	debug "All tests executed, generating JaCoCo raw report"
	debug "Running cmd: java -jar $JACOCO_CLI report jacoco.exec --classfiles $fullPathToClassToAnalize --sourcefiles $fullPathToSourceOfClassToAnalize --xml jacoco.report.xml"
	java -jar "$JACOCO_CLI" report "jacoco.exec" --classfiles "$fullPathToClassToAnalize" --sourcefiles "$fullPathToSourceOfClassToAnalize" --xml "jacoco.report.xml"
	exitCode="$?"
	if [[ "$exitCode" -ne "0" ]]; then
		error "Error generating JaCoCo raw report (${exitCode})" 505
	fi
	sed -i 's;<!DOCTYPE report PUBLIC "-//JACOCO//DTD Report 1.1//EN" "report.dtd">;;g' "jacoco.report.xml"
	debug "Generating resumed JaCoCo report (saving to file jacoco.report.resumed)"
	$JACOCO_REPORT "jacoco.report.xml" --class "$classToAnalyze" >"jacoco.report.resumed"
}


function prepareTestsForJacoco() {
	infoMessage "Preparing tests for JaCoCo..."
	if [[ "$USE_OFFLINE_INSTRUMENTATION" -eq "1" ]]; then
		infoMessage "Using offline instrumentation, tests will be left intact"
	else
		local from="$1"
		find "$from" | awk '/\.java/' | xargs -I {} grep -l "separateClassLoader = true," {} | xargs -I {} sed -i "s|separateClassLoader = true,|separateClassLoader = false,|g" {}
		exitCode="$?"
		if [[ "$exitCode" -ne "0" ]]; then
			error "An error ocurred while preparing tests for JaCoCo" 500
		fi
	fi
}

#MAIN
if [[ "$USE_OFFLINE_INSTRUMENTATION" -eq "1" ]]; then
	if [[ -d "$OFFLINE_INSTR_DIR_LOCATION" ]] && [ ! -z "$(ls -A $OFFLINE_INSTR_DIR_LOCATION)" ]; then
		error "Directory $USE_OFFLINE_INSTRUMENTATION exists and is not empty" 101
	elif [[ ! -d "$OFFLINE_INSTR_DIR_LOCATION" ]]; then
		debug "Generating offline instrumentation folder ($OFFLINE_INSTR_DIR_LOCATION)"
		mkdir "$OFFLINE_INSTR_DIR_LOCATION"
	fi
fi
#TIMES
evosuiteTime=""
############################################################################################################
#TEST GENERATION


START=$(date +%s.%N)
evosuite "$classname" "${CURRENT_DIR}/$binDir" "${CURRENT_DIR}/$testDir" "$evoCriterion" "$budget" "$seed"
ecode="$?"
if [[ "$ecode" -ne "0" ]]; then
	error "EvoSuite failed ($ecode)" 201
fi
END=$(date +%s.%N)
evosuiteTime=$(echo "$END - $START" | bc)
infoMessage "EvoSuite took $evosuiteTime"

prepareTestsForJacoco "${CURRENT_DIR}/$testDir"
compileEvosuiteTests "$classnameAsPath${ES_JUNIT_SUFFIX}.java" "${CURRENT_DIR}/${testDir}" "${CURRENT_DIR}/${binDir}:${CURRENT_DIR}/${testDir}" ecode
if [[ "$ecode" -ne "0" ]]; then
	error "EvoSuite tests compilation failed ($ecode)" 301
fi

tests=""
getTestsFrom "${CURRENT_DIR}/$testDir" tests

#COVERAGE
jacoco "${CURRENT_DIR}/$binDir" "${CURRENT_DIR}/$testDir" "${CURRENT_DIR}/$sourceDir" "${CURRENT_DIR}/$binDir" "$tests" "$classname"
