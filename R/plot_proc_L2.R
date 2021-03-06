#' Plot Changes Between Time-aligned and Cleaned Dendrometer Data
#'
#' \code{plot_proc_L2} plots changes between time-aligned (\code{L1}) and
#'   cleaned (\code{L2}) dendrometer data to visually evaluate the data
#'   cleaning.
#'
#' @param dendro_L1 time-aligned dendrometer data as produced by
#'   \code{\link{proc_L1}}.
#' @param dendro_L2 cleaned dendrometer data as produced by
#'   \code{\link{proc_dendro_L2}}.
#' @param plot_period character, specify whether plots should be displayed for
#'   the whole period (\code{plot_period = "full"}), separately for each
#'   year (\code{plot_period = "yearly"}) or for each month
#'   (\code{plot_period = "monthly"}).
#' @param plot_show character, specify whether all periods should be plotted
#'   (\code{plot_show = "all"}) or only those periods in which \code{L1}
#'   dendrometer data changed during data cleaning (\code{plot_show = "diff"}).
#' @param plot_name character, specify name of the PDF to which the plots are
#'   saved.
#' @param plot_export logical, specifies whether the plots are exported as a
#'   \code{PDF} file to the working directory or are plotted in the console.
#' @param thr_plot \code{data.frame}, containing the threshold values used for
#'   outlier detection. Command is only used internally by the function
#'   \code{\link{proc_dendro_L2}}.
#' @inheritParams proc_L1
#'
#' @return Plots are saved in a PDF to the current working directory as
#'   \code{proc_L2_plot.pdf} or as specified in \code{plot_name}.
#'
#'   The first panel shows the \code{L1} data, the second panel the
#'   cleaned \code{L2} data (in blue) with the \code{L1} data (in grey) in the
#'   background. Blue circles indicate interpolated points. Horizontal cyan
#'   lines at the bottom of the panel indicate frost periods. The third panel
#'   shows the changes (red) as well as the deleted values (pink) on a
#'   logarithmic scale. In case \code{plot_period = "monthly"}, the changes
#'   that occurred are numbered. The ID numbers facilitate the reversal of
#'   wrong or unwanted corrections with \code{\link{corr_dendro_L2}}.
#'   The last panel shows the tree-water deficit (twd).
#'
#' @export
#'
#' @examples
#' plot_proc_L2(dendro_L1 = dendro_data_L1, dendro_L2 = dendro_data_L2,
#'             plot_period = "yearly", plot_export = FALSE)
#'
plot_proc_L2 <- function(dendro_L1, dendro_L2, plot_period = "full",
                         plot_show = "all", plot_export = TRUE,
                         plot_name = "proc_L2_plot", tz = "UTC",
                         thr_plot = NULL) {

  # Check input variables -----------------------------------------------------
  list_inputs <- mget(ls())
  check_input_variables(list = list_inputs)


  # Check input data ----------------------------------------------------------
  data_L1 <- dendro_L1
  data_L2 <- dendro_L2
  check_data_L1(data_L1 = data_L1)
  check_data_L2(data_L2 = data_L2)


  # Calculate differences -----------------------------------------------------
  # add diff_old, used to plot removed differences (see corr_dendro_L2)
  if (!("diff_old" %in% colnames(data_L1))) {
    data_L1$diff_old <- NA
    data_L1$diff_nr_old <- NA
  }
  # add month_plot used to plot months with force or delete
  # (see corr_dendro_L2)
  if (!("month_plot" %in% colnames(data_L1))) {
    data_L1$month_plot <- 0
  }
  df_L1 <- data_L1 %>%
    dplyr::mutate(year = strftime(ts, format = "%Y", tz = tz)) %>%
    dplyr::mutate(month = strftime(ts, format = "%m", tz = tz)) %>%
    dplyr::group_by(series) %>%
    dplyr::mutate(diff_L1 = c(NA, diff(value, lag = 1))) %>%
    dplyr::ungroup() %>%
    dplyr::rename(value_L1 = value) %>%
    dplyr::select_if(!(names(.) %in% "version"))
  df_L2 <- data_L2 %>%
    dplyr::mutate(year = strftime(ts, format = "%Y", tz = tz)) %>%
    dplyr::mutate(month = strftime(ts, format = "%m", tz = tz)) %>%
    dplyr::group_by(series) %>%
    dplyr::mutate(diff_L2 = c(NA, diff(value, lag = 1))) %>%
    dplyr::ungroup() %>%
    dplyr::rename(value_L2 = value) %>%
    dplyr::select_if(!(names(.) %in% "version"))
  df <- dplyr::full_join(df_L1, df_L2, by = c("ts", "series", "year", "month"))

  sensors <- unique(df$series)
  years <- unique(df$year)

  if (plot_export) {
    grDevices::pdf(paste0(plot_name, ".pdf"), width = 8.3, height = 11.7)
  }
  for (s in 1:length(sensors)) {
    sensor_label <- sensors[s]
    passenv$sensor_label <- sensor_label
    df_sensor <- df %>%
      dplyr::filter(series == sensor_label)

    diff_sensor <- df_sensor %>%
      dplyr::mutate(diff = diff_L1 - diff_L2) %>%
      # remove small differences without flag
      dplyr::mutate(diff = ifelse(grepl(".*out|.*jump", flags), diff, 0)) %>%
      dplyr::mutate(diff = ifelse(is.na(diff), 0, diff)) %>%
      # add diff = 100 for removed outliers (flag = "out")
      dplyr::mutate(diff = ifelse(grepl("out", flags), 100, diff)) %>%
      dplyr::mutate(diff_nr = 0) %>%
      dplyr::mutate(diff_nr = ifelse(grepl(".*out|.*jump", flags), 1, 0)) %>%
      dplyr::mutate(diff_nr = cumsum(diff_nr)) %>%
      dplyr::mutate(diff_nr = ifelse(grepl(".*out|.*jump", flags),
                                     diff_nr, NA)) %>%
      # add diff for jumps
      dplyr::mutate(jump_group = !is.na(diff_nr)) %>%
      dplyr::mutate(jump_group = cumsum(jump_group)) %>%
      dplyr::mutate(y = c(0, diff(jump_group, lag = 1))) %>%
      dplyr::mutate(z = c(0, diff(y, lag = 1))) %>%
      dplyr::mutate(z = ifelse(z == -1, 1, z)) %>%
      dplyr::mutate(jump_nr = cumsum(z)) %>%
      dplyr::group_by(jump_nr) %>%
      dplyr::mutate(jump_group = ifelse(any(grepl(".*jump", flags)),
                                        jump_nr, NA)) %>%
      dplyr::ungroup() %>%
      dplyr::group_by(jump_group) %>%
      dplyr::mutate(diff_jump = sum(diff_L1, na.rm = TRUE)) %>%
      dplyr::ungroup() %>%
      dplyr::mutate(diff = ifelse(grepl(".*jump", flags),
                                  diff_jump, diff)) %>%
      dplyr::mutate(diff_plot = abs(diff)) %>%
      dplyr::select(-jump_group, -y, -z, -jump_nr, -diff_jump)


    # Plot L1, L2 and daily diff ----------------------------------------------
    if (plot_period %in% c("yearly", "monthly")) {

      for (y in 1:length(years)) {
        year_label <- years[y]
        passenv$year_label <- year_label
        df_year <- diff_sensor %>%
          dplyr::filter(year == year_label) %>%
          # set value_L1 and value_L2 to same value at beginning of year
          dplyr::mutate(value_L2 = value_L2 +
                          (value_L1[which(!is.na(value_L1))[1]] -
                             value_L2[which(!is.na(value_L2))[1]]))

        if (plot_period == "yearly") {
          if (sum(!is.na(df_year$value_L1)) != 0 &
              sum(!is.na(df_year$value_L2)) != 0) {
            if (plot_show == "diff" &
                max(df_year$diff_plot) == 0) {
              next
            }
            plotting_proc_L2(data_plot = df_year, plot_period = plot_period,
                             tz = tz)
          } else {
            next
          }
        }

        if (plot_period == "monthly") {
          months <- unique(df_year$month)

          for (m in 1:length(months)) {
            month_label <- months[m]
            year_label <- paste0(years[y], "-", months[m])
            passenv$year_label <- year_label
            df_month <- df_year %>%
              dplyr::filter(month == month_label) %>%
              # set value_L1 and value_L2 to same value at beginning of month
              dplyr::mutate(value_L2 = value_L2 +
                              (value_L1[which(!is.na(value_L1))[1]] -
                                 value_L2[which(!is.na(value_L2))[1]]))

            if (sum(!is.na(df_month$diff_nr)) != 0 |
                sum(!is.na(df_month$diff_nr_old)) != 0) {

              diff_month <- df_month %>%
                dplyr::mutate(day = strftime(ts, format = "%d", tz = tz)) %>%
                dplyr::group_by(year, month, day) %>%
                dplyr::mutate(
                  diff_nr_first = dplyr::first(diff_nr[which(!is.na(diff_nr))]),
                  diff_nr_last = dplyr::last(diff_nr[which(!is.na(diff_nr))]),
                  diff_nr_old_first =
                    dplyr::first(diff_nr_old[which(!is.na(diff_nr_old))]),
                  diff_nr_old_last =
                    dplyr::last(diff_nr_old[which(!is.na(diff_nr_old))])) %>%
                dplyr::mutate(
                  diff_nr = ifelse(diff_nr_first != diff_nr_last,
                                   paste0(diff_nr_first, "-", diff_nr_last),
                                   as.character(diff_nr_first)),
                  diff_nr_old = ifelse(diff_nr_old_first != diff_nr_old_last,
                                       paste0(diff_nr_old_first, "-",
                                              diff_nr_old_last),
                                       as.character(diff_nr_old_first))) %>%
                dplyr::ungroup() %>%
                dplyr::filter((diff != 0 & !is.na(diff_nr)) |
                                (diff_old != 0 & !is.na(diff_nr_old))) %>%
                # select middle value for positioning label in plot
                dplyr::group_by(year, month, day) %>%
                dplyr::slice(ceiling(dplyr::n() / 2)) %>%
                dplyr::ungroup() %>%
                dplyr::select(series, ts, diff_nr, diff_nr_old)

              df_month <- df_month %>%
                dplyr::select(-diff_nr, -diff_nr_old) %>%
                dplyr::full_join(., diff_month, by = c("series", "ts"))
            }

            if (sum(!is.na(df_month$value_L1)) != 0 &
                sum(!is.na(df_month$value_L2)) != 0) {
              if (plot_show == "diff" &
                  sum(!is.na(df_month$diff_nr)) == 0) {
                next
              }
              if (plot_show == "diff_corr") {
                if (sum(!is.na(df_month$diff_nr_old)) == 0 &
                    !(1 %in% df_month$month_plot)) {
                  next
                }
              }

              plotting_proc_L2(data_plot = df_month,
                               plot_period = plot_period, tz = tz)
            } else {
              next
            }
          }
        }
      }
    }

    if (plot_period == "full") {
      year_label <- paste0(years[1], "-", years[length(years)])
      passenv$year_label <- year_label

      if (sum(!is.na(diff_sensor$value_L1)) != 0 &
          sum(!is.na(diff_sensor$value_L2)) != 0) {
        plotting_proc_L2(data_plot = diff_sensor, plot_period = plot_period,
                         tz = tz)
      } else {
        next
      }
    }

    # Plot yearly growth and print variables  ---------------------------------
    plot_gro_yr_print_vars(data_plot = diff_sensor, thr_plot = thr_plot,
                           tz = tz)
  }
  if (plot_export) {
    grDevices::dev.off()
  }
}
