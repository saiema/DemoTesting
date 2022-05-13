#!/bin/bash

source utils.sh
source runEvoSuite_configuration.sh
DEBUG=1

getoptWorks=""
checkGetopt getoptWorks
if [[ "$getoptWorks" -eq "0" ]]; then
    debug "getopt is working"
else
    error "getopt command is not working, please check that getopt is installed and available" 1
fi

LONGOPTIONS=classes:,sourceDir:,binDir:,classpath:,configFile:,seedsFile:,runs:,runsPerSeed:,outputFolder:,help
OPTIONS=c:,s:,b:,p:,f:,e:,r:,u:,o:,h

#Display script usage
#error : if 0 the usage comes from normal behaviour, if > 0 then it comes from an error and will exit with this as exit code
#extra information : an additional message
function usage() {
    local code="$1"
    local extraMsg="$2"
    local msg="Runs EvoSuite and JaCoCo for a benchmark of classes, and generates a csv file with the results.\nUsage:\nrunEvoSuiteForBenchmark.sh -[-h]elp to show this message\nrunEvoSuiteForBenchmark.sh -[-c]lasses <path> -[-s]ourceDir <path> -[-b]inDir <path> -[-]class[p]ath <paths> -[-]con[f]igFile <path> -[-]s[e]edsFile <path> -[-r]uns <nat> -[-]r[u]nsPerSeed <nat> -[-o]utputFolder <path>\n\tClasses is a file with full classnames.\n\tSource and Bin paths refers to where the sources (.java) and compiled (.class) files are located respectivelly.\n\tThe classpath refers to additional paths needed, these must be separated by ':'.\n\tThe config file refers to a .evoconfig file with the EvoSuite configuration to use (see example.evoconfig).\n\tThe seeds file must contains numbers (one per each line) to be used as seeds for EvoSuite.\n\tRuns refers to how many runs for each class in the classes file will be run with a different seed, this number must be less or equal than the lines of the seeds file.\n\tRuns per seed is how many times a run for a particular class and seed will be repeated (this can be used if it is suspected that there's still randomness involved in EvoSuite that is not tied with the seed used).\n\tThe output folder is where results will be stored, these include generated tests and reports."
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
classesFile=""
classesFileSet=0
sourceDir=""
sourceDirSet=0
binDir=""
binDirSet=0
additionalClasspath=""
additionalClasspathSet=0
configFile=""
configFileSet=0
seedsFile=""
seedsFileSet=0
seedsAvailable=0
runs=0
runsSet=0
runsPerSeed=0
runsPerSeedSet=0
outputFolder=""
outputFolderSet=0


PARSED=$(getopt --options=$OPTIONS --longoptions=$LONGOPTIONS --name "$0" -- "$@")
getoptExitCode="$?"
if [[ "$getoptExitCode" -ne "0" ]]; then
    error "Error while parsing arguments ($getoptExitCode)" 1
fi

eval set -- "$PARSED"

while true; do
	case "$1" in
		--classes | -c)
			classesFile="$2"
			[ -z "$classesFile" ] || $(echo "$classesFile" | egrep -q "^[[:space:]]+$") && error "key,value separator is empty or contains only spaces" 2
			classesFileSet=1
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
		--classpath | -p)
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
		--seedsFile | -e)
		    seedsFile="$2"
		    [ -z "$seedsFile" ] || $(echo "$seedsFile" | egrep -q "^[[:space:]]+$") && error "seeds file path (${seedsFile}) is empty or contains only spaces" 8
            [ ! -f "$seedsFile" ] && error "seeds file (${seedsFile}) does not exists" 8
			seedsFileSet=1
			shift 2
		;;
		--runs | -r)
		    runs="$2"
		    [ -z "$runs" ] || $(echo "$runs" | egrep -qv "^[[:digit:]]+$") && error "runs is not a number (${runs})" 9
			runsSet=1
			shift 2
		;;
		--runsPerSeed | -u)
		    runsPerSeed="$2"
		    [ -z "$runsPerSeed" ] || $(echo "$runsPerSeed" | egrep -qv "^[[:digit:]]+$") && error "runs per seed is not a number (${runsPerSeed})" 10
            [[ "$runsPerSeed" -lt "0" ]] && error "runs per seed is a negative number (${runsPerSeed})" 10
			runsPerSeedSet=1
			shift 2
		;;
		--outputFolder | -o)
			outputFolder="$2"
			[ -z "$outputFolder" ] || $(echo "$outputFolder" | egrep -q "^[[:space:]]+$") && error "output directory path (${outputFolder}) is empty or contains only spaces" 11
			#[ -d "$outputFolder" ] && [ ! -z "$(ls -A ${outputFolder})" ] && error "output directory exists and is not empty" 11
			outputFolderSet=1
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
			usage 1 "Invalid arguments: $PARSED"
			exit 3
		;;
	esac
