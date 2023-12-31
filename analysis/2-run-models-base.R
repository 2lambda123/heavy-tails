# This file runs the base Gompertz models
library(rstan)

source("1.5-compile-fit-function.R")
source("1.6-extract-function.R")

model <- readRDS("stan-gomp.rds")
gpdd <- readRDS("gpdd-clean.rds")
id <- "gomp-base"

stan_pars <- c("lambda", "sigma_proc", "nu", "b")

options(mc.cores = min(c(4L, parallel::detectCores())))

fit_gpdd_model(gpdd_dat = gpdd, model = model, sub_folder = id,
  pars = stan_pars, control = list(adapt_delta = 0.95))

out <- plyr::ldply(unique(gpdd$main_id), extract_model,
  sub_folder = id, get_phi = FALSE, type = "gompertz")

saveRDS(out, file = paste0(id, "-hat.rds"))
