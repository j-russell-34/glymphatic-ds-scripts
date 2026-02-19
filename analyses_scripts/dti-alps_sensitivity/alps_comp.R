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
  dplyr::select(fsid, alps, subject, event)

#rename alps to alps_ds and fsid to fsid_ds
colnames(alps_ds_w_sib_filt_df)[colnames(alps_ds_w_sib_filt_df) == "alps"] <- "alps_ds"
colnames(alps_ds_w_sib_filt_df)[colnames(alps_ds_w_sib_filt_df) == "fsid"] <- "fsid_ds"

alps_control_df <- alps_df[alps_df$subject %in% control_match_df$subject, ]
#select fsid, alps, subject_label, event from alps_control_df
alps_control_filt_df <- alps_control_df %>%
  dplyr::select(fsid, alps, subject, event)

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

#run mixed effects model comparing groups in alps_ds_w_sib_df_bl
bl_comparison_paired <- lme(alps ~ group + age_at_visit + de_gender + site, random = ~1|family, data = alps_ds_w_sib_df_bl, method = "REML")
summary(bl_comparison_paired)

# Convert to wide format
paired_data <- alps_ds_w_sib_df %>%
  pivot_wider(
    names_from = group, 
    values_from = alps, 
    id_cols = c(family, event),
    names_prefix = "group_"
  ) %>%
  filter(!is.na(group_1) & !is.na(group_2))  # Only complete pairs

#select min event for each family
paired_data <- paired_data %>%
  group_by(family) %>%
  filter(event == min(event)) %>%
  ungroup()

#pivot paired data to long format
paired_data <- paired_data %>%
  pivot_longer(cols = starts_with("group_"), names_to = "group", values_to = "alps")

# Mean with confidence intervals plot
ggplot(paired_data, aes(x = group, y = alps, color = group)) +
  stat_summary(fun = mean, geom = "point", size = 5) +
  stat_summary(fun.data = mean_cl_normal, geom = "errorbar", width = 0.4) +
  geom_line(data = paired_data, aes(x = group, y = alps, group = family), size=0.2,alpha = 0.3, inherit.aes = FALSE) +
  geom_point(data = paired_data, aes(x = group, y = alps, color = group), size = 0.5) +
  labs(x = "Group", y = "ALPS Index") +
  scale_x_discrete(labels = c("group_1" = "DS", "group_2" = "SC")) +
  theme_minimal() +
    theme_minimal(base_size = 36) +
    theme(
        axis.title.y = element_markdown(),
        panel.grid = element_blank(),
        axis.line = element_line(color = "black"),
        axis.title = element_text(face = "bold"),
        panel.background = element_rect(fill = "white", color = NA),
        plot.background = element_rect(fill = "white", color = NA),
        legend.position = "none"
    )

ggsave(glue("{out_dir}/alps_sens/alps_paired_t_test_plot.svg"), width = 10, height = 8)

#add family to alps_df
alps_df <- left_join(alps_df, fam_df, by = c("subject", "event"))

#fill in NA family values with unique numbers starting after the max family number
max_family <- max(alps_df$family, na.rm = TRUE)
alps_df <- alps_df %>%
  group_by(subject) %>%
  mutate(family = ifelse(is.na(family), first(row_number()[is.na(family)]) + max_family - 1, family)) %>%
  ungroup()

#make family a factor
alps_df$family <- as.factor(alps_df$family)

#run group comarison
group_comparison <- lme(fixed = alps ~ group + age_at_visit + de_gender + site, 
                       random = ~1|subject/family, 
                       data = alps_df, 
                       method = "REML")

summary(group_comparison)

# Add min_visit_number column for each subject
alps_df <- alps_df %>%
  group_by(subject) %>%
  mutate(min_visit_number = min(event)) %>%
  ungroup()

# Now filter for baseline
baseline_df <- alps_df %>%
  filter(event == min_visit_number)



#plot of alps by group
ggplot(baseline_df, aes(x = group, y = alps, color = group)) +
  geom_point(data = baseline_df, aes(x = group, y = alps, color = group), position = position_jitter(width = 0.2), size = 0.5) +
  stat_summary(fun = mean, geom = "point", size = 5, color = "black") +
  stat_summary(fun.data = mean_cl_normal, geom = "errorbar", width = 0.4, color = "black") +
  labs(x = "Group", y = "ALPS Index") +
  scale_x_discrete(labels = c("1" = "DS", "2" = "SC")) +
  theme_minimal() +
    theme_minimal(base_size = 36) +
    theme(
        axis.title.y = element_markdown(),
        panel.grid = element_blank(),
        axis.line = element_line(color = "black"),
        axis.title = element_text(face = "bold"),
        panel.background = element_rect(fill = "white", color = NA),
        plot.background = element_rect(fill = "white", color = NA),
        legend.position = "none"
    )

ggsave(glue("{out_dir}/alps_sens/alps_baseline_comparison_plot.svg"), width = 10, height = 8)


