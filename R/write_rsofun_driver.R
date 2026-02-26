# write_rsofun_driver(driver_data, file.path(tempdir(), "rsofun_drivers.csv"))
# driver_data_restored <- read_rsofun_driver(file.path(tempdir(), "rsofun_drivers.csv"))
# driver_data_restored <- read_rsofun_driver(file.path(tempdir(), "rsofun_drivers_1.csv"))
# driver_data_restored <- read_rsofun_driver(file.path(tempdir(), "rsofun_drivers_2.csv"))

write_rsofun_driver <- function(driver, file){
  stopifnot(grepl(".csv$",file))
  file1 <- gsub(".csv$","_1.csv",file)
  file2 <- gsub(".csv$","_2.csv",file)

  # split into part without forcing and part with forcing and unnest
  driver_data |> dplyr::select(-forcing) |>
    tidyr::unnest(c(params_siml,
                    site_info),
                  names_sep = "_") |>
    readr::write_csv(file1)
  driver_data |> dplyr::select(sitename, forcing) |>
    tidyr::unnest(c(forcing),
                  names_sep = "_") |>
    readr::write_csv(file2)
}

read_rsofun_driver <- function(file){
  stopifnot(grepl(".csv$",file))
  basefile <- gsub("(_[12])*.csv$","",file)
  file1 <- paste0(basefile, "_1.csv"); stopifnot(file.exists(file1))
  file2 <- paste0(basefile, "_2.csv"); stopifnot(file.exists(file2))

  dplyr::left_join(
    readr::read_csv(file1) |>
      tidyr::nest(
        params_siml = dplyr::starts_with("params_siml_"),
        site_info   = dplyr::starts_with("site_info_"),
        .names_sep = "_"),
    readr::read_csv(file2) |>
      tidyr::nest(
        forcing = dplyr::starts_with("forcing"),
        .names_sep = "_"),
    by = dplyr::join_by(sitename))
}
