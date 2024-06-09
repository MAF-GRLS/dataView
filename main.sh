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

grep -i 'ameloblastoma\|carcinoma\|sarcoma\|adenoma\|tumor\|melanoma\|Fibroma\|Lymphoma\|Malignant\|epithelioma\|Meningioma\|myeloma\|Nephroblastoma\|Thymoma\|neoplasia\|neoplasm\|malignancy\|Leukemia' phenotypes/study_endpoints.csv | cut -d"," -f1 | sort | uniq > phenotypes_clean/study_endpoints_tumor.ids ## 811

python3 dataView/sum_conditions_samples.py "phenotypes_clean/conditions_neoplasia.csv" "phenotypes_clean/neoplasia_column_sums.txt" "phenotypes_clean/neoplasia_row_sums.txt"
cat phenotypes_clean/neoplasia_row_sums.txt | sed 's/://' | awk '{if($2>0)print $1}' | sort > phenotypes_clean/reported_tumor.ids ## 402
comm -12 phenotypes_clean/reported_tumor.ids phenotypes_clean/study_endpoints_tumor.ids | wc -l ## 310
 
## identify old samples
awk 'BEGIN{FS=","}{if ($2==10 && $4==0 && $5!="")print $1}'  phenotypes/conditions_summary.csv  > phenotypes_clean/sampleWith10YearsInfo.ids

cat phenotypes_clean/{study_endpoints_tumor.ids,reported_tumor.ids} | sort | uniq | grep -vFwf - phenotypes_clean/sampleWith10YearsInfo.ids > phenotypes_clean/sampleWith10YearsInfo_noTumors.ids ## 88
awk 'BEGIN{FS=OFS=","}NR==FNR{a[$3]=$4;next}{if(a[$1]){$1=a[$1];print}}' <(cat map_id_sex.tab | tr '\t' ',') phenotypes_clean/sampleWith10YearsInfo_noTumors.ids > phenotypes_clean/sampleWith10YearsInfo_noTumors.pubIDs

relateds=$HOME/MAF_newTut_king
awk 'BEGIN{FS=OFS="\t"}NR==FNR{a[$1]=1;next}{if($1 in a && $2 in a)print}' phenotypes_clean/sampleWith10YearsInfo_noTumors.pubIDs $relateds/Related_cluster_closeRel_short.tab >  phenotypes_clean/sampleWith10YearsInfo_noTumors_pubIDs_closeRel.tab
python $relateds/connected_components.py phenotypes_clean/sampleWith10YearsInfo_noTumors_pubIDs_closeRel.tab > phenotypes_clean/sampleWith10YearsInfo_noTumors_pubIDs_closeRel_conn.txt
###########
## Working with the updated version of phenotypes
rclone sync remote_UCDavis_GoogleDr:/MAF/source_files/updated_phenotypes/ updated_phenotypes/
tail -n+2 updated_phenotypes/cancer_details_updated_20240516.csv  | cut -d"," -f8,13 | sort | uniq -c | less

grep -i 'ameloblastoma\|carcinoma\|sarcoma\|adenoma\|tumor\|melanoma\|Fibroma\|Lymphoma\|Malignant\|epithelioma\|Meningioma\|myeloma\|Nephroblastoma\|Thymoma\|neoplasia\|neoplasm\|malignancy\|Leukemia' updated_phenotypes/cancer_details_updated_20240516.csv | cut -d"," -f1 | sort | uniq | sed 's/\"//g' > phenotypes_clean/study_endpoints_tumor.ids.updated ## 1074

python3 dataView/sum_conditions_samples.py "phenotypes_clean/conditions_neoplasia.csv" "phenotypes_clean/neoplasia_column_sums.txt" "phenotypes_clean/neoplasia_row_sums.txt"
cat phenotypes_clean/neoplasia_row_sums.txt | sed 's/://' | awk '{if($2>0)print $1}' | sort > phenotypes_clean/reported_tumor.ids ## 402
comm -12 phenotypes_clean/reported_tumor.ids phenotypes_clean/study_endpoints_tumor.ids | wc -l ## 310

## identify old samples
awk 'BEGIN{FS=","}{if ($2==10 && $4==0 && $5!="")print $1}'  phenotypes/conditions_summary.csv  > phenotypes_clean/sampleWith10YearsInfo.ids

