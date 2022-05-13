#!/bin/bash

source utils.sh
source runEvoSuite_configuration.sh
DEBUG=1

#set -x #Comment to disable debug output of this script (this is a full verbosity mode; you should use the debug functionality from utils.sh instead)

getoptWorks=""
checkGetopt getoptWorks
if [[ "$getoptWorks" -eq "0" ]]; then
    debug "getopt is working" 
else
    error "getopt command is not working, please check that getopt is installed and available" 1
fi

LONGOPTIONS=targetClassname:,sourceDir:,binDir:,testDir:,classpath:,configFile:,help
OPTIONS=t:,s:,b:,e:,c:,f:,h

#Display script usage
#error : if 0 the usage comes from normal behaviour, if > 0 then it comes from an error and will exit with this as exit code
#extra information : an additional message
function usage() {
    local code="$1"
    local extraMsg="$2"
    local msg="Runs EvoSuite for a particular class and a given configuration for EvoSuite, then it runs JaCoCo to meassure line and branch coverage.\nUsage:\nrunEvoSuite.sh -[-h]elp to show this message\nrunEvoSuite.sh -[-t]argetClassname <target> -[-s]ourceDir <path> -[-b]inDir <path> -[-]t[e]stDir <path> -[-c]lasspath <paths> -[-]con[f]igFile <path>\n\tTarget class is a full classname.\n\tSource and Bin paths refers to where the sources (.java) and compiled (.class) files are located respectivelly.\n\tThe classpath refers to additional paths needed, these must be separated by ':'.\n\tThe config file refers to a .evoconfig file with the EvoSuite configuration to use (see example.evoconfig)."
    if [[ "$code" -eq "0" ]]; then
        [ ! -z "$extraMsg" ] && infoMessage "$extraMsg"
        infoMessage "$msg"
        exit 0
    else
        if [ -z "$extraMsg" ]; then
            error "Wrong usage\n$msg" "$code"
        else
            error "Wrong usage\n${extraMsg}\n$msg" "$code"
        fi
    fi
}


#Arguments
classname=""
classnameSet=0
sourceDir=""
sourceDirSet=0
binDir=""
binDirSet=0
testDir=""
testDirSet=0
additionalClasspath=""
additionalClasspathSet=0
configFile=""
configFileSet=0

PARSED=$(getopt --options=$OPTIONS --longoptions=$LONGOPTIONS --name "$0" -- "$@")
getoptExitCode="$?"
if [[ "$getoptExitCode" -ne "0" ]]; then
    error "Error while parsing arguments ($getoptExitCode)" 1
fi

eval set -- "$PARSED"

while true; do
	case "$1" in
		--targetClassname | -t)
			classname="$2"
			[ -z "$classname" ] || $(echo "$classname" | egrep -q "^[[:space:]]+$") && error "key,value separator is empty or contains only spaces" 2
			classnameSet=1
			shift 2
		;;
		--sourceDir | -s)
			sourceDir="$2"
			[ -z "$sourceDir" ] || $(echo "$sourceDir" | egrep -q "^[[:space:]]+$") && error "source directory path (${sourceDir}) is empty or contains only spaces" 3
			[ ! -d "$sourceDir" ] && error "source directory ($sourceDir) does not exists or is not a directory" 3
			sourceDirSet=1
			shift 2
		;;
		--binDir | -b)
			binDir="$2"
			[ -z "$binDir" ] || $(echo "$binDir" | egrep -q "^[[:space:]]+$") && error "bin directory path (${binDir}) is empty or contains only spaces" 4
			[ ! -d "$binDir" ] && error "bin directory ($binDir) does not exists or is not a directory" 4
			binDirSet=1
			shift 2
		;;
		--testDir | -e)
			testDir="$2"
			[ -z "$testDir" ] || $(echo "$testDir" | egrep -q "^[[:space:]]+$") && error "tests directory path (${testDir}) is empty or contains only spaces" 5
			[ -d "$testDir" ] && [ ! -z "$(ls -A ${testDir})" ] && error "tests directory exists and is not empty" 5 
			testDirSet=1
			shift 2
		;;
		--classpath | -c)
			additionalClasspath="$2"
			[ -z "$additionalClasspath" ] || $(echo "$additionalClasspath" | egrep -q "^[[:space:]]+$") && error "additional classpath (${additionalClasspath}) is empty or contains only spaces" 6
			$(echo "$additionalClasspath" | egrep -q "(^:.*)|(.*:$)") && error "additional classpath ($additionalClasspath) cannot start or end with ':'" 6
			additionalClasspathSet=1
			shift 2
		;;
		--configFile | -f)
			configFile="$2"
			[ -z "$configFile" ] || $(echo "$configFile" | egrep -q "^[[:space:]]+$") && error "config file path (${configFile}) is empty or contains only spaces" 7
            $(echo "$configFile" | egrep -qv ".*\.evoconfig$") && error "config file ($configFile) does not have extension '.evoconfig'" 7
            [ ! -f "$configFile" ] && error "config file (${configFile}) does not exists" 7
			configFileSet=1
			shift 2
		;;
		--help | -h)
			usage 0 ""
		;;
		--)
			shift
			break
		;;
		*)
			echo "Invalid arguments"
			exit 3
		;;
	esac
