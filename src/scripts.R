library(pacman)
p_load(tidyverse, revtools, RefManageR, rbibutils, tools, glue)
p_load_gh("elizagrames/litsearchr")

# source file locations ----
PRISMA_template <- read.csv("src/PRISMA.csv")
webs <- c("web", "orgs", "citation") # for the non-db and non-registers citations
# fl <- read_csv("src/filter_lookup.csv")  now moved inside prisma_count_groups

# bib_read_join ----
# function to read the input directory (by default /data/bib_input) for bibliographic files, and then join them into a single .bib file that can be used for screening and referencing purposes.

bib_read_join <-
  function(input_folder, bib_output_path) {

    # figure out what you've got
    bibs_all <- list.files(input_folder, full.names = TRUE)
    
    if(length(bibs_all) == 0) {stop("Please check that you have the right input_folder path set.")}
    
    bib_raw <- map_dfr(bibs_all, ~ import_results(file = .x)) %>%
      rename_with(tolower)
    
    #check if year and date_published exist
    
    if("year" %in% colnames(bib_raw) & "date_published" %in% colnames(bib_raw)){
      bib_raw <- bib_raw %>%
        mutate(year = coalesce(as.character(year), date_published)) %>%
        mutate(year = as.numeric(str_match(year, "\\d\\d\\d\\d")))
    }

    if(!"year" %in% colnames(bib_raw) & "date_published" %in% colnames(bib_raw)){
      bib_raw <- bib_raw %>%
        mutate(year = as.numeric(str_match(date_published, "\\d\\d\\d\\d")))
    }

    bib_raw <- bib_raw %>%
      mutate(label = glue("{str_extract(author, '[A-Za-z]+')}_{year}")) %>%
      relocate(label) %>%
      mutate(label = make.unique(label))

    if("article_id" %in% colnames(bib_raw)) {
    bib_raw <- bib_raw %>%
      mutate(doi_guess = str_extract(article_id, "\\S+(?=\\s+(\\[doi\\]))"))  # find the missing dois
    }

    if("location_id" %in% colnames(bib_raw)) {
    bib_raw <- bib_raw %>%
      mutate(doi_guess = str_extract(location_id, "\\S+(?=\\s+(\\[doi\\]))"))
    }

    if(!"doi" %in% colnames(bib_raw) & "doi_guess" %in% colnames(bib_raw)) {
      bib_raw <- bib_raw %>%
        mutate(doi = doi_guess)
    }

    if("doi" %in% colnames(bib_raw) & "doi_guess" %in% colnames(bib_raw)) {
      bib_raw <- bib_raw %>%
        mutate(doi = coalesce(doi, doi_guess)) %>%
        select(!doi_guess)
    }

    if("author" %in% colnames(bib_raw) & "author_full" %in% colnames(bib_raw)) {
      bib_raw <- bib_raw %>%
        mutate(author = coalesce(author_full, author)) # stupid abbreviated author names
    }

      
    # output a bibliography for referencing purposes
    bib_raw %>%
      write_bibliography(., bib_output_path, format = "bib")

    # best to tidy that up to scrub out all the nas
      tibble(temp = read_lines(bib_output_path)) %>%
      filter(str_detect(temp, "=\\{NA\\}") == FALSE) %>%
        data.table::fwrite(., bib_output_path, quote=F)

     write_rds(bib_raw, "data/bib_raw.rds")
  }

# creates a df of duplicates. The reason for not just doing an anti join is to allow renaming of columns to lower case. This is a consequence of one of the interactice revtools function mysteriously treating id/ID, nad/NAD, and a few others as interchangable in an unpredictable way.

bib_duplicates <- function(full_data = bib_raw, deduplicated_data = bib_dedup) {
  
 # mystery_topic_cols <- c("id", "nad")
  
  full_data %>%
    anti_join(deduplicated_data) %>%
    mutate(rem_bef_screen = "dupe") %>%
    rename_with(tolower) %>%
    distinct()
  
}

# produce prisma input csv (for manual data collection) ----

