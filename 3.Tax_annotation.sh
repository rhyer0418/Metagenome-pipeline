# Metagenome Pipeline

    # Version: 1.22, 2025/6/24
    # Operation System: Ubuntu 20.04.6 LTS (GNU/Linux 5.4.0-196-generic x86_64)

db=~/db


 ## Read-based (HUMAnN3+MetaPhlAn4 && Kraken2+Bracken)

    conda create -n humann3
    conda activate humann3
    conda install metaphlan=4.1.1 humann=3.9  -c bioconda -c conda-forge -y
    humann --version # v3.9
    metaphlan -v # version 4.1.1 (11 Mar 2024)

# database check
    humann_databases
    
# install db
    cd ${db}
    mkdir -p ${db}/humann3 
    # full_chocophlan.v201901_v31.tar.gz 16 GB
    humann_databases --download chocophlan full ${db}/humann3
    # uniref90_annotated_v201901b_full.tar.gz 20 GB
    humann_databases --download uniref uniref90_diamond ${db}/humann3
    # full_mapping_v201901b.tar.gz  2.6 GB
    humann_databases --download utility_mapping full ${db}/humann3

    # set db location
    # check
    humann_config --print
    # set threads
    humann_config --update run_modes threads 8
    # set 
    humann_config --update database_folders nucleotide ${db}/humann3/chocophlan
    humann_config --update database_folders protein ${db}/humann3/uniref
    humann_config --update database_folders utility_mapping ${db}/humann3/utility_mapping
    # check
    humann_config --print


# kraken2 (2025.7)  kraken2 --version # 2.1.5
 n=kraken2.1.5
 mamba create -n ${n} -y -c bioconda kraken2=2.1.5 python=3.9
 conda activate ${n}
 mamba install bracken krakentools krona r-optparse -y 

 less `type bracken | cut -f2 -d '('|cut -f 1 -d ')'`|grep 'VERSION' # 3.0.1

#download db  20250402 72G
 k2_pluspf_20250402.tar.gz

#run
db=~/db
type=pluspf


for i in $(tail -n +2 result/metadata.txt | cut -f1); do
  kraken2 --db ${db}/kraken2/${type} \
    --paired temp/hr/${i}_paired_1.fastq temp/hr/${i}_paired_2.fastq \
    --threads 8 --use-names --report-zero-counts \
    --report temp/kraken2/${i}.report \
    --output temp/kraken2/${i}.output
done

##1. step1: kraken2.sh

#!/bin/bash
set -euo pipefail

db=~/db
type=pluspf

# 72
TOTAL_CORES=$(nproc)

# keep 4
RESERVED_CORES=4

# 
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

#### tmux 

   # Start a new tmux session named 'kraken_job'
       tmux new -s kraken_job

       sh kraken2.sh

   #Detach from the session (keep it running)
      Ctrl + B  (release both)  
      then press D

   #Reattach to the session later
      tmux attach -t kraken_job

#2. step2: krakentools transfer report to mpa

    for i in `tail -n+2 result/metadata.txt | cut -f1`;do
      kreport2mpa.py -r temp/kraken2/${i}.report \
        --display-header -o temp/kraken2/${i}.mpa; done

#3. step3: Merge all sample counts into one table
  # Create output directory
    mkdir -p result/kraken2

  # All sample result files may have the same number of lines but in different orders, so we sort them first
    tail -n +2 result/metadata.txt | cut -f1 | xargs -n1 -I{} bash -c '
     tail -n+2 temp/kraken2/{}.mpa | LC_ALL=C sort | cut -f2 | sed "1 s/^/{}/\n/" > temp/kraken2/{}_count'
