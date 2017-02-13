create.package.list <- function() {
  make.packages.html(temp = TRUE)
  file.copy(from = file.path(tempdir(), "R/doc/html/packages.html"),
            to = file.path("doc", "html"), overwrite = TRUE, copy.date = TRUE)

  doc <- htmlTreeParse(file.path("doc", "html", "packages.html"), useInternal = TRUE)

  oldNode <- newNode <- querySelector(doc, ".toplogo")
  xmlAttrs(newNode)["src"] <- "logo.png"
  addAttributes(newNode, width = "100", height = "78")
  replaceNodes(oldNode, newNode)

  remove.navigation(doc)
  saveXML(doc, file.path("doc", "html", "packages.html"))
}

replace.logo <- function(doc) {
  oldNode <- newNode <- querySelector(doc, ".toplogo")
  xmlAttrs(newNode)["src"] <- "../../../doc/html/logo.png"
  addAttributes(newNode, width = "100", height = "78")
  replaceNodes(oldNode, newNode)
}

remove.navigation <- function(doc) {
  removeNodes(xmlParent(xmlParent(querySelector(doc, ".arrow"))))
}

replace.link.to.description <- function(doc) {
  nodes <- getNodeSet(doc, "/html/body/ul/li/a")
  nodes %>% lapply(function(x){
    oldNode <- newNode <- x
    xmlAttrs(newNode)["href"] <- ifelse(tools::file_ext(xmlAttrs(oldNode)["href"]) != "html", paste0(xmlAttrs(oldNode)["href"], ".html"), xmlAttrs(oldNode)["href"])
    replaceNodes(oldNode, newNode)
  })
}

list.of.dir <- function(pkg, path) {
  viganettes <- list.files(file.path("library", pkg, "doc"))
  write("<html><head></head><body>", path)
  write(sprintf("<h1>Listing of directory %s</h1><hr><dl>", file.path("library", pkg, "doc")), path, append = TRUE)
  for (l in viganettes) {
    write(sprintf("<dt></dt><dd><a href=%s>%s</a></dd>", l, l), path, append = TRUE)
  }
  write("</dl></body></html>", path, append = TRUE)
}

generate.help.from.Rd <- function(pkg) {
  pkgRdDB <- tools:::fetchRdDB(file.path(find.package(pkg), 'help', pkg))
  topics <- names(pkgRdDB)
  as.list(topics) %>% lapply(function(x){
    tools::Rd2HTML(pkgRdDB[[x]], out = file.path("library", pkg, "html", paste(x, ".html", sep = "")), package = pkg, Links = tools::findHTMLlinks())
  })
}


generate.help.html <- function(pkg) {
  dir.create(file.path("library", pkg, "html"), recursive = TRUE)

  # R.css of knitr package
  file.copy(system.file('misc', 'R.css', package = 'knitr'), file.path("library", pkg, "html"))

  # 00index.html
  file.copy(file.path(find.package(pkg), 'html', "00Index.html"), file.path("library", pkg, "html"))
  doc <- htmlTreeParse(file.path("library", pkg, "html", "00Index.html"), useInternal = TRUE)
  replace.logo(doc)
  remove.navigation(doc)
  replace.link.to.description(doc)
  saveXML(doc, file.path("library", pkg, "html", "00Index.html"))

  # DESCRIPTION, NEWS
  c("DESCRIPTION", "NEWS") %>% lapply(function(x){
    if (file.exists(system.file(x, package = pkg))) {
      file.copy(system.file(x, package = pkg), f <- file.path("library", pkg, x), copy.date = TRUE)
      writeLines(c("<pre>", readLines(f), "</pre>"), paste0(f, ".html"))
      file.remove(f)
    }
  })

  # doc dir
  if (system.file("doc", package = pkg) != "") {
    file.copy(system.file("doc", package = pkg), file.path("library", pkg), recursive = TRUE, copy.date = TRUE)
    ## index.html
    if (file.exists(file.path("library", pkg, "doc", "index.html"))) {
      doc <- htmlTreeParse(file.path("library", pkg, "doc", "index.html"), useInternal = TRUE)
      replace.logo(doc)
      remove.navigation(doc)
      getNodeSet(doc, "/html/head/link") %>% lapply(function(x){
        oldNode <- newNode <- x
        xmlAttrs(newNode)["href"] <- "../../../doc/html/R.css"
        replaceNodes(oldNode, newNode)
      })
      saveXML(doc, file.path("library", pkg, "doc", "index.html"))
    } else {
      list.of.dir(pkg, file.path("library", pkg, "doc", "index.html"))
    }
  }
  # Help pages
  generate.help.from.Rd(pkg)
}

