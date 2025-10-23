# Combined Shiny application providing a unified experience for Melbourne residents and visitors.

# ---- Auto-install missing packages ----
pkgs <- c(
  "shiny", "leaflet", "dplyr", "jsonlite", "geosphere",
  "readr", "tidyr", "DT", "stringr", "plotly", "forcats",
  "htmltools", "sf", "osrm", "base64enc"
)

missing <- pkgs[!(pkgs %in% installed.packages()[, "Package"])]
if (length(missing)) {
  install.packages(missing, repos = "https://cloud.r-project.org")
}

invisible(lapply(pkgs, library, character.only = TRUE))

options(osrm.server = "https://router.project-osrm.org/",
        osrm.profile = "car")

logo_path <- file.path("img", "logo.png")
logo_src <- if (file.exists(logo_path)) {
  base64enc::dataURI(file = logo_path, mime = "image/png")
} else {
  "logo.png"
}

hero_bg_path <- file.path("img", "background.jpg")
bg_image_src <- if (file.exists(hero_bg_path)) {
  base64enc::dataURI(file = hero_bg_path, mime = "image/jpeg")
} else {
  ""
}


# ---- Data loading helpers ----

load_bus_data <- function() {
  read_csv("datasets/bus-stops-for-melbourne-visitor-shuttle.csv", show_col_types = FALSE) %>%
    separate(`Co-ordinates`, into = c("lat", "lng"), sep = ",", convert = TRUE) %>%
    mutate(
      lat = as.numeric(lat),
      lng = as.numeric(lng),
      StopName = ifelse(!is.na(Name) & Name != "", Name, Name)
    ) %>%
    filter(!is.na(lat) & !is.na(lng))
}

load_tram_data <- function() {
  read_csv("datasets/city-circle-tram-stops.csv", show_col_types = FALSE) %>%
    separate(`Geo Point`, into = c("lat", "lng"), sep = ",", convert = TRUE) %>%
    mutate(
      lat = as.numeric(lat),
      lng = as.numeric(lng),
      StopName = ifelse(!is.na(name) & name != "", name, name)
    ) %>%
    filter(!is.na(lat) & !is.na(lng))
}

load_landmarks <- function() {
  raw <- read_csv("datasets/landmarks-and-places-of-interest-including-schools-theatres-health-services-spor.csv",
                  show_col_types = FALSE) %>%
    separate(`Co-ordinates`, into = c("lat", "lng"), sep = ",", convert = TRUE) %>%
    mutate(
      lat = as.numeric(lat),
      lng = as.numeric(lng)
    ) %>%
    filter(!is.na(lat) & !is.na(lng)) %>%
    filter(lat >= -37.834256, lat <= -37.799947, lng >= 144.935655, lng <= 144.987276)

  raw %>%
    transmute(
      Theme,
      `Sub Theme`,
      Sub.Theme = `Sub Theme`,
      SubTheme = `Sub Theme`,
      `Feature Name`,
      Feature.Name = `Feature Name`,
      FeatureName = `Feature Name`,
      lat,
      lng
    )
}

load_tram_tracks_data <- function() {
  read_csv("datasets/tram-tracks.csv", show_col_types = FALSE)
}

load_cafes <- function() {
  read_csv("datasets/cafes-and-restaurants-with-seating-capacity.csv", show_col_types = FALSE) %>%
    rename(
      TradingName = `Trading name`,
      Industry = `Industry (ANZSIC4) description`,
      SeatingType = `Seating type`,
      Seats = `Number of seats`,
      Lon = Longitude,
      Lat = Latitude
    ) %>%
    mutate(
      Lat = as.numeric(Lat),
      Lon = as.numeric(Lon),
      Seats = suppressWarnings(as.numeric(Seats))
    ) %>%
    filter(!is.na(Lat) & !is.na(Lon))
}

# Helper badge renderer for tables
badge <- function(text, bg = "#ecf5ff", fg = "#2c7be5") {
  sprintf(
    "<span style='background:%s;color:%s;padding:2px 8px;border-radius:10px;font-weight:600;'>%s</span>",
    bg, fg, htmltools::htmlEscape(text)
  )
}


# ---- Map rendering helpers ----

map_combined <- function(bus_data, tram_data, landmark_data, tram_tracks_data) {

  bus_icon <- makeIcon(
    iconUrl = "img/bus.png",
    iconWidth = 45, iconHeight = 45,
    iconAnchorX = 20, iconAnchorY = 40,
    popupAnchorX = 0, popupAnchorY = -30
  )

  tram_icon <- makeIcon(
    iconUrl = "img/tram.png",
    iconWidth = 35, iconHeight = 35,
    iconAnchorX = 10, iconAnchorY = 30,
    popupAnchorX = 0, popupAnchorY = -30
  )

  landmark_icon <- makeIcon(
    iconUrl = "img/landmark.png",
    iconWidth = 45, iconHeight = 40,
    iconAnchorX = 20, iconAnchorY = 40,
    popupAnchorX = 0, popupAnchorY = -40
  )

  base_map <- leaflet(options = leafletOptions(minZoom = 13, maxZoom = 18)) %>%
    addProviderTiles("CartoDB.Positron") %>%
    setView(lng = 144.9631, lat = -37.8136, zoom = 14)

  base_map <- base_map %>%
    addMarkers(
      lng = bus_data$lng, lat = bus_data$lat,
      group = "Bus Stops",
      popup = bus_data$Name,
      icon = bus_icon,
      clusterOptions = markerClusterOptions()
    )

  base_map <- base_map %>%
    addMarkers(
      lng = tram_data$lng, lat = tram_data$lat,
      group = "City Circle Tram Stops",
      popup = tram_data$name,
      icon = tram_icon,
      clusterOptions = markerClusterOptions()
    )

  base_map <- base_map %>%
    addMarkers(
      lng = landmark_data$lng, lat = landmark_data$lat,
      group = "Landmarks",
      popup = paste0("<b>", landmark_data$Feature.Name, "</b><br>",
                     "Theme: ", landmark_data$Theme, "<br>",
                     "Sub Theme: ", landmark_data$Sub.Theme),
      icon = landmark_icon,
      clusterOptions = markerClusterOptions()
    )

  for (i in seq_len(nrow(tram_tracks_data))) {
    try({
      shape_json <- fromJSON(tram_tracks_data$`Geo Shape`[i])
      coords <- shape_json$coordinates[[1]][[1]]
      if (length(coords) > 0) {
        base_map <- base_map %>%
          addPolylines(
            data = as.data.frame(coords),
            lng = ~V1, lat = ~V2,
            color = "grey", weight = 2, opacity = 0.8,
            group = "Tram Tracks"
          )
      }
    }, silent = TRUE)
  }

  base_map %>%
    addLayersControl(
      overlayGroups = c("Bus Stops", "City Circle Tram Stops", "Landmarks", "Tram Tracks"),
      options = layersControlOptions(collapsed = FALSE)
    )
}

get_osrm_route <- function(from, to, profile = "foot") {
  if (length(from) != 2 || length(to) != 2 || any(is.na(from)) || any(is.na(to))) {
    return(NULL)
  }
  src <- c(from[1], from[2])
  dst <- c(to[1], to[2])
  old_profile <- getOption("osrm.profile")
  options(osrm.profile = profile)
  on.exit(options(osrm.profile = old_profile), add = TRUE)
  tryCatch(
    {
      suppressWarnings(
        osrmRoute(
          src = src,
          dst = dst,
          overview = "full",
          returnclass = "sf"
        )
      )
    },
    error = function(e) {
      message("OSRM route failed: ", e$message)
      NULL
    }
  )
}

