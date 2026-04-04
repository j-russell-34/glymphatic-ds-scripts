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
csv_dir <- glue("/Users/jasonkru/Documents/inputs/{STUDY}/csvs")
harmonized_dir <- glue("/Users/jasonkru/Documents/outputs/{STUDY}/harmonized")
bg_dir <- glue("/Users/jasonkru/Documents/outputs/{STUDY}/basal_ganglia_pib_sens")

#make output directories if they don't exist
if (!dir.exists(glue("{bg_dir}"))) {
  dir.create(glue("{bg_dir}"), recursive = TRUE)
}


#import list of b1000 only scans
b1000_only_scans <- read_csv(glue("{in_dir}/alps/b1000_subs.csv"))



#import bg pib data
bgpib_df <- read_csv(glue("/Users/jasonkru/Documents/outputs/{STUDY}/basal_ganglia_pib/pib_bg_harmonized.csv"))
#split consortium_site_id into consortium and site_id
bgpib_df$site_id <- str_split_fixed(bgpib_df$consortium_site_id, "_", 2)[,2]
# combine event_sequence and subject_label to make fsid
bgpib_df <- bgpib_df %>%
  mutate(fsid = paste0(subject_label, "_e", event_sequence)) %>%
  dplyr::select(fsid, Basal_Ganglia_SUVR.combat, site_id)


#import demographics data
dems_df <- read_csv(glue("{csv_dir}/demographics_all.csv"))
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
age_df <- read_csv(glue("{csv_dir}/age_at_event_25Mar2026.csv"))
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
#select subject fsid and alps_harmonized
alps_df <- alps_df %>%
  dplyr::select(subject, fsid, alps_harmonized)


#inner join alps_df and b1000_only_scans by fsid to only keep b1000 only scans
alps_df <- inner_join(alps_df, b1000_only_scans, by = "fsid")

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
merged_df <- bgpib_df %>%
  inner_join(dems_df, by = "fsid") %>%
  inner_join(age_df, by = "fsid") %>%
  inner_join(alps_df, by = "fsid")


#remove rows with missing data
merged_df <- merged_df %>%
  drop_na()

#lmem with basal ganglia pib as outcome and alps_harmonized, age, sex as fixed effects and site_id as random effect
lmem_bg_bgpib <- lme(alps_harmonized ~ Basal_Ganglia_SUVR.combat + age + sex + site_id, random = ~1|subject, data = merged_df, method = "REML")
summary(lmem_bg_bgpib)
intervals(lmem_bg_bgpib, which = "fixed")

#using effects package plot linear relationship between alps_harmonized and Basal_Ganglia_SUVR.combat

alps_effect <- Effect(c("Basal_Ganglia_SUVR.combat"), lmem_bg_bgpib)
pred <- as.data.frame(alps_effect)

plot <- ggplot(pred, aes(x = Basal_Ganglia_SUVR.combat, y = fit)) +
  geom_point(
    data = merged_df,
    mapping = aes(
      x = Basal_Ganglia_SUVR.combat,
      y = alps_harmonized
    ),
    alpha = 0.5,
    inherit.aes = FALSE
  ) +
  geom_line(
    data = merged_df,
    mapping = aes(
      x = Basal_Ganglia_SUVR.combat,
      y = alps_harmonized,
      group = subject
    ),
    alpha = 0.3,
    inherit.aes = FALSE) +
  geom_line(size = 1.2, color = "red") +
  labs(x = "BG PiB SUVR",
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

ggsave(glue("{bg_dir}/bg_alps_plot.svg"), plot, width = 10, height = 8)

#assess different componenets of alps
#load the dz summary csv
dz_df <- read_csv(glue("{in_dir}/alps/harmonized/dz_summary_harmonized.csv"))

#select fsid, dz_x_assoc, dz_y_proj, dz_z_assoc, dz_x_proj
dz_df <- dz_df %>%
  dplyr::select(fsid, dz_x_assoc, dz_y_proj, dz_z_assoc, dz_x_proj)

#merge dz_df with alps_df by fsid
alps_dz_df <- inner_join(merged_df, dz_df, by = "fsid")

#lmem with dz_x_assoc as outcome and Basal_Ganglia_SUVR.combat

lmem_dz_x_assoc <- lmer(dz_x_assoc ~ Basal_Ganglia_SUVR.combat + age + sex + site_id + (1|subject), data = alps_dz_df, REML = TRUE)
summary(lmem_dz_x_assoc)

lmem_dz_y_proj <- lmer(dz_y_proj ~ Basal_Ganglia_SUVR.combat + age + sex + site_id + (1|subject), data = alps_dz_df, REML = TRUE)
summary(lmem_dz_y_proj)

lmem_dz_z_assoc <- lmer(dz_z_assoc ~ Basal_Ganglia_SUVR.combat + age + sex + site_id + (1|subject), data = alps_dz_df, REML = TRUE)
summary(lmem_dz_z_assoc)

lmem_dz_x_proj <- lmer(dz_x_proj ~ Basal_Ganglia_SUVR.combat + age + sex + site_id + (1|subject), data = alps_dz_df, REML = TRUE)
summary(lmem_dz_x_proj)

