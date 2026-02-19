library(tidyverse)
library(dplyr)
library(glue)
library(ggpattern)
library(ggtext)
library(lme4)
library(lmerTest)
library(segmented)
library(MuMIn)
library(svglite)
library(nlme)
library(effects)

#study specific variables
STUDY <- "ABCDS"

#directories
in_dir <- glue("/Users/jasonkru/Documents/outputs/{STUDY}")
csv_dir <- glue("/Users/jasonkru/Documents/inputs/{STUDY}/csvs")
harmonized_dir <- glue("/Users/jasonkru/Documents/outputs/{STUDY}/harmonized")
vascular_dir <- glue("/Users/jasonkru/Documents/outputs/{STUDY}/vascular")


#import demographics data
dems_df <- read_csv(glue("{csv_dir}/demographics.csv"))
#fill gender updown on subject_label
dems_df <- dems_df %>%
  group_by(subject_label) %>%
  fill(de_gender, .direction = "downup") %>%
  ungroup()
#make fsid column in dems_df
dems_df <- dems_df %>%
  mutate(fsid = paste0(subject_label, "_e", event_sequence)) %>%
  dplyr::select(fsid, de_gender)

#rename de_gender to sex
colnames(dems_df)[which(colnames(dems_df) == "de_gender")] <- "sex"

#import age at event data
age_df <- read_csv(glue("{csv_dir}/age_at_event.csv"))
#make fsid column in age_df
age_df <- age_df %>%
  mutate(fsid = paste0(subject_label, "_e", event_sequence)) %>%
  dplyr::select(fsid, age_at_visit, mri_latency_in_days, event_sequence)

#convert latency days to years 
age_df <- age_df %>%
  mutate(mri_latency = (mri_latency_in_days / 365))

#drop latency days columns
age_df <- age_df %>%
  dplyr::select(-mri_latency_in_days)

#if mri_latency is NA and event_sequence is 1, set mri_latency to 0
age_df <- age_df %>%
  mutate(mri_latency = ifelse(is.na(mri_latency) & event_sequence == 1, 0, mri_latency))
#if clinical_latency is NA and event_sequence is 1, set clinical_latency to 0

#drop event_sequence column
age_df <- age_df %>%
  dplyr::select(-event_sequence)

#rename age_at_visit to age
colnames(age_df)[which(colnames(age_df) == "age_at_visit")] <- "age"

#import alps data
alps_df <- read_csv(glue("{in_dir}/alps/harmonized/alps_summary_harmonized.csv"))
#make site_id column in alps_df from string after _ in scan_type_site.x
alps_df <- alps_df %>%
  mutate(site_id = sub(".*_(.*)$", "\\1", scan_type_site.x))

#select subject fsid and alps_harmonized
alps_df <- alps_df %>%
  dplyr::select(subject, fsid, site_id, alps_harmonized)

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


#innerjoin all dataframes on fsid
merged_df <- dems_df %>%
  inner_join(age_df, by = "fsid") %>%
  inner_join(alps_df, by = "fsid")

#import vascular data
pvs_df <- read_csv(glue("{in_dir}/vascular/PVS_COUNTS.csv"))
#import wmh harmonized data
wmh_df <- read_csv(glue("{in_dir}/vascular/wmh_harmonized.csv"))

#make fsid column in pvs_df
pvs_df <- pvs_df %>%
  mutate(fsid = paste0(subject_label, "_e", event_sequence)) %>%
  dplyr::select(fsid, pvs_score, bg_pvs_score, cortical_pvs_score)

#inner join merged_df and pvs_df by fsid
pvs_df <- inner_join(merged_df, pvs_df, by = "fsid")

#make fsid column in wmh_df
wmh_df <- wmh_df %>%
  dplyr::select(fsid, Frontal_lobe.combat, Temporal_lobe.combat, Parietal_lobe.combat, Occipital_lobe.combat, total_wmh_harmonized)
  
#inner join pvs_df and wmh_df by fsid
pvs_df <- inner_join(pvs_df, wmh_df, by = "fsid")


#remove rows with missing data
pvs_df <- pvs_df %>%
  drop_na()

#lmem with alps as outcome and pvs_score, age, sex as fixed effects and site_id as random effect
lmem_pvs <- lmer(alps_harmonized ~ pvs_score + age + sex + site_id + (1|subject), data = pvs_df, REML = TRUE)
summary(lmem_pvs)
#lmem with choroid_plexus_FW as outcome and pvs_score, age, sex as fixed effects and site_id as random effect
lmem_pvs_cpfwf <- lmer(choroid_plexus_FW.combat ~ pvs_score + age + sex + site_id + (1|subject), data = pvs_df, REML = TRUE)
summary(lmem_pvs_cpfwf)


#lmem with alps as outcome and total_wmh_harmonized, age, sex as fixed effects and site_id as random effect
lmem_wmh <- lmer(alps_harmonized ~ total_wmh_harmonized + age + sex + site_id + (1|subject), data = pvs_df, REML = TRUE)
summary(lmem_wmh)
#lmem with choroid_plexus_FW as outcome and total_wmh_harmonized, age, sex as fixed effects and site_id as random effect
lmem_wmh_cpfwf <- lmer(choroid_plexus_FW.combat ~ total_wmh_harmonized + age + sex + site_id + (1|subject), data = pvs_df, REML = TRUE)
summary(lmem_wmh_cpfwf)


#using effects package plot linear relationship

cp_effect <- Effect(c("total_wmh_harmonized"), lmem_wmh_cpfwf)
pred <- as.data.frame(cp_effect)

