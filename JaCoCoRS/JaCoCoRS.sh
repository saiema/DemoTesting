#!/bin/bash

#set -x

#Data extractor for JaCoCo report

#$1 : log file (xml from JaCoCo)

CURRENT_DIR=$(dirname "$(readlink -f "$0")")
XPATH_HOME="${CURRENT_DIR}/XPathEvaluator"
LINE="LINE"
BRANCH="BRANCH"
MISSED=0
COVERED=1

log="$1"

getopt --test > /dev/null
if [[ $? -ne 4 ]]; then
    echo "I’m sorry, `getopt --test` failed in this environment."
    exit 1
else
    echo "getopt --test : OK!" 
fi

LONGOPTIONS=package:,class:,method:,full

# -temporarily store output to be able to check for errors
# -e.g. use “--options” parameter by name to activate quoting/enhanced mode
# -pass arguments only via   -- "$@"   to separate them correctly
PARSED=$(getopt --options=$OPTIONS --longoptions=$LONGOPTIONS --name "$0" -- "$@")
if [[ $? -ne 0 ]]; then
    # e.g. $? == 1
    #  then getopt has complained about wrong arguments to stdout
    exit 2
fi
# read getopt’s output this way to handle the quoting right:
eval set -- "$PARSED"

usePackage=0
useClass=0
useMethod=0
fullReport=0

# now enjoy the options in order and nicely split until we see --
while true; do
	case "$1" in
		--package)
			package="$2"
			usePackage=1
			shift 2
		;;
		--class)
			class="$2"
			useClass=1
			shift 2
		;;
		--method)
			method="$2"
			useMethod=1
			shift 2
		;;
		--full)
			fullReport=1
			shift
		;;        
		--)
			shift
			break
		;;
		*)
			echo "Programming error"
			exit 3
		;;
	esac
done

#=================FUNCTIONS======================================================================================================


pushd () {
    command pushd "$@" > /dev/null
}

popd () {
    command popd "$@" > /dev/null
}

function getReportName() {
	echo "//report/@name"
}

function getPackages() {
	echo "//package/@name"
}

function getPackageClasses() {
	local package="$1"
	echo "//package[@name='${package}']/class/@name"
}

function getClassMethods() {
	local package="$1"
	local class="$2"
	echo "//package[@name='${package}']/class[@name='${class}']/method/@name"
}

function getMethodDescriptions() {
	local package="$1"
	local class="$2"
	local method="$3"
	echo "//package[@name='${package}']/class[@name='${class}']/method[@name='${method}']/@desc"
}

function getClassCoverage() {
	local package="$1"
	local class="$2"
	local moc="$3" #MISSED : missed; COVERED : covered
	local lob="$4" #LINE for line, BRANCH for branch
	if [ "$moc" -eq "$MISSED" ]; then
		echo "//package[@name='${package}']/class[@name='${class}']/counter[@type='${lob}']/@missed"
	else
		echo "//package[@name='${package}']/class[@name='${class}']/counter[@type='${lob}']/@covered"
	fi
}

function getMethodClassCoverage() {
	local package="$1"
	local class="$2"
	local method="$3"
	local desc="$4"
	local moc="$5" #MISSED : missed; COVERED : covered
	local lob="$6" #LINE for line, BRANCH for branch
	if [ "$moc" -eq "$MISSED" ]; then
		echo "//package[@name='${package}']/class[@name='${class}']/method[@name='${method}' and @desc='${desc}']/counter[@type='${lob}']/@missed"
	else
		echo "//package[@name='${package}']/class[@name='${class}']/method[@name='${method}' and @desc='${desc}']/counter[@type='${lob}']/@covered"
	fi
}


function executeQuery() {
	local log="$1"
	local expression="$2"
	#local expression=$(getExpression "$filename")
	local JCP="$XPATH_HOME:$XPATH_HOME/bin"
	result=$(java -cp $JCP "main.Evaluator" "$log" "$expression")
	exitCode="$?"
	if [[ ! $exitCode == "0" ]]; then
		"main.Evaluator failed"
		exit 3;
	fi
	echo "$result"
}

