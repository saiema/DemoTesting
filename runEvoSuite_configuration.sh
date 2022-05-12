#!/bin/bash

#Constants
CURRENT_DIR=$(pwd)
#JUNIT AND EVOSUITE
#EVOSUITE_JAR="${CURRENT_DIR}/tools/evosuite/evosuite-1.0.6.jar" #USE THIS FOR EVOSUITE 1.0.6
EVOSUITE_JAR="${CURRENT_DIR}/tools/evosuite/evosuite-fb.jar" #USE THIS FOR EVOSUITE-FB
EVOSUITE_ADDITIONAL_FLAGS="-generateSuite" #This is required when using evosuite-fb
JUNIT="${CURRENT_DIR}/tools/junit-4.12.jar"
HAMCREST="${CURRENT_DIR}/tools/org.hamcrest.core_1.3.0.v201303031735.jar"
#TESTING_JARS_ES="${CURRENT_DIR}/tools/evosuite/evosuite-standalone-runtime-1.0.6.jar" #USE THIS FOR EVOSUITE 1.0.6
TESTING_JARS_ES="${CURRENT_DIR}/tools/evosuite/evosuite-fb-runtime.jar" #USE THIS FOR EVOSUITE-FB
ES_JUNIT_SUFFIX="ESTest"	#EvoSuite test suffix
#JACOCO
USE_OFFLINE_INSTRUMENTATION=1 #0 : do not use offline instrumentation; 1 : use offline instrumentation
OFFLINE_EXEC_FILE_LOCATION="jacoco.exec"
OFFLINE_INSTR_DIR_LOCATION="instrumentedCode"
JACOCO_AGENT="JaCoCoRS/jacocoagent.jar"
JACOCO_CLI="JaCoCoRS/jacococli.jar"
JACOCO_REPORT="JaCoCoRS/JaCoCoRS.sh"
