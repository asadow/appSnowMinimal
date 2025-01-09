FROM openanalytics/r-ver:4.4.2

LABEL maintainer="Adam Sadowski <asadowsk@uoguelph.ca>"

RUN /rocker_scripts/setup_R.sh https://packagemanager.posit.co/cran/__linux__/jammy/latest
RUN echo "\noptions(shiny.port=3838, shiny.host='0.0.0.0')" >> /usr/local/lib/R/etc/Rprofile.site

# system libraries of general use
# find through pak::pkg_sysreqs("DT", sysreqs_platform = "ubuntu-22.04")
RUN apt-get update && apt-get install --no-install-recommends -y \
    pandoc \
    make \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR project
COPY renv.lock renv.lock

RUN R -q -e 'install.packages("renv")'
RUN R -q -e 'renv::init(bare = TRUE)'
RUN R -q -e 'renv::restore()'

EXPOSE 3838

# create user
RUN groupadd -g 1000 shiny && useradd -c 'shiny' -u 1000 -g 1000 -m -d /home/shiny -s /sbin/nologin shiny
USER shiny
# function expects this directory to contain either app.R or ui.R and server.R
CMD ["R", "-q", "-e", "shiny::runApp('/app')"]