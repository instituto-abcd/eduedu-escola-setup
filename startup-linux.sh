#!/bin/bash

# Verifica se o script está sendo executado como sudo
if [ "$EUID" -ne 0 ]; then
    echo "Este script precisa ser executado com privilégios de superusuário (sudo)."
    echo "Exemplo de execução: sudo ./startup-linux.sh"
    exit 1
fi

# Função para instalar o wget
install_wget() {
    echo "O comando 'wget' não está instalado. Deseja instalar agora? (y/n)"
    read -r answer
    if [[ "$answer" =~ [Yy] ]]; then
        echo "Instalando o WGET..."
        apt update
        apt install wget -y
    else
        echo "É necessário instalar o 'wget' para continuar. Saindo..."
        exit 1
    fi
}

# Verifica se o wget está instalado
if ! command -v wget &> /dev/null; then
    install_wget
fi

# Função do spinner
spinner() {
    message=$2

    local PROC="$1"
    local str="${2:-$message}"
    local delay="0.1"
    while [ -d /proc/$PROC ]; do
        printf '\033[s\033[u[ / ] %s\033[u' "$str"; sleep "$delay"
        printf '\033[s\033[u[ — ] %s\033[u' "$str"; sleep "$delay"
        printf '\033[s\033[u[ \ ] %s\033[u' "$str"; sleep "$delay"
        printf '\033[s\033[u[ | ] %s\033[u' "$str"; sleep "$delay"
    done
    printf '\033[s\033[u%*s\033[u' $((${#str}+6)) " "  # return to normal
    echo "[ OK ] $message"
    return 0
}

# Função para exibir mensagem de falha
echo_fail() {
    printf "✘ Falha: $*\n"  # Use * para expandir todos os argumentos como uma única string
}


# Função para garantir a instalação do Docker
ensure_docker() {
    if ! command -v docker &> /dev/null; then
        echo "Instalando Docker..."
        apt update # Atualizar a lista de pacotes
        apt install ca-certificates curl -y # Autoridade de certificação
        install -m 0755 -d /etc/apt/keyrings # Definir permissões de propriedade para o diretório /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc # Baixar chave com curl
        chmod a+r /etc/apt/keyrings/docker.asc # Definir permissões de leitura para a chave
        echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
          $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
          tee /etc/apt/sources.list.d/docker.list > /dev/null # Adicionir o repositório Docker à lista de fontes APT
        apt update #Atualizar lista de repositórios:
        apt install docker-compose-plugin -y #Instalar o Docker Compose
        docker compose version #Verificar versão instalada
        echo "Docker Instalado"
    fi

    if ! docker ps -q >/dev/null 2>&1; then
        echo_fail "Não foi possível conectar ao Docker. Verifique sua instalação ou inicie o serviço antes de prosseguir."
        exit 1
    fi

    echo "Docker OK"
}

# Função para construir as imagens frontend
build_frontend() {
    echo "------------ Construção das Imagens Frontend ------------"

    VITE_API_URL="${APP_URL}:${API_PORT}/"

    docker-compose build --build-arg ARG_VITE_API_URL=$VITE_API_URL --build-arg ARG_VITE_ASSETS=LOCAL --build-arg ARG_VITE_APP_VERSION=$APP_VERSION admin aluno --quiet &
    spinner $! 'Imagens Frontend (Admin e Aluno)'

    echo "---------------------------------------------------------"
    echo ""
}

# Função para iniciar os containers da aplicação
compose_containers() {
    echo "------- Inicialização dos Containers da Aplicação -------"
    docker-compose up -d postgres --quiet-pull
    docker-compose up -d mongo --quiet-pull

    sleep 15

    docker-compose up -d --quiet-pull
    echo "---------------------------------------------------------"
    echo ""
}

# Função para validar o backend
validate_backend() {
    wget_command="wget"
    if ! command -v wget &> /dev/null; then
        install_wget
    fi

    $wget_command \
        --timeout=30 \
        --tries=30 \
        --waitretry=5 \
        -O /dev/null \
        -q "http://${LOCAL_IP}:${API_PORT}/swagger" &
    spinner $! 'Backend API'
}

# Função para validar o portal admin
validate_admin() {
    wget_command="wget"
    if ! command -v wget &> /dev/null; then
        install_wget
    fi

    $wget_command \
        --timeout=30 \
        --tries=30 \
        --waitretry=5 \
        -O /dev/null \
        -q "http://${LOCAL_IP}:${ADMIN_PORT}" &
    spinner $! 'Portal Admin'
}

# Função para validar o portal aluno
validate_aluno() {
    wget_command="wget"
    if ! command -v wget &> /dev/null; then
        install_wget
    fi

    $wget_command \
        --timeout=30 \
        --tries=30 \
        --waitretry=5 \
        -O /dev/null \
        -q "http://${LOCAL_IP}:${ALUNO_PORT}" &
    spinner $! 'Portal Aluno'
}

# Função para inicializar a aplicação
init() {
    echo "---------------- Inicialização Aplicação ----------------"
    validate_backend
    validate_admin
    validate_aluno
    echo "---------------------------------------------------------"
    echo ""
}

# Função para parar os containers da instalação atual
stopCurrentContainers() {
    echo "---------------- Parando containers da instalação atual ----------------"
    docker-compose down
    echo "---------------------------------------------------------"
    echo ""
}

# Recupera o IP local automaticamente
LOCAL_IP=$(hostname -I | awk '{print $1}')

# Função que exibe mensagens de pré-requisitos
prerequisites() {
    echo "------------ Pré-requisitos para Instalação -------------"

    ensure_docker

    echo "---------------------------------------------------------"
    echo ""
}

# Função principal
main() {
    prerequisites

    source .env

    if wget -q --spider "http://${LOCAL_IP}:${API_PORT}/swagger"
    then
        echo "Recompilando Instalação do EduEdu Escola - Versão ${APP_VERSION}"
    else
        echo "Iniciando Instalação do EduEdu Escola - Versão ${APP_VERSION}"
    fi

    stopCurrentContainers

    echo ""

    build_frontend || {
        echo_fail
    }

    compose_containers

    init
}

# Mede o tempo de execução
start=`date +%s`
main "$@"
end=`date +%s`
execution_time=$(($end-$start))

echo "EduEdu Escola - Versão ${APP_VERSION} - Tempo de inicialização: ${execution_time}s"
echo ""
echo "→   Portal Admin:   ${LOCAL_IP}:${ADMIN_PORT}"
echo "→   Portal Aluno:   ${LOCAL_IP}:${ALUNO_PORT}"