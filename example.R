source("r2docsets.R")

# single package
# which.package <- "quantreg"
# r2docsetts(which.package)

# several packages
sapply(c("quantreg", "dplyr", "plyr", "tidyr", "data.table", "magrittr", "zoo"),
       r2docsets)
