# This script requires access to the LEMONTREE input SITES data
# located at "data-raw/SITES/FLUXDATAKIT/hourly_inputs_with_LAI"
#
# The script aggregates the hourly data to daily (stored in '../data/INPUTS_DD/')
# and generates the rsofun drivers storing them at
# '../data/rsofun_drivers_LEMONTREE_SITES_1.csv' and
# '../data/rsofun_drivers_LEMONTREE_SITES_2.csv'


####   1.2 Models inputs: /rds/general/project/lemontree/live/source/inter_compar_HB/SITES/FLUXDATAKIT/hourly_inputs_with_LAI
####   - LAI from sentinel 2 (available from 20/19 onwards)
####   - climate from in situ measurement
####   - soil moisture from SPLASH (available on demand)

library(readr)
library(tidyverse)
library(lubridate)
library(FluxDataKit)
source(here::here("R/my_fdk_format_drivers.R"))
source(here::here("R/write_rsofun_driver.R"))

# need:
# example: rsofun::p_model_drivers
#  - sitename:     c("BE-Bra", "BE-Lon", "BE-Vie", "CH-Cha", "CH-Fru", "CH-Lae",
#                    "CH-Oe2", "CZ-BK1", "DE-Geb", "DE-Gri", "DE-Hai", "DE-Kli", "DE-Obe",
#                    "DE-Tha", "FI-Let", "GF-Guy", "IT-BCi", "IT-Lav", "IT-SR2", "US-GLE",
#                    "US-Ha1", "US-MMS", "US-Ne1", "US-UMd", "US-Var", "US-Wkg")
#  - params_siml:  tibble::tibble(
#                    spinup = TRUE,
#                    spinupyears = 10,
#                    recycle = 1,
#                    outdt = 1,
#                    ltre = FALSE,
#                    ltne = FALSE,
#                    ltrd = FALSE,
#                    ltnd = FALSE,
#                    lgr3 = TRUE,
#                    lgn3 = FALSE,
#                    lgr4 = FALSE,
#                  )
#  - site_info:   tibble::tibble(lon = 3.5957, lat = 43.7413, elv = 270, whc = 432.375)
#  - forcing:     # A tibble: 2,190 × 13
#                   date        temp   vpd      ppfd netrad    patm  snow       rain  tmin  tmax fapar   co2  ccov
#                   <date>     <dbl> <dbl>     <dbl>  <dbl>   <dbl> <dbl>      <dbl> <dbl> <dbl> <dbl> <dbl> <dbl>
#                 1 2007-01-01 10.0   183. 0.000106    4.17  99944.     0 0.0000255   7.12 13.0  0.605  384.     0
#                 2 2007-01-02  8.42  417. 0.000192  -22.2   99992.     0 0.00000694  6.79  9.33 0.603  384.     0
#                 3 2007-01-03  9.13  566. 0.000187  -16.6  100075      0 0           4.21 11.2  0.600  384.     0
#                 4 2007-01-04 10.1   375. 0.0000828 -16.8   99338.     0 0           3.96 12.2  0.598  384.     0
#                 5 2007-01-05 10.7   508. 0.000183   -6.60  99419.     0 0           9.26 11.4  0.596  384.     0


# define inputs ----
input_file_ccov <- here::here("data/ccov_LEMONTREE_SITES.csv")
input_dir_hourly <- here::here("data-raw/SITES/FLUXDATAKIT/hourly_inputs_with_LAI")
FluxDataKit::fdk_site_info

output_dir_DD <- here::here("data/INPUTS_DD/fluxnet") # NOTE: because of hardcoding in FluxDataKit::fdk_format_drivers a subfolder fluxnet is required
dir.create(output_dir_DD, recursive = TRUE, showWarnings = FALSE)

output_file_drivers <- here::here("data/rsofun_drivers_LEMONTREE_SITES.csv")


# load cloud-cover data that was ingested with 'data-raw/get_ccov_from_FDK.R' from ERA5 ----
ccov_df <- readr::read_csv(input_file_ccov)


