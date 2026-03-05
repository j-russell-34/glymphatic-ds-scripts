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

#make output directories if they don't exist
if (!dir.exists(glue("{out_dir}/alps_sens"))) {
  dir.create(glue("{out_dir}/alps_sens"), recursive = TRUE)
}

#import list of b1000 only scans
b1000_only_scans <- read_csv(glue("{in_dir}/alps/b1000_subs.csv"))

#inner join alps_df and b1000_only_scans by fsid to only keep b1000 only scans
alps_df <- inner_join(alps_df, b1000_only_scans, by = "fsid")

#rename alps_harmonized to alps
colnames(alps_df)[colnames(alps_df) == "alps_harmonized"] <- "alps"

#split scan_type_site into scan_type and site
alps_df <- alps_df %>%
  separate(scan_type_site.x, into = c("scan_type", "site"), sep = "_", extra = "merge")

#load the volumetric data
volumetric_df <- read_csv(glue("{harmonized_dir}/volumetrics_harmonized.csv"))

#nromalize bf volume
volumetric_df$basal_forebrain_norm <- (volumetric_df$harmonized_left_basal_forebrain + volumetric_df$harmonized_right_basal_forebrain) / volumetric_df$harmonized_eTIV

#remove age and subject from volumetric_df
volumetric_df <- volumetric_df %>%
  dplyr::select(-age, -subject)

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

#fit segmented model with constrained pre-breakpoint slope
#first fit a baseline model
alps_lmem_baseline <- lme(fixed = alps ~ sex +site, random = ~1|subject, data = alps_df, method = "REML")

#then fit a segmented model
alps_seg_model <- segmented.lme(obj = alps_lmem_baseline, 
                              seg.Z = ~ age,
                              psi = 45,
                              random = list(subject=pdDiag(~1)),
                              data = alps_df,
                              control = seg.control(display=TRUE, it.max=100, tol=1e-6, n.boot=50))

summary(alps_seg_model)

#plot the linear model ------------------------------------------------------
#alps
alps_effect <- Effect("age", alps_lmem)
pred <- as.data.frame(alps_effect)

plot <- ggplot(pred, aes(x = age, y = fit)) +
  geom_point(
    data = alps_df,
    mapping = aes(
      x = age,
      y = alps,
    ),
    alpha = 0.5,
    inherit.aes = FALSE
  ) +
  geom_line(
    data = alps_df,
    mapping = aes(
      x = age,
      y = alps,
      group = subject,
    ),
    alpha = 0.3,
    inherit.aes = FALSE) +
  geom_line(size = 1.2, color = "red") +
  #geom_ribbon(aes(ymin = lower, ymax = upper, fill = prefunclevel), alpha = 0.1) +
  labs(x = "Age",
       y = "ALPS Index") +
  theme_minimal(base_size = 36) +
  theme(
    legend.title = element_text(face = "bold"),
    panel.grid = element_blank(),
    axis.line = element_line(color = "black"),
    axis.title = element_text(face = "bold"),
    panel.background = element_rect(fill = "white", color = NA),
    plot.background = element_rect(fill = "white", color = NA)
  )

print(plot)

ggsave(glue("{out_dir}/alps_sens/alps_lmm_plot.svg"), width = 10, height = 8)

#merge alps_df and amyloid_df
alps_amyloid_df <- inner_join(alps_df, amyloid_df, by = "fsid")

#lmem comparing age and alps and amyloid
#alps_amyloid_lmem <- lme(fixed = Centiloids ~ alps + age + sex + site, random = ~1|subject, data = alps_amyloid_df, method = "REML")
#summary(alps_amyloid_lmem)

#lmem comparing age and alps and amyloid
amyloid_alps_lmem <- lme(fixed = alps ~ Centiloids + age + sex + site, random = ~1|subject, data = alps_amyloid_df, method = "REML")
summary(amyloid_alps_lmem)
intervals(amyloid_alps_lmem, which = "fixed")
#join alps with volumetric data
alps_volumetric_df <- inner_join(alps_df, volumetric_df, by = "fsid")

