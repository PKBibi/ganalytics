#' @include ganalytics-package.R
#' @include helper-functions.R
NULL

# Class definitions for ganalytics
# --------------------------------

# ---- GA dimension and metric variables ----

setOldClass(c("gaUserSegment", "R6"))
setOldClass(c("gaAccount", "R6"))
setOldClass(c("gaProperty", "R6"))
setOldClass(c("gaView", "R6"))

setClass(
  Class = "gaMetVar",
  prototype = prototype("ga:sessions"),
  contains = "character",
  validity = function(object) {
    if (!IsVarMatch(object@.Data, kGaVars$mets)) {
      return(
        paste("Invalid GA metric name", object@.Data, sep = ": ")
      )  
    }
    return(TRUE)
  }
)


setClass(
  Class = "gaDimVar",
  prototype = prototype("ga:date"),
  contains = "character",
  validity = function(object) {
    if (!IsVarMatch(object@.Data, kGaVars$dims)) {
      return(
        paste("Invalid GA dimension name", object@.Data, sep = ": ")
      )  
    }
    return(TRUE)
  }
)

setClassUnion(
  name = ".gaVar",
  members = c("gaMetVar", "gaDimVar")
)

setValidity(
  Class=".gaVar",
  method=function(object) {
    if(length(object) != 1) {
      return("gaVar's must be a character vector of length 1")
    }
    return(TRUE)
  }
)

IsVarMatch <- function(thisVar, inVars) {
  # The following method is a temporary workaround to support XX placeholders in dimension and metric
  # names, such as with custom dimensions, metrics and various goal related variables.
  inVars <- str_replace(inVars, "XX", replacement = "[0-9]+")
  inVars <- paste0("^", inVars, "$")
  any(str_detect(thisVar, ignore.case(inVars)))
}

# ---- GA expression operators ----


setClass(
  Class = "gaMetOperator",
  contains = "character",
  prototype = prototype("=="),
  validity = function(object) {
    if (!(object@.Data %in% kGaOps$met)) {
      return(
        paste("Invalid metric operator", object@.Data, sep = ": ")
      )
    }
    return(TRUE)
  }
)


setClass(
  Class = "gaDimOperator",
  contains = "character",
  prototype = prototype("=="),
  validity = function(object) {
    if (!(object@.Data %in% kGaOps$dim)) {
      return(
        paste("Invalid dimension operator", object@.Data, sep = ": ")
      )
    }
    return(TRUE)
  }
)

# export
# setClass(
#   #{dimensionOrMetricName}<>{minValue}_{maxValue} #For metrics or numerical dimensions, also dates
#   #{dimensionName}[]{value1}|{value2}|...
#   #A maximum of 10 values per in-list dimension condition is allowed. Only for dimensions
#   contains = ".gaOperator"
#   #dateOfSession<>2014-05-20_2014-05-30
#   dateOfSession is a special dimension
# )

setClassUnion(
  name = ".gaOperator",
  members = c("gaMetOperator", "gaDimOperator")
)

setValidity(
  Class = ".gaOperator",
  method = function(object) {
    if(length(object) != 1) {
      return("gaOperator's must be character vector of length 1")
    }
    return(TRUE)
  }
)

# ---- GA expression operands ----


setClass(
  Class = "gaMetOperand",
  contains = "numeric"
)


setClass(
  Class = "gaDimOperand",
  contains = "character"
)


setClass(
  "gaDimOperandList",
  contains = "list",
  validity = function(object) {
    if (length(object) < 1) {
      return(
        "A gaDimOperandList must be of at least length 1"
      )
    }
    if (any(lapply(object, class) != "gaDimOperand")) {
      return(
        "All items within a gaDimOperandList must be of class gaDimOperand"
      )
    }
    return(TRUE)
  }
)

setClassUnion(
  name = ".gaOperandScalar",
  members = c("gaMetOperand", "gaDimOperand")
)

setValidity(
  Class = ".gaOperandScalar",
  method = function(object) {
    if(length(object) != 1) {
      return(".gaOperand must be a vector of length 1")
    }
    return(TRUE)
  }
)

setClassUnion(
  name = ".gaOperand",
  members = c(".gaOperandScalar", "gaDimOperandList")
)

# ---- GA simple expressions -------------------------------------------------------

setClass(
  Class = ".gaExpr",
  representation = representation(
    gaVar = ".gaVar",
    gaOperator = ".gaOperator",
    gaOperand = ".gaOperand"
  ),
  contains = "VIRTUAL"
)