# load input forcing data ----
csv_files <- list.files(
  path = input_dir_hourly,
  include.dirs = FALSE,
  recursive = FALSE,
  full.names = TRUE)

csv_files <- csv_files[grepl(".csv$",csv_files)] # remove directories, only keep csv
csv_files <- csv_files[!grepl("GuyaFlux.csv",csv_files)] # remove GuyaFlux.csv with 75 columns

LEMONTREE_SITES_hourly_df <- readr::read_csv(csv_files)
# this will be transformed to daily input values further below



# define params_siml: ----
params_siml <- tibble::tibble(
  spinup      = TRUE, # FDK default: to bring soil moisture to steady state
  spinupyears = 10,   # FDK default: 10 is enough for soil moisture.
  recycle     = 1,    # FDK default: number of years recycled during spinup
  outdt       = 1,    # FDK default: periodicity of output. Chose integer greater than 1 to aggregate outputs.
  ltre = FALSE,       # FDK default. TODO: is anything not compatible with the default values?
  ltne = FALSE,       # FDK default. TODO: is anything not compatible with the default values?
  ltrd = FALSE,       # FDK default. TODO: is anything not compatible with the default values?
  ltnd = FALSE,       # FDK default. TODO: is anything not compatible with the default values?
  lgr3 = TRUE,        # FDK default. TODO: is anything not compatible with the default values?
  lgn3 = FALSE,       # FDK default. TODO: is anything not compatible with the default values?
  lgr4 = FALSE,       # FDK default. TODO: is anything not compatible with the default values?
)


# load site_info: ----
site_info <- FluxDataKit::fdk_site_info |>
  # select sites we need
  filter(sitename %in% LEMONTREE_SITES_hourly_df$sitename) |>
  # select columns we need
  select(sitename, lon, lat, elv, whc)



# prepare input forcing data ----
# This follows the last two steps of FluxDataKit '03_data_generation.Rmd'
# respectively '00_batch_convert_LSM_data.R' and '02_batch_format_rsofun_drivers.R':
#   - fdk_downsample_fluxnet()
#   - fdk_format_drivers()


## aggregate to daily data ----

for (site in unique(LEMONTREE_SITES_hourly_df$sitename)){
  print(sprintf("%s: start downscaling of site: %s",Sys.time(), site))

  # Prepare use of FluxDataKit::fdk_downsample_fluxnet()
  df <- LEMONTREE_SITES_hourly_df |>
    ungroup() |>
    dplyr::filter(sitename == !!site)  |>
    # workarounds to use fdk_downsample_fluxnet:
    dplyr::rename(TIMESTAMP_START = time) |>
    mutate(TA_F_MDS_QC = 1,    # mark as good-quality gap-filled otherwise filtered out
           VPD_F_MDS_QC = 1,   # mark as good-quality gap-filled otherwise filtered out
           SW_IN_F_MDS_QC = 1, # mark as good-quality gap-filled otherwise filtered out
           LW_IN_F_MDS_QC = 1) # mark as good-quality gap-filled otherwise filtered out

  FluxDataKit::fdk_downsample_fluxnet(df, site, out_path = output_dir_DD)
}


## format as rsofun drivers ----

# NOTE: because of hardcoding in FluxDataKit we use
#       my_fdk_format_drivers() instead of FluxDataKit::fdk_format_drivers().
driver_data <- my_fdk_format_drivers(
  site_info = FluxDataKit::fdk_site_info |>
    dplyr::filter(sitename %in% LEMONTREE_SITES_hourly_df$sitename),
  params_siml = params_siml,
  path = gsub("/fluxnet$","",output_dir_DD), # NOTE: because of hardcoding inside FluxDataKit a subfolder 'fluxnet' is added
  ccov = ccov_df |> select(-source),
  verbose = TRUE
)

## write as human-readable drivers ----
write_rsofun_driver(driver_data, output_file_drivers)
# driver_data_restored <- read_rsofun_driver(output_file_drivers)
# all.equal(driver_data, driver_data_restored) # check

