conda activate equineSNP
cd ~/MAF

## simplify each condition phenotype file
# Directory to save cleaned files
cleaned_dir="phenotypes_clean"
mkdir -p $cleaned_dir

# Iterate over each CSV file matching the pattern
for file in phenotypes/conditions_*.csv; do
  read -p "Do you want to process $file? (yes/no) " choice
  case "$choice" in
    yes|y )
      echo "Processing $file..."
      # Call the Python script and pass the file path as an argument
      python3 dataView/process_file.py "$file"
      ;;
    no|n )
      echo "Skipping $file."
      ;;
    * )
      echo "Invalid response. Skipping $file."
      ;;
  esac
done
 
## Output files are in 'phenotypes_clean'
## These files fail or useless and should be removed from the new 
## conditions_dictionary.csv
## conditions_other.csv
## conditions_summary.csv

## merge all new files into one file using  the  'subject_id' column 
python3 dataView/merge_files.py ## output: phenotypes_clean/merged_data.csv

## update IDs
awk 'BEGIN{FS=OFS=","}NR==FNR{a[$3]=$4;next}FNR==1{print;next}{if(a[$1]){$1=a[$1];print}}' <(cat map_id_sex.tab | tr '\t' ',') phenotypes_clean/merged_data.csv > phenotypes_clean/merged_data_pubIDs.csv

## Print the sum of each condition (column) & sample (row)
python3 dataView/sum_conditions_samples.py "phenotypes_clean/merged_data_pubIDs.csv" "phenotypes_clean/column_sums.txt" "phenotypes_clean/row_sums.txt"

## edit the output file 'column_sums.txt' to remove less important phenotypes 
cat phenotypes_clean/column_sums.txt | sort -t":" -k2,2nr > phenotypes_clean/column_selected.txt

## Subset the merged dataset to include the selected conditions only
python3 dataView/subset_merged_data.py "phenotypes_clean/merged_data_pubIDs.csv"  "phenotypes_clean/column_selected.txt" "phenotypes_clean/subset_merged_data_pubIDs.csv"

## Print the sum of each condition (column) & sample (row) of the new subset
python3 dataView/sum_conditions_samples.py "phenotypes_clean/subset_merged_data_pubIDs.csv" "phenotypes_clean/subset_column_sums.txt" "phenotypes_clean/subset_row_sums.txt"

## how many samples with more than one phenotype
cat phenotypes_clean/row_sums.txt | awk '{if($2>0)print}' | wc -l  ## 2820
cat phenotypes_clean/subset_row_sums.txt | awk '{if($2>0)print}' | wc -l ## 2811



##########
## Identify samples with tumors
tail -n+2 phenotypes/study_endpoints.csv | cut -d"," -f5,8 | sort | uniq -c | less

grep -i 'ameloblastoma\|carcinoma\|sarcoma\|adenoma\|tumor\|melanoma\|Fibroma\|Lymphoma\|Malignant\|epithelioma\|Meningioma\|myeloma\|Nephroblastoma\|Thymoma\|neoplasia' phenotypes/study_endpoints.csv | cut -d"," -f1 | sort | uniq > phenotypes_clean/study_endpoints_tumor.ids ## 798

python3 dataView/sum_conditions_samples.py "phenotypes_clean/conditions_neoplasia.csv" "phenotypes_clean/neoplasia_column_sums.txt" "phenotypes_clean/neoplasia_row_sums.txt"
cat phenotypes_clean/neoplasia_row_sums.txt | sed 's/://' | awk '{if($2>0)print $1}' | sort > phenotypes_clean/reported_tumor.ids ## 402
comm -12 phenotypes_clean/reported_tumor.ids phenotypes_clean/study_endpoints_tumor.ids | wc -l ## 310
 
## identify old samples
awk 'BEGIN{FS=","}{if ($2==10 && $4==0 && $5!="")print $1}'  phenotypes/conditions_summary.csv  > phenotypes_clean/sampleWith10YearsInfo.ids

cat phenotypes_clean/{study_endpoints_tumor.ids,reported_tumor.ids} | sort | uniq | grep -vFwf - phenotypes_clean/sampleWith10YearsInfo.ids > phenotypes_clean/sampleWith10YearsInfo_noTumors.ids
awk 'BEGIN{FS=OFS=","}NR==FNR{a[$3]=$4;next}{if(a[$1]){$1=a[$1];print}}' <(cat map_id_sex.tab | tr '\t' ',') phenotypes_clean/sampleWith10YearsInfo_noTumors.ids > phenotypes_clean/sampleWith10YearsInfo_noTumors.pubIDs

relateds=$HOME/MAF_newTut_king
awk 'BEGIN{FS=OFS="\t"}NR==FNR{a[$1]=1;next}{if($1 in a && $2 in a)print}' phenotypes_clean/sampleWith10YearsInfo_noTumors.pubIDs $relateds/Related_cluster_closeRel_short.tab >  phenotypes_clean/sampleWith10YearsInfo_noTumors_pubIDs_closeRel.tab
python $relateds/connected_components.py phenotypes_clean/sampleWith10YearsInfo_noTumors_pubIDs_closeRel.tab > phenotypes_clean/sampleWith10YearsInfo_noTumors_pubIDs_closeRel_conn.txt