plot <- ggplot(pred, aes(x = total_wmh_harmonized, y = fit)) +
  geom_point(
    data = pvs_df,
    mapping = aes(
      x = total_wmh_harmonized,
      y = choroid_plexus_FW.combat
    ),
    alpha = 0.5,
    inherit.aes = FALSE
  ) +
  geom_line(
    data = pvs_df,
    mapping = aes(
      x = total_wmh_harmonized,
      y = choroid_plexus_FW.combat,
      group = subject
    ),
    alpha = 0.3,
    inherit.aes = FALSE) +
  geom_line(size = 1.2, color = "red") +
  labs(x = "Total WMH Volume",
       y = "CP-FWf"
  ) +
  theme_minimal(base_size=36) +
  theme(
    legend.position = "right",
    legend.title = element_text(face = "bold"),
    panel.grid = element_blank(),
    axis.line = element_line(color = "black"),
    axis.title = element_text(face = "bold"),
    panel.background = element_rect(fill = "white", color = NA),
    plot.background = element_rect(fill = "white", color = NA)
  )

ggsave(glue("{vascular_dir}/total_wmh_cpfwf_plot.svg"), plot, width = 10, height = 8)

#plot non-sig effects as well for completeness
plot <- ggplot() +
  geom_point(
    data = pvs_df,
    mapping = aes(
      x = total_wmh_harmonized,
      y = alps_harmonized
    ),
    alpha = 0.5,
    inherit.aes = FALSE
  ) +
  geom_line(
    data = pvs_df,
    mapping = aes(
      x = total_wmh_harmonized,
      y = alps_harmonized,
      group = subject
    ),
    alpha = 0.3,
    inherit.aes = FALSE) +
  geom_line(size = 1.2, color = "red") +
  labs(x = "Total WMH Volume",
       y = "ALPS Index"
  ) +
  theme_minimal(base_size=36) +
  theme(
    legend.position = "right",
    legend.title = element_text(face = "bold"),
    panel.grid = element_blank(),
    axis.line = element_line(color = "black"),
    axis.title = element_text(face = "bold"),
    panel.background = element_rect(fill = "white", color = NA),
    plot.background = element_rect(fill = "white", color = NA)
  )

ggsave(glue("{vascular_dir}/total_wmh_alps_plot.svg"), plot, width = 10, height = 8)


#plot non-sig effects as well for completeness
plot <- ggplot() +
  geom_point(
    data = pvs_df,
    mapping = aes(
      x = pvs_score,
      y = alps_harmonized
    ),
    alpha = 0.5,
    inherit.aes = FALSE
  ) +
  geom_line(
    data = pvs_df,
    mapping = aes(
      x = pvs_score,
      y = alps_harmonized,
      group = subject
    ),
    alpha = 0.3,
    inherit.aes = FALSE) +
  geom_line(size = 1.2, color = "red") +
  labs(x = "Total PVS Score",
       y = "ALPS Index"
  ) +
  theme_minimal(base_size=36) +
  theme(
    legend.position = "right",
    legend.title = element_text(face = "bold"),
    panel.grid = element_blank(),
    axis.line = element_line(color = "black"),
    axis.title = element_text(face = "bold"),
    panel.background = element_rect(fill = "white", color = NA),
    plot.background = element_rect(fill = "white", color = NA)
  )

ggsave(glue("{vascular_dir}/total_pvs_alps_plot.svg"), plot, width = 10, height = 8)

#plot non-sig effects as well for completeness
plot <- ggplot() +
  geom_point(
    data = pvs_df,
    mapping = aes(
      x = pvs_score,
      y = choroid_plexus_FW.combat
    ),
    alpha = 0.5,
    inherit.aes = FALSE
  ) +
  geom_line(
    data = pvs_df,
    mapping = aes(
      x = pvs_score,
      y = choroid_plexus_FW.combat,
      group = subject
    ),
    alpha = 0.3,
    inherit.aes = FALSE) +
  geom_line(size = 1.2, color = "red") +
  labs(x = "Total PVS Score",
       y = "CP-FWf"
  ) +
  theme_minimal(base_size=36) +
  theme(
    legend.position = "right",
    legend.title = element_text(face = "bold"),
    panel.grid = element_blank(),
    axis.line = element_line(color = "black"),
    axis.title = element_text(face = "bold"),
    panel.background = element_rect(fill = "white", color = NA),
    plot.background = element_rect(fill = "white", color = NA)
  )

ggsave(glue("{vascular_dir}/total_pvs_cpfwf_plot.svg"), plot, width = 10, height = 8)

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
  dplyr::select(fsid, de_race, apoe_status, event_sequence)

#inner join pvs_df and race_data by fsid
pvs_df <- inner_join(pvs_df, race_data, by = "fsid")

#make baseline only dataframe for demographics from minimum event_sequence
pvs_df_bl <- pvs_df %>%
  group_by(subject) %>%
  filter(event_sequence == min(event_sequence)) %>%
  ungroup()

#count unique subjects in pvs_df
num_subjects <- length(unique(pvs_df_bl$subject))
print(glue("Number of unique subjects: {num_subjects}"))

#summary of age_at_visit
mean(pvs_df_bl$age)
sd(pvs_df_bl$age)
#table of de_gender
table(pvs_df_bl$sex)
#table of de_race
table(pvs_df_bl$de_race)
#table of apoe_status
table(pvs_df_bl$apoe_status)
#mean and sd of alps
mean(pvs_df_bl$alps_harmonized)
sd(pvs_df_bl$alps_harmonized)
#n of pvs_df
nrow(pvs_df)
#mean of choroid plexus freewater in pvs_df
mean(pvs_df_bl$choroid_plexus_FW.combat)
sd(pvs_df_bl$choroid_plexus_FW.combat)

#add row of visits per subject to alps_df
pvs_df <- pvs_df %>%
  group_by(subject) %>%
  mutate(visits_per_subject = n()) %>%
  ungroup()