done

[[ "$classesFileSet" -ne "1" ]] && usage 12 "Classes file was not set"
[[ "$sourceDirSet" -ne "1" ]] && usage 13 "Source directory was not set"
if [[ "$binDirSet" -ne "1" ]]; then
    binDir="$sourceDir"
    binDirSet=1
    warning "No binary directory set, will be using source directory instead"
fi
[[ "$additionalClasspathSet" -ne "1" ]] && debug "No additional classpath was set"
[[ "$configFileSet" -ne "1" ]] && usage 15 "Configuration file was not set"
[[ "$seedsFileSet" -ne "1" ]] && usage 16 "Seeds file was not set"
seedsAvailable=$(grep -oE "^[[:digit:]]+$" "$seedsFile" | wc -l)
[[ "$seedsAvailable" -eq "0" ]] && error "no seeds found in seeds file (${seedsFile})" 17
[[ "$runsSet" -ne "1" ]] && error "Runs was not set" 18
[[ ! "$runs" -gt "0" ]] && error "runs is not a positive number (${runs})" 19
if [[ "$runsPerSeedSet" -ne "1" ]]; then
    debug "No runs per seed was set, this will be set to 1 run per seed"
    runsPerSeed=1
fi
[[ "$outputFolderSet" -ne "1" ]] && error "Output folder was not set" 20

#output structure:
#
#|------------Benchmark Folder-----------------------|
#|                                                   |
#outputFolder -> classesFileName ->  configFileName -> class -> tests (with tests inside)
#                                                   |        -> logs
#                                                   | -> benchmark.csv

classes=$(grep -oE "^([[:alnum:]]|\.)+$" "$classesFile")
nclasses=$(grep -oE "^([[:alnum:]]|\.)+$" "$classesFile" | wc -l)

infoMessage "Starting benchmark for ($nclasses) classes\n\tGetting classes from ($classesFile)\n\tUsing config file ($configFile)\n\tGetting seeds ($seedsAvailable) from ($seedsFile)\n\tSaving result to ($outputFolder)"

benchmarkFolder=""
classesFileBaseName=$(echo "$classesFile" | sed "s|\.[^\.]*$||g")
configFileBaseName=$(echo "$configFile" | sed "s|\.[^\.]*$||g")
appendPaths "$outputFolder" "$classesFileBaseName" 1 benchmarkFolder
appendPaths "$benchmarkFolder" "$configFileBaseName" 1 benchmarkFolder
benchmarkCsv="benchmark.csv"
appendPaths "$benchmarkFolder" "$benchmarkCsv" 0 benchmarkCsv

infoMessage "Benchmark output folder will be ($benchmarkFolder)"

mkdir -p $benchmarkFolder
ecode="$?"
[[ "$ecode" -ne "0" ]] && error "Failed to create benchmark folder ($benchmarkFolder)" 21

for class in $classes; do
    testsDir="tests"
    logsDir="logs"
    classFolder=""
    appendPaths "$benchmarkFolder" "$class" 1 classFolder
    appendPaths "$classFolder" "$testsDir" 1 testsDir
    appendPaths "$classFolder" "$logsDir" 1 logsDir
    mkdir -p "$testsDir"
    ecode="$?"
    [[ "$ecode" -ne "0" ]] && error "Failed to create tests folder ($testsDir)" 22
    mkdir -p "$logsDir"
    ecode="$?"
    [[ "$ecode" -ne "0" ]] && error "Failed to create logs folder ($logsDir)" 23
    ./runEvoSuite.sh --targetClassname "$class" -s "$sourceDir" -b "$binDir" --testDir "$testsDir" --classpath "$additionalClasspath" --configFile "$configFile"
    ecode="$?"
    [[ "$ecode" -ne "0" ]] && error "runEvoSuite.sh failed ($ecode)" 24
    [ ! -z  "$(find . -name "jacoco.*")" ] && mv jacoco.* "$logsDir"
    if [ -e "$EVOSUITE_LOG" ]; then
        mv "$EVOSUITE_LOG" "$logsDir"
    else
        error "$EVOSUITE_LOG not found, this should not be happening" 25
    fi
done

