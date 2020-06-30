#!/bin/bash

#================================================================
# HEADER
#================================================================
#% SYNOPSIS
#+    ${SCRIPT_NAME} [-h] [-i, --input [input directory]]
#+                     [-o, --output [output directory]] 
#+                     [-m, --manifest [manifest file]]
#+                     [up|down]
#+
#% DESCRIPTION
#%    This script runs GapTools to validate data files
#%    to be submitted to dbGaP. It loads a docker-compose
#%    file and runs required docker containers.
#%
#%
#% OPTIONS
#%    -i, --input                   Input directory containing the 
#%                                  data files to be validated.
#%    -o, --output                  Output directory
#%    -m, --manifest                Manifest file with metadata
#%    -h, --help                    Print this help
#%
#% EXAMPLES
#%    ${SCRIPT_NAME} -i ./input_files/1000_Genomes_Study/ -o ./output_files/1000_Genomes_Study/ -m ./input_files/1000_Genomes_Study/metadata.json up
#%    ${SCRIPT_NAME} down
#%
#%
#% REQUIREMENTS
#%    docker
#%    docker-compose
#%
#%
#================================================================
# END_OF_HEADER
#================================================================



#== needed variables ==#
SCRIPT_HEADSIZE=$(head -200 ${0} |grep -n "^# END_OF_HEADER" | cut -f1 -d:)
SCRIPT_NAME="$(basename ${0})"

#== usage functions ==#
usage() { printf "Usage: "; head -${SCRIPT_HEADSIZE:-99} ${0} | grep -e "^#+" | sed -e "s/^#+[ ]*//g" -e "s/\${SCRIPT_NAME}/${SCRIPT_NAME}/g" ; }
usagefull() { head -${SCRIPT_HEADSIZE:-99} ${0} | grep -e "^#[%+-]" | sed -e "s/^#[%+-]//g" -e "s/\${SCRIPT_NAME}/${SCRIPT_NAME}/g" ; }

##################
# Parse and verify command line options
##################
OPTIONS=ht:i:o:m:
LONGOPTS=help,input:,output:,manifest:

# pass arguments only via   -- "$@"   to separate them correctly
! PARSED=$(getopt --options=$OPTIONS --longoptions=$LONGOPTS --name "$0" -- "$@")
if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
    # e.g. return value is 1
    #  then getopt has complained about wrong arguments to stdout
    echo "Wrong number/type of arguments"
    usage
    exit 2
fi
# read getopt output to handle the quoting:
eval set -- "$PARSED"

# interate through to set values for the script
while true; do
    case "$1" in
        -h|--help)
            usagefull
            exit
            ;;
        -i|--input)
            INPUT_DIR="$2" 
            INPUT_DIR="$(echo -e "${INPUT_DIR}" | tr -d '[[:space:]]')"
            if [ -z "$INPUT_DIR" ]; then
               echo $INPUT_DIR "Please provide the input directory"
               usage
               exit 2
            fi
            if [ z"${INPUT_DIR:0:1}" == "z-" ]; then
               echo $INPUT_DIR "Please provide the input directory"
               usage
               exit 2
            fi
            shift 2 
            ;;
        -o|--output)
            OUTPUT_DIR="$2" 
            OUTPUT_DIR="$(echo -e "${OUTPUT_DIR}" | tr -d '[[:space:]]')"
            if [ -z "$OUTPUT_DIR" ]; then
               echo $OUTPUT_DIR "Please provide the output directory"
               usage
               exit 2
            fi
            if [ z"${OUTPUT_DIR:0:1}" == "z-" ]; then
               echo $OUTPUT_DIR "Please provide the output directory"
               usage
               exit 2
            fi 
            shift 2
            ;;
        -m| --manifest)
            MANIFEST="$2" 
            MANIFEST="$(echo -e "${MANIFEST}" | tr -d '[[:space:]]')"
            if [ -z "$MANIFEST" ]; then
               echo $MANIFEST "Please provide full path to the manifest file"
               usage
               exit 2
            fi
            if [ z"${MANIFEST:0:1}" == "z-" ]; then
               echo $MANIFEST "Please provide full path to the manifest file"
               usage
               exit 2
            fi 
            shift 2
            ;;
        --)
            shift
            break
            ;;
        *)
            echo "An incorrect option has been supplied"
            usage
            exit 3
            ;;
    esac
done

##################
# Verify up/down arguments were supplied properly
##################
if [[ $# -ne 1 ]]; then
    echo $'\n'"$0: Incorrect options supplied"$'\n'
    usage
    exit 4
fi
DSTATE=$1
if ! [[ "${DSTATE}" =~ ^(up|down)$ ]]; then
    echo $'\n'"$0: The allowed options are up or down"$'\n'
    usage
    exit 4
fi

#########################
# Run the docker-compose commands to bring the environment down
# Skips the rest of the validation and exit the script
#########################
if [ $DSTATE == "down" ]; then
   docker-compose -f docker-compose-CeleryExecutor.yml down
   exit
fi

########################
# Validate that all options have been set
########################
ERROR_TEXT=""
if [ -z ${INPUT_DIR} ]; then
   ERROR_TEXT=$ERROR_TEXT$'Input directory has not been set.\n'
fi
if [ -z ${OUTPUT_DIR} ]; then
   ERROR_TEXT=$ERROR_TEXT$'Output directory has not been set.\n'
fi
# if [ -z ${FS_TYPE} ]; then
#    ERROR_TEXT=$ERROR_TEXT$'Filesystem type has not been set. Valid options are local or nfs.\n'
# fi
if [ ! -z "${ERROR_TEXT}" ]; then
   echo "$ERROR_TEXT"
   usage
   exit 2
fi

########################
# Validate that the input and output directories exist
########################
if [ ! -d "$INPUT_DIR" ]; then
   echo "Input directory does not exist"
   exit 2
fi
if [ ! -d "$OUTPUT_DIR" ]; then
   echo "Output directory does not exist"
   exit 2
fi
if [ ! -f "$MANIFEST" ]; then
   echo "Manifest file does not exist"
   exit 2
fi

########################
# Create a .env file to be used by docker-compose
########################
echo "OUTPUT_VOL=${OUTPUT_DIR}" > .env
echo "INPUT_VOL=${INPUT_DIR}" >> .env
echo "MANIFEST=${MANIFEST}" >> .env

#########################
# Run the docker-compose commands to bring the environment up
#########################
if [ $DSTATE == "up" ]; then
   docker-compose -f docker-compose-CeleryExecutor.yml up -d
   echo ""
   echo "The airflow server has started on port 8080. Visit "
   echo "http://<your_docker_host_ip>:8080/admin/airflow/graph?dag_id=GapTools"
   echo "in your web browser to view the status."
   echo ""
   echo ""
   echo "When the airflow process is complete run:"
   echo "./dbgap-docker.bash down"
   echo "to stop and delete the docker containers."
   echo ""
fi

