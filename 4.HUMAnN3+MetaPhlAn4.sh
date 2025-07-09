
# Metagenome Pipeline

    # Version: 1.22, 2025/6/24
    # Operation System: Ubuntu 20.04.6 LTS (GNU/Linux 5.4.0-196-generic x86_64)

db=~/db
cd 
tmux new -s MetaPhlAn4
tmux attach -t MetaPhlAn4

## Read-based (HUMAnN3+MetaPhlAn4 && Kraken2+Bracken)
## using MetaPhlAn v4 please use the database vJun23
wget http://cmprod1.cibio.unitn.it/biobakery4/metaphlan_databases/mpa_vJun23_CHOCOPhlAnSGB_202403.tar  # 3.1G
wget -c http://cmprod1.cibio.unitn.it/biobakery4/metaphlan_databases/bowtie2_indexes/mpa_vJun23_CHOCOPhlAnSGB_202403_bt2.tar #21G

tar xvf mpa_vJun23_CHOCOPhlAnSGB_202403.tar
tar xvf mpa_vJun23_CHOCOPhlAnSGB_202403_bt2.tar

### step 1：

tmux attach -t kraken_job

for i in `tail -n+2 result/metadata.txt|cut -f1`;do 
      cat temp/hr/${i}_paired_?.fastq \
      > temp/concat/${i}.fq; done


###  Controlling Standard Sample Alignment Time
  ## To optimize performance, one can use head to extract a subset of 20 million reads 
    for i in `tail -n+2 result/metadata.txt|cut -f1`;do 
       head -n80000000 temp/hr/${i}_paired_1.fastq  > temp/concat/${i}.fq
    done

# step 2：HUMAnN
Input: temp/concat/*.fq 
*   Output: temp/humann3/ 
    *   C1_pathabundance.tsv
    *   C1_pathcoverage.tsv
    *   C1_genefamilies.tsv
*   Final Output Files:
    •   result/metaphlan4/taxonomy.tsv
    •   result/metaphlan4/taxonomy.spf (for STAMP analysis)
    •   result/humann3/pathabundance_relab_unstratified.tsv
    •   result/humann3/pathabundance_relab_stratified.tsv
### The stratified file shows the contribution of each species to each functional pathway, while the unstratified file represents the overall functional composition regardless of taxonomic origin.


conda activate humann3
mkdir -p temp/humann3
humann --version # v3.9
humann_config

  tail -n+2 result/metadata.txt | cut -f1 | /home/Database/liuye/db/EasyMicrobiome/linux/rush -j 2 \
      "humann --input temp/concat/{1}.fq  \
      --output temp/humann3/ --threads 32 --metaphlan-options '--bowtie2db /home/Database/liuye/db/metaphlan4 --index mpa_vJun23_CHOCOPhlAnSGB_202403 --offline'" 

# move important result files
    for i in $(tail -n+2 result/metadata.txt | cut -f1); do  
       mv temp/humann3/${i}_humann_temp/${i}_metaphlan_bugs_list.tsv temp/humann3/
    done
# delete temp files
    rm -rf temp/concat/* temp/humann3/*_humann_temp


### step 3：Taxonomic Composition Table
mkdir -p result/metaphlan4

# Merge results, fix sample names, and preview
merge_metaphlan_tables.py temp/humann3/*_metaphlan_bugs_list.tsv | \
  sed 's/_metaphlan_bugs_list//g' | tail -n+2 | sed '1 s/clade_name/ID/' | sed '2i #metaphlan4' \
  > result/metaphlan4/taxonomy.tsv

csvtk -t stat result/metaphlan4/taxonomy.tsv
head -n5 result/metaphlan4/taxonomy.tsv

##Convert to STAMP’s .spf Format
# MetaPhlAn4 includes more unclassified and duplicate entries compared to v2.
# Use sort and uniq to remove duplicates.
metaphlan_to_stamp.pl result/metaphlan4/taxonomy.tsv \
  | sort -r | uniq > result/metaphlan4/taxonomy.spf

head result/metaphlan4/taxonomy.spf

# STAMP does not support "unclassified" entries, so they need to be filtered out before use.
grep -v 'unclassified' result/metaphlan4/taxonomy.spf > result/metaphlan4/taxonomy2.spf
head result/metaphlan4/taxonomy2.spf

# Download both metadata.txt and taxonomy2.spf for STAMP analysis