cat phenotypes_clean/{study_endpoints_tumor.ids.updated,reported_tumor.ids} | sort | uniq | grep -vFwf - phenotypes_clean/sampleWith10YearsInfo.ids > phenotypes_clean/sampleWith10YearsInfo_noTumors.ids.updated ## 71
awk 'BEGIN{FS=OFS=","}NR==FNR{a[$3]=$4;next}{if(a[$1]){$1=a[$1];print}}' <(cat map_id_sex.tab | tr '\t' ',') phenotypes_clean/sampleWith10YearsInfo_noTumors.ids.updated > phenotypes_clean/sampleWith10YearsInfo_noTumors.pubIDs.updated

relateds=$HOME/MAF_newTut_king
awk 'BEGIN{FS=OFS="\t"}NR==FNR{a[$1]=1;next}{if($1 in a && $2 in a)print}' phenotypes_clean/sampleWith10YearsInfo_noTumors.pubIDs.updated $relateds/Related_cluster_closeRel_short.tab >  phenotypes_clean/sampleWith10YearsInfo_noTumors_pubIDs_closeRel.tab.updated
python $relateds/connected_components.py phenotypes_clean/sampleWith10YearsInfo_noTumors_pubIDs_closeRel.tab.updated > phenotypes_clean/sampleWith10YearsInfo_noTumors_pubIDs_closeRel_conn.txt.updated


## what are the phenotypes in the long living samples
head -n1 phenotypes_clean/merged_data_pubIDs.csv > phenotypes_clean/merged_data_pubIDs_sampleWith10YearsInfo.csv
grep -Fwf phenotypes_clean/sampleWith10YearsInfo_noTumors.pubIDs.updated phenotypes_clean/merged_data_pubIDs.csv >> phenotypes_clean/merged_data_pubIDs_sampleWith10YearsInfo.csv
python3 dataView/sum_conditions_samples.py "phenotypes_clean/merged_data_pubIDs_sampleWith10YearsInfo.csv" "phenotypes_clean/10Years_column_sums.txt" "phenotypes_clean/10Years_row_sums.txt"
cat phenotypes_clean/10Years_column_sums.txt | awk '{if($2!="0.0")print}' | sort -k2,2nr | less


## Subset the merged dataset to include the selected conditions only
grep -i eye_pigmentary_uveitis phenotypes_clean/10Years_column_sums.txt > phenotypes_clean/column_10yPigUV.txt
python3 dataView/subset_merged_data.py "phenotypes_clean/merged_data_pubIDs_sampleWith10YearsInfo.csv"  "phenotypes_clean/column_10yPigUV.txt" "phenotypes_clean/10yPigUV_merged_data_pubIDs.csv"
cat phenotypes_clean/10yPigUV_merged_data_pubIDs.csv | awk -F',' '{if($2=="1.0")print $1}' ## grlsNVN2JEFF

grep -i eye_distichiasis phenotypes_clean/10Years_column_sums.txt > phenotypes_clean/column_10yDist.txt
python3 dataView/subset_merged_data.py "phenotypes_clean/merged_data_pubIDs_sampleWith10YearsInfo.csv"  "phenotypes_clean/column_10yDist.txt" "phenotypes_clean/10yDist_merged_data_pubIDs.csv"
cat phenotypes_clean/10yDist_merged_data_pubIDs.csv | awk -F',' '{if($2=="1.0")print $1}' ## grlsJS60YMLL

grep -i eye_cataracts phenotypes_clean/10Years_column_sums.txt > phenotypes_clean/column_10yCataract.txt
python3 dataView/subset_merged_data.py "phenotypes_clean/merged_data_pubIDs_sampleWith10YearsInfo.csv"  "phenotypes_clean/column_10yCataract.txt" "phenotypes_clean/10yCataract_merged_data_pubIDs.csv"
cat phenotypes_clean/10yCataract_merged_data_pubIDs.csv | awk -F',' '{if($2=="1.0")print $1}' | tr '\n' ','  ## grlsZ03WC1OO,grlsG2JULRR,grls8NWAH177,grlsBFIWWMNN,grlsVIJRLEII,grlsRBB2VHLL,



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

