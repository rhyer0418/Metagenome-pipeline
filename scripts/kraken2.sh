#!/bin/bash
set -euo pipefail

db=~/db
type=pluspf

# 72
TOTAL_CORES=$(nproc)

# keep 4
RESERVED_CORES=4

# 68
THREADS=$(( TOTAL_CORES - RESERVED_CORES ))
if [ $THREADS -lt 1 ]; then
  THREADS=1
fi

echo "Total CPU cores: $TOTAL_CORES"
echo "Reserved cores for system: $RESERVED_CORES"
echo "Threads assigned to kraken2: $THREADS"

DB_PATH="${db}/kraken2/${type}"

for i in $(tail -n +2 result/metadata.txt | cut -f1); do
  echo "Processing sample $i with $THREADS threads"
  kraken2 --db "${DB_PATH}" \
    --paired temp/hr/${i}_paired_1.fastq temp/hr/${i}_paired_2.fastq \
    --threads $THREADS --use-names --report-zero-counts \
    --report temp/kraken2/${i}.report \
    --output temp/kraken2/${i}.output
  echo "Finished sample $i"
done

echo "All samples processed."


