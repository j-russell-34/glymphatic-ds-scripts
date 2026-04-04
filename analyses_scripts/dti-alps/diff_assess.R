library(tidyverse)
library(dplyr)
library(glue)
#library(ggpattern)
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

#Set imports ---------------------------------------------------------------
#load the alps summary csv
alps_df <- read_csv(glue("{in_dir}/alps/harmonized/dz_summary_harmonized.csv"))

#split scan_type_site.x column into scan_type and site
alps_df <- alps_df %>%
  separate(scan_type_site.x, into = c("scan_type", "site"), sep = "_", extra = "merge")


#make group and de_gender factors
alps_df$group <- as.factor(alps_df$group)
alps_df$de_gender <- as.factor(alps_df$de_gender)

#separate fsid on _e to get event
alps_df$event <- str_split_fixed(alps_df$fsid, "_e", 2)[,2]

#import fw data
fw_data <- read_csv("/Users/jasonkru/Documents/outputs/ABCDS/fw/harmonized/fw_summary_harmonized.csv")

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

#import the control_match csv
control_match_df <- read_csv(glue("{csv_dir}/control_match.csv"))


#rename subject_label to subject and event_sequence to event
colnames(control_match_df)[colnames(control_match_df) == "subject_label"] <- "subject"
colnames(control_match_df)[colnames(control_match_df) == "event_sequence"] <- "event"

#make new dataframe filtering bashed on subject_label in control_match_df
alps_ds_w_sib_df <- alps_df[alps_df$subject %in% control_match_df$sibptid1, ]
#select fsid, alps, subject_label, event from alps_ds_w_sib_df
alps_ds_w_sib_filt_df <- alps_ds_w_sib_df %>%
  dplyr::select(fsid, subject, event)

#rename alps to alps_ds and fsid to fsid_ds
colnames(alps_ds_w_sib_filt_df)[colnames(alps_ds_w_sib_filt_df) == "alps"] <- "alps_ds"
colnames(alps_ds_w_sib_filt_df)[colnames(alps_ds_w_sib_filt_df) == "fsid"] <- "fsid_ds"

alps_control_df <- alps_df[alps_df$subject %in% control_match_df$subject, ]
#select fsid, alps, subject_label, event from alps_control_df
alps_control_filt_df <- alps_control_df %>%
  dplyr::select(fsid, subject, event)

#rename alps to alps_control and fsid to fsid_control
colnames(alps_control_filt_df)[colnames(alps_control_filt_df) == "fsid"] <- "fsid_control"
colnames(alps_control_filt_df)[colnames(alps_control_filt_df) == "alps"] <- "alps_control"

#from control_match_df, select sibptid1 and and subject_label
control_match_df <- control_match_df %>%
  dplyr::select(sibptid1, subject, event)

#make event character
control_match_df$event <- as.character(control_match_df$event)
alps_ds_w_sib_filt_df$event <- as.character(alps_ds_w_sib_filt_df$event)
alps_control_filt_df$event <- as.character(alps_control_filt_df$event)

#merge alps_control_filt_df and control_match_df on subject_label
alps_control_filt_df <- inner_join(alps_control_filt_df, control_match_df, by = c("subject", "event"))

#add a family column to alps_control_filt_df based on each unique subject label starting at 1
alps_control_filt_df <- alps_control_filt_df %>%
  mutate(family = as.numeric(as.factor(subject)))

#select fsid and family
ds_fam_df <- alps_control_filt_df %>%
  dplyr::select(sibptid1, event, family)

#select fsid and family
control_fam_df <- alps_control_filt_df %>%
  dplyr::select(subject, event, family)

#rename sibptid1 to subject
colnames(ds_fam_df)[colnames(ds_fam_df) == "sibptid1"] <- "subject"


#stack ds_fam_df and control_fam_df
fam_df <- rbind(ds_fam_df, control_fam_df)

#stack alps_ds_w_sib_df and fam_df
alps_ds_w_sib_df <- rbind(alps_ds_w_sib_df, alps_control_df)

#inner join alps_ds_w_sib_df and fam_df on subject and event
alps_ds_w_sib_df <- inner_join(alps_ds_w_sib_df, fam_df, by = c("subject", "event"))


#remove families with only one entry
remove_unique_family <- function(df, family_col = "family") {
  df %>%
    group_by(.data[[family_col]]) %>%
    filter(n() > 1) %>%
    ungroup()
}
#select min event for each family
alps_ds_w_sib_df_bl <- alps_ds_w_sib_df %>%
  group_by(family) %>%
  filter(event == min(event)) %>%
  ungroup()

#drop families with only one entry
alps_ds_w_sib_df_bl <- remove_unique_family(alps_ds_w_sib_df_bl)

#add family to alps_df
alps_df <- left_join(alps_df, fam_df, by = c("subject", "event"))

