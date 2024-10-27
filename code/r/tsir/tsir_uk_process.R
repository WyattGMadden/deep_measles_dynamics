library(tidyverse)

#merge tsir data sets
process_data <- function(loc, k) {
    dat <- readRDS(loc)
    dat$city <- substr(loc, 39, nchar(loc) - 13)
    #filter for speed. need to process all later
    dat <- dat[dat$k == k, ]
    return(dat)
}


process_all_k <- function(k) {
    city_data_list <- lapply(list.files("../../../output/data/tsir/uk/raw", full.names = T), 
                         function(x) process_data(loc = x, k = k))

    tsir_dat <- Reduce(rbind, city_data_list) %>% 
        rename(tsir = cases) %>% 
        filter(k == k)

    write.csv(tsir_dat, paste0("../../../output/data/tsir/uk/processed/tsir_", k, ".csv"))

    print(k)
}

k_select <- c(1, 4, 12, 20, 34, 52)
lapply(k_select, process_all_k)


tsir_dat <- list.files("../../../output/data/tsir/uk/processed/", full.names = T) %>% 
    lapply(function(x) read_csv(x) %>% mutate(k = substr(x, 46, nchar(x) - 4))) %>% 
    {Reduce(rbind, .)} %>% 
    select(2:ncol(.))





write_csv(tsir_dat, "../../../output/data/basic_nn_optimal/tsir_preds_processed.csv")
