# MEMData
Parsing, processing and analysis of MEM data

This parser reads ecological monitoring data of 'M1 Ochakovo' automated station of Moscow ecomonitoring, and saves it to local Rds files.
Parser creates/updates two files:
1. cumulative data in 'actual_data.Rds'
2. last parsing data as of on site at the moment of parsing ('actual_data_{datetime}.Rds')

This code and repository does not imply any rights for Moscow ecomonitoring data, and reads is from public website.
The user of this script uses it on his/her own risk and takes all the responsibility.
