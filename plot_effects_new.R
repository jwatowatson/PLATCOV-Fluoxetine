load('Rout/model_settings_Fluoxitine_new.RData')
model_settings$i <- row.names(model_settings)
######################################################################################################
library(ggplot2)
library(fitdistrplus)
library(tidyr)
library(ggpubr)
library(rstan)
library(dplyr)
library(scales)
######################################################################################################
my_probs = c(0.025, 0.1, .5, .9, .975)
source('functions.R')
######################################################################################################
formatter <- function(x){ 
  (x-1)*100 
}
######################################################################################################
effect_ests <- list()
for(i in 1:nrow(model_settings)){
  load(paste('Rout/model_fits_new/model_fits_',model_settings$i[i],'.RData',sep=''))
  platcov_dat <- data_list[[model_settings$Data_ID[i]]]
  intervention = model_settings$intervention[i] # prefix of analysis file
  ref_arm = model_settings$ref_arm[i]
  trt_intervention = unique(platcov_dat$Trt)
  trts = trt_intervention[trt_intervention!=ref_arm] # get interventions
  effect_ests[[i]] = 
    exp(summary(out, pars='trt_effect',use_cache=F,probs=my_probs)$summary[,c('2.5%', '10%','50%','90%','97.5%'),drop=F])
  rownames(effect_ests[[i]])=trts
}

A <- (rstan::extract(out, par = 'trt_effect'))

sum(exp(A$trt_effect) < 1.2)/length(A$trt_effect)

######################################################################################################
# 1. Fluoxetine analysis: effects
flag_fluoxetine <- which(model_settings$intervention == "Fluoxetine")
effect_fluoxetine <- as.data.frame(do.call("rbind", effect_ests[flag_fluoxetine]))
effect_fluoxetine$model <- model_settings$mod[flag_fluoxetine]
effect_fluoxetine$model <- as.factor(effect_fluoxetine$model)
levels(effect_fluoxetine$model) <- c("Linear", "Non-linear")
effect_fluoxetine$model <- factor(effect_fluoxetine$model, levels = rev(c("Linear", "Non-linear")))

effect_fluoxetine$Dmax <- model_settings$Dmax[flag_fluoxetine]
effect_fluoxetine$Dmax <- as.factor(effect_fluoxetine$Dmax)
levels(effect_fluoxetine$Dmax) <- c("5 days", "7 days")

colnames(effect_fluoxetine) <- c("L95", "L80", "med", "U80", "U95", "model", "Dmax")

intervention <- "Fluoxetine"
ref_arm <- "No study drug"

G1 <- ggplot(effect_fluoxetine, aes(x = model, y = med, col = Dmax, shape = model)) +
  geom_point(position = position_dodge(width = 0.5), size = 4) +
  geom_errorbar(aes(x = model, ymin = L95, ymax = U95),position = position_dodge(width = 0.5), width = 0, linewidth = 0.65) +
  geom_errorbar(aes(x = model, ymin = L80, ymax = U80),position = position_dodge(width = 0.5), width = 0, linewidth = 1.5) +
  geom_rect(aes(ymin = 0.9, ymax = 1.2, xmin = 0, xmax = 3), fill = "#7D7C7C", alpha = 0.05, col = NA) +
  coord_flip() +
  theme_bw() +
  geom_hline(yintercept = 1, col = "red", linetype = "dashed") +
  scale_color_manual(values = c("#004225", "#FFB000"), name = "Follow-up duration") +
  scale_shape_manual(values = c(16,17), name = "Model", guide = "none") +
  scale_y_continuous(labels = formatter, limits = c(0.9, 1.45), expand = c(0,0)) +
  ylab("Change in viral clearance rate (%)") +
  xlab("") +
  ggtitle("Estimated treatment effects")  + 
  theme(axis.title  = element_text(face = "bold"),
        plot.title = element_text(face = "bold"),
        legend.position = "bottom",
        axis.text = element_text(size = 10))
G1

formatter(effect_fluoxetine)

######################################################################################################
# 2. Fluoxitine analysis: Plot data
dataplot <- data_list[[1]]
#dataplot <- dataplot[dataplot$Timepoint_ID %in% 0:7,]
dataplot$Time

