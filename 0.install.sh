# Metagenome Pipeline

    # Date: 2025/5/24
    # Operation System: Ubuntu 20.04.6 LTS (GNU/Linux 5.4.0-196-generic x86_64)

# install software (All software and databases can be downloaded from the official website)
db=~/db
mkdir -p ${db} && cd ${db}

soft=~/miniconda3
PATH=${soft}/bin:${soft}/condabin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${db}/EasyMicrobiome/linux:${db}/EasyMicrobiome/script
echo $PATH

#dependencies
#miniconda3
wget -c https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh

conda 25.5.1
Python 3.13.3

conda config --add channels bioconda 
conda config --add channels conda-forge 
    
 #  ~/.condarc
    conda install mamba -c conda-forge -c bioconda -y
    mamba install pandas -c conda-forge -c bioconda -y
    mamba install conda-pack -c conda-forge -c bioconda -y
    
    conda config --show-sources
    conda env list

# 1. install kneaddata
conda create -y -n kneaddata
conda activate kneaddata

mamba install kneaddata fastqc multiqc fastp r-reshape2 -y 

### install kneaddata db

    # check
    kneaddata_database
    db=~/db
    # install bowtie2 index  3.5 GB
    mkdir -p ${db}/kneaddata/human
    kneaddata_database --download human_genome bowtie2 ${db}/kneaddata/human

tar xvzf Homo_sapiens_hg37_and_human_contamination_Bowtie2_v0.1.tar.gz
mkdir hg37dec_v0.1


# 2. install HUMAnN3/Kraken2
conda create -n humann3
conda activate humann3
conda install metaphlan=4.1.1 humann=3.9  -c bioconda -c conda-forge -y
humann --version # v3.9
metaphlan -v # version 4.1.1 (11 Mar 2024)

#test
humann_test  # no error ok

### install HUMAnN3 db
#check db
humann_databases

    # install
    cd ${db}
    mkdir -p ${db}/humann3 
    # microbiome 16 GB
    humann_databases --download chocophlan full ${db}/humann3
    # functional gene diamond索引 20 GB
    humann_databases --download uniref uniref90_diamond ${db}/humann3
    # mapping db  2.6 GB
    humann_databases --download utility_mapping full ${db}/humann3
#optional
wget -c ftp://download.nmdc.cn/tools/meta/humann3/full_chocophlan.v201901_v31.tar.gz
wget -c ftp://download.nmdc.cn/tools/meta/humann3/uniref90_annotated_v201901b_full.tar.gz
wget -c ftp://download.nmdc.cn/tools/meta/humann3/full_mapping_v201901b.tar.gz

### install, gunzip
mkdir -p ${db}/humann3/chocophlan
tar xvzf full_chocophlan.v201901_v31.tar.gz -C ${db}/humann3/chocophlan
mkdir -p ${db}/humann3/uniref
tar xvzf uniref90_annotated_v201901b_full.tar.gz -C ${db}/humann3/uniref
mkdir -p ${db}/humann3/utility_mapping			66	
tar xvzf full_mapping_v201901b.tar.gz -C ${db}/humann3/utility_mapping


# set db location
# check
humann_config --print

# Set number of threads (recommended between 3 and 8)
humann_config --update run_modes threads 8
# Set paths for nucleotide, protein, and utility mapping databases
humann_config --update database_folders nucleotide ${db}/humann3/chocophlan
humann_config --update database_folders protein ${db}/humann3/uniref
humann_config --update database_folders utility_mapping ${db}/humann3/utility_mapping
# Verify current configuration settings
humann_config --print


