
# Metagenome Pipeline

    # Version: 1.22, 2025/6/24
    # Operation System: Ubuntu 20.04.6 LTS (GNU/Linux 5.4.0-196-generic x86_64)
#uploaded data

1. Step 1: Data preprocessing
  # Environment variable settings
  conda env list
  soft=~/miniconda3
  db=~/db
  wd=~/meta  ## set work directory(wd)

mkdir -p $wd && cd $wd
mkdir -p seq temp result  

###  To ensure the analysis environment is correctly initialized, the required software paths and scripts are added to the environment variables and sourced via the ~/.bashrc file.
PATH=$soft/bin:$soft/condabin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$db/EasyMicrobiome/linux:$db/EasyMicrobiome/script
echo $PATH

pwd
### /home/Database/liuye/Data/HC/HC_119
# rename file name
for d in */; do mv "$d" "${d:0:5}"; done
# move to new directory: /home/Database/liuye/meta/seq/
find /home/Database/liuye/Data/HC/HC_119/HC*/ -type f -name "*.fq.gz" -exec mv {} /home/Database/liuye/meta/seq/ \;
#rename to HC*_1.clean.fq.gz
for f in *.clean.fq.gz; do
  prefix=$(echo "$f" | cut -c1-5)
  suffix=$(echo "$f" | grep -oE '_[12]\.clean\.fq\.gz$')
  mv "$f" "${prefix}${suffix}"
done
#Disease data
###  pwd: /home/Database/liuye/Data/SLE_first_treat/Clean_data
# rename file name
## echo
for d in SLE*; do
  newname=$(echo "$d" | grep -oE '^SLE[-A-Z]*[0-9]{3,4}')
  echo mv "$d" "$newname"
done
#run
for d in SLE*; do
  newname=$(echo "$d" | grep -oE '^SLE[-A-Z]*[0-9]{3,4}')
  mv "$d" "$newname"
done
# rename file name to *_1.clean.fq.gz
cd /home/Database/liuye/Data/SLE_first_treat/Clean_data
for dir in */; do
  cd "$dir" || continue
  prefix=$(basename "$dir")
  for f in *_*.clean.fq.gz; do
    suffix=$(echo "$f" | grep -oE '_[12]\.clean\.fq\.gz$')
    mv "$f" "$prefix$suffix"
  done
  cd ..
done

find /home/Database/liuye/Data/SLE_first_treat/Clean_data/SLE*/ -type f -name "*.fq.gz" -exec mv {} /home/Database/liuye/meta/seq/ \;
find /home/Database/liuye/Data/SLE_first_treat/Clean_data/XY*/ -type f -name "*.fq.gz" -exec mv {} /home/Database/liuye/meta/seq/ \;
# rename file name
for f in *.clean.fq.gz; do
  newname=$(echo "$f" | sed 's/-//g')
  mv "$f" "$newname"
done
# check number
find /home/Database/liuye/meta/seq/*fq.gz | wc -l
# n = 239 HC:119 Dis:120
 ls -lsh seq/*.fq.gz # check size

#temp
awk '$1 != "HC092"' metadata.txt > metadata_filtered.txt