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
fw_data <- read_csv("/Users/jasonkru/Documents/outputs/ABCDS/fw/harmonized/fw_summary_harmonized.csv")

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

#lmem comparing age and alps and amyloid
#alps_amyloid_lmem <- lme(fixed = Centiloids ~ alps + age + sex + site, random = ~1|subject, data = alps_amyloid_df, method = "REML")
#summary(alps_amyloid_lmem)

#lmem comparing age and alps and amyloid
amyloid_alps_lmem <- lme(fixed = alps ~ Centiloids + age + sex + site, random = ~1|subject, data = alps_amyloid_df, method = "REML")
summary(amyloid_alps_lmem)
intervals(amyloid_alps_lmem, which = "fixed")



#join tau data
alps_tau_df <- inner_join(alps_df, tau_df, by = "fsid")
#lmem comparing age and alps and tau
alps_tau_lmem <- lme(fixed = alps ~ metatemporal + age.x + sex + site, random = ~1|subject, data = alps_tau_df, method = "REML")
summary(alps_tau_lmem)
intervals(alps_tau_lmem, which = "fixed")


#lmem comparing cp FW and amyloid
cp_amyloid_lmem <- lme(fixed = choroid_plexus_FW.combat ~ Centiloids + age + sex + site, random = ~1|subject, data = alps_amyloid_df, method = "REML")
summary(cp_amyloid_lmem)
intervals(cp_amyloid_lmem, which = "fixed")

#lmem comparing cp FW and tau
cp_tau_lmem <- lme(fixed = choroid_plexus_FW.combat ~ metatemporal + age.x + sex + site, random = ~1|subject, data = alps_tau_df, method = "REML")
summary(cp_tau_lmem)
intervals(cp_tau_lmem, which = "fixed")


#import mCRT cognitive data
mcrt_data <- read_csv("/Users/jasonkru/Documents/inputs/ABCDS/csvs/Cued_Recall_25Mar2026.csv")

#import dsmse data
dsmse_data <- read_csv("/Users/jasonkru/Documents/inputs/ABCDS/csvs/Down_Syndrome_Mental_Status_Exam.csv")

#import premorbid iq data
premorbid_data <- read_csv("/Users/jasonkru/Documents/inputs/ABCDS/csvs/Premorbid_Functioning_Level_25Mar2026.csv")

#make fsid column by pasting subject_label and event_sequence with _e in between
premorbid_data <- premorbid_data %>%
  mutate(fsid = paste(subject_label, event_sequence, sep = "_e"))

#fill prefunclevel missing values based on subject up and down
premorbid_data <- premorbid_data %>%
  group_by(subject_label) %>%
  fill(prefunclevel, .direction = "downup") %>%
  ungroup()

#select fsid and prefunclevel from premorbid_data
premorbid_data <- premorbid_data %>%
  dplyr::select(fsid, prefunclevel)

#drop rows with NA in prefunclevel
premorbid_data <- premorbid_data %>%
  drop_na(prefunclevel)

#make prefunclevel a factor
premorbid_data$prefunclevel <- as.factor(premorbid_data$prefunclevel)



#make fsid column by pasting subject_label and event_sequence with _e in between
dsmse_data <- dsmse_data %>%
  mutate(fsid = paste(subject_label, event_sequence, sep = "_e"))

#select fsid and total_score from dsmse
dsmse_data <- dsmse_data %>%
  dplyr::select(fsid, dsmse_to2)


#make fsid column by pasting subject and event_sequence with _e in between
mcrt_data <- mcrt_data %>%
  mutate(fsid = paste(subject_label, event_sequence, sep = "_e"))

#select fsid and trs from mCRT
mcrt_data <- mcrt_data %>%
  dplyr::select(fsid, trs)

#inner join mcrt_data to alps_df by fsid
alps_df_cog <- inner_join(alps_df, mcrt_data, by = c("fsid"))
#inner join dsmse_data to alps_df_cog by fsid
alps_df_cog <- inner_join(alps_df_cog, dsmse_data, by = c("fsid"))
#inner join premorbid_data to alps_df_cog by fsid
alps_df_cog <- inner_join(alps_df_cog, premorbid_data, by = c("fsid"))

#drop rows with NA in trs
alps_df_cog <- alps_df_cog %>%
  drop_na(trs)

#drop rows with NA in dsmse_to2
alps_df_cog <- alps_df_cog %>%
  drop_na(dsmse_to2)

#run linear mixed models for alps predicting trs adjusting for age, de_gender, site, group with random effect of subject
alps_mcrt_mod <- lme(
  fixed  = trs ~ choroid_plexus_FW.combat + age_at_visit + de_gender + site + prefunclevel,
  random = ~ 1 | subject,
  data   = alps_df_cog,
  method = "REML"
)
summary(alps_mcrt_mod)
intervals(alps_mcrt_mod, which = "fixed")

alps_dsmse_mod <- lme(
  fixed  = dsmse_to2 ~ choroid_plexus_FW.combat + age_at_visit + de_gender + site + prefunclevel,
  random = ~ 1 | subject,
  data   = alps_df_cog,
  method = "REML"
)
summary(alps_dsmse_mod)


#get demographics of main and subgroups
#import race data and apoe4 status
race_data <- read_csv("/Users/jasonkru/Documents/inputs/ABCDS/csvs/demographics_all.csv")
apoe4_data <- read_csv("/Users/jasonkru/Documents/inputs/ABCDS/csvs/ApoE_Genotyping_Results_all.csv")

