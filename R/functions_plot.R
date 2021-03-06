#' Plot Command to Plot L2 Dendrometer Data
#'
#' \code{plotting_proc_L2} contains the code necessary to plot \code{L2}
#'   dendrometer data.
#'
#' @param data_plot input \code{data.frame} containing both \code{L1} and
#'   \code{L2} data as well as changes in \code{L2} for plotting.
#' @param plot_add logical, specify whether \code{L1} data should be plotted
#'   along with \code{L2} data in the second panel of the plot.
#' @inheritParams plot_proc_L2
#'
#' @keywords internal
#'
plotting_proc_L2 <- function(data_plot, plot_period, plot_add = TRUE,
                             plot_frost = TRUE, plot_interpol = TRUE, tz) {

  # define axis labels
  axis_labs <- axis_labels_period(df = data_plot, plot_period = plot_period,
                                  tz = tz)

  # plot ----------------------------------------------------------------------
  graphics::layout(mat = matrix(c(1, 2, 3, 4), nrow = 4),
                   heights = c(2, 1.6, 1, 2), widths = 1)

  # plot data_L1
  graphics::par(mar = c(0, 5, 4.1, 2.1))
  graphics::plot(data = data_plot, value_L1 ~ ts, type = "l", xaxt = "n",
                 ylab = "", las = 1, main = passobj("sensor_label"))
  graphics::title(ylab = paste0("L1 (", "\u00b5", "m)"), mgp = c(3.5, 1, 0))

  # plot data_L2
  graphics::par(mar = c(0, 5, 0, 2.1))
  graphics::plot(data = data_plot, value_L2 ~ ts, type = "n", xaxt = "n",
                 ylab = "", las = 1)
  if (plot_frost) {
    if (plot_period %in% c("yearly", "monthly")) {
      plot_frost_period(df = data_plot)
    }
  }
  if (plot_add) {
    graphics::lines(data = data_plot, value_L1 ~ ts, col = "grey70")
  }
  graphics::lines(data = data_plot, value_L2 ~ ts, col = "#08519c")
  if (plot_interpol) {
    if (plot_period %in% c("yearly", "monthly")) {
      plot_interpol_points(df = data_plot)
    }
  }
  graphics::title(ylab = paste0("L2 (", "\u00b5", "m)"), mgp = c(3.5, 1, 0))

  # plot diff
  graphics::par(mar = c(0, 5, 0, 2.1))
  options(warn = -1)
  graphics::plot(data = data_plot, value_L2 ~ ts, type = "n", xlab = "",
                 log = "y", yaxt = "n", xaxt = "n", ylab = "",
                 ylim = c(0.1, 1200), las = 1)
  graphics::abline(h = c(0.1, 1, 10, 100, 1000), col = "grey70")
  graphics::lines(data = data_plot, diff_old ~ ts, type = "h", lwd = 1.5,
                  col = "grey70")
  # different colors for deleted outliers and changes in values
  graphics::lines(data = data_plot, diff_plot ~ ts, type = "h", lwd = 2,
                  col = ifelse(grepl("out", data_plot$flags),
                               "#fcdcd9", "#ef3b2c"))
  if (plot_period == "monthly") {
    graphics::text(x = data_plot$ts,
                   y = rep(c(10, 3, 1, 0.3), length.out = nrow(data_plot)),
                   labels = data_plot$diff_nr_old, col = "grey40", font = 1)
    graphics::text(x = data_plot$ts,
                   y = rep(c(0.3, 1, 3, 10), length.out = nrow(data_plot)),
                   labels = data_plot$diff_nr, font = 2,
                   col = ifelse(grepl("out", data_plot$flags),
                                "#594f4f", "#802018"))
  }
  graphics::axis(2, at = c(0.1, 1, 10, 100, 1000),
                 labels = c(0, 1, 10, 100, 1000), las = 1)
  graphics::title(ylab = "difference [L1 - L2]", mgp = c(3.5, 1, 0))
  options(warn = 0)

  # plot twd
  graphics::par(mar = c(4.1, 5, 0, 2.1))
  graphics::plot(data = data_plot, twd ~ ts, type = "l", xaxt = "n",
                 xlab = passobj("year_label"),  ylab = "", las = 1,
                 col = "#7a0177")
  graphics::axis(1, at = axis_labs[[1]], labels = axis_labs[[2]])
  graphics::title(ylab = paste0("twd (", "\u00b5", "m)"), mgp = c(3.5, 1, 0))

}


