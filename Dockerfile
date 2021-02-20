FROM r-base:4.0.2

RUN apt-get update -qq \
&& apt-get install -y apt-utils \
&& apt-get install -y libssl-dev \
&& apt-get install -y curl \
&& apt-get install -y libcurl4-openssl-dev \
&& apt-get install -y libxml2-dev \
&& apt-get install -y libpq-dev \
&& apt-get install -y sendmail

RUN R -e "install.packages(c('xml2'), dependencies=TRUE, repos='https://cran.r-project.org/')"
RUN R -e "install.packages(c('rvest'), dependencies=TRUE, repos='https://cran.r-project.org/')"
RUN R -e "install.packages(c('jsonlite'), dependencies=TRUE, repos='https://cran.r-project.org/')"
RUN R -e "install.packages(c('tidyverse'), dependencies=TRUE, repos='https://cran.r-project.org/')"
RUN R -e "install.packages(c('yaml'), dependencies=TRUE, repos='https://cran.r-project.org/')"
RUN R -e "install.packages(c('RPostgres'), dependencies=TRUE, repos='https://cran.r-project.org/')"

WORKDIR /
RUN mkdir ./data

COPY 0_parsing.R 0_parsing.R
COPY 4_updateDB.R 4_updateDB.R
COPY ./data/actual_data.Rds ./data/actual_data.Rds
COPY credentials.yml credentials.yml

ENTRYPOINT ["Rscript", "0_parsing.R"]