setClass(
  Class = "gaMetExpr",
  contains = ".gaExpr",
  validity = function(object) {
    if (!class(object@gaVar)=="gaMetVar") {
      return("gaVar must be of class gaMetVar")
    } else if (!class(object@gaOperator)=="gaMetOperator") {
      return("gaOperator must be of class gaMetOperator")
    } else if (!class(object@gaOperand)=="gaMetOperand") {
      return("gaOperand must be of class gaMetOperand")
    } else {
      return(TRUE)
    }
  }
)


setClass(
  Class = "gaSegMetExpr",
  representation = representation(
    metricScope = "character"
  ),
  prototype = prototype(
    metricScope = "perSession"
  ),
  contains = "gaMetExpr",
  validity =  function(object) {
    if (!length(object@metricScope) == 1) {
      return("metricScope must be of length 1.")
    } else if (!(object@metricScope %in% c("", "perUser", "perSession", "perHit"))) {
      return("metricScope must be one of '', 'perUser', 'perSession' or 'perHit'.")
    } else {
      return(TRUE)
    }
  }
)


setClass(
  Class = "gaDimExpr",
  contains = ".gaExpr",
  validity = function(object) {
    if (!class(object@gaVar)=="gaDimVar") {
      return("gaVar must be of class gaDimVar")
    } else if (!class(object@gaOperator)=="gaDimOperator") {
      return("gaOperator must be of class gaDimOperator")
    } else if (!class(object@gaOperand)=="gaDimOperand") {
      return("gaOperand must be of class gaDimOperand")
    } else if (GaIsRegEx(object@gaOperator) & nchar(object@gaOperand) > 128) {
      return(
        paste("Regular expressions in GA Dimension Expressions cannot exceed 128 chars. Length", nchar(object@gaOperand), sep = " = ")
      )
    } else if (object@gaOperator %in% c("!=", "==")) {
      return(
        ValidGaOperand(object@gaVar, object@gaOperand)
      )
    } else {
      return(TRUE)
    }
  }
)

#' ValidGaOperand
#' 
#' Checks whether an operand value is valid for a selected dimension.
#' 
#' @param gaVar selected dimension to check operand against
#' @param gaOperand the operand value to check
#' 
ValidGaOperand <- function(gaVar, gaOperand) {
  test <- switch(
    gaVar,
    "ga:date" = grepl(pattern = "^[0-9]{8}$", x = gaOperand) &&
      (as.Date(x = gaOperand, format = kGaDateOutFormat) >= kGaDateOrigin),
    "ga:year" = grepl(pattern = "^[0-9]{4}$", x = gaOperand) &&
      (as.Date(x = gaOperand, format = "%Y") >= kGaDateOrigin),
    "ga:month" = grepl(pattern = "^(0[1-9]|1[0-2])$", x = gaOperand),
    "ga:week" = grepl(pattern = "^([0-4][1-9]|5[0-3])$", x = gaOperand),
    "ga:day" = grepl(pattern = "^([0-2][0-9][1-9]|3[0-5][0-9]|36[0-6])$", x = gaOperand),
    "ga:hour" = grepl(pattern = "^([01][0-9]|2[0-3])$", x = gaOperand),
    "ga:dayOfWeek" = grepl(pattern = "^[0-6]$", x = gaOperand),
    "ga:visitorType" = gaOperand %in% c("New Visitor", "Returning Visitor"),
    TRUE
  )
  if (gaVar %in% c("ga:nthMonth", "ga:nthWeek", "ga:nthDay", "ga:pageDepth", "ga:visitLength", "ga:visitCount", "ga:daysSinceLastVisit")) {
    test <- as.numeric(gaOperand) > 0
  } else if (gaVar %in% c("ga:searchUsed", "ga:javaEnabled", "ga:isMobile", "ga:isTablet", "ga:hasSocialSourceReferral")) {
    test <- gaOperand %in% c("Yes", "No")
  }
  if (test) {
    return(TRUE)
  } else {
    return(paste("Invalid", gaVar, "operand:", gaOperand))
  }
}

# ---- GA 'AND' and 'OR' compound expressions -------------------------------


setClass(
  Class = "gaOr",
  contains = "list",
  # A object of class gaOr must be a list containing
  # objects from the superclass .gaExpr
  # i.e. it must contain gaDimExprs or gaMetExprs, or both
  validity = function(object) {
    if (
      !all(
        sapply(
          X = object@.Data,
          FUN = function(x) {
            inherits(x, ".gaExpr")
          }
        )
      )
    ) {
      return("gaOr must be a list containing objects that all inherit from the class .gaExpr")
    } else {
      return(TRUE)
    }
  }
)


setClass(
  Class = "gaAnd",
  contains = "list",
  validity = function(object) {
    if (
      all(
        sapply(
          X = object@.Data,
          FUN = function(x) {
            class(x) == "gaOr"
          }
        )
      )
    ) {
      return(TRUE)
    } else {
      return("gaAnd must be a list containing objects all of the class gaOr")
    }
  }
)