#fill in NA family values with unique numbers starting after the max family number
max_family <- max(alps_df$family, na.rm = TRUE)

# Create a mapping of subjects with NAs to new unique family IDs
na_subject_mapping <- alps_df %>%
  filter(is.na(family)) %>%
  distinct(subject) %>%
  mutate(new_family_id = row_number() + max_family)

# Apply the mapping to fill NAs
alps_df <- alps_df %>%
  left_join(na_subject_mapping, by = "subject") %>%
  mutate(family = ifelse(is.na(family), new_family_id, family)) %>%
  dplyr::select(-new_family_id)

#make family a factor
alps_df$family <- as.factor(alps_df$family)

#lmem to assess effect of group on dz's
dz_x_assoc_lmem <- lme(dz_x_assoc ~ group + age_at_visit + de_gender + site, random = ~1|family/subject, data = alps_df)
summary(dz_x_assoc_lmem)

#calc mean in each group
alps_df %>%
  group_by(group) %>%
  summarise(mean_dz_x_assoc = mean(dz_x_assoc, na.rm = TRUE))

dz_z_assoc_lmem <- lme(dz_z_assoc ~ group + age_at_visit + de_gender + site, random = ~1|family/subject, data = alps_df)
summary(dz_z_assoc_lmem)

#calc mean in each group
alps_df %>%
  group_by(group) %>%
  summarise(mean_dz_z_assoc = mean(dz_z_assoc, na.rm = TRUE))

dz_x_proj_lmem <- lme(dz_x_proj ~ group + age_at_visit + de_gender + site, random = ~1|family/subject, data = alps_df)
summary(dz_x_proj_lmem)

#calc mean in each group
alps_df %>%
  group_by(group) %>%
  summarise(mean_dz_x_proj = mean(dz_x_proj, na.rm = TRUE))

dz_y_proj_lmem <- lme(dz_y_proj ~ group + age_at_visit + de_gender + site, random = ~1|family/subject, data = alps_df)
summary(dz_y_proj_lmem)
 
#calc mean in each group
alps_df %>%
  group_by(group) %>%
  summarise(mean_dz_y_proj = mean(dz_y_proj, na.rm = TRUE))


#select BL timepoint for each participant in alps_df
alps_df_bl <- alps_df %>%
  group_by(subject) %>%
  filter(event == min(event)) %>%
  ungroup()

#run lmems on BL timepoint only
dz_x_assoc_lmem_bl <- lme(dz_x_assoc ~ group + age_at_visit + de_gender + site, random = ~1|family, data = alps_df_bl)
summary(dz_x_assoc_lmem_bl)

#mean in each group
alps_df_bl %>%
  group_by(group) %>%
  summarise(mean_dz_x_assoc = mean(dz_x_assoc, na.rm = TRUE))

dz_z_assoc_lmem_bl <- lme(dz_z_assoc ~ group + age_at_visit + de_gender + site, random = ~1|family, data = alps_df_bl)
summary(dz_z_assoc_lmem_bl)

#mean in each group
alps_df_bl %>%
    group_by(group) %>%
    summarise(mean_dz_z_assoc = mean(dz_z_assoc, na.rm = TRUE))

dz_x_proj_lmem_bl <- lme(dz_x_proj ~ group + age_at_visit + de_gender + site, random = ~1|family, data = alps_df_bl)
summary(dz_x_proj_lmem_bl)
#mean in each group
alps_df_bl %>%
  group_by(group) %>%
  summarise(mean_dz_x_proj = mean(dz_x_proj, na.rm = TRUE))

dz_y_proj_lmem_bl <- lme(dz_y_proj ~ group + age_at_visit + de_gender + site, random = ~1|family, data = alps_df_bl)
summary(dz_y_proj_lmem_bl)
#mean in each group
alps_df_bl %>%
  group_by(group) %>%
  summarise(mean_dz_y_proj = mean(dz_y_proj, na.rm = TRUE))


#select group 1 from alps_df and run age effects
alps_df_group1 <- alps_df[alps_df$group == 1, ]

dz_x_assoc_lmem_group1 <- lme(dz_x_assoc ~ age_at_visit + de_gender + site, random = ~1|subject, data = alps_df_group1)
summary(dz_x_assoc_lmem_group1)
dz_z_assoc_lmem_group1 <- lme(dz_z_assoc ~ age_at_visit + de_gender + site, random = ~1|subject, data = alps_df_group1)
summary(dz_z_assoc_lmem_group1)
dz_x_proj_lmem_group1 <- lme(dz_x_proj ~ age_at_visit + de_gender + site, random = ~1|subject, data = alps_df_group1)
summary(dz_x_proj_lmem_group1)
dz_y_proj_lmem_group1 <- lme(dz_y_proj ~ age_at_visit + de_gender + site, random = ~1|subject, data = alps_df_group1)
summary(dz_y_proj_lmem_group1)