line_df <- function(p1, p2) {
  data.frame(lng = c(p1[1], p2[1]), lat = c(p1[2], p2[2]))
}

distance_with_fallback <- function(route_sf, fallback_distance) {
  if (!is.null(route_sf) && inherits(route_sf, "sf") && "distance" %in% names(route_sf)) {
    return(as.numeric(sum(route_sf$distance, na.rm = TRUE) * 1000))
  }
  fallback_distance
}

draw_route_segment <- function(proxy, route_sf, fallback_df, color, weight = 4, opacity = 0.8, dash = NULL) {
  if (!is.null(route_sf) && inherits(route_sf, "sf")) {
    proxy <- addPolylines(proxy, data = route_sf, color = color, weight = weight, opacity = opacity, dashArray = dash)
  } else {
    proxy <- addPolylines(proxy, data = fallback_df, lng = ~lng, lat = ~lat, color = color, weight = weight, opacity = opacity, dashArray = dash)
  }
  proxy
}


# ---- UI ----

app_styles <- '
  :root {
    --brand-primary: #1f3c88;
    --brand-secondary: #3d7ea6;
    --brand-accent: #f7b32b;
    --surface: #ffffff;
    --surface-muted: rgba(255,255,255,0.92);
  }
  body {
    font-family: "Source Sans Pro", "Helvetica Neue", Arial, sans-serif;
    background: linear-gradient(140deg, #f5f7ff 0%, #dde9ff 35%, #d3f0ff 100%);
    color: #1f2933;
    position: relative;
    min-height: 100vh;
  }
  body::before {
    content: "";
    position: fixed;
    top: -10px;
    left: -10px;
    right: -10px;
    bottom: -10px;
    background: none;
    filter: none;
    opacity: 0;
    transform: none;
    z-index: -2;
  }
  .page-shell {
    position: relative;
    z-index: 1;
  }
  .navbar.navbar-default {
    background: linear-gradient(130deg, #162852, var(--brand-secondary));
    border: none;
    box-shadow: 0 12px 32px rgba(18, 36, 76, 0.32);
    border-radius: 0;
    padding: 16px 34px;
    margin: 28px auto 30px;
    max-width: 1180px;
  }
  .brand-title {
    display: flex;
    align-items: center;
    gap: 14px;
  }
  .brand-title span {
    font-size: 1.55rem;
    letter-spacing: 0.6px;
    display: inline-flex;
    align-items: center;
  }
  .navbar .navbar-brand {
    color: #fdfdff !important;
    font-weight: 700;
    letter-spacing: 0.5px;
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 4px 0;
    line-height: 1.1;
  }
  .navbar .navbar-brand img {
    height: 48px;
    width: auto;
    border-radius: 10px;
    box-shadow: 0 6px 16px rgba(12, 25, 52, 0.28);
  }
  .navbar .nav > li > a {
    color: rgba(240,246,255,0.85) !important;
    font-weight: 600;
    transition: all 0.2s ease;
    border-radius: 18px;
    padding: 12px 18px;
  }
  .navbar .nav > li > a:hover,
  .navbar .nav > li.active > a,
  .navbar .nav > li.active > a:focus {
    color: #ffffff !important;
    background: rgba(255,255,255,0.18) !important;
    box-shadow: inset 0 0 0 1px rgba(255,255,255,0.2);
  }
  @media (min-width: 992px) {
    .navbar.navbar-default .container-fluid {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 28px;
      padding: 0;
    }
    .navbar .navbar-header {
      display: flex;
      align-items: center;
      gap: 18px;
      float: none;
    }
    .navbar .navbar-nav {
      display: flex;
      align-items: center;
      gap: 10px;
      margin: 0;
      float: none;
    }
    .navbar .navbar-nav > li {
      float: none;
    }
    .navbar .nav > li > a {
      padding: 10px 22px;
    }
  }
  @media (max-width: 991px) {
    .navbar.navbar-default {
      margin: 18px 16px 26px;
      padding: 14px 20px;
    }
    .navbar .navbar-brand img {
      height: 42px;
    }
    .navbar .navbar-brand {
      padding: 6px 0;
    }
  }
  .navbar .navbar-brand:hover {
    color: #ffffff !important;
  }
  .tab-content {
    padding-top: 0;
  }
  .title {
    text-align: center;
    font-size: 2.3em;
    font-weight: 700;
    padding: 16px;
    margin: 0 0 12px 0;
    color: #1d3557;
    background: transparent;
  }
  .sidebar {
    background: var(--surface-muted);
    padding: 18px 20px;
    border-radius: 14px;
    box-shadow: 0 14px 30px rgba(15, 23, 42, 0.15);
    backdrop-filter: blur(6px);
    cursor: move;
  }
  .sidebar h4 {
    margin-top: 4px;
    font-weight: 700;
    color: #1f2937;
  }
  #map {
    height: calc(100vh - 260px) !important;
    min-height: 520px;
    border-radius: 0;
    box-shadow: none;
  }
  .leaflet-control-layers {
    border-radius: 12px;
    box-shadow: 0 10px 24px rgba(15, 23, 42, 0.12) !important;
  }
  .map-page {
    padding: 4px 32px 40px;
  }
  .planner-toolbar {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(320px, 1fr));
    gap: 24px 28px;
    background: rgba(255,255,255,0.94);
    padding: 20px 24px;
    border-radius: 20px;
    box-shadow: 0 16px 32px rgba(30, 64, 175, 0.15);
    border: 1px solid rgba(67, 97, 238, 0.14);
    margin-bottom: 22px;
  }
  .planner-toolbar .toolbar-section {
    flex: 1 1 auto;
  }
  .planner-toolbar h4 {
    margin: 0 0 12px 0;
    font-weight: 700;
    color: #1f2937;
  }
  .toolbar-fields {
    display: flex;
    flex-wrap: wrap;
    gap: 12px;
    align-items: center;
  }
  .toolbar-fields .form-group {
    margin-bottom: 0 !important;
    flex: 1 1 220px;
    min-width: 200px;
  }
  .route-section {
    display: flex;
    flex-direction: column;
    gap: 14px;
  }
  .route-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 16px;
  }
  .route-header .primary-btn {
    margin-left: auto;
    min-width: 190px;
    height: 44px;
  }
  .route-header h4 {
    margin-bottom: 0;
  }
  .route-grid {
    width: 100%;
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
    gap: 16px;
    align-items: stretch;
  }
  .info-pair {
    display: flex;
    flex-direction: column;
    align-items: flex-start;
    gap: 6px;
    padding: 16px 18px;
    background: rgba(67, 97, 238, 0.08);
    border-radius: 16px;
    flex: 1 1 220px;
    min-height: 96px;
  }
  .info-label {
    font-weight: 700;
    color: #1f2937;
    letter-spacing: 0.2px;
  }
  .info-value {
    font-weight: 600;
    color: var(--brand-primary);
    font-size: 16px;
  }
  .landmark-pair {
    position: relative;
  }
  .landmark-pair .ghost-btn {
    align-self: flex-end;
    margin-top: auto;
  }
  .route-cta {
    display: flex;
    align-items: center;
    justify-content: center;
  }
  .route-cta .primary-btn {
    width: 100%;
    max-width: 240px;
    height: 48px;
  }
  .map-container {
    border-radius: 24px;
    overflow: hidden;
    box-shadow: 0 24px 48px rgba(15, 23, 42, 0.18);
  }
  .card {
    background: var(--surface);
    border-radius: 18px;
    padding: 24px 28px;
    margin-bottom: 28px;
    box-shadow: 0 10px 28px rgba(30, 64, 175, 0.12);
    border: 1px solid rgba(67, 97, 238, 0.08);
  }
  .insight-section {
    max-width: 1180px;
    margin: 0 auto;
  }
  .insight-hero {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
    gap: 26px;
    padding: 26px 32px;
    border-radius: 26px;
    margin-bottom: 28px;
    position: relative;
    overflow: hidden;
    box-shadow: 0 24px 40px rgba(17, 34, 64, 0.24);
    border: 1px solid rgba(255,255,255,0.18);
    color: #f8fbff;
  }
  .insight-hero::after {
    content: "";
    position: absolute;
    inset: 0;
    background: radial-gradient(circle at top right, rgba(255,255,255,0.18), transparent 55%);
    mix-blend-mode: screen;
    opacity: 0.85;
  }
  .insight-hero.transit-hero {
    background: linear-gradient(135deg, rgba(25, 55, 109, 0.92), rgba(64, 121, 207, 0.85));
  }
  .insight-hero.dining-hero {
    background: linear-gradient(135deg, rgba(142, 36, 170, 0.88), rgba(240, 101, 67, 0.82));
  }
  .insight-hero.planner-hero {
    background: linear-gradient(135deg, rgba(17, 80, 123, 0.9), rgba(67, 206, 162, 0.78));
  }
  .insight-hero .hero-text {
    position: relative;
    z-index: 1;
    display: flex;
    flex-direction: column;
    gap: 12px;
  }
  .insight-hero .hero-text h2 {
    margin: 0;
    font-size: 30px;
    font-weight: 700;
    letter-spacing: 0.4px;
  }
  .insight-hero .hero-text p {
    margin: 0;
    color: rgba(248, 252, 255, 0.9);
    line-height: 1.5;
  }
  .hero-visual {
    position: relative;
    z-index: 1;
    display: flex;
    flex-wrap: wrap;
    align-content: flex-end;
    gap: 16px;
  }
  .insight-badges {
    display: flex;
    flex-wrap: wrap;
    gap: 12px;
  }
  .insight-badge {
    background: rgba(255,255,255,0.14);
    padding: 10px 18px;
    border-radius: 999px;
    display: flex;
    flex-direction: column;
    gap: 2px;
    min-width: 160px;
    box-shadow: inset 0 0 0 1px rgba(255,255,255,0.25);
  }
  .insight-badge .badge-label {
    font-size: 12px;
    letter-spacing: 0.6px;
    text-transform: uppercase;
    opacity: 0.75;
    font-weight: 600;
  }
  .insight-badge .badge-value {
    font-size: 18px;
    font-weight: 700;
  }
  .insight-card .card-header {
    margin-bottom: 22px;
  }
  .insight-card .card-header h3 {
    margin: 0;
    color: #1d3557;
    font-weight: 700;
  }
  .insight-card .card-header p {
    margin-top: 8px;
    margin-bottom: 0;
    color: rgba(51, 65, 85, 0.82);
    max-width: 720px;
  }
  .insight-card .card-header .insight-badges {
    margin-top: 20px;
  }
  .filter-panel {
    background: rgba(67, 97, 238, 0.06);
    border-radius: 18px;
    padding: 18px 20px 10px;
    border: 1px solid rgba(67, 97, 238, 0.16);
    margin-bottom: 24px;
  }
  .filter-panel .filters,
  .filter-panel .filters-row {
    margin-bottom: 12px;
  }
  .insight-layout {
    display: grid;
    gap: 24px;
    grid-template-columns: repeat(auto-fit, minmax(320px, 1fr));
  }
  .insight-visual,
  .insight-table {
    background: rgba(255,255,255,0.9);
    border-radius: 18px;
    padding: 18px 20px 22px;
    box-shadow: 0 16px 24px rgba(15, 23, 42, 0.12);
    border: 1px solid rgba(67, 97, 238, 0.08);
  }
  .insight-visual h4,
  .insight-table h4 {
    margin-top: 0;
    margin-bottom: 12px;
    color: #1f2937;
    font-weight: 700;
  }
  .insight-tip {
    background: rgba(31, 60, 136, 0.08);
    border-radius: 14px;
    padding: 12px 16px;
    margin-top: 16px;
    color: rgba(30, 41, 59, 0.75);
    display: flex;
    gap: 10px;
    align-items: flex-start;
  }
  .insight-tip::before {
    content: "i";
    display: inline-flex;
    align-items: center;
    justify-content: center;
    font-weight: 700;
    width: 22px;
    height: 22px;
    background: rgba(31, 60, 136, 0.14);
    border-radius: 50%;
    color: var(--brand-secondary);
    flex: none;
  }
  .insight-panel-footer {
    margin-top: 20px;
    display: flex;
    justify-content: flex-end;
  }
  .insight-panel-footer .ghost-btn {
    background: rgba(255,255,255,0.95) !important;
  }
  .card h2 {
    margin-top: 0;
    margin-bottom: 20px;
    color: #1d3557;
    font-weight: 700;
  }
  .filters, .filters-row {
    display: flex;
    flex-wrap: wrap;
    gap: 14px;
    align-items: center;
    margin-bottom: 16px;
  }
  .filters-row .form-group,
  .filters .form-group {
    margin-bottom: 0 !important;
  }
  .form-control, .selectize-input, .btn, .irs {
    border-radius: 12px !important;
  }
  .home-hero {
    max-width: 100%;
    width: 100%;
    margin: 1px auto 2px auto;
    text-align: center;
    background: linear-gradient(160deg, rgba(9, 18, 41, 0.18), rgba(9, 18, 41, 0.35)),
                url("{{BG_IMAGE}}") center / cover no-repeat;
    padding: 26px 40px;
    border-radius: 32px;
    box-shadow: 0 30px 54px rgba(15, 23, 42, 0.25);
    border: 1px solid rgba(255, 255, 255, 0.22);
    color: #f6fbff;
  }
  .home-hero h1 {
    font-size: 42px;
    margin-bottom: 12px;
    color: #fdfdff;
    text-shadow: 0 6px 18px rgba(6, 18, 38, 0.35);
  }
  .home-hero p {
    font-size: 18px;
    color: rgba(240, 247, 255, 0.88);
    margin-bottom: 0;
  }
  .home-metrics {
    display: flex;
    flex-wrap: wrap;
    gap: 18px;
    justify-content: center;
    margin: 32px auto 48px auto;
    max-width: 900px;
  }
  .stat-card {
    flex: 1 1 220px;
    min-width: 200px;
    background: rgba(255,255,255,0.94);
    border-radius: 18px;
    padding: 22px;
    box-shadow: 0 16px 32px rgba(33, 53, 85, 0.15);
    border: 1px solid rgba(76, 201, 240, 0.12);
    text-align: center;
    transition: transform 0.18s ease, box-shadow 0.18s ease;
  }
  .stat-card:hover {
    transform: translateY(-6px);
    box-shadow: 0 20px 42px rgba(33, 53, 85, 0.2);
  }
  .stat-number {
    display: block;
    font-size: 34px;
    font-weight: 700;
    color: var(--brand-primary);
  }
  .stat-label {
    display: block;
    margin-top: 6px;
    font-size: 15px;
    color: rgba(30, 41, 59, 0.75);
    letter-spacing: 0.2px;
  }
  .home-cta {
    display: flex;
    gap: 16px;
    justify-content: center;
    flex-wrap: wrap;
    margin-bottom: 48px;
  }
  .primary-btn {
    background: linear-gradient(135deg, var(--brand-secondary), var(--brand-primary));
    color: #ffffff !important;
    border: none !important;
    padding: 10px 28px !important;
    border-radius: 999px !important;
    font-weight: 700 !important;
    letter-spacing: 0.4px;
    box-shadow: 0 16px 24px rgba(67, 97, 238, 0.25);
    transition: transform 0.18s ease, box-shadow 0.18s ease, background 0.18s ease;
  }
  .primary-btn:hover {
    transform: translateY(-2px);
    box-shadow: 0 20px 30px rgba(67, 97, 238, 0.28);
  }
  .ghost-btn {
    background: #ffffff !important;
    color: var(--brand-primary) !important;
    border: 1px solid rgba(44, 123, 229, 0.45) !important;
    padding: 10px 26px !important;
    border-radius: 999px !important;
    font-weight: 600 !important;
    transition: all 0.18s ease;
  }
  .ghost-btn:hover {
    background: rgba(255, 255, 255, 0.9) !important;
    color: var(--brand-secondary) !important;
    border-color: rgba(44, 123, 229, 0.65) !important;
  }
  .ghost-btn.ghost-compact {
    padding: 6px 14px !important;
    border-radius: 12px !important;
  }
  .full-width-btn {
    width: 100%;
    margin-top: 16px;
  }
  .home-cards {
    display: flex;
    flex-wrap: wrap;
    gap: 22px;
    justify-content: center;
    margin-bottom: 64px;
    max-width: 960px;
    margin-left: auto;
    margin-right: auto;
  }
  .info-card {
    flex: 1 1 260px;
    background: rgba(255,255,255,0.95);
    border-radius: 18px;
    padding: 14px 18px;
    box-shadow: 0 18px 34px rgba(15, 23, 42, 0.15);
    border-top: 4px solid rgba(67, 97, 238, 0.55);
    transition: transform 0.18s ease, box-shadow 0.18s ease;
    display: flex;
    flex-direction: column;
    min-height: 280px;
  }
  .info-card:hover {
    transform: translateY(-6px);
    box-shadow: 0 24px 40px rgba(15, 23, 42, 0.22);
  }
  .info-card h3 {
    margin-top: 4px;
    color: #1f2937;
    font-weight: 700;
  }
  .info-card p {
    color: rgba(51, 65, 85, 0.85);
    line-height: 1.5;
    margin-bottom: 8px;
  }
  .info-card .ghost-btn {
    margin-top: auto;
  }
  .container-fluid {
    padding: 8px 32px 24px;
  }
  .irs-bar, .irs-bar-edge, .irs-single {
    background: var(--brand-primary) !important;
    border-color: var(--brand-primary) !important;
  }
  .irs-from, .irs-to, .irs-single {
    background: var(--brand-primary) !important;
  }
  @media (max-width: 991px) {
    #map {
      height: 70vh !important;
    }
    .sidebar {
      position: static !important;
      margin-top: 16px;
      width: auto !important;
    }
    .home-hero {
      padding: 28px 24px;
    }
  }
  @media (max-width: 600px) {
    .home-hero h1 {
      font-size: 30px;
    }
    .home-hero p {
      font-size: 16px;
    }
  }