done

[[ "$classnameSet" -ne "1" ]] && usage 8 "Classname was not set"
[[ "$sourceDirSet" -ne "1" ]] && usage 8 "Source directory was not set"
if [[ "$binDirSet" -ne "1" ]]; then
    binDir="$sourceDir"
    binDirSet=1
    warning "No binary directory set, will be using source directory instead"
fi
[[ "$testDirSet" -ne "1" ]] && usage 8 "Tests directory was not set"
[[ "$additionalClasspathSet" -ne "1" ]] && debug "No additional classpath was set"
[[ "$configFileSet" -ne "1" ]] && usage 8 "Configuration file was not set"

infoMessage "Parsing EvoSuite configuration from ${configFile} ..."

evoArguments=""
evoProperties=""
parseFromConfigFile "${configFile}" "=" " " "#" "[[:lower:]]" "--" evoArguments
parseFromConfigFile "${configFile}" "=" "=" "#" "D" "-" evoProperties
evosuiteArguments=""
append "$evoArguments" "$evoProperties" " " evosuiteArguments

debug "EvoSuite configuration parsed\nArguments: ${evoArguments}\nProperties: ${evoProperties}\nEvoSuite all arguments: ${evosuiteArguments}"

classnameAsPath=$(echo "$classname" | sed 's;\.;/;g')

#############################################################################################################################################

#Runs evosuite for the given arguments:
#class 			: class for which to generate tests
#project classpath 	: classpath to project related code and libraries
#output dir		: where tests will be placed
#argumentsAndProperties :   arguments and properties for EvoSuite (excluding Dtest_dir and Djunit_suffix)
function evosuite() {
	infoMessage "Running EvoSuite..."
	#-base_dir $outputDir 
	local class="$1"
	local projectCP="$2"
	local outputDir="$3"
	local argumentsAndProperties="$4"
	debug "Running cmd: java -jar $EVOSUITE_JAR -class $class -projectCP $projectCP -Dtest_dir=$outputDir -Djunit_suffix=$ES_JUNIT_SUFFIX ${argumentsAndProperties}"
	java -jar $EVOSUITE_JAR -class $class -projectCP $projectCP -Dtest_dir="$outputDir" -Djunit_suffix="$ES_JUNIT_SUFFIX" "$EVOSUITE_ADDITIONAL_FLAGS" ${argumentsAndProperties} 2>&1 | tee -a "$EVOSUITE_LOG"
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
	local JUNIT_RUNNER=org.junit.runner.JUnitCore
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
		java -cp "$classpath:$testpath:$JUNIT:$HAMCREST:$TESTING_JARS_ES:$JACOCO_AGENT:$OFFLINE_INSTR_DIR_LOCATION" -Djacoco-agent.destfile=${OFFLINE_EXEC_FILE_LOCATION} $JUNIT_RUNNER $tests
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
		java -javaagent:"$JACOCO_AGENT" -cp "$classpath:$testpath:$JUNIT:$HAMCREST:$TESTING_JARS_ES" $JUNIT_RUNNER $tests
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
	infoMessage "Generating resumed JaCoCo report (saving to file jacoco.report.resumed)"
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
evosuite "$classname" "${CURRENT_DIR}/$binDir" "${CURRENT_DIR}/$testDir" "$evosuiteArguments"
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
