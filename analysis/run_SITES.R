# FROM THE INTERCOMPARISON INSTRUCTIONS:

# 1 Sites:
#   1.1 Criteria of selection:
#   - score of a minimum 2 for dominant land cover type and Sensor location bias based
#     on Fang, J., Chen, B. et al. Assessing Spatial Representativeness of Global Flux
#     Tower Eddy-Covariance Measurements Using Data from FLUXNET2015. Sci Data 11,
#     569 (2024). https://doi.org/10.1038/s41597-024-03291-3 (note that the study uses LANDSAT)
#
#   1.2 Models inputs: /rds/general/project/lemontree/live/source/inter_compar_HB/SITES/FLUXDATAKIT/hourly_inputs_with_LAI
#   - LAI from sentinel 2 (available from 20/19 onwards)
#   - climate from in situ measurement
#   - soil moisture from SPLASH (available on demand)
#
# 1.3 Models outputs:
#   cd /rds/general/project/lemontree/live/source/inter_compar_HB/SITES/OUTPUTS
#   mkdir YOUR_MODEL
#   cd YOUR_MODEL
#   put Model_Site.csv

# time frame : from 2019 until end of data
# format: cvs, 1 file per site, variables:
# outname       frequency units         comment  name
# gpp           hourly    umolCO2/m2/s           Gross Primary Production
# evsp          hourly    umolH2O/m2/s           Evaporation
# trans         hourly    umolH2O/m2/s           Transpiration
# evapotrans    hourly    umolH2O/m2/s           Total Evapo-Transpiration
# mrso          hourly    kg/m2                  Total Soil Moist. Content
# chi           hourly    (-)                    Ci_Ca_ratio
# vcmax25       hourly    umol/s/m2              Maximum rate of carboxylation in a leaf at 25degC
# jmax25        hourly    umol/s/m2              Maximum electron transport rates at 25degC

library(rsofun)
library(tidyverse)
source(here::here("R/write_rsofun_driver.R"))

# prepare input data set ----
# see file at '../data-raw/01_get_ccov_from_FDK.R'
# see file at '../data-raw/02_generate_drivers.R'


# load input data set ----
drivers <- read_rsofun_driver(here::here("data/rsofun_drivers_LEMONTREE_SITES.csv"))


# approximate fapar from LAI ----
drivers <- drivers |>
  tidyr::unnest(forcing) |>
  dplyr::mutate(fapar = 1 - exp(-0.5*LAI)) |> select(-LAI)|>       # TODO: double check that formula is 1 - exp(-LAI/2) note the minus.
  tidyr::nest(forcing = -c(sitename, params_siml, site_info))


# overwrite simulation parameters ----
drivers <- drivers |>
  mutate(params_siml = list(tibble::tibble(
    spinup = TRUE,
    spinupyears = 10,
    recycle = 1,
    outdt = 1,
    ltre = FALSE,
    ltne = FALSE,
    ltrd = FALSE,
    ltnd = FALSE,
    lgr3 = TRUE,
    lgn3 = FALSE,
    lgr4 = FALSE,
  )))


# run model ----
params_modl <- list(

  # TODO: overwrite with Paredes et al...:

  kphio              = 0.04998, # setup ORG in Stocker et al. 2020 GMD
  kphio_par_a        = 0.01,  # set to zero to disable temperature-dependence of kphio, setup ORG in Stocker et al. 2020 GMD
  kphio_par_b        = 1.0,
  soilm_thetastar    = 0.6 * 240,  # to recover old setup with soil moisture stress
  soilm_betao        = 0.01,
  beta_unitcostratio = 146.0,
  rd_to_vcmax        = 0.014, # value from Atkin et al. 2015 for C3 herbaceous
  tau_acclim         = 30.0,
  kc_jmax            = 0.41
)


# only keep complete years with 365 days (note: Feb 29 is already removed)
valid_drivers <-drivers |>
  tidyr::unnest(forcing) |>
    mutate(year = lubridate::year(date)) |>
    group_by(sitename, year) |> filter(n() == 365) |> ungroup() |>
  tidyr::nest(forcing = -c(sitename, params_siml, site_info))

invalid_drivers <- drivers |>
  filter(purrr::map(forcing, ~(nrow(.x) %% 365 != 0)) |> unlist())


# run model
df_output <- runread_pmodel_f(
  valid_drivers,
  par = params_modl,
  makecheck = TRUE,
  parallel = FALSE
)
df_output |> select(-site_info) |> unnest(data) |>
  readr::write_csv(here::here("data/rsofun_raw_results_LEMONTREE_SITES.csv"))



# TODO: what to do of sites with incomplete years?
# TODO: fix bug. Error when trying to simulate sites with incomplete years instead of warning() and returning NA.
# debug(runread_pmodel_f)
# debug(run_pmodel_f_bysite)
# df_output <- runread_pmodel_f(
#   invalid_drivers,
#   par = params_modl,
#   makecheck = TRUE,
#   parallel = FALSE
# )



# postprocess and output ----

# time frame : from 2019 until end of data
# format: cvs, 1 file per site, variables:
  # outname       frequency units         comment  name
  # gpp           hourly    umolCO2/m2/s           Gross Primary Production
  # evsp          hourly    umolH2O/m2/s           Evaporation
  # trans         hourly    umolH2O/m2/s           Transpiration
  # evapotrans    hourly    umolH2O/m2/s           Total Evapo-Transpiration
  # mrso          hourly    kg/m2                  Total Soil Moist. Content
  # chi           hourly    (-)                    Ci_Ca_ratio
  # vcmax25       hourly    umol/s/m2              Maximum rate of carboxylation in a leaf at 25degC
  # jmax25        hourly    umol/s/m2              Maximum electron transport rates at 25degC

df_output |> select(-site_info) |> unnest(data) |>
  # TODO: ensure units correspond to required output
  select(sitename,
         date,
         gpp_UNIT         = gpp,
         evsp_UNIT        = aet,
         trans_UNIT       = aet,
         evapotrans_UNIT  = aet,
         mrso_UNIT        = wcont,
         chi__            = chi,
         vcmax25_UNIT     = vcmax25,
         jmax25_UNIT      = jmax25)

#TODO: save as CSV and upload
# NOTE: do we need to append again 29 Feb of leap years ??
