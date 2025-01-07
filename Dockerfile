FROM openanalytics/r-ver:4.3.3

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

# pin renv version
ENV RENV_VERSION 1.0.5
RUN R -q -e "options(warn=2); install.packages('remotes')"
RUN R -q -e "options(warn=2); remotes::install_version('renv', '${RENV_VERSION}')"

# install R dependencies
# do this before copying the app-code, to ensure this layer is cached
WORKDIR /build
COPY snow/renv.lock /build/renv.lock
RUN R -q -e 'options(warn=2); renv::restore()'

# install R code
COPY snow /app
WORKDIR /app

EXPOSE 3838

# create user
RUN groupadd -g 1000 shiny && useradd -c 'shiny' -u 1000 -g 1000 -m -d /home/shiny -s /sbin/nologin shiny
USER shiny
# function expects this directory to contain either app.R or ui.R and server.R
CMD ["R", "-q", "-e", "shiny::runApp('/app')"]