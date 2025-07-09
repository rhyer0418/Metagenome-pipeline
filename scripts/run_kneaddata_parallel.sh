#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -euo pipefail

# Set the path to the database (please modify according to your environment)
#db="/home/Database/liuye/db"

# Number of parallel jobs (adjust as needed)
NUM_THREADS=8

# Batch processing
tail -n +2 result/metadata_filtered.txt | cut -f1 | \
xargs -P ${NUM_THREADS} -I {} bash -c '
  echo "Processing sample: {}";

  # Modify FASTQ headers to include /1 and /2 for kneaddata compatibility
  sed "1~4 s/ 1:/.1:/;1~4 s/$/\/1/" temp/qc/{}_1.fastq > temp/{}_1.fastq;
  sed "1~4 s/ 2:/.1:/;1~4 s/$/\/2/" temp/qc/{}_2.fastq > temp/{}_2.fastq;

  # Run kneaddata for host read removal
  kneaddata -i1 temp/{}_1.fastq -i2 temp/{}_2.fastq \
    -o temp/hr --output-prefix {} \
    --bypass-trim --bypass-trf --reorder \
    --bowtie2-options "--very-sensitive --dovetail" \
    -db /home/Database/liuye/db/kneaddata/human/hg37dec_v0.1/ \
    --remove-intermediate-output -v -t 3;

  # Clean up temporary files
  rm temp/{}_1.fastq temp/{}_2.fastq
'

echo "All samples processed."
