#' ganalytics
#' 
#' A Google Analytics client for R
#' 
#' S4 classes and methods for interacting with Google Analytics data in R.
#' 
#' @references Google Analytics dimensions and metrics reference:
#'   \url{https://developers.google.com/analytics/devguides/reporting/core/dimsmets}
#'   
#' @keywords package
#' @import methods
#' @import R6
#' @import httr
#' @import plyr
#' @importFrom lubridate now ymd_hms
#' @import stringr
#' @import jsonlite
#' @import XML
#' @importFrom selectr querySelector
#' @docType package
#' @name ganalytics
#' @aliases ganalytics ganalytics-package
NULL

#' @include globaldata.R
