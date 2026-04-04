library(tidyverse)
library(dplyr)
library(glue)
library(lme4)
library(lmerTest)
library(segmented)
#library(MuMIn)
library(svglite)
library(nlme)
library(effects)

#study specific variables
STUDY <- "ABCDS"

#directories
in_dir <- glue("/Users/jasonkru/Documents/outputs/{STUDY}")
out_dir <- glue("/Users/jasonkru/Documents/outputs/{STUDY}")
csv_dir <- glue("/Users/jasonkru/Documents/inputs/{STUDY}/csvs")
harmonized_dir <- glue("/Users/jasonkru/Documents/outputs/{STUDY}/harmonized")

#Set imports ---------------------------------------------------------------
#load the alps summary csv
alps_df <- read_csv(glue("{in_dir}/alps/harmonized/alps_summary_harmonized.csv"))

#rename alps_harmonized to alps
colnames(alps_df)[colnames(alps_df) == "alps_harmonized"] <- "alps"

#split scan_type_site into scan_type and site
alps_df <- alps_df %>%
  separate(scan_type_site.x, into = c("scan_type", "site"), sep = "_", extra = "merge")

#load tau data
tau_df <- read_csv(glue("{harmonized_dir}/tau_harmonized.csv"))

#load the amyloid data
amyloid_df <- read_csv(glue("{harmonized_dir}/centiloid_harmonized.csv"))

#rename age_at_visit to age
colnames(alps_df)[colnames(alps_df) == "age_at_visit"] <- "age"

#rename de_gender to gender
colnames(alps_df)[colnames(alps_df) == "de_gender"] <- "sex"

#fill in missing values in de_gender demographics_df with matching values based on subject_label
alps_df <- alps_df %>%
  group_by(subject) %>%
  fill(sex, .direction = "downup") %>%
  ungroup()

#remove subjects where sex or age is missing
alps_df <- alps_df %>%
  filter(!is.na(sex) & !is.na(age))

#remove subjects where alps_L or alps_R is missing
alps_df <- alps_df %>%
  filter(!is.na(alps_L) & !is.na(alps_R))

#drop rows where group is 2
alps_df <- alps_df %>%
  filter(group != 2)
  

#import fw data
fw_data <- read_csv("/Users/jasonkru/Documents/outputs/ABCDS/fw/harmonized/fw_eroded_summary_harmonized.csv")

#make fsid column in fw_data
fw_data <- fw_data %>%
  mutate(fsid = paste0(subject, "_", event_sequence))

#from fw_data, drop irrelevant columns
fw_data <- fw_data %>%
  dplyr::select(-c("mri_latency", "wm_FW", "choroid_plexus_FW", "scan_type_site.y", "subject"))

#inner join alps_df and fw_data by fsid
alps_df <- inner_join(alps_df, fw_data, by = "fsid")

#drop participants with wmh in alps ROIs
#import wmh_overlap report
wmh_overlap <- read_csv(glue("{in_dir}/alps/alps_wmh_overlap_full_report.csv"))

#rename subject_id to fsid
colnames(wmh_overlap)[colnames(wmh_overlap) == "subject_id"] <- "fsid"

#filter wmh_overlap to only include rows where overlap > 0
wmh_overlap <- wmh_overlap %>%
  filter(voxel_overlap == 0)

#inner join alps_df and wmh_overlap by fsid to only keep participants with 0 overlap
alps_df <- inner_join(alps_df, wmh_overlap, by = "fsid")

#simple lmem comparing age and alps
alps_lmem <- lme(fixed = alps ~ age + sex + site, random = ~1|subject, data = alps_df, method = "REML")
summary(alps_lmem)



#merge alps_df and amyloid_df
alps_amyloid_df <- inner_join(alps_df, amyloid_df, by = "fsid")




#join tau data
alps_tau_df <- inner_join(alps_df, tau_df, by = "fsid")


#lmem comparing cp FW and amyloid
cp_amyloid_lmem <- lme(fixed = choroid_plexus_FW.combat ~ Centiloids + age + sex + site, random = ~1|subject, data = alps_amyloid_df, method = "REML")
summary(cp_amyloid_lmem)
intervals(cp_amyloid_lmem, which = "fixed")

#lmem comparing cp FW and tau
cp_tau_lmem <- lme(fixed = choroid_plexus_FW.combat ~ metatemporal + age.x + sex + site, random = ~1|subject, data = alps_tau_df, method = "REML")
summary(cp_tau_lmem)
intervals(cp_tau_lmem, which = "fixed")