'

# Replace placeholder with actual background image
app_styles <- gsub("{{BG_IMAGE}}", bg_image_src, app_styles, fixed = TRUE)

home_tab <- tabPanel(
  "Home",
  value = "home",
  div(
    class = "container-fluid insight-section home-section",
    div(
      class = "home-hero",
      h1("Melbourne Journey Companion"),
      p("A single destination for Melbourne residents and visitors to plan journeys, understand landmark accessibility, and uncover nearby dining options.")
    ),
    div(
      class = "home-metrics",
      div(
        class = "stat-card",
        span(class = "stat-number", "40+"),
        span(class = "stat-label", "Melbourne CBD landmarks")
      ),
      div(
        class = "stat-card",
        span(class = "stat-number", "60+"),
        span(class = "stat-label", "Bus & City Circle stops")
      ),
      div(
        class = "stat-card",
        span(class = "stat-number", "500 m - 1 km"),
        span(class = "stat-label", "Custom explore radius")
      )
    ),
    # div(
    #   class = "home-cta",
    #   actionButton("go_map", "Launch Journey Planner", class = "primary-btn"),
    #   actionButton("go_insights", "View Access Insights", class = "ghost-btn")
    # ),
    div(
      class = "home-cards",
      div(
        class = "info-card",
        h3(tagList("Transport", tags$br(), "Navigation")),
        p("Use the Journey Planner page to explore landmarks, bus stops, and City Circle tram stops, then compare walking, bus, and tram routes in seconds."),
        actionButton("card_planner", "Open Journey Planner", class = "ghost-btn", width = "100%")
      ),
      div(
        class = "info-card",
        h3(tagList("Landmark", tags$br(), "Accessibility")),
        p("Filter by theme on the Transit Accessibility page to evaluate the closest bus and tram stops and generate shareable tables."),
        actionButton("card_transit", "Explore Transit Insights", class = "ghost-btn", width = "100%")
      ),
      div(
        class = "info-card",
        h3(tagList("Dining", tags$br(), "Recommendations")),
        p("Choose any landmark to instantly surface nearby dining venues, ranked by walking distance and seating capacity."),
        actionButton("card_dining", "Explore Dining Insights", class = "ghost-btn", width = "100%")
      )
    )
  )
)