#compare longitudinal change in alps by group with interaction of group and age_at_visit
long_comparison <- lme(alps ~ group + age_at_visit + de_gender + site, data = alps_df, random = ~1|subject/family, method = "REML")
summary(long_comparison)

long_comp_interaction <- lme(alps ~ group * age_at_visit + de_gender +site, data = alps_df, random = ~1|subject/family, method = "REML")
summary(long_comp_interaction)

effects_df <- as.data.frame(Effect(c("age_at_visit", "group"), long_comparison))

#plot linear model of alps by age_at_visit separated by group
ggplot(alps_df, aes(x = age_at_visit, y = alps, color = group)) +
  geom_point(data = alps_df, aes(x = age_at_visit, y = alps), alpha = 0.5, , size = 0.5) +
  labs(x = "Age at Visit", y = "ALPS Index") +
  theme_minimal(base_size = 36) +
  geom_line(data = alps_df, aes(x = age_at_visit, y = alps, group = subject, color = group), size = 0.4, alpha = 0.3, inherit.aes = FALSE) +
  geom_ribbon(data = effects_df, 
              aes(x = age_at_visit, ymin = lower, ymax = upper, fill = group), 
              alpha = 0.2, inherit.aes = FALSE) +
  geom_line(data = effects_df, 
            aes(x = age_at_visit, y = fit, color = group), 
            size = 1.5) +

  scale_color_discrete(labels = c("1" = "DS", "2" = "SC")) +
  scale_fill_discrete(labels = c("1" = "DS", "2" = "SC")) +
  theme(
    axis.title.y = element_markdown(),
    panel.grid = element_blank(),
    axis.line = element_line(color = "black"),
    axis.title = element_text(face = "bold"),
    panel.background = element_rect(fill = "white", color = NA),
    plot.background = element_rect(fill = "white", color = NA),
    legend.text = element_text(size = 20, face = "bold"),
    legend.title = element_blank(),
    legend.key.height = unit(1.5, "cm"),
    legend.margin = margin(0, 0, 0, 0),
    legend.box.margin = margin(0, 0, 0, 0)
  )

ggsave(glue("{out_dir}/alps_sens/alps_longitudinal_comparison_plot.svg"), width = 10, height = 8)


# Make baseline_df with family
baseline_df_fam <- alps_df %>%
  filter(event == min_visit_number)

# Linear model for baseline comparison with family as random effect
bl_comparison_fam <- lme(alps ~ group + age_at_visit + de_gender + site, random = ~1|family, data = baseline_df_fam, method = "REML")
summary(bl_comparison_fam)


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
  fixed  = trs ~ alps + age_at_visit + de_gender + site + prefunclevel,
  random = ~ 1 | subject,
  data   = alps_df_cog,
  method = "REML"
)
summary(alps_mcrt_mod)

alps_dsmse_mod <- lme(
  fixed  = dsmse_to2 ~ alps + age_at_visit + de_gender + site + prefunclevel,
  random = ~ 1 | subject,
  data   = alps_df_cog,
  method = "REML"
)
summary(alps_dsmse_mod)

# Get baseline ALPS (first visit per subject)
baseline_alps <- alps_df_cog %>%
  group_by(subject) %>%
  arrange(age_at_visit) %>%
  slice(1) %>%
  ungroup() %>%
  dplyr::select(subject, baseline_alps = alps, baseline_age = age_at_visit, de_gender, site)

#from alps_df_cog, select subject, fsid, age_at_visit, trs
mcrt_data <- alps_df_cog %>%
  dplyr::select(subject, fsid, age_at_visit, trs, dsmse_to2)

#make both subject columns character
mcrt_data$subject <- as.character(mcrt_data$subject)
baseline_alps$subject <- as.character(baseline_alps$subject)

# Merge baseline ALPS with all cognitive visits for each subject
alps_cog_long <- mcrt_data %>%
  left_join(baseline_alps, by = "subject") %>%
  filter(!is.na(baseline_alps))  # Keep only subjects with baseline ALPS

alps_cog_long <- alps_cog_long %>%
  mutate(time_since_baseline = age_at_visit - baseline_age)


#plot alps by mcrt trs
ggplot() +
  geom_point(data = alps_df_cog, aes(x = alps, y = trs), alpha = 0.5, inherit.aes = FALSE) +
  labs(x = "ALPS Index", y = "mCRT Total Recall Score") +
  theme_minimal(base_size = 36) +
  geom_line(data = alps_df_cog, aes(x = alps, y = trs, group = subject), size = 0.4, alpha = 0.3, inherit.aes = FALSE) +
  theme(
    axis.title.y = element_markdown(),
    panel.grid = element_blank(),
    axis.line = element_line(color = "black"),
    axis.title = element_text(face = "bold"),
    panel.background = element_rect(fill = "white", color = NA),
    plot.background = element_rect(fill = "white", color = NA),
  )

ggsave(glue("{out_dir}/alps_sens/alps_mcrt_plot.svg"), width = 10, height = 8)