#' Define Axis Labels Based on Period
#'
#' \code{axis_labels_period} defines axis ticks and labels based on the
#'   period used for plotting.
#'
#' @param df input \code{data.frame}
#' @inheritParams plot_proc_L2
#'
#' @keywords internal
#'
axis_labels_period <- function(df, plot_period, tz) {

  if (plot_period == "full") {
    ticks <- paste0(unique(df$year), "-01-01")
    ticks <- as.POSIXct(ticks, format = "%Y-%m-%d", tz = tz)
    labs <- substr(ticks, 1, 4)
  }
  if (plot_period == "yearly") {
    ticks <- paste0(unique(df$year), "-", unique(df$month), "-01")
    ticks <- as.POSIXct(ticks, format = "%Y-%m-%d", tz = tz)
    labs <- substr(ticks, 6, 7)
  }
  if (plot_period == "monthly") {
    ticks <- unique(substr(df$ts, 1, 10))
    ticks <- as.POSIXct(ticks, format = "%Y-%m-%d", tz = tz)
    labs <- substr(ticks, 9, 10)
  }

  axis_labs <- list(ticks, labs)

  return(axis_labs)
}


#' Plot Yearly Growth Curves and Print Variables
#'
#' \code{plot_gro_yr_print_vars} plots yearly growth curves for the whole
#'   period in a single plot and prints the used input variables for plotting.
#'   In addition, median, maximum and minimum growth values for different
#'   periods are printed.
#'
#' @inheritParams plot_proc_L2
#'
#' @keywords internal
#'
plot_gro_yr_print_vars <- function(data_plot, thr_plot, tz) {

  series_plot <- unique(data_plot$series)
  graphics::layout(mat = matrix(c(1, 2), nrow = 2), heights = c(2, 4),
                   widths = 1)

  # plot yearly growth curves
  graphics::par(mar = c(5.1, 4.1, 4.1, 2.1))

  data_plot <- data_plot %>%
    dplyr::mutate(doy = as.numeric(strftime(ts, format = "%j", tz = tz)) - 1)

  graphics::plot(data = data_plot, gro_yr ~ doy, type = "n",
                 main = passobj("sensor_label"), ylab = paste0("gro_yr (",
                                                               "\u00b5", "m)"),
                 xlab = "day of year", xlim = c(0, 365),
                 ylim = c(0, max(data_plot$gro_yr, na.rm = TRUE)), las = 1)

  years <- unique(data_plot$year)
  colors <- c("grey", grDevices::rainbow(length(years)))
  data_year <- data_plot %>%
    dplyr::group_by(year) %>%
    dplyr::group_split()
  for (y in 1:length(years)) {
    graphics::lines(data = data_year[[y]], gro_yr ~ doy, col = colors[y])
  }
  graphics::legend(x = "topleft", legend = years, col = colors, bty = "n",
                   lty = 1, seg.len = 0.8)


  # print used variables and threshold values
  if (length(thr_plot) != 0) {
    thr_print <- thr_plot %>%
      dplyr::filter(series == series_plot)

    graphics::par(mar = c(5.1, 4.1, 4.1, 2.1))

    graphics::plot(x = c(0, 1), y = c(0, 1), ann = FALSE, bty = "n",
                   type = "n", xaxt = "n", yaxt = "n")
    # print input variables
    graphics::text(x = 0, y = 1, adj = c(0, 1), font = 2, cex = 0.8,
                   labels = "input variables")
    graphics::text(x = 0, y = 0.97, adj = c(0, 1), cex = 0.8,
                   labels = paste0("tol_jump = ",
                                   passobj("tol_jump_plot"), "\n",
                                   "tol_out = ",
                                   passobj("tol_out_plot"), "\n",
                                   "frost_thr = ",
                                   passobj("frost_thr_plot"), "\n",
                                   "lowtemp = ",
                                   passobj("lowtemp_plot"), "\n",
                                   "interpol = ",
                                   passobj("interpol_plot"), "\n",
                                   "frag_len = ",
                                   passobj("frag_len_plot"), "\n",
                                   "tz = ", passobj("tz_plot")))
    # print applied thresholds and values
    graphics::text(x = 0.3, y = 1, adj = c(0, 1), font = 2, cex = 0.8,
                   labels = paste0("applied thresholds (", "\u00b5", "m)"))
    graphics::text(x = 0.3, y = 0.97, adj = c(0, 1), cex = 0.8,
                   labels = paste0("tol_jump = ",
                                   thr_print$thr_jump_min, " / ",
                                   thr_print$thr_jump_max, "\n",
                                   "tol_out = ",
                                   thr_print$thr_out_min, " / ",
                                   thr_print$thr_out_max, "\n",
                                   "tol_jump_frost = ",
                                   thr_print$thr_jump_min *
                                     passobj("frost_thr_plot"), " / ",
                                   thr_print$thr_jump_max *
                                     passobj("frost_thr_plot"), "\n",
                                   "tol_out_frost = ",
                                   thr_print$thr_out_min *
                                     passobj("frost_thr_plot"), " / ",
                                   thr_print$thr_out_max *
                                     passobj("frost_thr_plot"), "\n"))
    # print amount of missing, deleted and interpolated data
    list_missing <- calcmissing(data_plot = data_plot)
    graphics::text(x = 0.8, y = 1, adj = c(0, 1), font = 2, cex = 0.8,
                   labels = "changes in data")
    graphics::text(x = 0.8, y = 0.97, adj = c(0, 1), cex = 0.8,
                   labels = paste0("interpolated: ", list_missing[[1]], "%\n",
                                   "deleted: ", list_missing[[2]], "%\n",
                                   "missing: ", list_missing[[3]], "%"))
    # print growth values for different periods
    gro_period <- calcgroperiods(df = data_plot, reso = passobj("reso"),
                                 tz = tz)
    if (length(gro_period) > 0) {
      graphics::text(x = 0, y = 0.7, adj = c(0, 1), font = 2, cex = 0.8,
                     labels = paste0("growth statistics (", "\u00b5",
                                     "m): median (min / max)"))
      for (r in 1:nrow(gro_period)) {
        gro_period_single <- gro_period[r, ]
        graphics::text(x = 0, y = 0.7 - 0.03 * r, adj = c(0, 1), cex = 0.8,
                       labels = paste0(gro_period_single$period, ": ",
                                       gro_period_single$gro_med, " (",
                                       gro_period_single$gro_min, " / ",
                                       gro_period_single$gro_max, ")"))
      }
    }
    # print package version
    version_pck <- utils::packageDescription("treenetproc",
                                             fields = "Version", drop = TRUE)
    graphics::text(x = 1, y = 0.4, adj = c(1, 1), cex = 0.8,
                   labels = paste0("treenetproc: ", version_pck))
  }
}


