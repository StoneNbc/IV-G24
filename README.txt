Group 24 Interface – Launch Guide
=================================

Overview
--------
This package delivers the Group 24 interactive experience for Melbourne residents and visitors. The primary entry point is the Shiny application in `app.R`, which embeds the live Tableau visualisations published to Tableau Public.

Package Contents
----------------
- `app.R` – combined Shiny interface (launch this file).
- `datasets/` – source CSV files required by the app.
- `img/` – image assets used by the interface.
- `tableau.twbx` – packaged Tableau workbook for reference (the Shiny app already embeds the published version).
- Project report files (`PROJECT_REPORT.md`, `report.md`, `report.pdf`, `draft.md`) – documentation only.

Prerequisites
-------------
1. R version 4.1 or newer.
2. RStudio (recommended) or the command-line R interpreter.
3. Internet access the first time you run the app (to install any missing packages and to reach the OSRM routing service and Tableau Public embed).
4. System libraries for the `sf` package (GDAL/GEOS/PROJ). These are already present on most institutional lab machines; if you are on macOS, install them via Homebrew (`brew install gdal proj geos`) before running R if needed.

Before You Start
----------------
1. Unzip the submission archive into a writable directory (keep all files in the same relative locations).
2. Open the unzipped folder that contains this README.

Launching the Shiny Interface
-----------------------------
Option A – RStudio:
1. Open RStudio.
2. Use `File` → `Open File...` to open `app.R`.
3. Click the `Run App` button (top-right of the script editor). The interface will launch in the Viewer or your default browser.

Option B – Command Line:
1. Open a terminal and set the working directory to the unzipped folder.
2. Run:
   `Rscript -e "shiny::runApp('.', launch.browser = TRUE)"`
   The command will install any missing packages automatically and open the interface in your browser.

Using the Tableau Workbook (Optional)
-------------------------------------
If you wish to inspect the Tableau story locally, open `tableau.twbx` in Tableau Desktop 2021.4 or newer. This step is not required to mark the main interface because the Shiny app already embeds the published Tableau views.

Troubleshooting
---------------
- Package installation prompts: the script auto-installs missing R packages from CRAN. Accept any prompts that appear.
- Slow map routing: the OSRM routing service is called live; retry if the public server is temporarily busy.
- Firewall limitations: ensure outbound HTTPS access to `public.tableau.com` and `router.project-osrm.org`.

Support
-------
For marking queries, please contact the student team via the LMS messaging channel.