#plot alps by dsmse_to2
ggplot() +
  geom_point(data = alps_df_cog, aes(x = alps, y = dsmse_to2), alpha = 0.5, inherit.aes = FALSE) +
  labs(x = "ALPS Index", y = "DSMSE Total Score") +
  theme_minimal(base_size = 36) +
  geom_line(data = alps_df_cog, aes(x = alps, y = dsmse_to2, group = subject), size = 0.4, alpha = 0.3, inherit.aes = FALSE) +
  theme(
    axis.title.y = element_markdown(),
    panel.grid = element_blank(),
    axis.line = element_line(color = "black"),
    axis.title = element_text(face = "bold"),
    panel.background = element_rect(fill = "white", color = NA),
    plot.background = element_rect(fill = "white", color = NA),
  )

ggsave(glue("{out_dir}/alps_sens/alps_dsmse_plot.svg"), width = 10, height = 8)

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

#left join with alps_df for full dataset 
alps_df <- left_join(alps_df, race_data, by = c("fsid"))

#left join with alps_df_cog for cognitive dataset
alps_df_cog <- left_join(alps_df_cog, race_data, by = c("fsid"))

#split alps_df by group
#group 1 ds_df
ds_df <- alps_df %>%
  filter(group == 1)
#group 2 sc_df
sc_df <- alps_df %>%
  filter(group == 2)

#demos for down syndrome group
#select baseline visits
ds_baseline <- ds_df %>%
  group_by(subject) %>%
  filter(event == min(event)) %>%
  ungroup()

#summary of age_at_visit
mean(ds_baseline$age_at_visit)
sd(ds_baseline$age_at_visit)
#table of de_gender
table(ds_baseline$de_gender)
#table of de_race
table(ds_baseline$de_race)
#table of apoe_status
table(ds_baseline$apoe_status)
#mean and sd of alps
mean(ds_baseline$alps)
sd(ds_baseline$alps)
#n of ds_baseline
nrow(ds_baseline)
#mean of choroid plexus freewater in ds_baseline
mean(ds_baseline$choroid_plexus_FW.combat)
sd(ds_baseline$choroid_plexus_FW.combat)

#repeart for sc group
#select baseline visits
sc_baseline <- sc_df %>%
  group_by(subject) %>%
  filter(event == min(event)) %>%
  ungroup()

#summary of age_at_visit
mean(sc_baseline$age_at_visit)
sd(sc_baseline$age_at_visit)
#table of de_gender 
table(sc_baseline$de_gender)
#table of de_race 
table(sc_baseline$de_race)
#table of apoe_status
table(sc_baseline$apoe_status)
#mean and sd of alps
mean(sc_baseline$alps)
sd(sc_baseline$alps)
#n of sc_baseline
nrow(sc_baseline)
#mean of choroid plexus freewater in sc_baseline
mean(sc_baseline$choroid_plexus_FW.combat)
sd(sc_baseline$choroid_plexus_FW.combat)

#count total rows
nrow(ds_df)
#divide by number of unique subjects to get average visits per subject
nrow(ds_df) / length(unique(ds_df$subject))
#count max visit number for any subject
max(table(ds_df$subject))

nrow(sc_df)
#divide by number of unique subjects to get average visits per subject
nrow(sc_df) / length(unique(sc_df$subject))
#count max visit number for any subject
max(table(sc_df$subject))

#add row of visits per subject to alps_df
alps_df <- alps_df %>%
  group_by(subject) %>%
  mutate(visits_per_subject = n()) %>%
  ungroup()

#make full_bl_df with baseline visits for both groups
full_bl_df <- alps_df %>%
  group_by(subject) %>%
  filter(event == min(event)) %>%
  ungroup()

#t-test comparing age_at_visit by group in full_bl_df
t_test_age <- t.test(age_at_visit ~ group, data = full_bl_df)
print(t_test_age)

#chi squared test comparing de_gender by group in full_bl_df
gender_table <- table(full_bl_df$de_gender, full_bl_df$group)
chi_test_gender <- chisq.test(gender_table)
print(chi_test_gender)

#Fisher's exact test comparing de_race by group in full_bl_df
race_table <- table(full_bl_df$de_race, full_bl_df$group)
fisher_test_race <- fisher.test(race_table)
print(fisher_test_race)

#Fisher's exact test comparing apoe_status by group in full_bl_df
apoe_table <- table(full_bl_df$apoe_status, full_bl_df$group)
fisher_test_apoe <- fisher.test(apoe_table)
print(fisher_test_apoe)

#t-test comparing alps by group in full_bl_df
t_test_alps <- t.test(alps ~ group, data = full_bl_df)
print(t_test_alps)

#t-test comparing choroid plexus freewater by group in full_bl_df
t_test_fw <- t.test(choroid_plexus_FW.combat ~ group, data = full_bl_df)
print(t_test_fw)


#kruskal wallis test comparing visits_per_subject by group in full_bl_df
kruskal_test_visits <- kruskal.test(visits_per_subject ~ group, data = full_bl_df)
print(kruskal_test_visits)