Dmax <- 7
dataplot = 
  dataplot %>% ungroup() %>%
  filter(Timepoint_ID %in% c(0:Dmax, 14), mITT) %>%
  arrange(log10_viral_load==log10_cens_vl) %>%
  mutate(Variant = as.factor(Variant),
         Site = as.factor(Site),
         RnaseP_scaled = scale(40 - CT_RNaseP,scale = F),
         Mean_age = mean(Age[!duplicated(ID)]),
         SD_age = sd(Age[!duplicated(ID)]),
         Age_scaled = (Age-Mean_age)/SD_age,
         Symptom_onset = ifelse(is.na(Symptom_onset),2,Symptom_onset)) 

dataplot$Timepoint_ID_num <- dataplot$Timepoint_ID

#dataplot$Timepoint_ID <- as.factor(dataplot$Timepoint_ID)
#levels(dataplot$Timepoint_ID) <- c("Day 0", "Day 1", "Day 2", "Day 3", 
#                                   "Day 4", "Day 5", "Day 6", "Day 7")   

dataplot2 <- aggregate(log10_viral_load~ID+Timepoint_ID+Timepoint_ID_num+Trt+Site+BMI+Plate+Age+Sex+Symptom_onset, 
                       data = dataplot, FUN = median)

dataplot3<- aggregate(log10_viral_load~Timepoint_ID+Timepoint_ID_num+Trt, data = dataplot, FUN = quantile, c(0.25, 0.5, 0.75))
dataplot3[,4:6] <- as.data.frame(as.matrix(dataplot3[,4]))
colnames(dataplot3)[4:6] <- c("Q1", "Q2", "Q3")

intervention = "Fluoxetine"
ref_arm = "No study drug"


G2 <- ggplot() +
  geom_jitter(data = dataplot, aes(x = Timepoint_ID_num, y = log10_viral_load, col = Trt), 
              alpha = 0.2, size = 1.5, shape = 21,
              width = 0.15) +
  # geom_line(data = subset(dataplot2, as.numeric(Timepoint_ID) <= 8), aes(x =  Timepoint_ID, y = log10_viral_load, group = ID, col = Trt), 
  #           alpha = 0.5, linewidth = 0.5, linetype = 1) +
  scale_fill_manual(values = c("#005AB5", "#DC3220"), name = "") +
 # ggnewscale::new_scale_color() +
  geom_line(data = subset(dataplot3, Timepoint_ID_num <= 7), aes(x =  Timepoint_ID_num, y = Q2, group = Trt, col = Trt), linewidth = 1, linetype = 1) +
  geom_line(data = subset(dataplot3,  Timepoint_ID_num >= 7), aes(x =  Timepoint_ID_num, y = Q2, group = Trt, col = Trt), linewidth = 0.75, linetype = "dashed") +
  geom_point(data = dataplot3, aes(x = Timepoint_ID_num, y = Q2, fill = Trt), size = 3.5, shape = 24) +
  scale_color_manual(values = c("#005AB5", "#DC3220"), name = "") +
  theme_bw() +
  scale_x_continuous(breaks = 0:14) +
  scale_y_continuous(labels=label_math(), breaks = seq(0,8,2)) +
  xlab("Time since randomisation (days)") +
  ylab("SARS-CoV-2 genomes/mL") + 
  theme(axis.title  = element_text(face = "bold"),
        plot.title = element_text(face = "bold"),
        legend.position = "bottom",
        axis.text = element_text(size = 10)) +
  ggtitle("Viral load dynamics") +
  annotate("text", x = 6, y = 8.5, label = paste(intervention,':', length(unique(dataplot$ID[dataplot$Trt == intervention])), "patients", sep = " "), hjust = 0) +
  annotate("text", x = 6, y = 8, label = paste(ref_arm,':', length(unique(dataplot$ID[dataplot$Trt == ref_arm])), "patients", sep = " "), hjust = 0)    

G2   