# ---- Simple and compound expression class union ----

setClassUnion(
  name = ".gaCompoundExpr",
  members = c(".gaExpr", "gaOr", "gaAnd")
)

# ---- GA filter ----


setClass(
  Class = "gaFilter",
  contains = "gaAnd",
  validity = function(object) {
    ## Check that single expressions within each OR expression exclusively
    ## belong to one class, i.e. either Metrics or Dimensions
    if (
      all(
        sapply(
          X = object@.Data,
          FUN = function(gaOr) {
            length(
              unique(
                sapply(
                  X = gaOr,
                  FUN = class
                )
              )
            ) == 1
          }
        )
      )
    ) {
      return(TRUE)
    } else {
      return("An OR expression in a filter cannot mix metrics and dimensions.")
    }
  }
)

# ---- GA Dynamic and pre-defined segments ----

setClass(
  Class = ".gaDimensionOrMetricConditions",
  representation = representation(
    negation = "logical"
  ),
  prototype = prototype(
    negation = FALSE
  ),
  contains = "VIRTUAL",
  validity = function(object) {
    if (length(object@negation) == 1) {
      TRUE
    } else {
      "Slot negation must be of length 1."
    }
  }
)


setClass(
  Class = "gaSequenceStep",
  representation = representation(
    immediatelyPrecedes = "logical"
  ),
  prototype = prototype(
    immediatelyPrecedes = FALSE
  ),
  contains = "gaAnd",
  validity = function(object) {
    if (length(object@immediatelyPrecedes) == 1) {
      return(TRUE)
    } else {
      return("immediatelyPrecedes must be of length 1.")
    }
  }
)


setClass(
  Class = "gaSequenceCondition",
  contains = c("list", ".gaDimensionOrMetricConditions"),
  validity = function(object) {
    if (all(sapply(object@.Data, function(x) {
      inherits(x, "gaSequenceStep")
    }))) {
      TRUE
    } else {
      "All conditions within a sequence list must belong to the superclass gaSequenceStep."
    }
  }
)


setClass(
  Class = "gaNonSequenceCondition",
  contains = c("gaAnd", ".gaDimensionOrMetricConditions")
)


setClass(
  Class = "gaSegmentCondition",
  representation = representation(
    conditionScope = "character"
  ),
  prototype = prototype(
    conditionScope = "sessions"
  ),
  contains = "list",
  validity = function(object) {
    if (all(sapply(object@.Data, function(x) {
      inherits(x, ".gaDimensionOrMetricConditions")
    }))) {
      if (length(object@conditionScope) == 1) {
        if (object@conditionScope %in% c("users", "sessions")) {
          TRUE
        } else {
          "Slot 'conditionScope' must be either 'users' or 'sessions'."
        }
      } else {
        "Slot 'conditionScope' must be of length 1."
      }
    } else {
      "All conditions within a gaSegmentCondition list must belong to the superclass .gaDimensionOrMetricConditions."
    }
  }
)


setClass(
  Class = "gaDynSegment",
  contains = "list",
  validity = function(object) {
    if (all(sapply(object@.Data, function(x) {inherits(x, "gaSegmentCondition")}))) {
      TRUE
    } else {
      "All objects with a gaDynSegment list must belong to the class gaSegmentCondition."
    } 
  }
)


setClass(
  Class = "gaSegmentId",
  contains = "character",
  validity = function(object) {
    pattern <- "^gaid::\\-?[0-9]+$"
    if (length(object) != 1) {
      return("gaSegmentId must be a character vector of length 1")
    }
    if (!grepl(pattern = pattern, x = object@.Data)) {
      return(
        paste("gaSegmentId must match the regular expression ", pattern, sep = "")
      )
    }
    TRUE
  }
)

setClassUnion(
  name = ".gaSegment",
  members = c("gaDynSegment", "gaSegmentId")
)

# setClassUnion(
#   name = ".gaLogical",
#   members = c(".gaOperator",".gaCompoundExpr")
# )

# ---- GA query dimensions, metrics, and sortby lists ----


setClass(
  Class = "gaDateRange",
  representation = representation(
    startDate = "Date",
    endDate = "Date"
  ),
  prototype = prototype(
    startDate = Sys.Date() - 8,
    endDate = Sys.Date() - 1
  ),
  validity = function(object) {
    if (length(object@startDate) == length(object@endDate)) {
      if (all(object@endDate >= object@startDate)) {
        return(TRUE)
      } else {
        return("endDate cannot be before startDate")
      }
    } else {
      return("startDate and endDate must be the same length")
    }
  }
)