map_tab <- tabPanel(
  "Journey Planner",
  value = "planner",
  div(
    class = "container-fluid insight-section map-page",
    div(
      class = "insight-hero planner-hero",
      div(
        class = "hero-text",
        h2("Design the Smartest Route"),
        p("Set your starting point and landmark to compare walking paths with the quickest tram and bus options before you head out.")
      ),
      div(
        class = "hero-visual",
        div(
          class = "insight-badge",
          span(class = "badge-label", "Modes compared"),
          span(class = "badge-value", "Walk · Bus · Tram")
        ),
        div(
          class = "insight-badge",
          span(class = "badge-label", "Instant insights"),
          span(class = "badge-value", "Stops & distance")
        )
      )
    ),
    div(
      class = "planner-toolbar",
      div(
        class = "toolbar-section",
        h4("Landmark Filters"),
        div(
          class = "toolbar-fields",
          selectInput("theme_filter", "Select Theme:", choices = NULL),
          selectInput("subtheme_filter", "Select Sub Theme:", choices = NULL)
        )
      )
    ),
    div(
      class = "planner-toolbar",
      div(
        class = "toolbar-section route-section",
        div(
          class = "route-header",
          h4("Route Calculator"),
          actionButton("route_btn", "Calculate Route", class = "primary-btn route-header-btn")
        ),
        div(
          class = "route-grid",
          div(
            class = "info-pair",
            span(class = "info-label", "Your Location"),
            textOutput(
              "user_location_text",
              inline = TRUE,
              container = function(...) span(class = "info-value", ...)
            )
          ),
          div(
            class = "info-pair landmark-pair",
            span(class = "info-label", "Selected Landmark"),
            textOutput(
              "landmark_location_text",
              inline = TRUE,
              container = function(...) span(class = "info-value", ...)
            ),
            actionButton("clear_landmark_btn", "Clear", class = "ghost-btn ghost-compact")
          ),
        )
      )
    ),
    div(class = "map-container", leafletOutput("map"))
  )
)

