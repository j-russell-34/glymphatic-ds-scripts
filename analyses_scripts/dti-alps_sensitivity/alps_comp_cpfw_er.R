library(tidyverse)
library(dplyr)
library(glue)
library(ggpattern)
library(ggtext)
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

#make output directories if they don't exist
if (!dir.exists(glue("{out_dir}/alps_sens"))) {
  dir.create(glue("{out_dir}/alps_sens"), recursive = TRUE)
}

#Set imports ---------------------------------------------------------------
#load the alps summary csv
alps_df <- read_csv(glue("{in_dir}/alps/harmonized/alps_summary_harmonized.csv"))

#import list of b1000 only scans
b1000_only_scans <- read_csv(glue("{in_dir}/alps/b1000_subs.csv"))

#inner join alps_df and b1000_only_scans by fsid to only keep b1000 only scans
alps_df <- inner_join(alps_df, b1000_only_scans, by = "fsid")

#split scan_type_site.x column into scan_type and site
alps_df <- alps_df %>%
  separate(scan_type_site.x, into = c("scan_type", "site"), sep = "_", extra = "merge")

#rename alps_harmonized to alps
colnames(alps_df)[colnames(alps_df) == "alps_harmonized"] <- "alps"

#make group and de_gender factors
alps_df$group <- as.factor(alps_df$group)
alps_df$de_gender <- as.factor(alps_df$de_gender)

#separate fsid on _e to get event
alps_df$event <- str_split_fixed(alps_df$fsid, "_e", 2)[,2]

#import fw data
fw_data <- read_csv("/Users/jasonkru/Documents/outputs/ABCDS/fw/harmonized/fw_eroded_summary_harmonized.csv")

#make fsid column in fw_data
fw_data <- fw_data %>%
  mutate(fsid = paste0(subject, "_", event_sequence))

#from fw_data, drop irrelevant columns
fw_data <- fw_data %>%
  dplyr::select(fsid, choroid_plexus_FW.combat)

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


#select only group 1 (DS) for analyses
group_1_df <- alps_df %>%
  filter(group == 1)

#relationship between alps and and cp-fw
alps_cpfw_model <- lme(
  fixed  = choroid_plexus_FW.combat ~ alps + age_at_visit + de_gender + site,
  random = ~ 1 | subject,
  data   = group_1_df,
  method = "REML"
)
summary(alps_cpfw_model)