produce_outputs <- function(prisma_output_path) {
#returns a complicated list with model etc. Pulling out the classified bibliography...
bib_screened_topic <- bib_screened_topic_full[["raw"]] 

# again, create df of screened-out results for later counting
bib_screened_out <- bib_screened %>%
  anti_join(bib_screened_topic) %>%
  mutate(pass_screen = "no")

#now "screening" and "screened_topics" columns have the juicy stuff. Bit of logic to create a pass_screen column (matching flow chart requirements):
output_columns <- c("label", "stud_rep",	"prev_new",	"id_method",	"rem_bef_screen",	"pass_screen", "retrieve", "eligible")

bib_duplicates <- bib_duplicates %>%
  rename_with(tolower)

# then joining excluded parts back again for counting
bib_output_prisma <- bib_screened_topic %>%
  mutate(pass_screen = case_when(
    screening == "selected" & screened_topics == "selected" ~ "yes",
    TRUE ~ "no")) %>%
  mutate(rem_bef_screen = "") %>%
  add_row(bib_duplicates) %>%
  add_row(bib_screened_out) %>%
  mutate(stud_rep = "study", prev_new = "new", id_method="db",retrieve = "", eligible = "") %>%
  select(any_of(output_columns))

# write out the prisma-format spreadsheet for manual data input
write_csv(bib_output_prisma, prisma_output_path)

}

# prisma calculations ----

#little function to tidy the awkward exclusion reasons
reason_tidier <- function(df) {
  df <-
    format_delim(df,
                 delim = ",",
                 eol = ";",
                 col_names = FALSE)
  df <- substr(df, 1, nchar(df) - 1)
  df <- gsub(",", ", ", df)
  df <- gsub(";", "; ", df)
  
}

# generates interactive subpages with citations
category_breakdown <- function(row_no) {
  category_urls <- urls %>% slice(row_no) 
  
  category_data <- category_urls$data
  category_url <- category_urls$url
  
  quarto_render("prisma2020_template.qmd", output_file=category_url, execute_params=list(data = category_data))
  
}

filter_function <- function(filter_string, var) {
  # helper to allow the filter logic to be read from df
  counts$data %>% filter(eval(parse(text=filter_string)))
}

prisma_count_groups <- function(prisma_data_path) {
  # main prisma counting functions  
  bib_list <- list()
  
  fl <- read_csv("src/filter_lookup.csv") 
  
  bib_list$data <- read_csv(prisma_data_path)
  
  bib_list$others_excluded <- bib_list$data %>%
    filter(id_method %in% webs & eligible != "yes" & retrieve == "yes") %>%
    count(eligible) %>%
    arrange(eligible) %>%
    reason_tidier(.)
  
  bib_list$dbr_excluded <- bib_list$data %>%
    filter(!id_method %in% webs & eligible != "yes" & retrieve == "yes") %>%
    count(eligible) %>%
    arrange(eligible) %>%
    reason_tidier(.)
  
  bib_list$prisma2020 <- map2(.x = fl$filter_string, .y = fl$var, ~ bib_list$data %>% filter(eval(parse(text=.x)))) %>%
    set_names(fl$var) %>%
    tibble(groups = ., data = fl$var) %>%
    rowwise() %>%
    mutate(n = nrow(groups)) %>%
    mutate(n = as.character(n)) %>%
    add_row(data = "other_excluded", n = bib_list$others_excluded) %>%
    add_row(data = "dbr_excluded", n = bib_list$dbr_excluded)
  
  bib_list
  
}

## sorting out the data for the template html pages
url_find <- function(df) {
  
  urls <- PRISMA_template %>%
    select(data , url) %>%
    left_join(df, by = "data") %>%
    drop_na(url, n) %>%
    filter(n != 0)  
  
  # we have urls df with nested publication data for the categories. However...
  # this lacks the dbr_excluded data, which should go into the groups column as a nested tibble
  # the correct location in urls is urls[[3]][[match("dbr_excluded", urls$data)]]
  # the correct data source location is counts$data %>% filter(!id_method %in% webs & eligible != "yes" & retrieve == "yes")
  
  temp <- counts$data %>% filter(!id_method %in% webs & eligible != "yes" & retrieve == "yes")
  urls[[3]][[match("dbr_excluded", urls$data)]] <- temp
  
  saveRDS(urls, "data/urls.rds")
  
} 
