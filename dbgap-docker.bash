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
#%    This script runs GaPTools to validate data files
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
#% NOTES
#%    macOS and other BSD-based systems do not support long options (--help, etc)
#%    Use the short option equivalents (-i, -o, -m, -h)
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
if [[ "$OSTYPE" == "darwin"* ]]; then
   # macOS uses the BSD getopt, which does not support long options.
   ! PARSED=$(getopt $OPTIONS "$@")
else
   ! PARSED=$(getopt --options=$OPTIONS --longoptions=$LONGOPTS --name "$0" -- "$@")
fi

if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
    # e.g. return value is 1
    #  then getopt has complained about wrong arguments to stdout
    echo "Wrong number/type of arguments"
    usage
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS uses the BSD getopt, which does not support long options.
        echo "WARNING:  On macOS:  long options (e.g. '--help') are not supported."
    fi
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
# Normalize paths
########################

function normalize_path() {
  path1="$1"
  if [ "${path1:0:1}" != '/' -a "${path1:0:2}" != './' ] ; then
    path1="./$path1"
  fi
  printf '%s' "$path1"
}

INPUT_DIR=$(normalize_path "$INPUT_DIR")
OUTPUT_DIR=$(normalize_path "$OUTPUT_DIR")
MANIFEST=$(normalize_path "$MANIFEST")

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

########################
# fill fernet key
########################
env_file=airflow-variables.env
# if not exists, then add
grep '^FERNET_KEY=' "$env_file" > /dev/null
if [ $? -ne 0  ]; then

   python_code="from cryptography.fernet import Fernet; FERNET_KEY = Fernet.generate_key().decode(); print(FERNET_KEY); "
   fernet_key=$(docker run -it --rm 'ncbi/gaptools:latest' /usr/bin/python3 -c "$python_code" )
   if [ $? -ne 0 ]; then
      echo "Cannot generate fernet key"
      exit 2
   fi

   printf "\nFERNET_KEY=%s\n\n" "$fernet_key" >> "$env_file"

fi

#########################
# check if fernet key is properly set
#########################

docker run -it --rm --env-file "$env_file" 'ncbi/gaptools:latest' /bin/bash -c "printenv | grep '^FERNET_KEY=' > /dev/null"
if [ $? -ne 0 ]; then
   echo "Cannot fill fernet key properly"
   exit 2
fi

#########################
# Check to see if webserver container is up
#########################
docker_check() {
   while IFS= read -r docker_line
      do
         ## look for Up on the gaptools worker container
         if [[ ($docker_line =~ .*\/entrypoint\.sh\ we.*) &&  ($docker_line =~ .*\(healthy\).*) ]]; then
            return 0
         fi
      done < <(docker ps)
   return 1
}

#########################
# Run the docker-compose commands to bring the environment up
#########################
if [ $DSTATE == "up" ]; then
   docker pull ncbi/gaptools:latest
   docker-compose -f docker-compose-CeleryExecutor.yml up -d
   i=0
   while ! docker_check
   do
      i=$((i+1))
      echo "Waiting for webserver to start... ${i} of 20"
      if [[ $i == 20 ]]; then
         echo "Timed out waiting for webserver to start"
         echo "Check the docker container logs by executing the command \"docker logs [container_name]\""
         echo "E.g. \"docker logs gaptools_webserver_1\""
         echo
         exit 2
      fi
      sleep 10
   done

   echo ""
   echo "The airflow server has started on port 8080. Visit "
   echo "http://<your_docker_host_ip>:8080"
   echo "in your web browser to view the status."
   echo ""
   echo ""
   echo "When the airflow process is complete run:"
   echo "./dbgap-docker.bash down"
   echo "to stop and delete the docker containers."
   echo ""
   echo ""
   echo "At the end of the workflow, the output files will be created under ${OUTPUT_DIR}."
   echo ""
fi
