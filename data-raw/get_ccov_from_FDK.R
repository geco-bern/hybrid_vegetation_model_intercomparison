# This script requires access to CRU cloud cover data at "/data_2/FluxDataKit/FDK_inputs/cloud_cover/"
# and with the LEMONTREE input SITES located at "data-raw/SITES/FLUXDATAKIT/hourly_inputs_with_LAI"
# it generates the cloud cover time series for each site
# and stores them as '../data/ccov_LEMONTREE_SITES.csv'

# Get list of sites
csv_files <- list.files(
  path = here::here("data-raw/SITES/FLUXDATAKIT/hourly_inputs_with_LAI"),
  include.dirs = FALSE,
  recursive = FALSE,
  full.names = TRUE)

csv_files <- csv_files[grepl(".csv$",csv_files)] # remove directories, only keep csv
csv_files <- csv_files[!grepl("GuyaFlux.csv",csv_files)] # remove GuyaFlux.csv with 75 columns

LEMONTREE_SITES_hourly_df <- readr::read_csv(csv_files)

needed_sites <- unique(LEMONTREE_SITES_hourly_df$sitename)

# Get ccov for these sites based on FluxDataKit (uses either ERA5 or CRU data)

#NOTE: below function is copied from FluxDataKit, but extended with 'source' column
#' Process cloud cover data to return daily cloud cover values
#' for a given date range and (flux) site.
#'
#' @param path path with the ERA5 cloud cover data, by site
#' @param site site name to process
#' @param start_date start date of a data series
#' @param end_date end date of a data series
#'
#' @return daily mean cloud cover value (0-1), for a given date range
#' @export
my_fdk_process_cloud_cover <- function(path,site) {

  era_files <-  list.files(path, glob2rx(paste0(site, "*.nc")), full.names = TRUE)

  if (length(era_files) > 0){

    # load in the data using terra
    r <- suppressWarnings(terra::rast(era_files))

    # split out time, convert time to dates
    time <- terra::time(r)

    # take the mean value by day
    r <- terra::tapp(r, "days", fun = "mean")

    # put into data frame
    df <- terra::values(r, dataframe = TRUE)
    date <- as.Date(names(df), "d_%Y.%m.%d")

    data.frame(
      date = date,
      ccov = as.vector(unlist(df)),
      sitename = site,
      source = "ERA5"
    )

  } else {
    # read CRU cloud cover data
    readRDS("~/data/FluxDataKit/FDK_inputs/cloud_cover/df_cru.rds") |>
      dplyr::filter(sitename == site) |>
      tidyr::unnest(data) |>
      dplyr::select(date, ccov, sitename) |>
      mutate(source = "CRU")
  }
}

# Loop over needed files
needed_sites <- as.list(needed_sites)
names(needed_sites) <- needed_sites

ccov_list <- needed_sites |>
  purrr::map(~(
    my_fdk_process_cloud_cover(
      path = "/data_2/FluxDataKit/FDK_inputs/cloud_cover/",
      site = .x
      )
    )
  )

# Save as csv
readr::write_csv(
  ccov_list |> bind_rows(),
  here::here("data/ccov_LEMONTREE_SITES.csv")
)