#lmem comparing age and alps and volumetric
#alps_volumetric_lmem <- lme(fixed = basal_forebrain_norm ~ alps + age + sex + site, random = ~1|subject, data = alps_volumetric_df, method = "REML")
#summary(alps_volumetric_lmem)

#lmem comparing ALPs and fw
alps_cp_lmem <- lme(fixed = alps ~ choroid_plexus_FW.combat + age +  sex + site, random = ~1|subject, data = alps_df, method = "REML")
summary(alps_cp_lmem)
intervals(alps_cp_lmem, which = "fixed")

#lmem comparing ALPs and wm FW
#alps_wm_lmem <- lme(fixed = alps ~ wm_FW.combat + age +  sex + site, random = ~1|subject, data = alps_df, method = "REML")
#summary(alps_wm_lmem)

#join tau data
alps_tau_df <- inner_join(alps_df, tau_df, by = "fsid")
#lmem comparing age and alps and tau
alps_tau_lmem <- lme(fixed = alps ~ metatemporal + age.x + sex + site, random = ~1|subject, data = alps_tau_df, method = "REML")
summary(alps_tau_lmem)
intervals(alps_tau_lmem, which = "fixed")

#relationships between WM and amyloid and tau
#lmem comparing wm FW and amyloid
wm_amyloid_lmem <- lme(fixed = wm_FW.combat ~ Centiloids + age + sex + site, random = ~1|subject, data = alps_amyloid_df, method = "REML")
summary(wm_amyloid_lmem)
#lmem comparing cp FW and amyloid
cp_amyloid_lmem <- lme(fixed = choroid_plexus_FW.combat ~ Centiloids + age + sex + site, random = ~1|subject, data = alps_amyloid_df, method = "REML")
summary(cp_amyloid_lmem)
#lmem comparing wm FW and tau
wm_tau_lmem <- lme(fixed = wm_FW.combat ~ metatemporal + age.x + sex + site, random = ~1|subject, data = alps_tau_df, method = "REML")  
summary(wm_tau_lmem)
#lmem comparing cp FW and tau
cp_tau_lmem <- lme(fixed = choroid_plexus_FW.combat ~ metatemporal + age.x + sex + site, random = ~1|subject, data = alps_tau_df, method = "REML")
summary(cp_tau_lmem)

#plot sig WMH relationships with alps, amyloid and tau --------------------------------------
#alps vs cp FW
alps_cp_effect <- Effect("choroid_plexus_FW.combat", alps_cp_lmem)
pred <- as.data.frame(alps_cp_effect)

ggplot(pred, aes(x = choroid_plexus_FW.combat, y = fit)) +
  geom_point(
    data = alps_df,
    mapping = aes(
      x = choroid_plexus_FW.combat,
      y = alps,
    ),
    alpha = 0.5,
    inherit.aes = FALSE
  ) +
  #join lines for each subject
  geom_line(
    data = alps_df,
    mapping = aes(
      x = choroid_plexus_FW.combat,
      y = alps,
      group = subject,
    ),
    alpha = 0.3,
    inherit.aes = FALSE) +
  geom_line(size = 1.2, color = "red") +
  labs(x = "CP-FWf",
       y = "ALPS Index") +
  theme_minimal(base_size = 36) +
  theme(
    legend.title = element_text(face = "bold"),
    panel.grid = element_blank(),
    axis.line = element_line(color = "black"),
    axis.title = element_text(face = "bold"),
    panel.background = element_rect(fill = "white", color = NA),
    plot.background = element_rect(fill = "white", color = NA)
  )

ggsave(glue("{out_dir}/alps_sens/alps_cp_fw_lmm_plot.svg"), width = 10, height = 8)