##########
## QC the hemangiosarcoma samples

## 1. confirm that 094-000525 has no genotyping data
grep -i grlsIJPE4Z33 phenotypes_clean/merged_data_pubIDs.csv

## 2. QC control samples
## 2A) do any of control samples have tumors?
tail -n+2 ~/MAF_newTut/gwas_hemangiosarcoma/controlsForSeq.csv | cut -d"," -f3 | grep -Fwf - phenotypes_clean/reported_tumor.ids
#094-000081
#094-002792
paste <(head -n1 phenotypes_clean/conditions_neoplasia.csv | tr ',' '\n') <(grep "094-000081" phenotypes_clean/conditions_neoplasia.csv | tr ',' '\n')
#094-000081 hair_matrix_tumor
paste <(head -n1 phenotypes_clean/conditions_neoplasia.csv | tr ',' '\n') <(grep "094-002792" phenotypes_clean/conditions_neoplasia.csv | tr ',' '\n')
#094-002792 soft_tissue_sarcoma

tail -n+2 ~/MAF_newTut/gwas_hemangiosarcoma/controlsForSeq.csv | cut -d"," -f3 | grep -Fwf - phenotypes_clean/study_endpoints_tumor.ids

## 2B) Are control samples old enough?
tail -n+2 ~/MAF_newTut/gwas_hemangiosarcoma/controlsForSeq.csv | cut -d"," -f3 | grep -Fwf - phenotypes/conditions_summary.csv | less
094-000472,9,DOG,0,1,0,0,0,0,1,0,0,0,1,0,0,0,0,0,0
094-000487,4,DOG,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
094-000525,9,DOG,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
094-000573,8,DOG,0,1,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0
094-002792,7,DOG,0,1,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0
094-011061,9,DOG,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0


## 3. QC cases
## A) are they really cases?
cat phenotypes_clean/study_endpoints_tumor.ids | grep -vFwf - ~/MAF_newTut/gwas_hemangiosarcoma/casesForSeq.csv
#9,grlsPA3037CC,094-025292
#12,grls3S4N0Q33,094-016409
#13,grls6J8CR300,094-032589
#14,grlsVCOWTN99,094-031751
#16,grlsPMRYSYY,094-003439
#24,grls1XT2PQ77,094-006087
#36,grlsFK1K1D00,094-030989
#38,grlsX1Q3RTUU,094-020678

## B) do they have other tumors in condition_neoplasia?
cat phenotypes_clean/study_endpoints_tumor.ids | grep -vFwf - ~/MAF_newTut/gwas_hemangiosarcoma/casesForSeq.csv | cut -d"," -f3 | grep -Fwf - phenotypes_clean/reported_tumor.ids
#094-025292
#094-032589
paste <(head -n1 phenotypes_clean/conditions_neoplasia.csv | tr ',' '\n') <(grep "094-025292" phenotypes_clean/conditions_neoplasia.csv | tr ',' '\n')
#094-025292
#neoplasia_histiocytic_sarcoma   1.0
#neoplasia_liver_tumor   1.0
paste <(head -n1 phenotypes_clean/conditions_neoplasia.csv | tr ',' '\n') <(grep "094-032589" phenotypes_clean/conditions_neoplasia.csv | tr ',' '\n')
#094-032589
#neoplasia_eye_tumor

## C) look into study_endpoints for other tumors
cat ~/MAF_newTut/gwas_hemangiosarcoma/casesForSeq.csv | cut -d"," -f3 | grep -Fwf -  phenotypes/study_endpoints.csv | sort

## D) look into study_endpoints for subtypes
cat ~/MAF_newTut/gwas_hemangiosarcoma/casesForSeq.csv | cut -d"," -f3 | grep -Fwf -  phenotypes/study_endpoints.csv | grep Hemangiosarcoma | cut -d"," -f1,5 | sort | uniq | cut -d"," -f2 | sort | uniq -c

## 4. relatedness?
relateds=$HOME/MAF_newTut_king
gwas=$HOME/MAF_newTut/gwas_hemangiosarcoma
awk 'BEGIN{FS=OFS="\t"}NR==FNR{a[$2]=1;next}{if($1 in a && $2 in a)print}' <(cat  $gwas/controlsForSeq.csv | tr ',' '\t') $relateds/Related_cluster_closeRel_short.tab >  $gwas/controlsForSeq_closeRel.tab
#python $relateds/connected_components.py $gwas/controlsForSeq_closeRel.tab > $gwas/controlsForSeq_closeRel_conn.txt
awk 'BEGIN{FS=OFS="\t"}NR==FNR{a[$2]=1;next}{if($1 in a && $2 in a)print}' <(cat  $gwas/casesForSeq.csv | tr ',' '\t') $relateds/Related_cluster_closeRel_short.tab >  $gwas/casesForSeq_closeRel.tab
python $relateds/connected_components.py $gwas/casesForSeq_closeRel.tab > $gwas/casesForSeq_closeRel_conn.txt
awk 'BEGIN{FS=OFS="\t"}NR==FNR{a[$2]=$3;next}{print a[$1],a[$2],$3}' <(cat $gwas/casesForSeq.csv | tr ',' '\t') $gwas/casesForSeq_closeRel.tab > $gwas/casesForSeq_closeRel_genoIDs.tab
