# Metagenome Pipeline

    # Version: 1.22, 2025/6/24
    # Operation System: Ubuntu 20.04.6 LTS (GNU/Linux 5.4.0-196-generic x86_64)

1. Step 2: 1.1 Quality Control
mkdir -p temp/qc result/qc

conda activate kneaddata  
# fastp: version 0.24.1
# multi-samples
tail -n +2 result/metadata_filtered.txt | cut -f1 | \
xargs -P 6 -I {} bash -c \
  'fastp -i seq/{}_1.clean.fq.gz -I seq/{}_2.clean.fq.gz \
   -j temp/qc/{}_fastp.json -h temp/qc/{}_fastp.html \
   -o temp/qc/{}_1.fastq -O temp/qc/{}_2.fastq > temp/qc/{}.log 2>&1'

# one sample qc
  fastp -i HC091_1.clean.fq.gz  -I HC091_2.clean.fq.gz \
      -o ../temp/qc/HC091_1.fastq -O ../temp/qc/HC091_2.fastq \
      -h ../temp/qc/HC091.html -j ../temp/qc/HC091.json \
      > ../temp/qc/HC091.log 2>&1 

  fastp -i HC092_1.clean.fq.gz  -I HC092_2.clean.fq.gz \
      -o ../temp/qc/HC092_1.fastq -O ../temp/qc/HC092_2.fastq \
      -h ../temp/qc/HC091.html -j ../temp/qc/HC091.json \
      > ../temp/qc/HC092.log 2>&1 


# summary of results
    echo -e "SampleID\tRaw\tClean" > temp/fastp
    for i in `tail -n+2 result/metadata.txt|cut -f1`;do
        echo -e -n "$i\t" >> temp/fastp
        grep 'total reads' temp/qc/${i}.log|uniq|cut -f2 -d ':'|tr '\n' '\t' >> temp/fastp
        echo "" >> temp/fastp
        done
    sed -i 's/ //g;s/\t$//' temp/fastp

# reorder by metadata
    awk 'BEGIN{FS=OFS="\t"}NR==FNR{a[$1]=$0}NR>FNR{print a[$1]}' temp/fastp result/metadata.txt \
      > result/qc/fastp.txt
    cat result/qc/fastp.txt




## 1.2 KneadData: Host removal
mkdir -p temp/hr
conda activate kneaddata
kneaddata --version # kneaddata v0.12.2
#db
  soft=~/miniconda3
  db=~/db
  wd=~/meta
/home/Database/liuye/db/kneaddata/human/Homo_sapiens_hg37_and_human_contamination_Bowtie2_v0.1.tar.gz  # 3.5G 

#rush
    time tail -n+2 result/metadata.txt|cut -f1|rush -j 2 \
      "sed '1~4 s/ 1:/.1:/;1~4 s/$/\/1/' temp/qc/{}_1.fastq > temp/{}_1.fastq; \
      sed '1~4 s/ 2:/.1:/;1~4 s/$/\/2/' temp/qc/{}_2.fastq > temp/{}_2.fastq; \
      kneaddata -i1 temp/{1}_1.fastq -i2 temp/{1}_2.fastq \
      -o temp/hr --output-prefix {1} \
      --bypass-trim --bypass-trf --reorder \
      --bowtie2-options '--very-sensitive --dovetail' \
      -db ${db}/kneaddata/human/hg37dec_v0.1 \
      --remove-intermediate-output -v -t 3; \
      rm temp/{}_1.fastq temp/{}_2.fastq"

#xargs
sh run_kneaddata_parallel.sh 
nohup sh run_kneaddata_parallel.sh > main.log 2>&1 &
[1] 13885

###run_kneaddata_addsamples.sh

#!/bin/bash

# Exit immediately on error, unset var, or pipeline failure
set -euo pipefail

# Number of parallel jobs
NUM_THREADS=2

# Path to kneaddata human genome database
DB_PATH="/home/Database/liuye/db/kneaddata/human/hg37dec_v0.1/"

# Process only HC091 and HC092
echo -e "HC091\nHC092" | \
xargs -P "${NUM_THREADS}" -I {} bash -c '
  SAMPLE={}
  echo "Processing sample: ${SAMPLE}"

  # Modify FASTQ headers to include /1 and /2
  sed "1~4 s/ 1:/.1:/;1~4 s/\$/\/1/" temp/qc/${SAMPLE}_1.fastq > temp/${SAMPLE}_1.fastq
  sed "1~4 s/ 2:/.1:/;1~4 s/\$/\/2/" temp/qc/${SAMPLE}_2.fastq > temp/${SAMPLE}_2.fastq

  # Run kneaddata
  kneaddata -i1 temp/${SAMPLE}_1.fastq -i2 temp/${SAMPLE}_2.fastq \
    -o temp/hr --output-prefix ${SAMPLE} \
    --bypass-trim --bypass-trf --reorder \
    --bowtie2-options "--very-sensitive --dovetail" \
    -db '"${DB_PATH}"' \
    --remove-intermediate-output -v -t 3

  # Clean up
  rm temp/${SAMPLE}_1.fastq temp/${SAMPLE}_2.fastq

  echo "Done: ${SAMPLE}"
'

echo "All selected samples (HC091 & HC092) processed."


chmod +x run_kneaddata_addsamples.sh