or:

 tail -n +2 result/metadata.txt | cut -f1 | rush -j 1      'tail -n+2 temp/kraken2/{1}.mpa | LC_ALL=C sort | cut -f 2 | sed "1 s/^/{1}\n/" > temp/kraken2/{1}_count'


  # Use the last sample in metadata.txt to extract taxonomy labels (used as row names)
    header=$(tail -n 1 result/metadata.txt | cut -f 1)
    echo $header

    tail -n+2 temp/kraken2/${header}.mpa | LC_ALL=C sort | cut -f 1 | \
      sed "1 s/^/Taxonomy\n/" > temp/kraken2/0header_count

  # Preview the first few taxonomy names
    head -n 3 temp/kraken2/0header_count

  # Merge all sample counts into one table (paste by column)
    ls temp/kraken2/*count
    paste temp/kraken2/*count > result/kraken2/tax_count.mpa

  # Check the structure of the resulting table
    csvtk -t stat result/kraken2/tax_count.mpa

file                          num_cols  num_rows
result/kraken2/tax_count.mpa       240    35,472

  # Preview the first few lines of the merged count table
    head -n 5 result/kraken2/tax_count.mpa

#4. step4. Bracken（Bayesian Reestimation of Abundance after Kraken) 
mkdir -p temp/bracken
conda activate kraken2.1.5
readLen=150
prop=0.2
db=~/db
type=pluspf

 for tax in D P C O F G S;do
  for i in $(tail -n+2 result/metadata.txt | cut -f1); do
        bracken -d ${db}/kraken2/${type}/ \
                -i temp/kraken2/${i}.report \
                -r ${readLen} -l ${tax} -t 0 \
                -o temp/bracken/${i}.${tax}.brk \
                -w temp/bracken/${i}.${tax}.report
    done
done

# Ensure the number of lines in each file is consistent before merging
wc -l temp/bracken/*.report

# Merge Bracken results into a table: sort by taxonomy, extract the 6th column (read count), and prepend sample name
tail -n+2 result/metadata.txt | cut -f1 | /home/Database/liuye/db/EasyMicrobiome/linux/rush -j 1 \
  'tail -n+2 temp/bracken/{1}.brk | LC_ALL=C sort | cut -f6 | sed "1 s/^/{1}\n/" \
  > temp/bracken/{1}.count'

# single level
for tax in P C O F G S; do
  tail -n+2 result/metadata.txt | cut -f1 | /home/Database/liuye/db/EasyMicrobiome/linux/rush -j 1 \
    'tail -n+2 temp/bracken/{1}.'"${tax}"'.brk | LC_ALL=C sort | cut -f6 | sed "1 s/^/{1}\n/" > temp/bracken/{1}.'"${tax}"'.count'
done


# Use taxonomy from the last sample as row names
h=`tail -n1 result/metadata.txt | cut -f1`
tail -n+2 temp/bracken/${h}.brk | LC_ALL=C sort | cut -f1 | \
  sed "1 s/^/Taxonomy\n/" > temp/bracken/0header.count

#single level
for tax in P C O F G S; do
  echo "[${tax}] generating header and merging..."
# Get taxonomy names from any one sample (e.g., last one)
  h=$(tail -n1 result/metadata.txt | cut -f1)
  # Extract taxonomy names as first column
  tail -n+2 temp/bracken/${h}.${tax}.brk | LC_ALL=C sort | cut -f1 | \
    sed '1 s/^/Taxonomy\n/' > temp/bracken/0header.${tax}.count

  paste temp/bracken/0header.${tax}.count temp/bracken/*.${tax}.count > result/kraken2/bracken.${tax}.txt
done

# Check number of count files, should be n+1 (n samples + 1 header)
ls temp/bracken/*S.count | wc -l

# Combine all sample counts into a matrix and remove zero-abundance rows
#  Combine taxonomy + sample counts into a matrix
paste temp/bracken/0header.${tax}.count temp/bracken/*.${tax}.count \
  > result/kraken2/bracken.${tax}.txt


# Get statistics for the merged table (excluding the header by default)
/home/Database/liuye/db/EasyMicrobiome/linux/csvtk -t stat result/kraken2/bracken.${tax}.txt

# Filter the feature table by prevalence threshold (-p), optional normalization (-r), and filtering (-e)
Rscript /home/Database/liuye/db/EasyMicrobiome/script/filter_feature_table.R \
  -i result/kraken2/bracken.${tax}.txt \
  -p ${prop} \
  -o result/kraken2/bracken.${tax}.${prop}

#every level
for tax in P C O F G S; do
  echo "Filtering ${tax} level..."
  Rscript /home/Database/liuye/db/EasyMicrobiome/script/filter_feature_table.R \
    -i result/kraken2/bracken.${tax}.txt \
    -p ${prop} \
    -o result/kraken2/bracken.${tax}.${prop}
done


# Preview the filtered table
# head result/kraken2/bracken.${tax}.${prop}
done

/home/Database/liuye/db/EasyMicrobiome/linux/csvtk -t stat result/kraken2/bracken.?.txt
/home/Database/liuye/db/EasyMicrobiome/linux/csvtk -t stat result/kraken2/bracken.?.$prop

#4. step4. Further analysis

# Remove Chordata (e.g., human) from phylum-level results
grep 'Chordata' result/kraken2/bracken.P.${prop}
grep -v 'Chordata' result/kraken2/bracken.P.${prop} > result/kraken2/bracken.P.${prop}-H

# Manually remove host contamination by species name, e.g., human (requires species-level results)
# Species-level: Remove Homo sapiens (P:Chordata, S:Homo sapiens)
grep 'Homo sapiens' result/kraken2/bracken.S.${prop}
grep -v 'Homo sapiens' result/kraken2/bracken.S.${prop} > result/kraken2/bracken.S.${prop}-H

#Clean up large intermediate annotation output files
rm -rf temp/kraken2/*.output

#Diversity Calculation and Visualization
## Alpha Diversity Calculation
### Metrics: Berger Parker (BP), Simpson (Si), inverse Simpson (ISi), Shannon (Sh)

echo -e "SampleID\tBerger Parker\tSimpson\tinverse Simpson\tShannon" > result/kraken2/alpha.txt

for i in `tail -n+2 result/metadata.txt | cut -f1`; do
    echo -e -n "$i\t" >> result/kraken2/alpha.txt
    for a in BP Si ISi Sh; do
        alpha_diversity.py -f temp/bracken/${i}.S.brk -a $a | cut -f 2 -d ':' | tr '\n' '\t' >> result/kraken2/alpha.txt
    done
    echo "" >> result/kraken2/alpha.txt
done

cat result/kraken2/alpha.txt

#Beta Diversity Calculation
beta_diversity.py -i temp/bracken/*.S.brk --type bracken > result/kraken2/beta.txt
cat result/kraken2/beta.txt

# Krona Plot
for i in `tail -n+2 result/metadata.txt | cut -f1`; do
    kreport2krona.py -r temp/kraken2/${i}.report -o temp/kraken2/${i}.krona --no-intermediate-ranks
    ktImportText temp/kraken2/${i}.krona -o result/kraken2/krona.${i}.html
done


## Pavian Sankey Plot
  Visit the online visualization platform: 
https://fbreitwieser.shinyapps.io/pavian/