#' Plot Frost Period
#'
#' \code{plot_frost_period} draws a horizontal line in periods of possible
#'   frost, i.e. when the temperature < \code{lowtemp}.
#'   This function is exported for its use in vignettes only.
#'
#' @param df input \code{data.frame}
#'
#' @export
#' @keywords internal
#'
plot_frost_period <- function(df) {

  df <- df %>%
    dplyr::mutate(frost = ifelse(is.na(frost), FALSE, frost))

  if (sum(df$frost, na.rm = TRUE) > 0) {
    x0 <- df %>%
      dplyr::mutate(frost_group = cumsum(!frost)) %>%
      dplyr::filter(frost == TRUE) %>%
      dplyr::group_by(frost_group) %>%
      dplyr::slice(1) %>%
      dplyr::ungroup() %>%
      dplyr::select(ts)
    x0 <- x0$ts

    x1 <- df %>%
      dplyr::mutate(frost_group = cumsum(!frost)) %>%
      dplyr::filter(frost == TRUE) %>%
      dplyr::group_by(frost_group) %>%
      dplyr::slice(dplyr::n()) %>%
      dplyr::ungroup() %>%
      dplyr::select(ts)
    x1 <- x1$ts

    y0 <- min(df$value_L2, na.rm = TRUE) + 0.02 *
      (max(df$value_L2, na.rm = TRUE) - min(df$value_L2,
                                                 na.rm = TRUE))

    for (s in 1:length(x0)) {
      graphics::segments(x0 = x0[s], y0, x1 = x1[s], y1 = y0, col = "#1ac4c4")
    }
  }
}


