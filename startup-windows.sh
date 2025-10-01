#!/bin/bash

# Reset
Color_Off='\033[0m'       # Text Reset

# Regular Colors
Black='\033[0;30m'        # Black
Red='\033[0;31m'          # Red
Green='\033[0;32m'        # Green
Yellow='\033[0;33m'       # Yellow
Blue='\033[0;34m'         # Blue
Purple='\033[0;35m'       # Purple
Cyan='\033[0;36m'         # Cyan
White='\033[0;37m'        # White

# Bold
BBlack='\033[1;30m'       # Black
BRed='\033[1;31m'         # Red
BGreen='\033[1;32m'       # Green
BYellow='\033[1;33m'      # Yellow
BBlue='\033[1;34m'        # Blue
BPurple='\033[1;35m'      # Purple
BCyan='\033[1;36m'        # Cyan
BWhite='\033[1;37m'       # White

# Underline
UBlack='\033[4;30m'       # Black
URed='\033[4;31m'         # Red
UGreen='\033[4;32m'       # Green
UYellow='\033[4;33m'      # Yellow
UBlue='\033[4;34m'        # Blue
UPurple='\033[4;35m'      # Purple
UCyan='\033[4;36m'        # Cyan
UWhite='\033[4;37m'       # White

# Background
On_Black='\033[40m'       # Black
On_Red='\033[41m'         # Red
On_Green='\033[42m'       # Green
On_Yellow='\033[43m'      # Yellow
On_Blue='\033[44m'        # Blue
On_Purple='\033[45m'      # Purple
On_Cyan='\033[46m'        # Cyan
On_White='\033[47m'       # White

# High Intensity
IBlack='\033[0;90m'       # Black
IRed='\033[0;91m'         # Red
IGreen='\033[0;92m'       # Green
IYellow='\033[0;93m'      # Yellow
IBlue='\033[0;94m'        # Blue
IPurple='\033[0;95m'      # Purple
ICyan='\033[0;96m'        # Cyan
IWhite='\033[0;97m'       # White

# Bold High Intensity
BIBlack='\033[1;90m'      # Black
BIRed='\033[1;91m'        # Red
BIGreen='\033[1;92m'      # Green
BIYellow='\033[1;93m'     # Yellow
BIBlue='\033[1;94m'       # Blue
BIPurple='\033[1;95m'     # Purple
BICyan='\033[1;96m'       # Cyan
BIWhite='\033[1;97m'      # White

# High Intensity backgrounds
On_IBlack='\033[0;100m'   # Black
On_IRed='\033[0;101m'     # Red
On_IGreen='\033[0;102m'   # Green
On_IYellow='\033[0;103m'  # Yellow
On_IBlue='\033[0;104m'    # Blue
On_IPurple='\033[0;105m'  # Purple
On_ICyan='\033[0;106m'    # Cyan
On_IWhite='\033[0;107m'   # White