#cp FW vs amyloid
cp_amyloid_effect <- Effect("Centiloids", cp_amyloid_lmem)
pred <- as.data.frame(cp_amyloid_effect)

ggplot(pred, aes(x = Centiloids, y = fit)) +
  geom_point(
    data = alps_amyloid_df,
    mapping = aes(
      x = Centiloids,
      y = choroid_plexus_FW.combat,
    ),
    alpha = 0.5,
    inherit.aes = FALSE
  ) +
  #join lines for each subject
  geom_line(
    data = alps_amyloid_df,
    mapping = aes(
      x = Centiloids,
      y = choroid_plexus_FW.combat,
      group = subject,
    ),
    alpha = 0.3,
    inherit.aes = FALSE) +
  geom_line(size = 1.2, color = "red") +
  labs(x = "Centiloids",
       y = "CP-FWf") +
  theme_minimal(base_size = 36) +
  theme(
    legend.title = element_text(face = "bold"),
    panel.grid = element_blank(),
    axis.line = element_line(color = "black"),
    axis.title = element_text(face = "bold"),
    panel.background = element_rect(fill = "white", color = NA),
    plot.background = element_rect(fill = "white", color = NA)
  )
ggsave(glue("{out_dir}/alps_sens/amy_cp_fw_lmm_plot.svg"), width = 10, height = 8)

#alps amyloid
ggplot() +
  geom_point(
    data = alps_amyloid_df,
    mapping = aes(
      x = Centiloids,
      y = alps,
    ),
    alpha = 0.5,
    inherit.aes = FALSE
  ) +
  #join lines for each subject
  geom_line(
    data = alps_amyloid_df,
    mapping = aes(
      x = Centiloids,
      y = alps,
      group = subject,
    ),
    alpha = 0.3,
    inherit.aes = FALSE) +
  labs(x = "Centiloids",
       y = "ALPS Index") +
  theme_minimal(base_size = 36) +
  theme(
    legend.title = element_text(face = "bold"),
    panel.grid = element_blank(),
    axis.line = element_line(color = "black"),
    axis.title = element_text(face = "bold"),
    panel.background = element_rect(fill = "white", color = NA),
    plot.background = element_rect(fill = "white", color = NA)
  )
ggsave(glue("{out_dir}/alps_sens/amy_alps_plot.svg"), width = 10, height = 8)

#plot cp FW vs tau
cp_tau_effect <- Effect("metatemporal", cp_tau_lmem)
pred <- as.data.frame(cp_tau_effect)

ggplot(pred, aes(x = metatemporal, y = fit)) +
  geom_point(
    data = alps_tau_df,
    mapping = aes(
      x = metatemporal,
      y = choroid_plexus_FW.combat,
    ),
    alpha = 0.5,
    inherit.aes = FALSE
  ) +
  #join lines for each subject
  geom_line(
    data = alps_tau_df,
    mapping = aes(
      x = metatemporal,
      y = choroid_plexus_FW.combat,
      group = subject,
    ),
    alpha = 0.3,
    inherit.aes = FALSE) +
  geom_line(size = 1.2, color = "red") +
  labs(x = "Tau",
       y = "CP-FWf") +
  theme_minimal(base_size = 36) +
  theme(
    legend.title = element_text(face = "bold"),
    panel.grid = element_blank(),
    axis.line = element_line(color = "black"),
    axis.title = element_text(face = "bold"),
    panel.background = element_rect(fill = "white", color = NA),
    plot.background = element_rect(fill = "white", color = NA)
  )
ggsave(glue("{out_dir}/alps_sens/tau_cp_fw_lmm_plot.svg"), width = 10, height = 8)

