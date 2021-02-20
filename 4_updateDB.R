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