######################################################################################################
png("Plots/Fluoxetine_analysis.png", width = 10, height = 5, units = "in", res = 350)
ggarrange(G2, G1, nrow = 1, ncol = 2, align = "hv", labels = "AUTO")
dev.off()
######################################################################################################
# 3. Individual half-life
Dmax <- 7
flag <-which(model_settings$Dmax == Dmax & model_settings$intervention == "Fluoxetine" & grepl("Linear_", model_settings$mod))
load(paste('Rout/model_fits_new/model_fits_',model_settings$i[flag],'.RData',sep=''))

slopes <- as.data.frame(-1*(summary(out, pars='slope',use_cache=F,probs=my_probs)$summary[,c('2.5%','10%','50%','90%','97.5%'),drop=F]))
colnames(slopes) <- c("L95", "L80", "med", "U80", "U95")
t_half <- (log10(2)/(slopes)*24)

platcov_dat <- data_list[[1]]

platcov_dat_analysis = 
  platcov_dat %>% ungroup() %>%
  filter(Time <= Dmax, mITT) %>%
  arrange(log10_viral_load==log10_cens_vl) %>%
  mutate(Variant = as.factor(Variant),
         Site = as.factor(Site),
         RnaseP_scaled = scale(40 - CT_RNaseP,scale = F),
         Mean_age = mean(Age[!duplicated(ID)]),
         SD_age = sd(Age[!duplicated(ID)]),
         Age_scaled = (Age-Mean_age)/SD_age,
         Symptom_onset = ifelse(is.na(Symptom_onset),2,Symptom_onset)) 

t_half <- cbind(t_half, unique(platcov_dat_analysis[,c("ID", "Trt")]))
t_half <- as.data.frame(t_half)
t_half <- t_half[order(t_half$Trt, t_half$med),]
t_half$i <- 1:nrow(t_half)

med_t_half <- aggregate(list("med" = t_half$med), by = list("Trt" = t_half$Trt), median)

G3 <- ggplot(t_half, aes(x = i, y = med, col = Trt)) + geom_point() +
  theme_bw() +
  coord_flip(ylim=c(0, 50)) +
  scale_y_continuous(expand = c(0,0)) +
  geom_errorbar(aes(ymin = L80, ymax = U80), width = 0, alpha = 0.4) +
  geom_hline(data = med_t_half, aes(yintercept = med, col = Trt, linetype = Trt), linewidth = 0.75) +
  scale_color_manual(values = c("#005AB5", "#DC3220"), name = "") +
  scale_linetype_manual(values = c("dashed","dashed"), guide = "none") +
  ylab("Viral clearance half-life (hours)") +
  xlab("") +
  theme(
    axis.text.y = element_blank(),
    axis.ticks.y = element_blank(),
    axis.title  = element_text(face = "bold"),
    plot.title = element_text(face = "bold"),
    legend.position = "bottom") +
  ggtitle(paste0("Viral clearance half-life"))
######################################################################################################  
png("Plots/Fluoxetine_analysis_half_life_7d.png", width = 5, height = 5, units = "in", res = 350)
G3
dev.off()
######################################################################################################
# 4. Fluoxetine meta analysis
flag_fluoxetine_meta <- which(model_settings$intervention == "Fluoxetine_meta")
effect_fluoxetine_meta <- (do.call("rbind", effect_ests[flag_fluoxetine_meta]))

Trt_meta <- row.names(effect_fluoxetine_meta)
effect_fluoxetine_meta <- data.frame(effect_fluoxetine_meta, Trt_meta)

effect_fluoxetine_meta$model <- rep(model_settings$mod[flag_fluoxetine_meta], each = length(unique(Trt_meta)))
effect_fluoxetine_meta$model <- as.factor(effect_fluoxetine_meta$model)
levels(effect_fluoxetine_meta$model) <- c("Linear", "Non-linear")
effect_fluoxetine_meta$model <- factor(effect_fluoxetine_meta$model, levels = rev(c("Linear", "Non-linear")))


effect_fluoxetine_meta$Dmax <- rep(model_settings$Dmax[flag_fluoxetine_meta], each = length(unique(Trt_meta)))
effect_fluoxetine_meta$Dmax <- as.factor(effect_fluoxetine_meta$Dmax)
levels(effect_fluoxetine_meta$Dmax) <- c("5 days", "7 days")

colnames(effect_fluoxetine_meta) <- c("L95", "L80", "med", "U80", "U95", "Trt","model", "Dmax")
row.names(effect_fluoxetine_meta) <- NULL

