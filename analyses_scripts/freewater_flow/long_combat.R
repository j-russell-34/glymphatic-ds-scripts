library(dplyr)
library(glue)
library(longCombat)
library(readr)
library(stringr)
library(tidyr)

#set dirs
inputs <- "/Users/jasonkru/Documents/inputs/ABCDS/csvs"
outputs <- "/Users/jasonkru/Documents/outputs/ABCDS/fw"
harmonized_dir <- "/Users/jasonkru/Documents/outputs/ABCDS/fw/harmonized"

#import the site_scanner_filtered.csv file
site_scanner_filtered <- read_csv(paste0(inputs, "/dti_scan_site_type_filtered.csv"))

#select fsid and scan_type_site from site_scanner_filtered
site_scanner_filtered <- site_scanner_filtered %>%
  dplyr::select(fsid, scan_type_site, group)

#make group a factor
site_scanner_filtered$group <- as.factor(site_scanner_filtered$group)

#import the fw data file
fw_cp_data <- read_csv(paste0(outputs, "/concatenated_choroid_plexus_FW.csv"))
fw_wm_data <- read_csv(paste0(outputs, "/concatenated_wm_FW.csv"))

#import qc data
dti_qc <- read_csv(paste0(outputs, "/tractoflow_qc.csv"))

#make fsid from subject in dti_qc be extracting #####_e#
dti_qc <- dti_qc %>%
  mutate(fsid = str_extract(Subject, "\\d+_e\\d+"))

#select fsid and status columns from dti_qc
dti_qc <- dti_qc %>%
  dplyr::select(fsid, Status)

#filter dti_qc to remove those where status is fail
dti_qc <- dti_qc %>%
  filter(Status != "Fail")

#inner join dti_qc and fw_cp_data on fsid
fw_cp_data <- inner_join(fw_cp_data, dti_qc, by = "fsid")

#inner join fw_cp_data and fw_wm_data on fsid
fw_data <- inner_join(fw_cp_data, fw_wm_data, by = "fsid")

#import the age and time vars
demographics_df <- read_csv(paste0(inputs, "/demographics_all.csv"))
age_df <- read_csv(paste0(inputs, "/age_at_event_all.csv"))

#make fsid column in demographics_df
demographics_df$fsid <- paste(demographics_df$subject_label, demographics_df$event_sequence, sep = "_e")

#fill gender updown on subject_label
demographics_df <- demographics_df %>%
  group_by(subject_label) %>%
  fill(de_gender, .direction = "downup") %>%
  ungroup()

#make fsid column in age_df
age_df$fsid <- paste(age_df$subject_label, age_df$event_sequence, sep = "_e")

#select fsid, de_gender from demographics_df
demographics_df <- demographics_df %>%
  dplyr::select(fsid, de_gender)

#select fsid, age_at_visit, mri_latency_in_days from age_df
age_df <- age_df %>%
  dplyr::select(fsid, age_at_visit, mri_latency_in_days)

#inner join demographics_df and age_df on fsid
demographics_df <- inner_join(demographics_df, age_df, by = "fsid")

#inner join site_scanner_filtered and demographics_df on site_id
site_scanner_filtered <- inner_join(site_scanner_filtered, demographics_df, by = "fsid")

#if mri_latency_in_days is NA and fsid is *_e1 set mri_latency_in_days to 0
site_scanner_filtered$mri_latency_in_days[is.na(site_scanner_filtered$mri_latency_in_days) & grepl("_e1", site_scanner_filtered$fsid)] <- 0

#convert mri_latency_in_days to years
site_scanner_filtered$mri_latency_in_days <- site_scanner_filtered$mri_latency_in_days / 365

#rename mri_latency to mri_latency_in_days
site_scanner_filtered <- site_scanner_filtered %>%
  rename(mri_latency = mri_latency_in_days)


#from fw_data summary select fsid, fw measures
fw_data <- fw_data %>%
  dplyr::select(fsid, wm_FW, choroid_plexus_FW)

#inner join fw_data and site_scanner_filtered on fsid
fw_data <- inner_join(fw_data, site_scanner_filtered, by = "fsid")

#remove any rows where scan_type_site count is less than 15
fw_data <- fw_data %>%
  group_by(scan_type_site) %>%
  filter(n() >= 15) %>%
  ungroup()

#remove rows with NA in any column
fw_data <- fw_data %>%
  drop_na()

#split fsid into subject and event_sequence
fw_data <- fw_data %>%
  mutate(subject = str_extract(fsid, "\\d+"),
         event_sequence = str_extract(fsid, "e\\d+")) %>%
  dplyr::select(-fsid)

#need to add group to formula once controls processed
combat_fw <-longCombat(idvar='subject',
                         timevar='mri_latency',
                         batchvar='scan_type_site',
                         features=c('wm_FW', 'choroid_plexus_FW'),
                         formula='de_gender + group + age_at_visit * mri_latency',
                         ranef='(1|subject)',
                         data=fw_data)

fw_harmonized <- combat_fw$data_combat

featurenames.combat <- names(fw_harmonized)[4:5]

fw_summary <- merge(fw_data, fw_harmonized[,c(1,2,3,4,5)], by=c('subject', 'mri_latency'))

#save the fw_summary dataframe to a csv file
write_csv(fw_summary, paste0(harmonized_dir, "/fw_summary_harmonized.csv"))
