#! /apps/R/4.2.2/bin/Rscript
source("tsir_run_functions.R")
library(tsiR)
library(tidyverse)
library(kernlab)
set.seed(10161993)
writeLines(deparse(runtsir), "runtsir.R")



births <- read_csv("../../../data/data_from_measles_LASSO/births_urban.csv") %>%
    rename("year" = X) %>% 
    pivot_longer(2:ncol(.), names_to = "city", values_to = "births") %>%
    mutate(births = births / 26)

inf_pop_urb <- read_csv("../../../data/data_from_measles_competing_risks/inferred_pop_urban.csv") %>%
    rename("time" = `...1`) %>% 
    pivot_longer(2:ncol(.), names_to = "city", values_to = "pop")

cases <- read_csv("../../../data/data_from_measles_LASSO/cases_urban.csv") %>%
    rename("time" = `...1`) %>% 
    pivot_longer(2:ncol(.), names_to = "city", values_to = "cases") %>% 
    mutate(year = floor(time))

all_cities <- cases %>% 
    left_join(births, by = c("year", "city")) %>% 
    left_join(inf_pop_urb, by = c("time", "city")) %>% 
    mutate(time = 1900 + time) %>% 
    select(-year)


pops <- inf_pop_urb[inf_pop_urb$time == min(inf_pop_urb$time), ]
top_5 <- pops[order(pops$pop, decreasing = T), ]$city[1:10]
random_5 <- sample(pops$city[!(pops$city %in% top_5)], 10)
cities_to_fit <- pops$city

#fit tsir on each city separately
for (i in cities_to_fit) {
    df_to_fit <- all_cities[all_cities$city == i, ] %>% 
        select(-city)

    k <- 52
    tlag <- 130
    all_dat_df <- get_preds_one_city(dat = df_to_fit, 
                                     train_index = k + tlag, k = k)

    saveRDS(all_dat_df, paste0("../../../output/data/tsir/uk/raw/tsir_", i, "_test_fit.rds"))
    #write.csv(all_dat_df, paste0("../../output/data/tsir_no_train/tsir_", i, "_test_fit.csv"))
    writeLines(c("#################", "", "", paste0(i, " fit complete"), "", "", "#################"))
}



