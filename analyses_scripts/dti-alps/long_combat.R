library(dplyr)
library(glue)
library(longCombat)

#set dirs
inputs <- "/Users/jasonkru/Documents/inputs/ABCDS/csvs"
outputs <- "/Users/jasonkru/Documents/outputs/ABCDS/alps"
harmonized_dir <- "/Users/jasonkru/Documents/outputs/ABCDS/alps/harmonized"

#import the site_scanner_filtered.csv file
site_scanner_filtered <- read_csv(paste0(inputs, "/dti_scan_site_type_filtered.csv"))

#select fsid and scan_type_site from site_scanner_filtered
site_scanner_filtered <- site_scanner_filtered %>%
  dplyr::select(fsid, scan_type_site, group)

#make group a factor
site_scanner_filtered$group <- as.factor(site_scanner_filtered$group)

#import the alps_summary.csv file
alps_summary <- read_csv(paste0(outputs, "/alps_summary.csv"))

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

#make fsid column in alps_summary
alps_summary$fsid <- paste(alps_summary$subject, alps_summary$event, sep = "_e")

#from alps summary select fsid, alps
alps_summary <- alps_summary %>%
  dplyr::select(fsid, subject, alps_L, alps_R)

#inner join alps_summary and site_scanner_filtered on fsid
alps_summary <- inner_join(alps_summary, site_scanner_filtered, by = "fsid")

combat_alps <-longCombat(idvar='subject',
                         timevar='mri_latency',
                         batchvar='scan_type_site',
                         features=c('alps_L', 'alps_R'),
                         formula='de_gender + group + age_at_visit * mri_latency',
                         ranef='(1|subject)',
                         data=alps_summary)

alps_harmonized <- combat_alps$data_combat

featurenames.combat <- names(alps_harmonized)[4:5]

alps_summary <- merge(alps_summary, alps_harmonized[,c(1,2,3,4,5)], by=c('subject', 'mri_latency'))

#average the left and right alps
alps_summary$alps_harmonized <- (alps_summary$alps_L.combat + alps_summary$alps_R.combat) / 2

#save the alps_summary dataframe to a csv file
write_csv(alps_summary, paste0(harmonized_dir, "/alps_summary_harmonized.csv"))