spinner() {
    message=$2
    color=$3

    local PROC="$1"
    local str="${2:-$message}"
    local delay="0.1"
    tput civis  # hide cursor
    printf "$color"
    while [ -d /proc/$PROC ]; do
        printf '\033[s\033[u[ / ] %s\033[u' "$str"; sleep "$delay"
        printf '\033[s\033[u[ — ] %s\033[u' "$str"; sleep "$delay"
        printf '\033[s\033[u[ \ ] %s\033[u' "$str"; sleep "$delay"
        printf '\033[s\033[u[ | ] %s\033[u' "$str"; sleep "$delay"
    done
    printf '\033[s\033[u%*s\033[u\033[0m' $((${#str}+6)) " "  # return to normal
    tput cnorm  # restore cursor
    echo -e "${BGreen}[ OK ] $message"
    return 0
}

echo_fail() {
  printf "\e[31m✘ \e[0m$@\n"
}

ensure_docker() {
    which docker >/dev/null 2>&1 || return 1
    docker ps -q >/dev/null 2>&1 || return 1

    echo "Docker OK"
}

ensure_wsl() {
    OUTPUT="$(wsl --status)" # Essa linha retorna um warning esquisito, mas que não interrompe a operação
    WSL_VERSION=$(echo "$OUTPUT" | grep -o " [^ ]*$" | tail -1)

    if [ $WSL_VERSION != 2 ]; then
        return 1
    fi

    echo "WSL OK"
}

ensure_curl() {
  {
    curl --version >/dev/null 2>&1
  } || {
    return 1
  }

  echo "CURL OK"
}

build_frontend() {
    echo -e "${BBlue}------------ Construção das Imagens Frontend ------------"

    VITE_API_URL="${APP_URL}:${API_PORT}/"
    VITE_ADMIN_URL="${APP_URL}:${ADMIN_PORT}/login"

    docker-compose build \
    --build-arg ARG_VITE_API_URL=$VITE_API_URL \
    --build-arg ARG_VITE_ASSETS=LOCAL \
    --build-arg API_URL="$VITE_API_URL" \
    --build-arg ADMIN_URL="$VITE_ADMIN_URL" \
    --build-arg ARG_VITE_APP_VERSION=$APP_VERSION admin aluno --quiet &
    spinner $! 'Imagens Frontend (Admin e Aluno)' $BYellow

    echo -e "${BBlue}---------------------------------------------------------"
    echo -e ""
}

compose_containers() {
    echo -e "${BBlue}------- Inicialização dos Containers da Aplicação -------"
    docker-compose up -d postgres --quiet-pull
    docker-compose up -d mongo --quiet-pull

    sleep 15

    docker-compose up -d --quiet-pull
    echo -e "${BBlue}---------------------------------------------------------"
    echo -e ""
}

validate_backend() {
    curl \
        --connect-timeout 30 \
        --retry 30 \
        --retry-delay 5 \
        -s http://127.0.0.1:3000/swagger > /dev/null &
    spinner $! 'Backend API' $BYellow
}

validate_admin() {
    curl \
        --connect-timeout 30 \
        --retry 30 \
        --retry-delay 5 \
        -s http://127.0.0.1:8080 > /dev/null &
    spinner $! 'Portal Admin' $BYellow
}

validate_aluno() {
    curl \
        --connect-timeout 30 \
        --retry 30 \
        --retry-delay 5 \
        -s http://127.0.0.1:9090 > /dev/null &
    spinner $! 'Portal Aluno' $BYellow
}

init() {
    echo -e "${BBlue}---------------- Inicialização Aplicação ----------------"
    validate_backend
    validate_admin
    validate_aluno
    echo -e "${BBlue}---------------------------------------------------------"
    echo -e ""
}

stopCurrentContainers() {
    local action=$1

    case $action in
        "install")
            echo "---------------- Parando containers e removendo imagens ----------------"
            cd "$SCRIPT_DIR" || exit
            
            # Exclua os diretórios originais apenas se existirem
            [ -d assets-data ] && rm -rf assets-data
            [ -d postgres-data ] && rm -rf postgres-data
            [ -d mongodb-data ] && rm -rf mongodb-data

            docker-compose -f docker-compose.yml down --rmi all -v
            ;;
        "update")
            echo "---------------- Parando e removendo containers e imagens de admin, aluno e backend ----------------"
            cd "$SCRIPT_DIR" || exit

            docker-compose -f docker-compose.yml down --volumes --remove-orphans

            echo "Removendo imagens específicas..."
            docker rmi -f $(docker images -q admin) 2>/dev/null
            docker rmi -f $(docker images -q aluno) 2>/dev/null
            docker rmi -f $(docker images -q backend) 2>/dev/null
            ;;
        *)
            echo_fail "Ação inválida. Saindo..."
            ;;
    esac

    echo "---------------------------------------------------------"
    echo ""
}

setIPMachine() {
    case "$OSTYPE" in
        solaris*) OS_NAME="SOLARIS" ;;
        darwin*)  OS_NAME="OSX" ;; 
        linux*)   OS_NAME="LINUX" ;;
        bsd*)     OS_NAME="BSD" ;;
        msys*)    OS_NAME="WINDOWS" ;;
        *)        OS_NAME="unknown: $OSTYPE" ;;
    esac

    if [ "$OS_NAME" = "WINDOWS" ]; then
        # Primeiro tenta pegar IP 192.168.x.x
        APP_URL=$(ipconfig.exe | grep -Eo "192\.168\.[0-9]{1,3}\.[0-9]{1,3}" | head -n1)

        # Se não achar, tenta 10.x.x.x
        if [ -z "$APP_URL" ]; then
            APP_URL=$(ipconfig.exe | grep -Eo "10\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}" | head -n1)
        fi

        # Se ainda não achar, tenta 172.16–31.x.x
        if [ -z "$APP_URL" ]; then
            APP_URL=$(ipconfig.exe | grep -Eo "172\.(1[6-9]|2[0-9]|3[0-1])\.[0-9]{1,3}\.[0-9]{1,3}" | head -n1)
        fi
    else
        APP_URL=$(ifconfig | sed -En 's/127.0.0.1//;s/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p' | head -n 1)
    fi

    MACHINE_IP=$(echo "$APP_URL" | sed 's/ *$//g')

    echo "IP detectado automaticamente: ${MACHINE_IP}"

    if grep -q '^APP_ADDRESS=' ".env"; then
        sed -i "s|^APP_ADDRESS=.*|APP_ADDRESS=${MACHINE_IP}|" .env
    else
        echo "APP_ADDRESS=${MACHINE_IP}" >> .env
    fi
}