#tail -n+2 ~/MAF_newTut/gwas_hemangiosarcoma/controlsForSeq.csv | cut -d"," -f3 | grep -Fwf - phenotypes_clean/study_endpoints_tumor.ids
tail -n+2 ~/MAF_newTut/gwas_hemangiosarcoma/controlsForSeq.csv | cut -d"," -f3 | grep -Fwf - phenotypes_clean/study_endpoints_tumor.ids.updated


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
#cat phenotypes_clean/study_endpoints_tumor.ids | grep -vFwf - ~/MAF_newTut/gwas_hemangiosarcoma/casesForSeq.csv
cat phenotypes_clean/study_endpoints_tumor.ids.updated | grep -vFwf - ~/MAF_newTut/gwas_hemangiosarcoma/casesForSeq.csv


## B) do they have other tumors in condition_neoplasia?
#cat phenotypes_clean/study_endpoints_tumor.ids | grep -vFwf - ~/MAF_newTut/gwas_hemangiosarcoma/casesForSeq.csv | cut -d"," -f3 | grep -Fwf - phenotypes_clean/reported_tumor.ids
cat ~/MAF_newTut/gwas_hemangiosarcoma/casesForSeq.csv | cut -d"," -f3 | grep -Fwf - phenotypes_clean/conditions_neoplasia.csv | while read line;do 
paste <(head -n1 phenotypes_clean/conditions_neoplasia.csv | tr ',' '\n') <(echo "$line" | tr ',' '\n') | grep -v hemangiosarcoma | awk '{if($2!="0.0")print}'
done
subject_id      094-000320
neoplasia_eye_tumor     1.0
subject_id      094-006705
neoplasia_mast_cell_tumor       1.0
subject_id      094-016217
neoplasia_melanoma      1.0
subject_id      094-025292
neoplasia_histiocytic_sarcoma   1.0
neoplasia_liver_tumor   1.0
subject_id      094-025540
neoplasia_eye_tumor     1.0
subject_id      094-032589
neoplasia_eye_tumor     1.0

## C) look into study_endpoints for other tumors
#cat ~/MAF_newTut/gwas_hemangiosarcoma/casesForSeq.csv | cut -d"," -f3 | grep -Fwf -  phenotypes/study_endpoints.csv | sort
cat ~/MAF_newTut/gwas_hemangiosarcoma/casesForSeq.csv | cut -d"," -f3 | grep -Fwf -  updated_phenotypes/cancer_details_updated_20240516.csv  | sort

## D) look into study_endpoints for subtypes
#cat ~/MAF_newTut/gwas_hemangiosarcoma/casesForSeq.csv | cut -d"," -f3 | grep -Fwf -  phenotypes/study_endpoints.csv | grep Hemangiosarcoma | cut -d"," -f1,5 | sort | uniq | cut -d"," -f2 | sort | uniq -c
cat ~/MAF_newTut/gwas_hemangiosarcoma/casesForSeq.csv | cut -d"," -f3 | grep -Fwf -  updated_phenotypes/cancer_details_updated_20240516.csv | grep Hemangiosarcoma | cut -d"," -f1,8 | sort | uniq | cut -d"," -f2 | sort | uniq -c

## 4. relatedness?
relateds=$HOME/MAF_newTut_king
gwas=$HOME/MAF_newTut/gwas_hemangiosarcoma
awk 'BEGIN{FS=OFS="\t"}NR==FNR{a[$2]=1;next}{if($1 in a && $2 in a)print}' <(cat  $gwas/controlsForSeq.csv | tr ',' '\t') $relateds/Related_cluster_closeRel_short.tab >  $gwas/controlsForSeq_closeRel.tab
#python $relateds/connected_components.py $gwas/controlsForSeq_closeRel.tab > $gwas/controlsForSeq_closeRel_conn.txt
awk 'BEGIN{FS=OFS="\t"}NR==FNR{a[$2]=1;next}{if($1 in a && $2 in a)print}' <(cat  $gwas/casesForSeq.csv | tr ',' '\t') $relateds/Related_cluster_closeRel_short.tab >  $gwas/casesForSeq_closeRel.tab
python $relateds/connected_components.py $gwas/casesForSeq_closeRel.tab > $gwas/casesForSeq_closeRel_conn.txt
awk 'BEGIN{FS=OFS="\t"}NR==FNR{a[$2]=$3;next}{print a[$1],a[$2],$3}' <(cat $gwas/casesForSeq.csv | tr ',' '\t') $gwas/casesForSeq_closeRel.tab > $gwas/casesForSeq_closeRel_genoIDs.tab



#############################################################

