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
df_result <- runread_pmodel_f(
  valid_drivers,
  par = params_modl,
  makecheck = TRUE,
  parallel = FALSE
)
df_result |> select(-site_info) |> unnest(data) |>
  readr::write_csv(here::here("data/rsofun_raw_results_LEMONTREE_SITES.csv"))



# TODO: what to do of sites with incomplete years?
# TODO: fix bug. Error when trying to simulate sites with incomplete years instead of warning() and returning NA.
# debug(runread_pmodel_f)
# debug(run_pmodel_f_bysite)
# df_result <- runread_pmodel_f(
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


# Unit transformation
M_C_g_mol   = 12 # g/mol
M_H2O_g_mol = 18 # g/mol
g_kg = 1000      # g/kg

df_output <- df_result |> select(-site_info) |> unnest(data) |>
  mutate(sitename = sitename,
         date     = date,
         gpp_umolCm2s            = gpp / 86400 / M_C_g_mol * 10^6,
                                            # NOTE: from gC/m2/d to umolC/m2/s
         evsp_umolH2Om2s         = NA,      # NOTE: from mm/d == kg/m2/d to umolH2O/m2/s
         trans_umolH2Om2s        = NA,      # NOTE: from mm/d == kg/m2/d to umolH2O/m2/s
         evapotrans_umolH2Om2s   = aet / 86400 * g_kg / M_H2O_g_mol * 10^6,
                                            # NOTE: from mm/d == kg/m2/d to umolH2O/m2/s
         mrso_kgm2        = wcont,          # NOTE: mm == kg/m2
         chi__            = chi,
         vcmax25_umolCm2s = vcmax25*10^6,   # NOTE: from molC/m2/s to umolC/m2/s
         jmax25_umolCm2s  = jmax25*10^6) |> # NOTE: from molC/m2/s to umolC/m2/s
  select(sitename,
         date,
         gpp_umolCm2s,
         evsp_umolH2Om2s,
         trans_umolH2Om2s,
         evapotrans_umolH2Om2s,
         mrso_kgm2,
         chi__,
         vcmax25_umolCm2s,
         jmax25_umolCm2s)

# save as CSV and upload manually
# NOTE: do we need to append again 29 Feb of leap years ??

# # combined csv:
# readr::write_csv(
#   df_output,
#   here::here("data/rsofun_results_LEMONTREE_SITES.csv"))

# per-site csv:
df_output |>
  group_split(sitename) %>%
  purrr::map(.f = function(subdf){
    readr::write_csv(
      x = subdf,
      file = here::here(paste0("data/rsofun_results_",first(subdf$sitename),".csv")))
  })



# NOTE: our rsofun outputs are reduced in temporal extent
#       because our code requires complete years
dplyr::full_join(
  df_output |> group_by(sitename) |> summarise(days_simulated = n()),
  drivers |> group_by(sitename) |> summarise(days_requested = purrr::map(forcing, nrow) |> unlist())
) |> print(n=26)
  # # A tibble: 26 × 3
  #    sitename days_simulated days_requested
  #    <chr>             <int>          <int>
  #  1 BE-Bra              730            730
  #  2 BE-Lon              730            730
  #  3 BE-Vie              730            730
  #  4 CH-Cha              730            730
  #  5 CH-Fru              730            730
  #  6 CH-Lae              365            719    xxx reduced
  #  7 CH-Oe2              730            730
  #  8 CZ-BK1              365            726    xxx reduced
  #  9 DE-Geb              730            730
  # 10 DE-Gri              365            372    xxx reduced
  # 11 DE-Hai              365            722    xxx reduced
  # 12 DE-Kli              730            730
  # 13 DE-Obe              730            730
  # 14 DE-Tha              365            704    xxx reduced
  # 15 FI-Let              730            730
  # 16 GF-Guy              365            725    xxx reduced
  # 17 IT-BCi              730            730
  # 18 IT-Lav              730            730
  # 19 IT-SR2              730            730
  # 20 US-GLE              365            639    xxx reduced
  # 21 US-Ha1              730            730
  # 22 US-MMS              730            730
  # 23 US-Ne1              730            730
  # 24 US-UMd             1095           1095
  # 25 US-Var              730           1029    xxx reduced
  # 26 US-Wkg             1095           1095