effect_fluoxetine_meta$Trt <- factor(effect_fluoxetine_meta$Trt, levels = c("Ivermectin", "Favipiravir", "Fluoxetine",
                                                                            "Molnupiravir", "Remdesivir", "Nirmatrelvir + Ritonavir"))
levels(effect_fluoxetine_meta$Trt)[6] <- "Nirmatrelvir"

G4 <- ggplot(effect_fluoxetine_meta[effect_fluoxetine_meta$model == "Linear" & effect_fluoxetine_meta$Dmax == "5 days",], aes(x = Trt, y = med, col = Dmax)) +
  geom_point(position = position_dodge(width = 0.5), size = 3) +
  geom_rect(aes(ymin = 0.6, ymax = 1.2, xmin = 0, xmax = 7), fill = "gray", alpha = 0.05, col = NA) +
  theme_bw() +
  coord_flip() +
  geom_errorbar(aes(ymin = L95, ymax = U95), width = 0, position = position_dodge(width = 0.5)) +
  geom_errorbar(aes(x = Trt, ymin = L80, ymax = U80),position = position_dodge(width = 0.5), width = 0, linewidth = 1) +
  geom_point(position = position_dodge(width = 0.5), size = 3) +
  geom_hline(yintercept = 1, col = "red", linetype = "dashed") +
  scale_color_manual(values = c("#BB2525", "#191D88"), name = "Follow-up duration") +
  scale_shape_manual(values = c(16,17), name = "Model", guide = "none") +
  scale_y_continuous(labels = formatter, limits = c(0.6, 2.8), expand = c(0,0),
                     breaks = seq(0.8,2.8,0.2)) +
  ylab("Change in rate of viral clearance (%)") +
  xlab("") + 
  theme(axis.title  = element_text(face = "bold"),
        plot.title = element_text(face = "bold"),
        legend.position = "bottom",
        plot.margin = unit(c(0.2, 0.2, 0.2, 0.2), 
                           "inches")) +
  ggtitle("Linear model")
######################################################################################################  
png("Plots/Fluoxetine_meta_analysis_5days.png", width = 6, height = 6, units = "in", res = 350)
G4
dev.off()
######################################################################################################
effect_fluoxetine_meta

G5 <- ggplot(effect_fluoxetine_meta[effect_fluoxetine_meta$model == "Linear" & effect_fluoxetine_meta$Dmax == "5 days",], 
             aes(x = Trt, y = med, col = Trt)) +
  geom_point(position = position_dodge(width = 0.5), size = 3) +
  geom_rect(aes(ymin = 0.6, ymax = 1.2, xmin = 0, xmax = 7), fill = "gray", alpha = 0.05, col = NA) +
  theme_bw() +
  coord_flip() +
  geom_errorbar(aes(ymin = L95, ymax = U95), width = 0, position = position_dodge(width = 0.5), linewidth = 0.75) +
  geom_errorbar(aes(x = Trt, ymin = L80, ymax = U80),position = position_dodge(width = 0.5), width = 0, linewidth = 1.8) +
  geom_point(position = position_dodge(width = 0.5), size = 4) +
  geom_hline(yintercept = 1, col = "red", linetype = "dashed") +
  scale_color_manual(values =  c("#FF2626", "#A03C78", "#ED8E7C", "#1C6DD0", "#FFC95F", "#93D9A3")) +
  scale_shape_manual(values = c(16,17), name = "Model", guide = "none") +
  scale_y_continuous(labels = formatter, limits = c(0.6, 2.8), expand = c(0,0),
                     breaks = seq(0.8,2.8,0.2)) +
  ylab("Change in rate of viral clearance (%)") +
  xlab("") + 
  theme(axis.title  = element_text(face = "bold"),
        plot.title = element_text(face = "bold"),
        legend.position = "none",
        plot.margin = unit(c(0.2, 0.2, 0.2, 0.2), 
                           "inches")) +
  ggtitle("Linear model")

G5
######################################################################################################  
png("Plots/Fluoxetine_meta_analysis_by_drug.png", width = 5, height = 5, units = "in", res = 350)
G5
dev.off()
######################################################################################################  