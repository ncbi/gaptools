# GapTools
dbGaP data validation tool. GapTools is distributed as a docker image on Dockerhub.

## Pre-requisites:

##### Docker Installation:

You must have Docker installed and working to be able to run GapTools. Docker is available on many different operating systems, including most modern Linux distributions, like CentOS, Debian, Ubuntu, etc. Follow the link below for more information about how to install Docker on your particular operating system. 

* [Docker installation guide](https://docs.docker.com/engine/install/#supported-platforms)

To ensure that you can run GapTools under your user account, run the below command and check for a response similar to the one below (your version and build numbers might be different than the ones below). The minimum supported Docker version to run GapTools is 17.04.0.  

```
docker -v

Docker version 19.03.6, build 369ce74a3c
```
##### Docker Compose Installation:

GapTools uses docker-compose to run multiple containers under a single service. Follow the link below for more details on how to install docker-compose.
* [Instructions to install docker-compose](https://docs.docker.com/compose/install/#install-compose)
    
##### Access to data files

The docker host running GapTools requires access to the data files that need to be validated. The files can either be on a local file system, a network file share (NFS) or in a storage bucket on the cloud. If the files are on a network file share (NFS) or in a storage bucket on the cloud, they need to be mounted as file system on the docker host. Below are some tools that are commonly used to mount cloud storage buckets as file systems on linux servers

1) [s3-fuse for Amazon Web Services (AWS)](https://github.com/s3fs-fuse/s3fs-fuse)      
1) [gcsfuse for Google Cloud Platform](https://github.com/GoogleCloudPlatform/gcsfuse/)
 
    
##### Unused port 8080 on your docker host

GapTools requires port 8080 to be available on the host system running docker. Run the below command to check if port 8080 is available on the docker host. If the below command does not produce any output, then port 8080 is available on the docker host.
```
netstat -an | grep "8080"
```

## Setup

Once all pre-requisites are met, follow the instructions below to setup GapTools. The setup can be validated using a sample study that is included as part of GapTools installation. The input files for the sample study are inside the __input_files/1000_Genomes_Study/__ directory of the cloned GapTools GitHub repository.

For the sample study, we will have GapTools generate all output files inside the __output_files/1000_Genomes_Study/__ directory.
```
git clone https://github.com/ncbi/GapTools

cd GapTools
mkdir -p output_files/1000_Genomes_Study

# Change file permissions to allow GapTools to write output files on docker host
chmod -R o+w output_files
```

## Execution

Once GapTools is setup, to execute it on the included sample study, run the below script from inside the same directory where the GapTools GitHub repository is cloned. 
```
./dbgap-docker.bash -i ./input_files/1000_Genomes_Study/ -o ./output_files/1000_Genomes_Study -m ./input_files/1000_Genomes_Study/metadata.json up
```

GapTools uses Apache Airflow behind the scenes as the workflow orchestrator to perform all the validation tasks. You can check the status of the task execution by accessing Airflow web interface at:

```
http://<docker_host_ip>:8080/admin/airflow/graph?dag_id=GapTools
```  

At the end of the workflow, the output files will be created under the specified output directory.
## Usage

To use GapTools for your study, modify the above command and pass as input parameters:

__-i__ -- path to the input files for your study

__-o__ -- path where output files should be generated

__-m__ -- path to the manifest file for your study 

## Stop Docker Containers

Once your study is processed, run the below command to stop the GapTools service.
```
./dbgap-docker.bash down
```

## Contact
If you have any questions or to report any issues, please contact us at: [dbgap-help@ncbi.nlm.nih.gov](dbgap-help@ncbi.nlm.nih.gov)