#' Plot Interpolated Points
#'
#' \code{plot_interpol_points} adds points on top of line graph to show
#'   points that were interpolated.
#'
#' @param df input \code{data.frame}
#'
#' @keywords internal
#'
plot_interpol_points <- function(df) {

  interpol <- grep("fill", df$flags)
  if (length(interpol) > 0) {
    graphics::points(x = df$ts[interpol], y = df$value_L2[interpol],
                     col = "#08519c", pch = 1, cex = 1.2)
  }
}


#' Plot Phases
#'
#' \code{plot_phase} plots phases of shrinkage and expansion based on
#'   selected maxima and minima and returns some statistics on the phases.
#'
#' @param df input \code{data.frame}.
#' @param phase \code{data.frame} containing statistics on the shrinkage
#'   phase and expansion phase.
#'
#' @return Plots are saved to current working directory as
#'   \code{phase_plot.pdf}.
#'
#' @keywords internal
#'
plot_phase <- function(df, phase, plot_export) {

  series <- unique(phase$series)
  if (plot_export) {
    grDevices::pdf(paste0("phase_plot_", series, ".pdf"),
                   width = 8.3, height = 5.8)
  }

  shrink <- phase %>%
    dplyr::mutate(mode = "shrink") %>%
    dplyr::filter(!is.na(shrink_start)) %>%
    dplyr::select(start = shrink_start, end = shrink_end, dur = shrink_dur,
                  amp = shrink_amp, slope = shrink_slope, mode)

  exp <- phase %>%
    dplyr::mutate(mode = "exp") %>%
    dplyr::filter(!is.na(exp_start)) %>%
    dplyr::select(start = exp_start, end = exp_end, dur = exp_dur,
                  amp = exp_amp, slope = exp_slope, mode)

  phase <- dplyr::bind_rows(shrink, exp) %>%
    dplyr::arrange(start)

  # add extrema to df
  extrema_start <- phase %>%
    dplyr::mutate(extrema = mode) %>%
    dplyr::mutate(extrema = ifelse(mode == "shrink", "max", "min")) %>%
    dplyr::select(ts = start, extrema)

  df <- phase %>%
    dplyr::mutate(extrema = mode) %>%
    dplyr::mutate(extrema = ifelse(mode == "shrink", "min", "max")) %>%
    dplyr::select(ts = end, extrema) %>%
    dplyr::full_join(., extrema_start, by = c("ts", "extrema")) %>%
    dplyr::right_join(., df, by = "ts") %>%
    dplyr::arrange(series, ts)

  for (p in 1:nrow(phase)) {
    phase_plot <- phase[p, ]

    plot_start <- phase_plot$start - as.difftime(12, units = "hours")
    plot_end <- phase_plot$end + as.difftime(12, units = "hours")

    df_plot <- df %>%
      dplyr::filter(ts >= plot_start & ts <= plot_end)

    graphics::plot(x = df_plot$ts, y = df_plot$value, type = "l",
                   xaxt = "n", las = 1,
                   ylab = paste0("Stem radius (", "\u00b5", "m)"),
                   xlab = paste("Time (Hours)\n",
                                as.Date(phase_plot$start), "to",
                                as.Date(phase_plot$end)),
                   main = paste0(df_plot$series[1], "\n",
                                 ifelse(phase_plot$mode == "shrink",
                                        "Shrinkage", "Expansion")))
    graphics::axis.POSIXct(1, x = df_plot$ts, format = "%H")
    graphics::abline(v = as.POSIXct(unique(as.Date(df_plot$ts))),
                     lty = "dashed", col = "grey")

    graphics::points(x = phase_plot$start,
                     y = df_plot$value[df_plot$ts == phase_plot$start],
                     pch = ifelse(phase_plot$mode == "shrink", 16, 17))
    graphics::points(x = phase_plot$end,
                     y = df_plot$value[df_plot$ts == phase_plot$end],
                     pch = ifelse(phase_plot$mode == "shrink", 17, 16))
    # plot adjacent maxima and minima
    graphics::points(x = df_plot$ts[df_plot$extrema == "max"],
                     y = df_plot$value[df_plot$extrema == "max"],
                     pch = 1)
    graphics::points(x = df_plot$ts[df_plot$extrema == "min"],
                     y = df_plot$value[df_plot$extrema == "min"],
                     pch = 2)

    graphics::legend(x = ifelse(phase_plot$mode == "shrink",
                                "bottomleft", "bottomright"),
                     legend = c(paste("Phase duration =",
                                      phase_plot$dur),
                                paste("Amplitude =",
                                      round(phase_plot$amp, 2)),
                                paste("Slope =",
                                      round(phase_plot$slope, 4))),
                                bty = "n")
  }

  if (plot_export) {
    grDevices::dev.off()
  }
}