readIPMachineFromUser() {
    echo -e "${BWhite}Informe o IP ou alias da máquina na Rede Interna: "
    read MACHINE_IP

    if [ -z $MACHINE_IP ]; then
        MACHINE_IP=127.0.0.1
    fi

    echo "IP ou alias informado: ${MACHINE_IP}"
    
    APP_ADDRESS="APP_ADDRESS=${MACHINE_IP}"
    sed -i "1s/.*/$APP_ADDRESS/" .env
    
    echo ""
}

prerequisites() {
    echo -e "${BBlue}------------ Pré-requisitos para Instalação -------------"

    echo 'Verificação da instalação do CURL'
    ensure_curl || {
        echo_fail "${BWhite}CURL não encontrado. Por favor, efetue a instalação do CURL e tente novamente (https://curl.se/download.html)."
        exit 1
    }

    echo 'Verificação da instalação do Docker'
    ensure_docker || {
        echo_fail "${BWhite}Não foi possível conectar ao Docker. Verifique sua instalação (https://docs.docker.com/engine/install/) ou inicie o serviço antes de prosseguir."
        exit 1
    }

    echo 'Verificação da versão do WSL'
    ensure_wsl || {
        echo_fail "${BWhite}Versão do WSL incompatível. Efetue a atualização seguindo os passos da documentação (https://learn.microsoft.com/pt-br/windows/wsl/install#upgrade-version-from-wsl-1-to-wsl-2)."
        exit 1
    }

    echo -e "${BBlue}---------------------------------------------------------"
    echo ""
}

ask_installation_or_update(){
    echo "Verificando se existem containers ou imagens no Docker..."
    
    local existing_containers=$(docker ps -q)
    local existing_images=$(docker images -q)

    if [ -n "$existing_containers" ] || [ -n "$existing_images" ]; then
        echo "Foram encontrados containers ou imagens no Docker."

        echo "Selecione uma opção:"
        echo "1. Instalação"
        echo "2. Atualização"
        echo "3. Sair"
        read -r option

        case $option in
            1)
                echo "Você está prestes a iniciar uma instalação do zero. Todos os containers e imagens existentes serão removidos."
                echo "Tem certeza de que deseja prosseguir? (s/n)"
                read -r confirm
                if [ "$confirm" == "s" ] || [ "$confirm" == "S" ]; then
                    echo "Iniciando instalação..."
                    stopCurrentContainers install
                else
                    echo "Operação de instalação cancelada."
                    exit 0
                fi
                ;;
            2)
                echo "Iniciando atualização..."
                stopCurrentContainers update
                ;;
            3)
                echo "Saindo..."
                exit 0
                ;;
            *)
                echo -e "${BRed}Opção inválida. Saindo..."
                exit 1
                ;;
        esac
    else
        echo -e "${BGreen}Nenhum container ou imagem existente encontrado. Prosseguindo com a nova instalação."
    fi
}

main() {
    
    prerequisites

    source "$SCRIPT_DIR/.env"
    ask_installation_or_update

    # readIPMachineFromUser
    setIPMachine
    source .env

    # Troca o valor da variável MONGO_URI
    sed -i "s|^MONGO_URI=.*|MONGO_URI=mongodb://${MONGO_USER}:${MONGO_PASSWORD}@mongo:${MONGO_PORT}/?authSource=admin|" .env

    # Troca o valor da variável DATABASE_URL
    sed -i "s|^DATABASE_URL=.*|DATABASE_URL=postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@postgres:${POSTGRES_PORT}/${POSTGRES_DB}?schema=public|" .env


    if curl -s http://127.0.0.1:$API_PORT/swagger > /dev/null
    then
        echo -e "${BWhite}Recompilando Instalação do EduEdu Escola - Versão ${APP_VERSION}"
    else
        echo -e "${BWhite}Iniciando Instalação do EduEdu Escola - Versão ${APP_VERSION}"
    fi

    echo ""

    build_frontend || {
        echo_fail
    }

    compose_containers

    init
}

start=`date +%s`
main "$@"
end=`date +%s`
execution_time=$(($end - $start))

echo -e "${BIGreen}EduEdu Escola - Versão ${APP_VERSION} - ${BWhite}Tempo de inicialização: ${BYellow}${execution_time}s"
echo -e ""
echo -e "${White}→   ${BWhite}Portal Admin:   ${APP_URL}:${ADMIN_PORT}"
echo -e "${White}→   ${BWhite}Portal Aluno:   ${APP_URL}:${ALUNO_PORT}"