access_insights_transit_tab <- tabPanel(
  "Transit Accessibility",
  value = "access_transit",
  div(
    class = "container-fluid insight-section",
    div(
      class = "insight-hero transit-hero",
      div(
        class = "hero-text",
        h2("Transit Accessibility"),
        p("Compare how each landmark theme connects with Melbourne's bus and tram network before you set out.")
      ),
      div(
        class = "hero-visual",
        div(
          class = "insight-badge",
          span(class = "badge-label", "Stops mapped"),
          span(class = "badge-value", "60+ city nodes")
        ),
        div(
          class = "insight-badge",
          span(class = "badge-label", "Coverage window"),
          span(class = "badge-value", "400 m - 1 km")
        )
      )
    ),
    div(
      class = "card insight-card",
      div(
        class = "card-header",
        h3("Landmark Public Transport Accessibility"),
        p("Refine the filters to highlight the closest tram and bus stops, then explore how walking distance shifts across landmark categories.")
      ),
      div(
        class = "filter-panel",
        div(
          class = "filters",
          selectInput("theme", "Theme", choices = NULL, width = "280px"),
          selectInput("subtheme", "Sub Theme", choices = NULL, width = "280px"),
          numericInput("maxdist", "Max Distance Filter (m, optional)", value = NA, min = 0, step = 50, width = "220px")
        )
      ),
      div(
        class = "insight-layout",
        div(
          class = "insight-visual",
          h4("Accessibility Overview"),
          plotlyOutput("plot_access", height = "420px"),
          div(
            class = "insight-tip",
            "Tip: Hover on a landmark to compare the tram and bus options serving the same destination."
          )
        ),
        div(
          class = "insight-table",
          h4("Closest Stops Detail"),
          DTOutput("table_access"),
          div(
            class = "insight-tip",
            "Enter a maximum walking distance above to focus on mobility-friendly drop-off points."
          )
        )
      )
    )
  )
)

access_insights_dining_tab <- tabPanel(
  "Dining Insights",
  value = "access_dining",
  div(
    class = "container-fluid insight-section",
    div(
      class = "insight-hero dining-hero",
      div(
        class = "hero-text",
        h2("Design Post-Visit Meal"),
        p("Pair each landmark with nearby dining experiences based on walking distance, capacity, and vibe.")
      ),
      div(
        class = "hero-visual",
        div(
          class = "insight-badge",
          span(class = "badge-label", "Venues analysed"),
          span(class = "badge-value", "400+ eateries")
        ),
        div(
          class = "insight-badge",
          span(class = "badge-label", "Quick toggle"),
          span(class = "badge-value", "Distance vs capacity")
        )
      )
    ),
    div(
      class = "card insight-card",
      div(
        class = "card-header",
        h3("Top Nearby Restaurants by Distance"),
        p("Adjust the filters to switch between intimate cafes and higher-capacity dining rooms before locking in a venue.")
      ),
      div(
        class = "filter-panel",
        div(
          class = "filters-row",
          selectInput("theme2", "Theme", choices = NULL, width = "220px"),
          selectInput("subtheme2", "Sub Theme", choices = NULL, width = "220px"),
          selectizeInput(
            "landmark2", "Landmark", choices = NULL, width = "360px",
            options = list(placeholder = "Search or select a landmark...")
          )
        ),
        div(
          class = "filters-row",
          sliderInput("radius", "Radius (m)", min = 100, max = 1000, value = 500, step = 50, width = "300px"),
          sliderInput("topn", "Top N results", min = 5, max = 30, step = 5, value = 10, width = "300px")
        ),
        div(
          class = "filters-row",
          radioButtons(
            "sort_metric", "Sort by:",
            choices = c("Distance (asc)" = "distance", "Capacity (desc)" = "seats"),
            selected = "distance", inline = TRUE
          )
        )
      ),
      div(
        class = "insight-layout",
        div(
          class = "insight-visual",
          h4("Dining Radius Visual"),
          plotlyOutput("plot_cafes", height = "460px"),
          div(
            class = "insight-tip",
            "Tip: Switch the sorting to capacity when organising group dinners or family gatherings."
          )
        )
      )
    )
  )
)

ui <- tagList(
  tags$head(tags$style(HTML(app_styles))),
  div(
    class = "page-shell",
    navbarPage(
      title = div(
        class = "brand-title",
        img(src = logo_src, alt = "Melbourne skyline logo"),
        span("Melbourne Companion")
      ),
      id = "main_nav",
      selected = "home",
      collapsible = TRUE,
      home_tab,
      map_tab,
      access_insights_transit_tab,
      access_insights_dining_tab
    )
  )
)


# ---- SERVER ----

