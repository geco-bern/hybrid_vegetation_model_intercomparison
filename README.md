# Hybrid Vegetation Model Intercomparison

## Project Aim and Description

TBD

To reproduce prepare data with scripts in `data-raw` followed by running
`analysis/run_SITES.R`.

## Project Structure

### The R folder

The `R` folder contains R functions, not scripts. 

Functions are actions you need more than once, which can not be generated
easily with external packages and are tailored to your project.

### The src folder

The `src` folder contains scripts and code which is not R related, in packages
this folder often contains Fortran or C code which needs to be compiled. Here,
it is common to store bash or python functions which might assist in data
cleaning or data gathering which can't be done in R alone.

### The data-raw folder

The `data-raw` folder contains, as the name suggests, raw data and the scripts
to download and pre-process the data. This is data which requires significant
pre-processing to be of use in analysis. In other words, this data is not 
analysis ready (within the context of the project).

To create full transparency in terms of the source of this raw data it is best
to include (numbered) scripts to download and pre-process the data. Either in
these scripts, or in a separate README, include the source of the data (reference)
Ultimately, the output of the workflow in data-raw is data which is analysis ready.

It is best practice to store various raw data products in their own sub-folder,
with data downloading and processing scripts in the main `data-raw` folder.

```
data-raw/
├─ raw_data_product/
├─ 00_download_raw_data.R
├─ 01_process_raw_data.R
```

Where possible it is good practice to store output data (in `data`) either as human 
readable CSV files, or as R serialized files 
(generated using with the `saveRDS()` function).

It is common that raw data is large in size, which limits the option of storing
the data in a git repository. If this isn't possible this data can be excluded
from the git repository by explicitly adding directories to `.gitignore` to
avoid accidentally adding them.

When dealing with heterogeneous systems dynamic paths can be set to (soft) link
to raw-data outside the project directory.

### The data folder

The `data` folder contains analysis ready data. This is data which you can use,
as is. This often contains the output of a `data-raw` pre-processing workflow,
but can also include data which doesn't require any intervention, e.g. a land
cover map which is used as-is. Output from `data-raw` often undergoes a
dramatic dimensionality reduction and will often fit github file size limits. In
some cases however some data products will still be too large, it is recommended
to use similar practices as describe for `data-raw` to ensure transparency
on the sourcing of this data (and reproducible acquisition).

It is best to store data in transparently named sub-folders according to the
product type, once more including references to the source of the data where
possible. Once more, download scripts can be used to ensure this transparency
as well.

```
data/
├─ data_product/
├─ 00_download_data.R
```

### The analysis folder

The `analysis` folder contains, *surprise*, R scripts covering analysis of your
analysis ready data (in the `data` folder). These are R scripts with output
which is limited to numbers, tables and figures. It should not include R
markdown code!

It is often helpful to create additional sub-folders for statistics and figures,
especially if figures are large and complex (i.e. visualizations, rather than
graphical representations of statistical properties, such as maps). 

Scripts can have a numbered prefix to indicate an order of execution, but this
is generally less important as you will work on analysis ready data. If there
is carry over between analysis, either merge the two files or use numbered
prefixes.

```
analysis/
├─ statistics/
│  ├─ 00_random_forest_model.R
│  ├─ 01_random_forest_tuning.R
├─ figures/
│  ├─ global_model_results_map.R
│  ├─ complex_process_visualization.R
```

Output of the analysis routines can be written to file (`manuscript` folder) or
visualized on the console or plot viewer panel.

### Capturing your session state

If you want to ensure full reproducibility you will need to capture the state of the system and libraries with which you ran the original analysis. Note that you will have to execute all code and required libraries for `renv` to correctly capture all used libraries.

When setting up your project you can run:

``` r
# Initiate a {renv} environment
renv::init()
```

To initiate your static R environment. Whenever you want to save the state of your project (and its packages) you can call:

``` r
# Save the current state of the environment / project
renv::snapshot()
```

To save any changes made to your environment. All data will be saved in a project description file called a lock file (i.e. `renv.lock`). It is advised to update the state of your project regularly, and in particular before closing a project.

When you move your project to a new system, or share a project on github with collaborators, you can revert to the original state of the analysis by calling:

``` r
# On a new system, or when inheriting a project
# from a collaborator you can use a lock file
# to restore the session/project state using
renv::restore()
```

> NOTE: As mentioned in the {renv} documentation: "For development and collaboration, the `.Rprofile`, `renv.lock` and `renv/activate.R` files should be committed to your version control system. But the `renv/library` directory should normally be ignored. Note that `renv::init()` will attempt to write the requisite ignore statements to the project `.gitignore`." We refer to \@ref(learning-objectives-6) for details on github and its use.

