# R2docsets

The `r2docsets` script generates dash docsets for offline viewing for R packages.

This script derives from [these gists](https://gist.github.com/whatalnk/b245bf69f69913571c4a) and [the `docsetr` package](https://github.com/whatalnk/docsetr). It differs in that it generates single docset for a R package.


Other notable changes:

- `pwd` is always set to the script directory; This reduces further errors due to script disruptions.
- package `pipR` is replaced by `magrittr`.

Dependent packages:
- RSQLite
- XML
- selectr
- magrittr

Install dependencies in `R` by

``` r
install.packages(c("RSQLite", "XML", "selectr", "magrittr"))
```