server <- function(input, output, session) {
  # Load datasets once
  bus_data <- load_bus_data()
  tram_data <- load_tram_data()
  landmarks_all <- load_landmarks()
  tram_tracks_data <- load_tram_tracks_data()
  cafes <- load_cafes()

  # Datasets tailored for each tab
  landmark_data <- landmarks_all %>%
    select(Theme, Sub.Theme, `Sub Theme`, Feature.Name, `Feature Name`, lat, lng)

  landmarks_tbl <- landmarks_all %>%
    transmute(
      Theme,
      SubTheme,
      FeatureName,
      lat,
      lng
    )

  bus_stops <- bus_data %>%
    mutate(StopName = ifelse(!is.na(StopName) & StopName != "", StopName, Name))
  tram_stops <- tram_data %>%
    mutate(StopName = ifelse(!is.na(StopName) & StopName != "", StopName, name))

  observeEvent(input$go_map, {
    updateTabsetPanel(session, "main_nav", selected = "planner")
  })

  observeEvent(input$card_planner, {
    updateTabsetPanel(session, "main_nav", selected = "planner")
  })

  observeEvent(input$go_insights, {
    updateTabsetPanel(session, "main_nav", selected = "access_transit")
  })

  observeEvent(input$card_transit, {
    updateTabsetPanel(session, "main_nav", selected = "access_transit")
  })

  observeEvent(input$card_dining, {
    updateTabsetPanel(session, "main_nav", selected = "access_dining")
  })

  # ---- Map tab logic ----
  user_location <- reactiveVal(NULL)
  selected_landmark <- reactiveVal(NULL)
  selected_landmark_name <- reactiveVal("Choose the landmark you want to visit!")

  output$user_location_text <- renderText({ "Click on the map to set your position!" })
  observe({
    output$landmark_location_text <- renderText({ selected_landmark_name() })
  })

  updateSelectInput(session, "theme_filter", choices = c("All", unique(landmark_data$Theme)), selected = "All")
  observe({
    theme_subsets <- if (input$theme_filter == "All") {
      landmark_data
    } else {
      landmark_data %>% filter(Theme == input$theme_filter)
    }
    updateSelectInput(session, "subtheme_filter", choices = c("All", unique(theme_subsets$Sub.Theme)), selected = "All")
  })

  filtered_landmarks <- reactive({
    filtered <- landmark_data
    if (input$theme_filter != "All") {
      filtered <- filtered %>% filter(Theme == input$theme_filter)
    }
    if (input$subtheme_filter != "All") {
      filtered <- filtered %>% filter(Sub.Theme == input$subtheme_filter)
    }
    filtered
  })

  output$map <- renderLeaflet({
    map_combined(bus_data, tram_data, filtered_landmarks(), tram_tracks_data)
  })

  observeEvent(input$map_click, {
    click <- input$map_click
    if (!is.null(click)) {
      user_location(c(click$lng, click$lat))
      output$user_location_text <- renderText({ paste(round(click$lat, 5), ",", round(click$lng, 5)) })
      leafletProxy("map") %>%
        clearGroup("user_location") %>%
        addMarkers(lng = click$lng, lat = click$lat, popup = "Your Location", group = "user_location")
    }
  })

  observeEvent(input$map_marker_click, {
    marker <- input$map_marker_click

    clicked_landmark <- landmark_data %>%
      filter(round(lng, 6) == round(marker$lng, 6) & round(lat, 6) == round(marker$lat, 6))

    if (nrow(clicked_landmark) > 0) {
      name <- clicked_landmark$Feature.Name[1]
      selected_landmark(c(marker$lng, marker$lat))
      selected_landmark_name(name)
    }
  })

  observeEvent(input$clear_landmark_btn, {
    selected_landmark(NULL)
    selected_landmark_name("Choose the landmark you want to visit!")
  })

  find_closest_station <- function(location, stations_data) {
    distances <- distHaversine(location, cbind(stations_data$lng, stations_data$lat))
    stations_data[which.min(distances), ]
  }

  route_calculated <- reactiveVal(FALSE)

  observeEvent(input$route_btn, {
    if (is.null(user_location()) || is.null(selected_landmark())) {
      showNotification("Please select both your location and a landmark on the map.", type = "warning")
      return()
    }

    if (!route_calculated()) {
      closest_bus_user <- find_closest_station(user_location(), bus_data)
      closest_tram_user <- find_closest_station(user_location(), tram_data)
      closest_bus_landmark <- find_closest_station(selected_landmark(), bus_data)
      closest_tram_landmark <- find_closest_station(selected_landmark(), tram_data)

      landmarkIcon <- makeIcon(iconUrl = "img/landmark.png", iconWidth = 40, iconHeight = 40)
      busStopIcon <- makeIcon(iconUrl = "img/bus.png", iconWidth = 30, iconHeight = 30)
      tramStopIcon <- makeIcon(iconUrl = "img/tram.png", iconWidth = 30, iconHeight = 30)

      user_pt <- user_location()
      landmark_pt <- selected_landmark()
      bus_user_pt <- c(closest_bus_user$lng, closest_bus_user$lat)
      bus_landmark_pt <- c(closest_bus_landmark$lng, closest_bus_landmark$lat)
      tram_user_pt <- c(closest_tram_user$lng, closest_tram_user$lat)
      tram_landmark_pt <- c(closest_tram_landmark$lng, closest_tram_landmark$lat)

      walk_only_route <- get_osrm_route(user_pt, landmark_pt, profile = "foot")
      walk_only_fallback <- line_df(user_pt, landmark_pt)
      dist_walk_only <- distance_with_fallback(walk_only_route, distHaversine(user_pt, landmark_pt))

      walk_to_bus_route <- get_osrm_route(user_pt, bus_user_pt, profile = "foot")
      walk_to_bus_fallback <- line_df(user_pt, bus_user_pt)
      walk_to_bus_dist <- distance_with_fallback(walk_to_bus_route, distHaversine(user_pt, bus_user_pt))

      bus_segment_route <- get_osrm_route(bus_user_pt, bus_landmark_pt, profile = "car")
      bus_segment_fallback <- line_df(bus_user_pt, bus_landmark_pt)
      bus_segment_dist <- distance_with_fallback(bus_segment_route, distHaversine(bus_user_pt, bus_landmark_pt))

      walk_from_bus_route <- get_osrm_route(bus_landmark_pt, landmark_pt, profile = "foot")
      walk_from_bus_fallback <- line_df(bus_landmark_pt, landmark_pt)
      walk_from_bus_dist <- distance_with_fallback(walk_from_bus_route, distHaversine(bus_landmark_pt, landmark_pt))

      dist_bus_route <- walk_to_bus_dist + bus_segment_dist + walk_from_bus_dist

      walk_to_tram_route <- get_osrm_route(user_pt, tram_user_pt, profile = "foot")
      walk_to_tram_fallback <- line_df(user_pt, tram_user_pt)
      walk_to_tram_dist <- distance_with_fallback(walk_to_tram_route, distHaversine(user_pt, tram_user_pt))

      tram_segment_route <- get_osrm_route(tram_user_pt, tram_landmark_pt, profile = "car")
      tram_segment_fallback <- line_df(tram_user_pt, tram_landmark_pt)
      tram_segment_dist <- distance_with_fallback(tram_segment_route, distHaversine(tram_user_pt, tram_landmark_pt))

      walk_from_tram_route <- get_osrm_route(tram_landmark_pt, landmark_pt, profile = "foot")
      walk_from_tram_fallback <- line_df(tram_landmark_pt, landmark_pt)
      walk_from_tram_dist <- distance_with_fallback(walk_from_tram_route, distHaversine(tram_landmark_pt, landmark_pt))

      dist_tram_route <- walk_to_tram_dist + tram_segment_dist + walk_from_tram_dist

      map_proxy <- leafletProxy("map") %>%
        clearMarkers() %>%
        clearMarkerClusters() %>%
        clearShapes()

      if (dist_walk_only <= dist_bus_route && dist_walk_only <= dist_tram_route) {
        showNotification("The shortest route is walking.", type = "message")
        map_proxy <- draw_route_segment(
          map_proxy,
          walk_only_route,
          walk_only_fallback,
          color = "black",
          weight = 3,
          opacity = 0.8,
          dash = "5, 5"
        )

      } else if (dist_bus_route <= dist_tram_route) {
        showNotification("Displaying the shortest route via Bus.", type = "message")
        map_proxy <- draw_route_segment(
          map_proxy,
          walk_to_bus_route,
          walk_to_bus_fallback,
          color = "black",
          weight = 3,
          opacity = 0.8,
          dash = "5, 5"
        )
        map_proxy <- draw_route_segment(
          map_proxy,
          bus_segment_route,
          bus_segment_fallback,
          color = "blue",
          weight = 4,
          opacity = 0.85
        )
        map_proxy <- draw_route_segment(
          map_proxy,
          walk_from_bus_route,
          walk_from_bus_fallback,
          color = "black",
          weight = 3,
          opacity = 0.8,
          dash = "5, 5"
        )

      } else {
        showNotification("Displaying the shortest route via City Circle Tram.", type = "message")
        map_proxy <- draw_route_segment(
          map_proxy,
          walk_to_tram_route,
          walk_to_tram_fallback,
          color = "black",
          weight = 3,
          opacity = 0.8,
          dash = "5, 5"
        )
        map_proxy <- draw_route_segment(
          map_proxy,
          tram_segment_route,
          tram_segment_fallback,
          color = "red",
          weight = 4,
          opacity = 0.85
        )
        map_proxy <- draw_route_segment(
          map_proxy,
          walk_from_tram_route,
          walk_from_tram_fallback,
          color = "black",
          weight = 3,
          opacity = 0.8,
          dash = "5, 5"
        )
      }

      map_proxy %>%
        addMarkers(lng = user_location()[1], lat = user_location()[2], popup = "Your Location") %>%
        addMarkers(lng = selected_landmark()[1], lat = selected_landmark()[2],
                   popup = selected_landmark_name(), icon = landmarkIcon) %>%
        addMarkers(lng = closest_bus_user$lng, lat = closest_bus_user$lat,
                   popup = "Closest Bus Stop (to You)", icon = busStopIcon) %>%
        addMarkers(lng = closest_bus_landmark$lng, lat = closest_bus_landmark$lat,
                   popup = "Closest Bus Stop (to Landmark)", icon = busStopIcon) %>%
        addMarkers(lng = closest_tram_user$lng, lat = closest_tram_user$lat,
                   popup = "Closest Tram Stop (to You)", icon = tramStopIcon) %>%
        addMarkers(lng = closest_tram_landmark$lng, lat = closest_tram_landmark$lat,
                   popup = "Closest Tram Stop (to Landmark)", icon = tramStopIcon)

      route_calculated(TRUE)
      updateActionButton(session, "route_btn", label = "Cancel Route")

    } else {
      output$map <- renderLeaflet({ map_combined(bus_data, tram_data, filtered_landmarks(), tram_tracks_data) })

      user_location(NULL)
      selected_landmark(NULL)
      selected_landmark_name("Choose the landmark you want to visit!")
      output$user_location_text <- renderText({ "Click on the map to set your position!" })

      route_calculated(FALSE)
      updateActionButton(session, "route_btn", label = "Calculate Route")
    }
  })


  # ---- Insights tab logic ----
  themes <- c("All", sort(unique(landmarks_tbl$Theme)))
  updateSelectInput(session, "theme", choices = themes, selected = "All")
  updateSelectInput(session, "theme2", choices = themes, selected = "All")

  observe({
    lmk_theme_subset <- if (is.null(input$theme) || input$theme == "All") {
      landmarks_tbl
    } else {
      landmarks_tbl %>% filter(Theme == input$theme)
    }
    subs <- c("All", sort(unique(lmk_theme_subset$SubTheme)))
    updateSelectInput(session, "subtheme", choices = subs, selected = "All")

    lmk_theme_subset2 <- if (is.null(input$theme2) || input$theme2 == "All") {
      landmarks_tbl
    } else {
      landmarks_tbl %>% filter(Theme == input$theme2)
    }
    subs2 <- c("All", sort(unique(lmk_theme_subset2$SubTheme)))
    updateSelectInput(session, "subtheme2", choices = subs2, selected = "All")
  })

  observe({
    df <- landmarks_tbl
    if (!is.null(input$theme2) && input$theme2 != "All") df <- df %>% filter(Theme == input$theme2)
    if (!is.null(input$subtheme2) && input$subtheme2 != "All") df <- df %>% filter(SubTheme == input$subtheme2)
    choices <- df$FeatureName
    updateSelectInput(
      session, "landmark2",
      choices = choices,
      selected = if (length(choices)) choices[[1]] else character(0)
    )
  })

  lmk_coords <- as.matrix(landmarks_tbl[, c("lng", "lat")])
  bus_coords <- as.matrix(bus_stops[, c("lng", "lat")])
  tram_coords <- as.matrix(tram_stops[, c("lng", "lat")])
  cafe_coords <- as.matrix(cafes[, c("Lon", "Lat")])

  D_bus <- if (nrow(lmk_coords) > 0 && nrow(bus_coords) > 0) distm(lmk_coords, bus_coords, fun = distHaversine) else matrix(numeric())
  D_tram <- if (nrow(lmk_coords) > 0 && nrow(tram_coords) > 0) distm(lmk_coords, tram_coords, fun = distHaversine) else matrix(numeric())
  D_cafe <- if (nrow(lmk_coords) > 0 && nrow(cafe_coords) > 0) distm(lmk_coords, cafe_coords, fun = distHaversine) else matrix(numeric())

  access_tbl_reactive <- reactive({
    df <- landmarks_tbl
    if (!is.null(input$theme) && input$theme != "All") df <- df %>% filter(Theme == input$theme)
    if (!is.null(input$subtheme) && input$subtheme != "All") df <- df %>% filter(SubTheme == input$subtheme)
    if (nrow(df) == 0) return(df)

    idx <- match(df$FeatureName, landmarks_tbl$FeatureName)

    bus_min_idx <- if (length(D_bus)) max.col(-D_bus[idx, , drop = FALSE]) else integer(nrow(df))
    tram_min_idx <- if (length(D_tram)) max.col(-D_tram[idx, , drop = FALSE]) else integer(nrow(df))

    bus_dist <- if (length(D_bus)) round(D_bus[cbind(idx, bus_min_idx)]) else rep(NA_integer_, nrow(df))
    tram_dist <- if (length(D_tram)) round(D_tram[cbind(idx, tram_min_idx)]) else rep(NA_integer_, nrow(df))

    nearest_bus <- if (nrow(bus_stops)) bus_stops$StopName[bus_min_idx] else NA_character_
    nearest_tram <- if (nrow(tram_stops)) tram_stops$StopName[tram_min_idx] else NA_character_

    advantage <- ifelse(
      is.na(bus_dist) & is.na(tram_dist), NA_character_,
      ifelse(is.na(tram_dist) | (!is.na(bus_dist) & bus_dist <= tram_dist), "Bus", "Tram")
    )

    out <- tibble(
      Landmark = df$FeatureName,
      Theme = df$Theme,
      SubTheme = df$SubTheme,
      `Nearest Bus Stop` = nearest_bus,
      `Bus Dist (m)` = bus_dist,
      `Nearest Tram Stop` = nearest_tram,
      `Tram Dist (m)` = tram_dist,
      Advantage = advantage
    )

    if (!is.null(input$maxdist) && !is.na(input$maxdist)) {
      md <- as.numeric(input$maxdist)
      out <- out %>% filter(
        (!is.na(`Bus Dist (m)`) & `Bus Dist (m)` <= md) |
          (!is.na(`Tram Dist (m)`) & `Tram Dist (m)` <= md)
      )
    }

    out %>%
      mutate(MinDist = pmin(`Bus Dist (m)`, `Tram Dist (m)`, na.rm = TRUE)) %>%
      arrange(MinDist) %>%
      select(-MinDist)
  })

  output$plot_access <- renderPlotly({
    df <- access_tbl_reactive()

    if (is.null(df) || nrow(df) == 0 ||
        !all(c("Bus Dist (m)", "Tram Dist (m)") %in% colnames(df))) {
      return(plotly_empty(type = "bar") %>%
               layout(title = "No landmarks found for current filters"))
    }

    df <- df %>%
      mutate(
        MinDist = pmin(`Bus Dist (m)`, `Tram Dist (m)`, na.rm = TRUE),
        MinType = case_when(
          is.na(`Bus Dist (m)`) & is.na(`Tram Dist (m)`) ~ NA_character_,
          is.na(`Tram Dist (m)`) ~ "Bus",
          is.na(`Bus Dist (m)`) ~ "Tram",
          `Bus Dist (m)` <= `Tram Dist (m)` ~ "Bus",
          TRUE ~ "Tram"
        ),
        ShortName = ifelse(nchar(Landmark) > 22, paste0(substr(Landmark, 1, 22), "..."), Landmark),
        UniqueName = make.unique(ShortName),
        hover = paste0(
          "<b>", Landmark, "</b><br>",
          "Nearest Bus: ", `Nearest Bus Stop`, " (", round(`Bus Dist (m)`), " m)<br>",
          "Nearest Tram: ", `Nearest Tram Stop`, " (", round(`Tram Dist (m)`), " m)<br>",
          "Closer to: ", MinType
        ),
        Color = case_when(
          MinType == "Bus" ~ "rgba(52,152,219,0.85)",
          MinType == "Tram" ~ "rgba(230,126,34,0.85)",
          TRUE ~ "rgba(149,165,166,0.70)"
        )
      ) %>%
      arrange(MinDist)

    max_n <- 25
    if (nrow(df) > max_n) df <- df %>% slice_head(n = max_n)

    plot_ly(
      data = df, y = ~factor(UniqueName, levels = UniqueName), x = ~MinDist,
      type = "bar", orientation = "h",
      text = ~paste0(ShortName, " - ", round(MinDist), " m"),
      hovertext = ~hover,
      hoverinfo = "text",
      textposition = "auto",
      insidetextanchor = "middle",
      marker = list(color = ~Color,
                    line = list(color = "rgba(0,0,0,0.15)", width = 0.5))
    ) %>%
      layout(
        title = list(
          text = "Shortest Public Transport Distance per Landmark<br><sup>Blue = Bus closer; Orange = Tram closer</sup>",
          x = 0.02
        ),
        xaxis = list(title = "Minimum Distance (m)", rangemode = "tozero", zeroline = TRUE),
        yaxis = list(title = "", automargin = TRUE, autorange = "reversed"),
        margin = list(l = 220, r = 40, t = 70, b = 60),
        bargap = 0.3
      )
  })

  output$table_access <- renderDT({
    df <- access_tbl_reactive()
    df$Advantage <- ifelse(
      is.na(df$Advantage), "",
      ifelse(
        df$Advantage == "Bus", badge("Bus", bg = "#eaf4ff", fg = "#3498db"),
        badge("Tram", bg = "#fff0e6", fg = "#e67e22")
      )
    )

    datatable(
      df, escape = FALSE, rownames = FALSE,
      options = list(
        paging = FALSE, searching = TRUE, ordering = TRUE,
        fixedHeader = TRUE, scrollY = "420px", scrollX = TRUE,
        dom = "Bfrtip",
        buttons = list("copy", "csv", "excel", "colvis")
      ),
      extensions = c("Buttons")
    ) %>%
      formatStyle(
        "Bus Dist (m)",
        background = styleInterval(
          c(200, 400, 600, 800, 1000),
          c("#e9f7ef", "#d4f4e1", "#bff0d3", "#ffd5cc", "#ffb8aa", "#ff9c91")
        )
      ) %>%
      formatStyle(
        "Tram Dist (m)",
        background = styleInterval(
          c(200, 400, 600, 800, 1000),
          c("#e9f7ef", "#d4f4e1", "#bff0d3", "#ffd5cc", "#ffb8aa", "#ff9c91")
        )
      )
  })

  top_cafes_reactive <- reactive({
    req(input$landmark2, input$radius)

    lmk <- landmarks_tbl %>% filter(FeatureName == input$landmark2)
    req(nrow(lmk) == 1)

    lmk_lonlat <- c(lmk$lng, lmk$lat)
    if (nrow(cafes) > 0 && all(c("Lon", "Lat") %in% names(cafes))) {
      D_mat <- geosphere::distHaversine(matrix(lmk_lonlat, ncol = 2), as.matrix(cafes[, c("Lon", "Lat")]))
      D <- as.numeric(D_mat)
    } else {
      D <- numeric(0)
    }

    cafes_with_dist <- cafes %>%
      mutate(distance_m = as.numeric(D))

    per_shop <- cafes_with_dist %>%
      filter(distance_m <= as.numeric(input$radius)) %>%
      group_by(`Property ID`) %>%
      summarise(
        TradingName = dplyr::first(na.omit(TradingName)),
        Industry = dplyr::first(na.omit(Industry)),
        Lon = dplyr::first(Lon),
        Lat = dplyr::first(Lat),
        SeatsTotal = sum(Seats, na.rm = TRUE),
        distance_m = dplyr::first(distance_m),
        .groups = "drop"
      ) %>%
      mutate(
        TradingName = ifelse(is.na(TradingName) | TradingName == "",
                             paste0("Shop ", `Property ID`), TradingName)
      )

    if (input$sort_metric == "distance") {
      per_shop <- per_shop %>% arrange(distance_m)
    } else {
      per_shop <- per_shop %>% arrange(desc(SeatsTotal))
    }

    per_shop %>% slice_head(n = input$topn)
  })

  output$plot_cafes <- renderPlotly({
    df <- top_cafes_reactive()
    if (is.null(df) || nrow(df) == 0) {
      return(plotly_empty(type = "bar") %>%
               layout(title = "No nearby restaurants found within selected range"))
    }

    if (input$sort_metric == "distance") {
      df <- df %>% arrange(distance_m)
    } else {
      df <- df %>% arrange(desc(SeatsTotal))
    }

    df <- df %>%
      mutate(
        ShortName = ifelse(nchar(TradingName) > 22, paste0(substr(TradingName, 1, 22), "..."), TradingName),
        y = factor(ShortName, levels = ShortName),
        hovertext = paste0(
          "<b>", TradingName, "</b><br>",
          "Distance: ", round(distance_m), " m<br>",
          "Total seats: ", SeatsTotal
        )
      )

    if (all(is.na(df$distance_m)) || all(is.na(df$SeatsTotal))) {
      return(plotly_empty(type = "bar") %>%
               layout(title = "No valid data available"))
    }

    plot_ly() %>%
      add_trace(
        data = df, y = ~y, x = ~distance_m, type = "bar", orientation = "h",
        name = "Distance (m)",
        text = ~paste0(round(distance_m), " m"),
        hovertext = ~hovertext, hoverinfo = "text",
        textposition = "outside",
        insidetextanchor = "start",
        marker = list(
          color = "rgba(52,152,219,0.85)",
          line = list(color = "rgba(52,152,219,1)", width = 0.5)
        ),
        width = 0.35, offsetgroup = 1
      ) %>%
      add_trace(
        data = df, y = ~y, x = ~SeatsTotal, type = "bar", orientation = "h",
        name = "Total Seats",
        text = ~SeatsTotal,
        hovertext = ~hovertext, hoverinfo = "text",
        textposition = "outside",
        insidetextanchor = "start",
        marker = list(
          color = "rgba(230,126,34,0.85)",
          line = list(color = "rgba(230,126,34,1)", width = 0.5)
        ),
        width = 0.35, offsetgroup = 2, xaxis = "x2"
      ) %>%
      layout(
        barmode = "group",
        xaxis = list(
          title = "Distance (m)",
          rangemode = "tozero",
          zeroline = TRUE,
          side = "bottom"
        ),
        xaxis2 = list(
          title = "Total Seats",
          overlaying = "x",
          side = "top",
          rangemode = "tozero",
          zeroline = TRUE,
          showgrid = FALSE
        ),
        yaxis = list(
          title = "",
          automargin = TRUE,
          autorange = "reversed"
        ),
        margin = list(l = 220, r = 40, t = 50, b = 60),
        legend = list(orientation = "h", x = 0, y = -0.25),
        bargap = 0.3
      )
  })
}


shinyApp(ui, server)
