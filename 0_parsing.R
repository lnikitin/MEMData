library(rvest)
library(xml2)
library(jsonlite)
library(tidyverse)

pages_to_parse <- c(
  'https://mosecom.mos.ru/ochakovskaya/'
)

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

extract_simple_dataframe <- function(data, measurement_representation, period_type, pollutant){
  raw_data <- data.frame(
  measurement_representation = measurement_representation,
  period_type = period_type,
  pollutant = pollutant,
  timestamp = 
    data[[measurement_representation]][[period_type]][[pollutant]][['data']][ , 1] ,
  datetime = as.POSIXct(data[[measurement_representation]][[period_type]][[pollutant]][['data']][ , 1] / 1000,
                        tz = 'Europe/Moscow',
                        origin = as.POSIXlt('1970-01-01 00:00:00', tz = 'Europe/Moscow') ),
  measurement = data[[measurement_representation]][[period_type]][[pollutant]][['data']][ , 2]
  )
    
  return(raw_data)
}

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


dt <- extract_simple_dataframe(pollution_data, 'proportions', 'y', 'CO')

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

pollution_data_flat_df <- do.call(rbind, pollution_data_list)


history_pollution_data <- readRDS('actual_data.Rds')
pollution_data_full <- union(history_pollution_data, pollution_data_flat_df) %>%
  arrange(measurement_representation, period_type, pollutant, timestamp)

saveRDS(pollution_data_flat_df, paste0('actual_data-', format(Sys.time(), '%Y-%m-%d_%H-%M-%S'), '.Rds'))
saveRDS(pollution_data_full, 'actual_data.Rds')
