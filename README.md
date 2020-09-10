# MEMData
# Parsing, processing and analysis of MEM data

This parser reads ecological monitoring data of 'M1 Ochakovo' automated station of Moscow ecomonitoring, and saves it to local Rds files.
Parser creates/updates two files:
1. cumulative data in 'actual_data.Rds'
2. last parsing data as of on site at the moment of parsing ('actual_data_{datetime}.Rds')

This code and repository does not imply any rights for Moscow ecomonitoring data, and reads is from public website.
The user of this script uses it on his/her own risk and takes all the responsibility.

# Парсинг, обработка и анализ данных МЭМ

Парсер загружает данные автоматической станции экологического мониторинга "М1 Очаково" с сайта Мосэкомониторинга и сохраняет их локально в файлы 'Rds'.
В ходе работы парсер создает/обновляет два файла:
1. 'actual.Rds' с кумулятивными данными
2. 'actual_data_{datetime}.Rds' с данными сайта по состоянию на момент парсинга

Данный код не предоставляет никаких прав на данные Мосэкомониторинга. Он лишь загружает их с открытого сайта.
Запуская данный код, пользователь делает это на свой страх и риск, понимая и принимая все возможные последствия.
