library(rvest)
library(xml2)
library(jsonlite)
library(tidyverse)

pages_to_parse <- c(
  'https://mosecom.mos.ru/ochakovskaya/'
)

### Parse page and tidy data

get_site_data <- function(page_to_parse){
  
  full_page_html <- xml2::read_html(pages_to_parse)
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
  
  pollution_data <-
    data_to_extract %>%
    .[[1]] %>%
    .[1] %>%
    paste0(., '}') %>%
    fromJSON()
  
  metadata <- 
    data_to_extract %>%
    .[[1]] %>%
    .[2] %>%
    paste0('{', .) %>%
    fromJSON(flatten = T)

  
  transform_data <- function(data, measurement_representation, period_type, pollutant){
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
  
  pollution_data_flat_df <- do.call(rbind, pollution_data_list) %>% cbind(pages_to_parse, .)
  
  return(pollution_data_flat_df)
  
}

### Determine safe timeout interval to conceal parsing activity

determine_safe_timeout_interval <- function(){
  next_hour <- as.POSIXlt(Sys.time())$hour + 1
  initial_random_sleep <- 0L
  while( as.POSIXlt(Sys.time() + initial_random_sleep)$hour != next_hour){
    initial_random_sleep <- runif(1, 300, 3600)
    }
  
  return(initial_random_sleep)
  
}

update_data <- function(pages_to_parse){
  current_pollution_data <- lapply(pages_to_parse, get_site_data)
  
  history_pollution_data <- readRDS('data/actual_data.Rds')
  
  pollution_data_full <<- union(history_pollution_data, current_pollution_data[[1]]) %>%
    arrange(measurement_representation, period_type, pollutant, timestamp)
  
  saveRDS(current_pollution_data[[1]], paste0('data/actual_data-', format(Sys.time(), '%Y-%m-%d_%H-%M-%S'), '.Rds'))
  saveRDS(pollution_data_full, 'data/actual_data.Rds')
  
}

while(TRUE){
  update_data(pages_to_parse)
  sleep_interval <- determine_safe_timeout_interval()
  Sys.sleep(sleep_interval)
}
