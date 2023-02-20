![](img/header.png) PRISMA2020 helper
================
[KIND Learning Network](https://learn.nes.nhs.scot/36783)
2023-02-20

## Introduction

PRISMA2020 helper is a set of workflow tools to help build
PRISMA2020-compliant flow diagrams. It ties together several existing R
packages:

- [litsearchr](https://elizagrames.github.io/litsearchr/), used to
  import bibliographies
- [revtools](https://revtools.net/), used to manage reference screening
  and topic modelling
- [PRISMA2020](https://cran.r-project.org/web/packages/PRISMA2020/index.html),
  used to generate the PRISMA2020 flow diagrams

## Status

This is currently experimental, untested, and liable to change. Please
[raise any
issues](https://github.com/bclarke-nes/PRISMA2020_helper/issues)
encountered during use.

## Rationale

While PRISMA2020 flow diagrams play a vital tool in making systematic
reviews better, constructing these diagrams is arguous. This set of
tools allow users to automate some stages of this data collection
(e.g. counting duplicates or publications excluded at screening).

## Use

- download code
- create a ./data subdirectory
- add an appropriately named subdirectory for the bibliographical input
  for your project in ./data/ and populate with .bib, .nbib, or other
  reference files
- open the prisma2020_bibread.R and follow the steps to load, and screen
  references
- once that is complete, your data directory will contain:
  - a bibliography.bib file for citation purposes
  - a bib_output_prisma.csv file for PRISMA data collection. The
    right-most two columns of this csv can then be edited manually as
    papers are retrieved and appraised.
- once manual data collection is complete, the Quarto PRISMA2020 flow
  diagram (together with interactive subpages) can be generated from
  prisma2020_flow.qmd
