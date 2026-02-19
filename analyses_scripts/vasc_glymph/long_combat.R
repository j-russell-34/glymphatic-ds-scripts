library(dplyr)
library(glue)
library(readr)
library(tidyr)
library(stringr)
library(longCombat)

#set dirs
inputs <- "/Users/jasonkru/Documents/inputs/ABCDS/csvs"
outputs <- "/Users/jasonkru/Documents/outputs/ABCDS/"
harmonized_dir <- "/Users/jasonkru/Documents/outputs/ABCDS/vascular"

#import the site_scanner_filtered.csv file
site_scanner_filtered <- read_csv(paste0(inputs, "/study_var.csv"))

#select fsid and scan_type_site from site_scanner_filtered
site_scanner_filtered <- site_scanner_filtered %>%
  dplyr::select(subject_label, event_sequence, consortium, site_id)

#make fsid column
site_scanner_filtered$fsid <- paste(site_scanner_filtered$subject_label, site_scanner_filtered$event_sequence, sep = "_e")

#make composite consortium and site_id
site_scanner_filtered$consortium_site_id <- paste(site_scanner_filtered$consortium, site_scanner_filtered$site_id, sep = "_")

#select fsid, consortium_site_id
site_scanner_filtered <- site_scanner_filtered %>%
  dplyr::select(fsid, consortium_site_id)


#import imaging data
wmh_df = read_csv(paste0(harmonized_dir, "/WMH_LOBAR.csv"))
#make fsid column in wmh_df
wmh_df$fsid <- paste(wmh_df$subject_label, wmh_df$event_sequence, sep = "_e")


#dataframes with biological vars and age at event
dems_df = read_csv(paste0(inputs, "/demographics.csv"))
age_df = read_csv(paste0(inputs, "/age_at_event.csv"))

#fill gender updown on subject_label
dems_df <- dems_df %>%
  group_by(subject_label) %>%
  fill(de_gender, .direction = "downup") %>%
  ungroup()

#make fsid column in age_df
age_df$fsid <- paste(age_df$subject_label, age_df$event_sequence, sep = "_e")

#make fsid column in dems_df
dems_df$fsid <- paste(dems_df$subject_label, dems_df$event_sequence, sep = "_e")

#select fsid, de_gender and age from dems_df
dems_df <- dems_df %>%
  dplyr::select(fsid, de_gender)

#select fsid, age_at_visit from age_df
age_df <- age_df %>%
  dplyr::select(fsid, age_at_visit)

#merge dems_df and age_df on fsid
dems_df <- left_join(dems_df, age_df, by="fsid")

#select fsid, gender and age from dems_df
dems_df <- dems_df %>%
  dplyr::select(fsid, de_gender, age_at_visit)

#merge fbp_df and dems_df on fsid
wmh_df <- left_join(wmh_df, dems_df, by="fsid")

#drop rows with NA in wmh_df
wmh_df <- wmh_df %>%
  drop_na()

#inner join site_scanner_filtered and wmh df on fsid
wmh_df <- inner_join(site_scanner_filtered, wmh_df, by = "fsid")
#import mri_latency data
mri_latency_df <- read_csv(paste0(inputs, "/age_at_event.csv"))

#make fsid column in mri_latency_df
mri_latency_df["fsid"] <- paste(mri_latency_df$subject_label, mri_latency_df$event_sequence, sep = "_e")

#select fsid, subject and mri_latency_in_days from mri_latency_df

mri_latency_df <- mri_latency_df %>%
  dplyr::select(fsid, mri_latency_in_days, subject_label)

#divide mri_latency_in_days by 365
mri_latency_df$mri_latency_in_days <- mri_latency_df$mri_latency_in_days / 365


#if mri_latency_in_days is NA and fsid is *_e1 set mri_latency_in_days to 0
mri_latency_df$mri_latency_in_days[is.na(mri_latency_df$mri_latency_in_days) & grepl("_e1", mri_latency_df$fsid)] <- 0


#rename mri_latency_in_days to mri_latency
mri_latency_df <- mri_latency_df %>%
  rename(mri_latency = mri_latency_in_days)


#inner join mri_latency_df and wmh_df on fsid
wmh_df <- inner_join(wmh_df, mri_latency_df, by = "fsid")

#make table and count instances of consortium_site_id
table(wmh_df$consortium_site_id)

#drop instances where consortium_site_id count is <10
wmh_df <- wmh_df %>%
  group_by(consortium_site_id) %>%
  filter(n() >= 5) %>%
  ungroup()

#remove NAs
wmh_df <- wmh_df %>%
  drop_na()

features <- c("Frontal_lobe", "Temporal_lobe", "Parietal_lobe", "Occipital_lobe")

combat_wmh <-longCombat(idvar='subject_label.x',
                         timevar='mri_latency',
                         batchvar='consortium_site_id',
                         features=c(features),
                         formula='de_gender + age_at_visit + mri_latency',
                         ranef='(1|subject_label.x)',
                         data=wmh_df)

wmh_harmonized <- combat_wmh$data_combat

#from original wmh_df select fsid and subject_label.x and mri_latency
wmh_original <- wmh_df %>%
  dplyr::select(fsid, subject_label.x, mri_latency)

#inner join wmh_harmonized and wmh_original on subject_label.x and mri_latency
wmh_harmonized_to_csv <- inner_join(wmh_harmonized, wmh_original, by = c("subject_label.x", "mri_latency"))

#rename subject_label.x to subject
wmh_harmonized_to_csv <- wmh_harmonized_to_csv %>%
  rename(subject = subject_label.x)

#calculated total_wmh_harmonized
wmh_harmonized_to_csv <- wmh_harmonized_to_csv %>%
  mutate(total_wmh_harmonized = Frontal_lobe.combat + Temporal_lobe.combat + Parietal_lobe.combat + Occipital_lobe.combat)

#save wmh_harmonized
write_csv(wmh_harmonized_to_csv, paste0(harmonized_dir, "/wmh_harmonized.csv"))