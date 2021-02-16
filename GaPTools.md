# GaPTools
The National Center for Biotechnology Information's [dbGaP archive](https://www.ncbi.nlm.nih.gov/gap/) has processed, archived and distributed genome scale datasets 
from over 1500 different studies comprised from data collected on over 2.5 million study participants (subjects) since 2007. 
In support of National Institutes of Health [Genomic Data Sharing policy](https://osp.od.nih.gov/scientific-sharing/genomic-data-sharing/) and the emerging NIH data sharing ecosystem 
the NCBI has developed a QA/QC software tool named GaPTools to evaluate consistency of genome scale datasets. This tool is used to evaluate datasets 
prior to submission to public archives, such as dbGaP. This software package uses the same code and therefore is consistent with the code for the internal dbGaP automated processing pipeline. 
The tool is intended to identify common inconsistencies that can delay processing/sharing of the data. The use of this tool and correcting any errors prior to submission will substantially 
reduce the time needed for dbGaP staff to process and release data. This tool is not designed for genomic analysis. GaPTools is distributed as a docker image on Dockerhub.

#### Why Docker?
GaPTools uses Apache Airflow behind the scenes as the workflow orchestrator to perform all the validation tasks. Apache Airflow is a platform to programmatically author, schedule and monitor workflows. 
Workflows are authored as directed acyclic graphs (DAGs) of tasks. The airflow scheduler executes tasks on an array of workers while following the specified dependencies.

There are four main components of Apache Airflow:
* A metadata database for tasks
* UI web client for monitoring task execution
* A scheduler that triggers tasks
* An executor (worker) that gets the tasks done

Though all the above components can be setup independently, we use Docker to reduce the overhead of setup and configuration of the individual components. 
All these components are defined and configured in a single docker-compose file, which is used to bring up all the components with a single command.

#### Current QC Checks
The initial release of GaPTools includes the functions to check the issues that most commonly cause delays in processing and prevent data archiving and sharing via dbGaP, including:
* Basic format checks
    * File Formats are consistent with dbGaP submission guide with regard to
        * Required columns
        * Illegal characters
* Subject and Sample ID checks
    * Subject IDs from SSM are present in SC file.
    * Pedigree file IDs (Subject Mother and Father columns) are present in SC file.
    * Sample IDs listed in genotype files (PLINK or .VCF) are present in in SSM file.
* Pedigree file
    * Subjects listed as Twins have same Mother and Father.
    * Mother IDs are female and Father IDss are male in pedigree file.
    * Subject Sex in pedigree file is consistent with Sex in SC file.
* Genotype Checks
    * Computed Sex values determined using GRAF software (based on the heterozygosity of non-pseudo-autosomal X chromosome markers) are consistent with the reported Sex values in SC and Pedigree files.
    * Detection of Cryptic Duplicate Samples. Samples that belong to different Subjects (and are not twins) but have the same genetic profile as determined by GRAF.
    * Detection of Sample IDs that belong to the same subject but have different genetic profiles as determined by GRAF.
    * Detection of Parent offspring pairs as determined using GRAF software that are not specified in Pedigree file.
* Reports
    * Report with all reported and computed Sex values produced by GRAF.
    * Report of computed relationships produced by GRAF.

The full list of errors detected by the system can be found here:[Validation Error Codes](https://www.ncbi.nlm.nih.gov/gap/public_utils/messages/)

#### Required Files
GaPTools is designed to check core phenotype data files and genomic datasets in both [PLINK](https://www.cog-genomics.org/plink/1.9/formats) and [VCF](https://en.wikipedia.org/wiki/Variant_Call_Format) format. 
To review the required files and their format for individual level data submission please see the [dbGaP submission guide](https://www.ncbi.nlm.nih.gov/gap/docs/submissionguide/).

##### Metadata file
This tool also requires as an input parameter, a json file with the metadata information about the files to be processed. The file has to be named `metadata.json`. 

Here is a sample `metadata.json` file:
```
{
  "NAME": "1000 Genomes Public Study",
  "FILES": [
    {
      "name": "1000_Genomes_SC.txt",
      "type": "subject_consent_file"
    },
    {
      "name": "1000_Genomes_SSM.txt",
      "type": "subject_sample_mapping_file"
    }
  ]
}

``` 

The metadata file, at the very minimum, requires the following attributes:
* A `NAME` attribute that describes the study being processed
* A `FILES` attribute that contains information about the 2 required files:
    * `subject_consent_file`
    * `subject_sample_mapping_file`

An optional file of type `pedigree_file` can also be added to the `FILES` list in the metadata file.

#### Usage
Please refer to the [README](README.md) file for instructions to setup and execute GaPTools.

#### Check Processing Status
Once GaPTools is triggered to process the files, the status of the workflow execution can be checked by browsing to the URL below:
```
http://<docker_host_ip>:8080/admin/airflow/graph?dag_id=gaptools
```
The URL opens the embedded Airflow UI web console that displays the status of the DAG execution. Here is an example of a DAG that has successfully finished processing:

![](images/gaptools_dag.png)

 #### Airflow DAG Task Definitions
* `CHECK_METADATA_FILES` - Validates the structure of the metadata.json file. It also checks the metadata file has all the required attributes.
* `CREATE_GENO_TELEMETRY` - Creates a telemetry file for subsequent tasks to refer to.
* `VALIDATE_PEDIGREE` - Validates the Pedigree file (if present) for any errors. Does nothing if Pedigree file is not provided.
* `VALIDATE_SSM` - Validates the Subject Sample Mapping file for any errors.
* `VALIDATE_SC`- Validates the Subject Consent file for any errors.
* `VALIDATE_SSM_VS_GENO` - Compares the Subject Sample Mapping and Geno Telemetry files and reports any errors.
* `VALIDATE_PEDIGREE_VS_SC` - Compares the Pedigree and Subject Consent files and reports any errors. Does nothing if the Pedigree file is not provided.
* `VALIDATE_SSM_VS_SC` - Compares the Subject Consent and Subject Sample Mapping files and reports any errors.
* `IS_ID_ERROR_DETECTED` - Checks if any ID errors are detected from the above validation tasks.
* `PROCESS_GENO_FILES` - Executed when no ID errors are detected.
* `EXTRACT_VCF_FILES` - Extract VCF files to a location in the output directory.
* `EXTRACT_PLINK_FILES` - Extract PLINK files to a location in the output directory.
* `MERGE_GENO_MATRIX_FRAGMENTS` - Consolidate VCF and PLINK files whenever it is possible.
* `UPDATE_FAM_FILES` - Update PLINK FAM files with sex information from the Subject Consent file.
* `RUN_GRAF_SEX` - Execute GRAF command to produce sex report.
* `RUN_GRAF_RELATIONSHIP` - Execute GRAF command to produce relationship report.
* `END_OF_VALIDATIONS` - Marks the end of the validations.
* `REPORT_VALIDATION_RESULTS` - Generates a consolidated report of the processing of Geno files.


#### Output Files
At the end of all the validation tasks, GaPTools generates reports in the specified output directory. It produces consolidated reports written to a file in an email format under the `<output_dir>/client_emails/studies/` directory.

GaPTools also generates individual reports in JSON format for every task in the Airflow DAG. These individual reports are created under the `<output_dir>/client_messages/` directory.

#### Included Sample Studies
GaPTools includes three sample studies to demonstrate the functionality of the tool. 
The supplied examples have data from the [1000 Genomes Project](https://www.internationalgenome.org/), 
as well as two artificially created studies with intentional errors to illustrate error reporting. 
These samples located under `input_files/` directory in separate folders.

#### References
[NCBI's Database of Genotypes and Phenotypes: dbGaP.](https://pubmed.ncbi.nlm.nih.gov/24297256/)
Tryka KA, Hao L, Sturcke A, Jin Y, Wang ZY, Ziyabari L, Lee M, Popova N, Sharopova N, Kimura M, Feolo M.
Nucleic Acids Res. 2014 Jan;42(Database issue):D975-9. doi: 10.1093/nar/gkt1211. Epub 2013 Dec 1.
PMID: 24297256

[Quickly identifying identical and closely related subjects in large databases using genotype data.](https://pubmed.ncbi.nlm.nih.gov/28609482/)
Jin Y, Schäffer AA, Sherry ST, Feolo M.
PLoS One. 2017 Jun 13;12(6):e0179106. doi: 10.1371/journal.pone.0179106. eCollection 2017.
PMID: 28609482

[Second-generation PLINK: rising to the challenge of larger and richer datasets.](https://pubmed.ncbi.nlm.nih.gov/25722852/)
Chang CC, Chow CC, Tellier LC, Vattikuti S, Purcell SM, Lee JJ.
Gigascience. 2015 Feb 25;4:7. doi: 10.1186/s13742-015-0047-8. eCollection 2015.
PMID: 25722852
