library(rvest)
library(xml2)
library(jsonlite)
library(tidyverse)
library(yaml)
library(RPostgres)

credentials <- yaml::yaml.load_file('credentials.yml')

pages_to_parse <- list(
  'https://mosecom.mos.ru/ochakovskaya/',
  'https://mosecom.mos.ru/ochakovskoe-2/'
)


### Parse page and tidy data

get_site_data <- function(page_to_parse){
  # Задержка при парсинге разных страниц
  Sys.sleep(3.6)
  
  full_page_html <- xml2::read_html(page_to_parse)
  data_to_extract <- 
    full_page_html %>% 
    html_node('body') %>%
    xml_find_all('//div[@class = "wrap "]') %>%
    xml_find_all('//div[@class = "container"]') %>%
    xml_find_all('//div[@class = "content page-stan-content"]') %>%
    xml_find_all('//div[@class = "dinamic"]') %>%
    xml_find_all('//div[@class = "chart-block"]') %>%
    xml_find_all('//script[@type = "text/javascript"]') %>%
    xml_find_all('//script[contains(text(), "AirCharts.init")]') %>%
    regmatches(. , gregexpr(pattern = '(?={)(.*)(?<=})', text = ., perl = T)) %>%
    .[[1]] %>%
    strsplit('}, {', fixed = T)
  
  
  pollution_data <- tryCatch(
    data_to_extract %>%
      .[[1]] %>%
      .[1] %>%
      paste0(., '}') %>%
      fromJSON(),
    error = function(cond){message("Parsing error"); return(NULL)}
  )
  
  metadata <- 
    data_to_extract %>%
    .[[1]] %>%
    .[2] %>%
    paste0('{', .) %>%
    fromJSON(flatten = T)
  
  
  transform_data <- function(data, measurement_representation, period_type, pollutant){
    if(length(data)){
      raw_data <- data.frame(
        measurement_representation = measurement_representation,
        period_type = period_type,
        pollutant = pollutant,
        timestamp = data[ , 1] ,
        datetime = as.POSIXct(data[ , 1] / 1000,
                              #tz = 'Europe/Moscow',
                              origin = as.POSIXct('1970-01-01 00:00:00', tz = 'Europe/Moscow') ),
        date = as.Date(as.POSIXct(data[ , 1] / 1000,
                                  #tz = 'Europe/Moscow',
                                  origin = as.POSIXct('1970-01-01 00:00:00', tz = 'Europe/Moscow') ), 
                       tz = 'Europe/Moscow'),
        measurement = data[ , 2]
      )
      
      return(raw_data)
    }
  }
  
  
  pollution_data_list <- list()
  
  for(measurement_representation in names(pollution_data)){
    for(period_type in names(pollution_data[[measurement_representation]])){
      for(pollutant in names(pollution_data[[measurement_representation]][[period_type]])){
        pollution_data_list[[length(pollution_data_list) + 1]] <- 
          transform_data(pollution_data[[measurement_representation]][[period_type]][[pollutant]][['data']],
                         measurement_representation,
                         period_type,
                         pollutant)
        
      }
    }
  }
  
  pollution_data_flat_df <- do.call(rbind, pollution_data_list) %>% cbind(page_to_parse, .)
  
  return(pollution_data_flat_df)
  
}

### Determine safe timeout interval to conceal parsing activity

determine_safe_timeout_interval <- function(){
  next_hour <- as.POSIXlt(Sys.time())$hour + 1
  initial_random_sleep <- 0L
  while( as.POSIXlt(Sys.time() + initial_random_sleep)$hour != next_hour){
    initial_random_sleep <- runif(1, 900, 4500)
    }
  
  return(initial_random_sleep)
  
}

update_files <- function(current_pollution_data, pollution_data_full){
  saveRDS(current_pollution_data[[1]], paste0('data/actual_data-', format(Sys.time(), '%Y-%m-%d_%H-%M-%S'), '.Rds'))
  saveRDS(pollution_data_full, 'data/actual_data.Rds')
}

update_db <- function(current_pollution_data, pollution_data_full){
  ecodata_con <- RPostgres::dbConnect(RPostgres::Postgres(),
                              dbname = credentials[['POSTGRES_DB']],
                              host = credentials[['host']],
                              port = credentials[['port']],
                              user = credentials[['POSTGRES_USER']],
                              password = credentials[['POSTGRES_PASSWORD']],
                              timezone = "Europe/Moscow"
                              )
  RPostgres::dbWriteTable(ecodata_con, 'mem_pollution_data', pollution_data_full, overwrite = TRUE)
  
  RPostgres::dbDisconnect(ecodata_con)  
}

update_data <- function(pages_to_parse){
  current_pollution_data <- lapply(pages_to_parse, get_site_data) %>% do.call(union, .)
  
  history_pollution_data <- list(readRDS('data/actual_data.Rds'))
  
  pollution_data_full <<- do.call(union, c(history_pollution_data, list(current_pollution_data) )) %>%
    arrange(page_to_parse, measurement_representation, period_type, pollutant, timestamp)
  
  update_files(current_pollution_data, pollution_data_full)
  #update_db(current_pollution_data, pollution_data_full)
  
}

while(TRUE){
  cat(paste(Sys.time(), 'Start parsing data'))
  update_data(pages_to_parse)
  sleep_interval <- determine_safe_timeout_interval()
  cat(paste('\nData parsing complete. Next try in', 
            sleep_interval %/% 3600, 'hours',  
            sleep_interval %% 3600 %/% 60, 'minutes',
            floor(sleep_interval %% 60),'seconds', '\n') )
  Sys.sleep(sleep_interval)
}