#ALPS tau
ggplot() +
  geom_point(
    data = alps_tau_df,
    mapping = aes(
      x = metatemporal,
      y = alps,
    ),
    alpha = 0.5,
    inherit.aes = FALSE
  ) +
  #join lines for each subject
  geom_line(
    data = alps_tau_df,
    mapping = aes(
      x = metatemporal,
      y = alps,
      group = subject,
    ),
    alpha = 0.3,
    inherit.aes = FALSE) +
  labs(x = "Tau",
       y = "ALPS Index") +
  theme_minimal(base_size = 36) +
  theme(
    legend.title = element_text(face = "bold"),
    panel.grid = element_blank(),
    axis.line = element_line(color = "black"),
    axis.title = element_text(face = "bold"),
    panel.background = element_rect(fill = "white", color = NA),
    plot.background = element_rect(fill = "white", color = NA)
  )
ggsave(glue("{out_dir}/alps_sens/tau_alps_lmm_plot.svg"), width = 10, height = 8)


#import mCRT cognitive data
mcrt_data <- read_csv("/Users/jasonkru/Documents/inputs/ABCDS/csvs/Cued_Recall.csv")

#import dsmse data
dsmse_data <- read_csv("/Users/jasonkru/Documents/inputs/ABCDS/csvs/Down_Syndrome_Mental_Status_Exam.csv")

#import premorbid iq data
premorbid_data <- read_csv("/Users/jasonkru/Documents/inputs/ABCDS/csvs/Premorbid_Functioning_Level.csv")

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

alps_dsmse_mod <- lme(
  fixed  = dsmse_to2 ~ choroid_plexus_FW.combat + age_at_visit + de_gender + site + prefunclevel,
  random = ~ 1 | subject,
  data   = alps_df_cog,
  method = "REML"
)
summary(alps_dsmse_mod)

#using Effects package plot trs by choroid_plexus_FW.combat
effect <- Effect("choroid_plexus_FW.combat", alps_mcrt_mod)
pred <- as.data.frame(effect)

#plot choroid_plexus_FW.combat by mcrt trs with effect line
ggplot(data=pred, aes(x = choroid_plexus_FW.combat, y = fit)) +
  geom_point(data = alps_df_cog, aes(x = choroid_plexus_FW.combat, y = trs), alpha = 0.5, inherit.aes = FALSE) +
  labs(x = "CP-FWf", y = "mCRT Total Recall Score") +
  theme_minimal(base_size = 36) +
  geom_line(size = 1.2, color = "red") +
  geom_line(data = alps_df_cog, aes(x = choroid_plexus_FW.combat, y = trs, group = subject), size = 0.4, alpha = 0.3, inherit.aes = FALSE) +
  theme(
    axis.title.y = element_markdown(),
    panel.grid = element_blank(),
    axis.line = element_line(color = "black"),
    axis.title = element_text(face = "bold"),
    panel.background = element_rect(fill = "white", color = NA),
    plot.background = element_rect(fill = "white", color = NA),
  )

ggsave(glue("{out_dir}/alps_sens/choroid_plexus_FW_mcrt_plot.svg"), width = 10, height = 8)

#plot choroid_plexus_FW.combat by dsmse_to2
ggplot() +
  geom_point(data = alps_df_cog, aes(x = choroid_plexus_FW.combat, y = dsmse_to2), alpha = 0.5, inherit.aes = FALSE) +
  labs(x = "CP-FWf", y = "DSMSE Total Score") +
  theme_minimal(base_size = 36) +
  geom_line(data = alps_df_cog, aes(x = choroid_plexus_FW.combat, y = dsmse_to2, group = subject), size = 0.4, alpha = 0.3, inherit.aes = FALSE) +
  theme(
    axis.title.y = element_markdown(),
    panel.grid = element_blank(),
    axis.line = element_line(color = "black"),
    axis.title = element_text(face = "bold"),
    panel.background = element_rect(fill = "white", color = NA),
    plot.background = element_rect(fill = "white", color = NA),
  )

ggsave(glue("{out_dir}/alps_sens/choroid_plexus_FW_dsmse_plot.svg"), width = 10, height = 8)


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