create.sqlite.index <- function(pkg, conn) {
  dbBegin(conn)
  doc <- htmlTreeParse(file.path("library", pkg, "html", "00Index.html"), useInternal = TRUE)
  nodes.tr <- getNodeSet(doc, "//table/tr")
  for (n in nodes.tr) {
    nodes.tr.a <- xmlChildren(n)$td %>% getNodeSet("./a")
    nodes.tr.a.attr <- nodes.tr.a[[1]] %>% xmlAttrs()
    name <- xmlValue(nodes.tr.a[[1]])
    path <- file.path("library", pkg, "html", nodes.tr.a.attr["href"])
    if (name == paste(pkg, "-package", sep = "")) {
      type <- "Instruction"
    } else {
      type <- "Function"
    }
    name <- sub(pattern = "'", replacement = "''", x = name)
    dbGetQuery(conn, sprintf("insert into searchIndex(name, type, path, package, version) values('%s', '%s', '%s', '%s', '%s')", name, type, path, pkg, packageVersion(pkg)))
  }
  dbGetQuery(conn, sprintf("insert into searchIndex(name, type, path, package, version) values('%s', 'Package', '%s', '%s', '%s')", pkg, file.path("library", pkg, "html", "00Index.html"), pkg , packageVersion(pkg)))
  dbCommit(conn)
}

r2docsets <- function(which.package) {
    # in Rlibs.docset/Contents/Resources/Documents
    sapply(c("RSQLite", "XML", "selectr", "magrittr"),
           require, character.only=TRUE)

    pwd <- getwd()

    unlink(sprintf("%s.docset", which.package), recursive = TRUE)
    docsetroot <- sprintf("%s.docset/Contents/Resources/Documents", which.package)
    dir.create(file.path(docsetroot), recursive = TRUE)
    file.copy(from = "Info.plist",
              to = sprintf("%s.docset/Contents/", which.package))

    # switch to Documents folder
    setwd(docsetroot)

    # Package list
    dir.create(file.path("doc", "html"), recursive = TRUE)

    make.packages.html(temp = TRUE)
    file.copy(from = file.path(tempdir(), ".R/doc/html/packages.html"),
              to = file.path("doc", "html"), copy.date = TRUE)
    file.copy(from = file.path(R.home("doc"), "html", "R.css"),
              to = file.path("doc", "html"), copy.date = TRUE)
    download.file(url = "https://www.r-project.org/Rlogo.png",
                  destfile = file.path("doc", "html", "logo.png"), mode = "wb")

    doc <- htmlTreeParse(file.path("doc", "html", "packages.html"),
                         useInternal = TRUE)
    replace.logo(doc)
    remove.navigation(doc)
    saveXML(doc, file.path("doc", "html", "packages.html"))

    generate.help.html(which.package)

    con <- dbConnect(SQLite(), dbname = "../docSet.dsidx")
    dbGetQuery(con, "CREATE TABLE searchIndex(id INTEGER PRIMARY KEY, name TEXT, type TEXT, path TEXT, package TEXT, version TEXT)")
    dbListTables(con)
    dbGetQuery(con, "select * from searchIndex")

    create.sqlite.index(which.package, con)

    dbDisconnect(con)

    setwd(pwd)
}
