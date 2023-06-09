#  Przykladowe rozwiazanie zadania z laboratorium 6, TCH
#  1. Plik Dockerfile wykorzystuje zewnętrzne, dedykowane repo na Github
#  2. Dostęp i sklonowanie tego repo realizowane są woparciu o protokół SSH 
#  3. Plik Dockerfile realizuje wieloetapową budowe obrazów  

# ======== etap1 ==== nazwa: dev_stage =================
# === cel: budowa aplikacji w kontenerze roboczym ======

# deklaracja wersji rozszerzonego frontendu dla Buildkit
# syntax=docker/dockerfile:1.3

FROM scratch as dev_stage

# zmienna VERSION przekazywana do procesu budowy obrazu 
ARG VERSION

# utworzenie warstwy bazowej obrazu 
# ==!!!nalezy opcjonal niezmienić architekture docelowa!!!==
ADD alpine-minirootfs-3.17.3-aarch64.tar /

# uaktualnienie systemu w warstwie bazowej oraz instalacja
# niezbędnych komponentów środowiska roboczego
RUN apk update && \
    apk upgrade && \
    apk add --no-cache nodejs \
    npm=9.1.2-r0 \
    openssh-client \
    git && \
    rm -rf /etc/apk/cache

# szablon aplikacji React jest inicjalizowany w kontenerze
RUN npx create-react-app rlab5

# skanowanie "podmontowanego" przy uruchomieniu, katalogu z kluczami 
RUN mkdir -p -m 0600 ~/.ssh && ssh-keyscan github.com >> ~/.ssh/known_hosts 

# utworzenie katalogu docelowego dla sklonowanych ródeł aplikacji
RUN mkdir -p /repo6 

# kopiowanie przygotowanej aplikacji z Github repo 
RUN --mount=type=ssh git clone git@github.com:SenatorP51/lab6_solution.git repo6 && \
    mv /repo6/App.js /rlab5/src/App.js

# od tego kroku domyslnym katalogiem wewnętrz systemu plikow 
# obrazu jest katalog /rlab5
WORKDIR /rlab5

# powiazanie zmiennej VERSION z procesu build ze zmienna 
# "widzianą" w kontenerze; przedrostek REACT_APP_ wynika 
# z zasad nazewnictwa zmiennych w Reactjs   
ENV REACT_APP_VERSION=${VERSION}

# instalacja zaleności i budowa aplikacji
RUN npm install
RUN npm run build

# ========= etap2 ==== tzw. produkcyjny =================
# == cel: budowa produkcyjnego kontenera zawierajacego == 
# == wylacznie serwer HTTP oraz zbudowaną aplikacje =====

# deklaracja wersji rozszerzonego frontendu dla Buildkit
# musi być powtarzana na kadym etapie
# syntax=docker/dockerfile:1.3

FROM nginx:1.24
# powtorzenie deklaracji zmiennej ze wzgledu na chec 
# wpisania wersji aplikacji do metadanych
ARG VERSION
ENV REACT_APP_VERSION=${VERSION}
RUN echo $REACT_APP_VERSION

# deklaracja metadanych zgodna z OCI
LABEL org.opencontainers.image.authors="lab6@solution.org"
LABEL org.opencontainers.image.version="$VERSION"

# kopiowanie aplikacji jako domyślnej dla serwera HTTP
COPY --from=dev_stage /rlab5/build/. /var/www/html

# kopiowanie konfiguracji serwera HTTP dla srodowiska produkcyjnego
COPY --from=dev_stage /repo6/default.conf /etc/nginx/conf.d/default.conf

# deklaracja portu aplikacji w kontenerze 
EXPOSE 80

# monitorowanie dostepnosci serwera 
HEALTHCHECK --interval=10s --timeout=1s \
 CMD curl -f http://localhost:80/ || exit 1

# deklaracja sposobu uruchomienia serwera
CMD ["nginx", "-g", "daemon off;"]