function getValue() {
	local expression="$1"
	array=(${expression//=/ })
	echo $(echo "${array[1]}" | sed 's/"//g')
}

function getValues() {
	local expressionsWithEL="$1"
	local _result=""	
	readarray -t array <<< "$expressionsWithEL"
	for element in "${array[@]}"
	do
		elementValue=$(getValue $element)
		if [ -z "$_result" ]; then
			_result="$elementValue"
		else
			_result="$_result $elementValue"
		fi
	done
	echo "$_result"
}

function _reportMethod() {
	local log="$1"
	local package="$2"
	local class="$3"
	local method="$4"
	local desc="$5"
	#=====queries
	methodCoverage_missed_line_query=$(getMethodClassCoverage "$package" "$class" "$method" "$desc" "$MISSED" "$LINE")
	methodCoverage_covered_line_query=$(getMethodClassCoverage "$package" "$class" "$method" "$desc" "$COVERED" "$LINE")
	methodCoverage_missed_branch_query=$(getMethodClassCoverage "$package" "$class" "$method" "$desc" "$MISSED" "$BRANCH")
	methodCoverage_covered_branch_query=$(getMethodClassCoverage "$package" "$class" "$method" "$desc" "$COVERED" "$BRANCH")
	#=====raw data
	methodCoverage_missed_line_raw=$(executeQuery "$log" "$methodCoverage_missed_line_query")
	methodCoverage_covered_line_raw=$(executeQuery "$log" "$methodCoverage_covered_line_query")
	methodCoverage_missed_branch_raw=$(executeQuery "$log" "$methodCoverage_missed_branch_query")
	methodCoverage_covered_branch_raw=$(executeQuery "$log" "$methodCoverage_covered_branch_query")
	#=====values
	showLines=0
	showBranch=0
	if [ ! -z "$methodCoverage_missed_line_raw" ]; then #no line coverage (not even 0%)
		methodCoverage_missed_line_value=$(getValue "$methodCoverage_missed_line_raw")
		methodCoverage_covered_line_value=$(getValue "$methodCoverage_covered_line_raw")
		methodCoverage_line_total=$(echo "scale=2;$methodCoverage_missed_line_value + $methodCoverage_covered_line_value" | bc -l)
		methodCoverage_line_perc=$(echo "scale=2;($methodCoverage_covered_line_value / $methodCoverage_line_total) * 100" | bc -l)
		showLines=1	
	fi
	if [ ! -z "$methodCoverage_missed_branch_raw" ]; then #no branch coverage (not even 0%)
		methodCoverage_missed_branch_value=$(getValue "$methodCoverage_missed_branch_raw")
		methodCoverage_covered_branch_value=$(getValue "$methodCoverage_covered_branch_raw")
		methodCoverage_branch_total=$(echo "scale=2;$methodCoverage_missed_branch_value + $methodCoverage_covered_branch_value" | bc -l)
		methodCoverage_branch_perc=$(echo "scale=2;($methodCoverage_covered_branch_value / $methodCoverage_branch_total) * 100" | bc -l)
		showBranch=1
	fi
	#======report
	echo "package...$package"
	echo "class.....$class"
	echo "method....$method#$desc"
	if [ "$showLines" -eq "1" ]; then
		echo "method LINE coverage"
		echo "TOTAL    :  $methodCoverage_line_total"
		echo "COVERED  :  $methodCoverage_covered_line_value"
		echo "MISSED   :  $methodCoverage_missed_line_value"
		echo "COVERAGE :  ${methodCoverage_line_perc}%"
	fi
	if [ "$showBranch" -eq "1" ]; then
		echo "method BRANCH coverage"
		echo "TOTAL    :  $methodCoverage_branch_total"
		echo "COVERED  :  $methodCoverage_covered_branch_value"
		echo "MISSED   :  $methodCoverage_missed_branch_value"
		echo "COVERAGE :  ${methodCoverage_branch_perc}%"
	fi
}

function reportMethod() {
	local log="$1"
	local package="$2"
	local class="$3"
	local method="$4"
	all_methods_desc_query=$(getMethodDescriptions "$package" "$class" "$method")
	all_methods_desc_raw=$(executeQuery "$log" "$all_methods_desc_query")
	all_methods_desc=$(getValues "$all_methods_desc_raw")
	for desc in $all_methods_desc
	do
		_reportMethod "$log" "$package" "$class" "$method" "$desc"
	done
}


function reportClass() {
	local log="$1"
	local package="$2"
	local class="$3"
	local fullReport="$4"
	#=====queries
	classCoverage_missed_line_query=$(getClassCoverage "$package" "$class" "$MISSED" "$LINE")
	classCoverage_covered_line_query=$(getClassCoverage "$package" "$class" "$COVERED" "$LINE")
	classCoverage_missed_branch_query=$(getClassCoverage "$package" "$class" "$MISSED" "$BRANCH")
	classCoverage_covered_branch_query=$(getClassCoverage "$package" "$class" "$COVERED" "$BRANCH")
	#=====raw data
	classCoverage_missed_line_raw=$(executeQuery "$log" "$classCoverage_missed_line_query")
	classCoverage_covered_line_raw=$(executeQuery "$log" "$classCoverage_covered_line_query")
	classCoverage_missed_branch_raw=$(executeQuery "$log" "$classCoverage_missed_branch_query")
	classCoverage_covered_branch_raw=$(executeQuery "$log" "$classCoverage_covered_branch_query")
	#=====values
	showLines=0
	showBranch=0
	if [ ! -z "$classCoverage_missed_line_raw" ]; then #no line coverage (not even 0%)
		classCoverage_missed_line_value=$(getValue "$classCoverage_missed_line_raw")
		classCoverage_covered_line_value=$(getValue "$classCoverage_covered_line_raw")
		classCoverage_line_total=$(echo "scale=2;$classCoverage_missed_line_value + $classCoverage_covered_line_value" | bc -l)
		classCoverage_line_perc=$(echo "scale=2;($classCoverage_covered_line_value / $classCoverage_line_total) * 100" | bc -l)
		showLines=1	
	fi
	if [ ! -z "$classCoverage_missed_branch_raw" ]; then #no branch coverage (not even 0%)
		classCoverage_missed_branch_value=$(getValue "$classCoverage_missed_branch_raw")
		classCoverage_covered_branch_value=$(getValue "$classCoverage_covered_branch_raw")
		classCoverage_branch_total=$(echo "scale=2;$classCoverage_missed_branch_value + $classCoverage_covered_branch_value" | bc -l)
		classCoverage_branch_perc=$(echo "scale=2;($classCoverage_covered_branch_value / $classCoverage_branch_total) * 100" | bc -l)
		showBranch=1
	fi
	#======report
	echo "package...$package"
	echo "class.....$class"
	if [ "$showLines" -eq "1" ]; then
		echo "class LINE coverage"
		echo "TOTAL    :  $classCoverage_line_total"
		echo "COVERED  :  $classCoverage_covered_line_value"
		echo "MISSED   :  $classCoverage_missed_line_value"
		echo "COVERAGE :  ${classCoverage_line_perc}%"
	fi
	if [ "$showBranch" -eq "1" ]; then
		echo "class BRANCH coverage"
		echo "TOTAL    :  $classCoverage_branch_total"
		echo "COVERED  :  $classCoverage_covered_branch_value"
		echo "MISSED   :  $classCoverage_missed_branch_value"
		echo "COVERAGE :  ${classCoverage_branch_perc}%"
	fi
	if [ "$fullReport" -eq "1" ]; then
		all_classes_methods_query=$(getClassMethods "$package" "$class")
		all_classes_methods_raw=$(executeQuery "$log" "$all_classes_methods_query")
		all_classes_methods=$(getValues "$all_classes_methods_raw")
		all_classes_methods=$(echo "$all_classes_methods" | sed "s/ /\n/g" | sort -u)
		for method in $all_classes_methods
		do
			reportMethod "$log" "$package" "$class" "$method"
		done
	fi
}

function reportPackage() {
	local log="$1"
	local package="$2"
	local fullReport="$3"
	all_classes_query=$(getPackageClasses "$package")
	all_classes_raw=$(executeQuery "$log" "$all_classes_query")
	all_classes=$(getValues "$all_classes_raw")
	for class in $all_classes
	do
		reportClass "$log" "$package" "$class" "$fullReport"
	done
}


#================================================================================================================================


report_query=$(getReportName)
report_raw=$(executeQuery "$log" "$report_query")
if [ "$(getValue $report_raw)" == 'JaCoCo' ]; then
	echo "JaCoCo report!"
else
	echo "got $(getValue $report_raw) instead"
	exit 1
fi

packages=""
if [ "$usePackage" -eq "0" ]; then
	packages_query=$(getPackages)
	packages_raw=$(executeQuery "$log" "$packages_query")
	packages=$(getValues "$packages_raw")
fi


if [ "$useMethod" -eq "1" ] && [ "$useClass" -eq "1" ] && [ "$usePackage" -eq "1" ]; then
	#show only method for specific class for specific package
	reportMethod "$log" "$package" "$class" "$method"
elif [ "$useClass" -eq "1" ] && [ "$usePackage" -eq "1" ]; then
	#show only specific class for specific package
	reportClass "$log" "$package" "$class" "$fullReport"
elif [ "$usePackage" -eq "1" ]; then
	reportPackage "$log" "$package" "$fullReport"
else
	#show either all packages or specific package
	for package in $packages
	do
		reportPackage "$log" "$package" "$fullReport"
	done
fi
