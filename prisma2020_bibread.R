# this is a set of tools for loading, tidying, and screening references following the PRISMA2020 scheme
# it's heavily based on revtools - especially the interactive Shiny apps, which are used from that package 

source("src/scripts.R") # especially bib_convert to help tidy bibliographies

# set paths ----
input_folder <- c("data/bl")
bib_output_path <- c("data/bibliography.bib")
prisma_output_path <- c("data/bib_output_prisma.csv")

# to load and tidy bibliographic data from input files ----
bib_read_join(input_folder, bib_output_path)

# can also use this to fake the manual PRISMA category data for demonstration purposes only ----
fake_screen(prisma_output_path)
make_fake_prisma(prisma_output_path)

# proper screening ----

# loading joined bibliography ----
bib_raw <- read_rds("data/bib_raw.rds")

# to interactively screen this same data for duplicates ----
bib_dedup <- screen_duplicates(bib_raw)

# to create a df of duplicates entries for later PRISMA counting ----
bib_duplicates <- bib_duplicates()

# to interactively screen abstracts or titles - one or the other ----
    
    # titles
    bib_screened <- screen_titles(bib_dedup) %>%
      rename("screening" = screened_titles)
    
    # abstracts
    bib_screened <-
      screen_abstracts(bib_dedup) %>% 
      rename("screening" = screened_abstracts) 

# to screen topics - interactive again
bib_screened_topic_full <- bib_screened %>%
  filter(screening == "selected") %>%
  screen_topics()

produce_outputs(prisma_output_path) # tidying screening results and producing final PRISMA2020 csv for manual editing