#set dummy apoe_status column if allele_combo is E3/E4, E4/E3 then hereozygote etc
apoe4_data <- apoe4_data %>%
  mutate(apoe_status = case_when(
    allele_combo %in% c("E3/E4", "E4/E3", "E4/E2", "E2/E4") ~ "Heterozygote",
    allele_combo %in% c("E4/E4") ~ "Homozygote",
    allele_combo %in% c("E2/E2", "E2/E3", "E3/E2", "E3/3E", "E3/E3") ~ "Non-carrier",
    TRUE ~ "Unknown"
  ))

#select subject_label, apoe_status from apoe4_data
apoe4_data <- apoe4_data %>%
  dplyr::select(subject_label, apoe_status)

#outer_join with race_data on subject_label, inc many to many
race_data <- full_join(race_data, apoe4_data, by = "subject_label", relationship = "many-to-many")


#make fsid column by pasting subject_label and event_sequence with _e in between
race_data <- race_data %>%
  mutate(fsid = paste(subject_label, event_sequence, sep = "_e"))

#fill race updown based on subject_label 
race_data <- race_data %>%
  group_by(subject_label) %>%
  arrange(event_sequence) %>%
  fill(de_race, .direction = "updown") %>%
  ungroup()

#select fsid, de_race from race_data
race_data <- race_data %>%
  dplyr::select(fsid, de_race, apoe_status)

#left join with alps_amyloid_df, alps_tau_df and alps_cog_df  
alps_amyloid_df <- left_join(alps_amyloid_df, race_data, by = c("fsid"))
alps_tau_df <- left_join(alps_tau_df, race_data, by = c("fsid"))
alps_cog_df <- left_join(alps_df_cog, race_data, by = c("fsid"))

#remove 'e' from start of event_sequence in alps_amyloid_df, alps_tau_df and alps_cog_df and make numeric event column
alps_amyloid_df <- alps_amyloid_df %>%
  mutate(event = as.numeric(gsub("e", "", event_sequence)))

alps_tau_df <- alps_tau_df %>%
  mutate(event = as.numeric(gsub("e", "", event_sequence)))

alps_cog_df <- alps_cog_df %>%
  mutate(event = as.numeric(gsub("e", "", event_sequence)))

#demos for amyloid group
#select baseline visits
amyloid_baseline <- alps_amyloid_df %>%
  group_by(subject) %>%
  filter(event == min(event)) %>%
  ungroup()

#summary of age_at_visit
mean(amyloid_baseline$age_at_visit)
sd(amyloid_baseline$age_at_visit)
#table of de_gender
table(amyloid_baseline$de_gender)
#table of de_race
table(amyloid_baseline$de_race)
#table of apoe_status
table(amyloid_baseline$apoe_status)
#mean and sd of alps
mean(amyloid_baseline$alps)
sd(amyloid_baseline$alps)
#n of amyloid_baseline
nrow(amyloid_baseline)
#mean of choroid plexus freewater in amyloid_baseline
mean(amyloid_baseline$choroid_plexus_FW.combat)
sd(amyloid_baseline$choroid_plexus_FW.combat)

#repeat for Tau
#select baseline visits
tau_baseline <- alps_tau_df %>%
  group_by(subject) %>%
  filter(event == min(event)) %>%
  ungroup()
#summary of age_at_visit
mean(tau_baseline$age_at_visit)
sd(tau_baseline$age_at_visit)
#table of de_gender
table(tau_baseline$de_gender)
#table of de_race
table(tau_baseline$de_race)
#table of apoe_status
table(tau_baseline$apoe_status)
#mean and sd of alps
mean(tau_baseline$alps)
sd(tau_baseline$alps)
#n of tau_baseline
nrow(tau_baseline)
#mean of choroid plexus freewater in tau_baseline
mean(tau_baseline$choroid_plexus_FW.combat)
sd(tau_baseline$choroid_plexus_FW.combat)

#repeat for cognition
#select baseline visits
cog_baseline <- alps_cog_df %>%
  group_by(subject) %>%
  filter(event == min(event)) %>%
  ungroup()
#summary of age_at_visit
mean(cog_baseline$age_at_visit)
sd(cog_baseline$age_at_visit)
#table of de_gender
table(cog_baseline$de_gender)
#table of de_race
table(cog_baseline$de_race)
#table of apoe_status
table(cog_baseline$apoe_status)
#mean and sd of alps
mean(cog_baseline$alps)
sd(cog_baseline$alps)
#n of cog_baseline
nrow(cog_baseline)
#mean of choroid plexus freewater in cog_baseline
mean(cog_baseline$choroid_plexus_FW.combat)
sd(cog_baseline$choroid_plexus_FW.combat)

#count total rows
nrow(alps_amyloid_df)
#divide by number of unique subjects to get average visits per subject
nrow(alps_amyloid_df) / length(unique(alps_amyloid_df$subject))
#count max visit number for any subject
max(table(alps_amyloid_df$subject))
nrow(alps_tau_df)
#divide by number of unique subjects to get average visits per subject
nrow(alps_tau_df) / length(unique(alps_tau_df$subject))
#count max visit number for any subject
max(table(alps_tau_df$subject))
nrow(alps_cog_df)
#divide by number of unique subjects to get average visits per subject
nrow(alps_cog_df) / length(unique(alps_cog_df$subject))
#count max visit number for any subject
max(table(alps_cog_df$subject))

