# GapTools
 dbGaP data validation tool repo

## Pre-requisites:
```
Docker
Docker-compose
Unused port 8080 on your Docker host
User account with docker group membership on the Docker host
```

## Setup
```
git clone https://github.com/ncbi/GapTools
cd GapTools
mkdir output_files

# Change file permissions to allow container to access files
chmod -R o+w output_files
chmod -R o+w input_files
```

## Execution
```
./dbgap-docker.bash -i ./input_files/ -o ./output_files/ -m input_files/user_study/metadata.json -s user_study up

Open Airflow UI: http://<docker_host_ip>:8080/admin/airflow/graph?dag_id=SandboxSubmission
```

## Stop Docker Containers
```
./dbgap-docker.bash down
```

## To Scale Up Airflow Workers
```
docker-compose -f docker-compose-CeleryExecutor.yml up -d --scale worker=5
```