setClass(
  Class = "gaMetrics",
  prototype = prototype(
    list(new("gaMetVar"))
  ),
  contains = "list",
  validity = function(object) {
    if (
      all(
        sapply(
          X = object,
          FUN = function(gaVar) {
            class(gaVar) == "gaMetVar"
          }
        )
      )
    ) {
      if (length(object) <= kGaMax$metrics) {
        return(TRUE)
      } else {
        paste("Maximum of", kGaMax$metrics, "metrics allowed.", sep = " ")
      }
    } else {
      return("Must be a list containing objects of class gaMetVar")
    }
  }
)


setClass(
  Class = "gaDimensions",
  prototype = prototype(
    list(new("gaDimVar"))
  ),
  contains = "list",
  validity = function(object) {
    if (
      all(
        sapply(
          X = object,
          FUN = function(.gaVar) {
            class(.gaVar) == "gaDimVar"
          }
        )
      )
    ) {
      if (length(object) <= kGaMax$dimensions) {
        return(TRUE)
      } else {
        paste("Maximum of", kGaMax$dimensions, "dimensions allowed.", sep = " ")
      }
    } else {
      return("Must be a list containing objects of class gaDimVar")
    }
  }
)


setClass(
  Class = "gaSortBy",
  representation = representation(
    desc = "logical"
  ),
  prototype = prototype(
    list(),
    desc = logical()
  ),
  contains = "list",
  validity = function(object) {
    if (
      all(
        sapply(
          X = object@.Data,
          FUN = function(gaVar) {
            inherits(gaVar, ".gaVar")
          }
        )
      )
    ) {
      if (length(object@.Data) == length(object@desc)) {
        return(TRUE)
      } else {
        return("List vector and desc vector must be of equal lengths")
      }
    } else {
      return("Must be a list containing objects of class .gaVar")
    }
  }
)

setClassUnion(
  name = ".gaVarList",
  members = c("gaMetrics", "gaDimensions", "gaSortBy"),
)

# ---- Ga Profile ID ----


setClass(
  Class = "gaProfileId",
  contains = "character",
  validity = function(object) {
    if (
      all(
        sapply(
          X = object,
          FUN = function(profileId) {
            grepl(pattern = "^ga:[0-9]+$",  x = profileId)
          }
        )
      )
    ) {
      return(TRUE)
    } else {
      return("gaProfileId must be an string of digits preceeded by 'ga:'")
    }
  }
)

# -- GA query construct ----

samplingLevel_levels <- c("DEFAULT", "FASTER", "HIGHER_PRECISION")

setClassUnion("characterOrList", c("character", "list"))

setClass(
  Class = "gaQuery",
  representation = representation(
    profileId = "gaProfileId",
    dateRange = "gaDateRange",
    metrics = "gaMetrics",
    dimensions = "gaDimensions",
    sortBy = "gaSortBy",
    filters = "gaFilter",
    segment = ".gaSegment",
    samplingLevel = "character",
    maxResults = "numeric",
    authFile = "character",
    userName = "character",
    appCreds = "characterOrList"
  ),
  prototype = prototype(
    dateRange = new("gaDateRange"),
    metrics = new("gaMetrics"),
    dimensions = new("gaDimensions"),
    sortBy = new("gaSortBy"),
    samplingLevel = "DEFAULT",
    maxResults = kGaMaxResults
  ),
  validity = function(object) {
    if (length(object@maxResults) == 1) {
      if (object@maxResults >= 1) {
        if (object@maxResults <= kGaMaxRows) {
          if (!is.null(object@sortBy)) {
            if (
              all(
                !is.na(
                  match(
                    x = object@sortBy,
                    table = union(object@metrics, object@dimensions)
                  )
                )
              )
            ) {
              if ((length(object@samplingLevel) != 1) | !(object@samplingLevel %in% samplingLevel_levels)) {
                return(paste("samplingLevel must be one of:", samplingLevel_levels))
              } else {
                return(TRUE)
              }
            } else {
              return("sortBy must contain varNames also used as metrics and/or dimensions")
            }
          } else {
            return(TRUE)
          }
        } else {
          return("maxResults cannot be greater than 1,000,000")
        }
      } else {
        return("maxResults must be at least 1")
      }
    } else {
      return("maxResults must be of length 1")
    }
  }
)

setClassUnion(
  name = ".gaUrlClasses",
  members = c(
    #".gaCompoundExpr",
    ".gaExpr", "gaOr", "gaAnd", "gaDynSegment",
    
    #".gaVarList",
    "gaMetrics", "gaDimensions", "gaSortBy",
    
    ".gaVar",
    ".gaOperator",
    ".gaOperand",
    ".gaSegment",
    "gaFilter",
    "gaProfileId",
    "Date",
    "gaQuery"
  )
)

setClass(
  Class = "utf8",
  contains = "character"
)
