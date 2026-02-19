library(dplyr)
library(glue)
library(readr)
library(tidyr)
library(stringr)
library(longCombat)

#set dirs
inputs <- "/Users/jasonkru/Documents/inputs/ABCDS/csvs"
outputs <- "/Users/jasonkru/Documents/outputs/ABCDS/"
harmonized_dir <- "/Users/jasonkru/Documents/outputs/ABCDS/basal_ganglia_fbp"

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
fbp_df = read_csv(paste0(outputs, "concat_gtm_stats_fbp.csv"))
bg_suvr_df = read_csv(paste0(outputs, "fbp_basal_ganglia.csv"))



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

#change subject_id to fsid in fbp_df
fbp_df <- fbp_df %>%
  rename(fsid = subject_id)  

bg_suvr_df <- bg_suvr_df %>%
  rename(fsid = Subject_ID)  

#join bg_suvr_df to fbp_df on fsid
fbp_df <- inner_join(fbp_df, bg_suvr_df, by = "fsid")

#longCombat formulas choke on feature names that contain dashes, so make them syntactic
orig_feature_names <- setdiff(colnames(fbp_df), "fsid")
clean_feature_names <- make.names(orig_feature_names, unique = TRUE)
colnames(fbp_df)[match(orig_feature_names, colnames(fbp_df))] <- clean_feature_names
features <- clean_feature_names

#select fsid, gender and age from dems_df
dems_df <- dems_df %>%
  dplyr::select(fsid, de_gender, age_at_visit)

#merge fbp_df and dems_df on fsid
fbp_df <- left_join(fbp_df, dems_df, by="fsid")

#drop rows with NA in fbp _df
fbp_df <- fbp_df %>%
  drop_na()

#inner join site_scanner_filtered and fbp df on fsid
fbp_df <- inner_join(site_scanner_filtered, fbp_df, by = "fsid")

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


#inner join mri_latency_df and fbp_df on fsid
fbp_df <- inner_join(fbp_df, mri_latency_df, by = "fsid")

#make table and count instances of consortium_site_id
table(fbp_df$consortium_site_id)

#drop instances where consortium_site_id count is <10
fbp_df <- fbp_df %>%
  group_by(consortium_site_id) %>%
  filter(n() >= 5) %>%
  ungroup()
fbp_df <- fbp_df %>%
  group_by(consortium_site_id) %>%
  filter(n() >= 5) %>%
  ungroup()



combat_fbp <-longCombat(idvar='subject_label',
                         timevar='mri_latency',
                         batchvar='consortium_site_id',
                         features=c(features),
                         formula='de_gender + age_at_visit + mri_latency',
                         ranef='(1|subject_label)',
                         data=fbp_df)

fbp_harmonized <- combat_fbp$data_combat


#import consensus dx
consensus_dx <- read_csv(paste0(inputs, "/consensus.csv"))
consensus_dx$fsid <- paste(consensus_dx$subject_label, consensus_dx$event_sequence, sep = "_e")
consensus_dx <- consensus_dx %>%
  dplyr::select(event_sequence, subject_label, consensus_dx)

#convert event_sequence to character to match thickness_harmonized
consensus_dx$event_sequence <- as.character(consensus_dx$event_sequence)

#split fsid into event_sequence and subject_label
mri_latency_df <- mri_latency_df %>%
  separate(fsid, into = c("subject_label", "event_sequence"), sep = "_e")

#make subject label and event_sequence characters
mri_latency_df$subject_label <- as.character(mri_latency_df$subject_label)
mri_latency_df$event_sequence <- as.character(mri_latency_df$event_sequence)
consensus_dx$event_sequence <- as.character(consensus_dx$event_sequence)
consensus_dx$subject_label <- as.character(consensus_dx$subject_label)
fbp_harmonized$subject_label <- as.character(fbp_harmonized$subject_label)

#inner_join consensus_dx and mri_latency_df on event_sequence and subject_label
consensus_brief <- inner_join(consensus_dx, mri_latency_df, by = c("event_sequence", "subject_label"))


#inner join consensus_brief and fbp_harmonized on event_sequence and subject_label
fbp_harmonized_to_csv <- inner_join(consensus_brief, fbp_harmonized, by = c("mri_latency", "subject_label"))

#save fbp_harmonized
write_csv(fbp_harmonized_to_csv, paste0(harmonized_dir, "/fbp_bg_harmonized.csv"))