#' Plot Command to Plot L1 Data
#'
#' \code{plotting_L1} plots \code{L1} data.
#'
#' @param data_L1_orig uncorrected original \code{L1} data. If specified, it
#'   is plotted behind the corrected \code{L1} data.
#' @inheritParams plot_proc_L2
#'
#' @keywords internal
#'
plotting_L1 <- function(data_L1, data_L1_orig, plot_period, tz) {

  if (length(data_L1_orig) != 0) {
    plot_add <- TRUE
  } else {
    plot_add <- FALSE
  }

  # define axis labels
  axis_labs <- axis_labels_period(df = data_L1, plot_period = plot_period,
                                  tz = tz)

  # plot
  graphics::plot(data = data_L1, value ~ ts, type = "n",
                 xlab = passobj("year_label"),
                 ylab = "L1", xaxt = "n", las = 1,
                 main = passobj("sensor_label"))
  if (plot_add) {
    graphics::lines(data = data_L1_orig, value ~ ts, col = "grey70")
  }
  graphics::lines(data = data_L1, value ~ ts, col = "#08519c")
  graphics::axis(1, at = axis_labs[[1]], labels = axis_labs[[2]])
}


#' Plot density of differences
#'
#' \code{plot_density} plots the density of the value differences between
#'   two time stamps. In addition, the threshold values used to classify
#'   outliers are shown.
#'
#' @param df input \code{data.frame}.
#' @param ran numeric, range of rows in df considered for the density plot.
#'   Compatible with different window sizes for data processing.
#' @param low numeric, low threshold defining outliers. Inherited of the
#'   function \code{\link{calcflagmad}}.
#' @param high numeric, high threshold defining outliers. Inherited of the
#'   function \code{\link{calcflagmad}}.
#' @param limit_val numeric, defines the x-axis limits of the density plot.
#'   The x-axis limits are drawn at \code{limit_val * threshold}. Threshold
#'   values are inherited of the function \code{\link{calcflagmad}}.
#' @param plot_export logical, defines whether plots are exported or shown
#'   directly in the console.
#' @inheritParams proc_dendro_L2
#'
#' @return Plots are saved to current working directory as
#'   \code{density_plot.pdf}.
#'
#' @keywords internal
#'
plot_density <- function(df, low, high, limit_val = 20, frost_thr,
                         reso) {

  series <- unique(df$series)[1]
  df_plot <- df %>%
    dplyr::mutate(diff_val = c(NA, diff(value)) * (60 / reso))

  graphics::plot(stats::density(x = df_plot$diff_val, na.rm = TRUE),
                 xlim = c(limit_val * low, limit_val * high),
                 xlab = "", ylab = "Density",
                 main = paste(series, "\n", substr(df_plot$ts[1], 1, 10),
                              "to", substr(dplyr::last(df_plot$ts), 1, 10)))

  graphics::rug(x = df_plot$diff_val[df$frost == FALSE], col = "#9c2828",
                quiet = TRUE)
  graphics::rug(x = df_plot$diff_val[df$frost == TRUE], col = "#73bfbf",
                side = 3, quiet = TRUE)
  graphics::abline(v = low, col = "#9c2828")
  graphics::abline(v = high, col = "#9c2828")
  graphics::abline(v = low * frost_thr, col = "#73bfbf")
  graphics::abline(v = high * frost_thr, col = "#73bfbf")
}
