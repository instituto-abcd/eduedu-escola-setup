#!/bin/bash

# Recupera o diretório do script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# Constantes
DOCKER_COMPOSE_VERSION="v2.8.0"

# Cores para formatação do texto
GREEN="\033[32m"
RESET="\033[0m"

# Função para exibir mensagem de falha e sair
echo_fail() {
    printf "✘ Falha: $*\n" >&2
    exit 1
}

# Função para exibir mensagem de sucesso
echo_success() {
    printf "${GREEN}✔ Sucesso: $*${RESET}\n"
}

# Função do spinner para exibição de progresso
spinner() {
    local PROC="$1"
    local str="${2:-$message}"
    local delay="0.1"
    local success_message="${3:-$message}"

    while [ -d /proc/$PROC ]; do
        printf '\033[s\033[u[ / ] %s\033[u' "$str"; sleep "$delay"
        printf '\033[s\033[u[ — ] %s\033[u' "$str"; sleep "$delay"
        printf '\033[s\033[u[ \ ] %s\033[u' "$str"; sleep "$delay"
        printf '\033[s\033[u[ | ] %s\033[u' "$str"; sleep "$delay"
    done

    printf '\033[s\033[u%*s\033[u' $((${#str}+6)) " "  # return to normal
    echo_success "$success_message"
}

# Função para instalar o wget se não estiver instalado
install_wget() {
    # Verifica se o comando wget está disponível
    if ! command -v wget &>/dev/null; then
        echo "O comando 'wget' não está instalado. Instalando agora..."

        # Atualiza a lista de pacotes
        apt update

        # Instala o wget
        apt install wget -y || echo_fail "Houve um erro durante a instalação do 'wget'. Saindo..."
        echo_success "O comando 'wget' foi instalado com sucesso."
    fi
}

# Função para verificar se o usuário está no grupo docker
check_docker_group() {
    if groups | grep -q docker; then
        echo "Usuário já está no grupo docker."
    else
        echo "Adicionando o usuário ao grupo docker..."
        sudo usermod -aG docker $USER || echo_fail "Houve um erro ao adicionar o usuário ao grupo docker. Saindo..."
        echo "Faça logout e login novamente para que as alterações tenham efeito."
    fi
}

# Função para garantir a instalação do Docker
ensure_docker() {
    # Verifica se o Docker já está instalado
    if ! command -v docker &>/dev/null; then
        echo "## Instalando Docker..."

        # Atualiza a lista de pacotes
        apt update

        # Instala as dependências do Docker
        apt-get install -y \
            ca-certificates \
            curl \
            gnupg \
            lsb-release || echo_fail "Houve um erro durante a instalação das dependências do Docker. Saindo..."

        # Adiciona o repositório oficial do Docker
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/docker.gpg
        echo "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list

        # Atualiza a lista de pacotes e instala o Docker
        apt update
        apt-get install -y docker-ce docker-ce-cli containerd.io || echo_fail "Houve um erro durante a instalação do Docker. Saindo..."

        # Baixa e instala o Docker Compose
        curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose

        # Verifica se o Docker está instalado corretamente
        command -v docker &>/dev/null || echo_fail "Docker não instalado corretamente. Saindo..."

        # Verifica se o Docker Compose está instalado corretamente
        command -v docker-compose &>/dev/null || echo_fail "Docker Compose não instalado corretamente. Saindo..."

        # Verifica se o Docker está em execução
        docker ps -q &>/dev/null || echo_fail "Não foi possível conectar ao Docker. Verifique sua instalação ou inicie o serviço antes de prosseguir."

        # Verifica se o usuário está no grupo docker
        check_docker_group

        echo_success "## Docker instalado e configurado com sucesso!"
    else
        echo_success "## Docker já está instalado!"
        docker-compose version
    fi
}

# Função para construir as imagens frontend
build_frontend() {
    echo "------------ Construção das Imagens Frontend ------------"

    VITE_API_URL="${APP_URL}:${API_PORT}/"

    docker-compose -f docker-compose.linux.yml build \
        --build-arg ARG_VITE_API_URL="$VITE_API_URL" \
        --build-arg ARG_VITE_ASSETS=LOCAL \
        --build-arg ARG_VITE_APP_VERSION="$APP_VERSION" admin aluno &

    spinner $! 'Imagens Frontend' 'Imagens Frontend (Admin e Aluno)'

    echo "---------------------------------------------------------"
    echo ""
}

# Função para iniciar ou reiniciar os containers da aplicação
compose_containers() {
    echo "------- Inicialização dos Containers da Aplicação -------"

    cd "$SCRIPT_DIR" || exit
    docker-compose -f docker-compose.linux.yml up -d

    echo "---------------------------------------------------------"
    echo ""
}

# Função para validar se o backend está disponível
validate_backend() {
    local API_HEALTH_URL="http://${LOCAL_IP}:${API_PORT}/swagger"

    if wget --quiet --tries=1 --timeout=5 --spider "${API_HEALTH_URL}"; then
        echo "→   Backend:          ${API_HEALTH_URL} [ OK ]"
    else
        echo_fail "→   Backend:          ${API_HEALTH_URL} [ Falha ]"
    fi
}

# Função para validar se o admin está disponível
validate_admin() {
    local ADMIN_URL="http://${LOCAL_IP}:${ADMIN_PORT}"

    if wget --quiet --tries=1 --timeout=5 --spider "${ADMIN_URL}"; then
        echo "→   Portal Admin:     ${ADMIN_URL} [ OK ]"
    else
        echo_fail "→   Portal Admin:     ${ADMIN_URL} [ Falha ]"
    fi
}

# Função para validar se o aluno está disponível
validate_aluno() {
    local ALUNO_URL="http://${LOCAL_IP}:${ALUNO_PORT}"

    if wget --quiet --tries=1 --timeout=5 --spider "${ALUNO_URL}"; then
        echo "→   Portal Aluno:     ${ALUNO_URL} [ OK ]"
    else
        echo_fail "→   Portal Aluno:     ${ALUNO_URL} [ Falha ]"
    fi
}

# Função para parar os containers da instalação atual
stop_current_containers() {
    local action=$1

    case $action in
        "install")
            echo "---------------- Parando containers e removendo imagens ----------------"
            cd "$SCRIPT_DIR" || exit
            
            # Backup dos bancos de dados
	    #[ -e postgres-data.zip ] && rm -rf postgres-data.zip
            #[ -e mongodb-data.zip ] && rm -rf mongodb-data.zip

            # Crie arquivos de backup apenas se os diretórios existirem
            #[ -d postgres-data ] && zip -r postgres-data.zip postgres-data
            #[ -d mongodb-data ] && zip -r mongodb-data.zip mongodb-data

            # Exclua os diretórios originais apenas se existirem
            [ -d assets-data ] && rm -rf assets-data
            [ -d postgres-data ] && rm -rf postgres-data
            [ -d mongodb-data ] && rm -rf mongodb-data

            docker-compose -f docker-compose.linux.yml down --rmi all -v
            ;;
        "update")
            echo "---------------- Parando e removendo containers e imagens de admin, aluno e backend ----------------"
            cd "$SCRIPT_DIR" || exit

            docker-compose -f docker-compose.linux.yml down --volumes --remove-orphans

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


prerequisites() {
    echo "------------ Pré-requisitos para Instalação -------------"
    # Recupera o IP local automaticamente
    LOCAL_IP=$(hostname -I | awk '{print $1}')
    
    # Verifica se a variável APP_ADDRESS já existe no arquivo .env
    if grep -q "APP_ADDRESS=" .env; then
        # Atualiza a variável APP_ADDRESS no arquivo .env
        sed -i "s/APP_ADDRESS=.*/APP_ADDRESS=${LOCAL_IP}/" .env
    else
        # Adiciona a variável APP_ADDRESS ao arquivo .env
        echo "APP_ADDRESS=${LOCAL_IP}" >> .env
    fi

    export APP_ADDRESS="${LOCAL_IP}"

    ensure_docker

    echo "IP local detectado: ${APP_ADDRESS}"

    echo "---------------------------------------------------------"
    echo ""
}


# Função para perguntar ao usuário se é uma instalação, atualização ou saída
ask_installation_or_update() {
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
                    stop_current_containers install
                else
                    echo "Operação de instalação cancelada."
                    exit 0
                fi
                ;;
            2)
                echo "Iniciando atualização..."
                stop_current_containers update
                ;;
            3)
                echo "Saindo..."
                exit 0
                ;;
            *)
                echo_fail "Opção inválida. Saindo..."
                ;;
        esac
    else
        stop_current_containers install
    fi
}

# Função principal
main() {
    start=$(date +%s)

    prerequisites
    
    source "$SCRIPT_DIR/.env"

    ask_installation_or_update

    if wget -q --spider "http://${LOCAL_IP}:${API_PORT}/swagger"; then
        echo "Recompilando Instalação do EduEdu Escola - Versão ${APP_VERSION}"
    else
        echo "Iniciando Instalação do EduEdu Escola - Versão ${APP_VERSION}"
    fi

    build_frontend || echo_fail "Falha na construção das imagens frontend."

    compose_containers

    # Espera os serviços subirem completamente
    sleep 30

    validate_backend
    validate_admin
    validate_aluno

    # Mede o tempo de execução
    end=$(date +%s)
    execution_time=$((end-start))

    echo_success "EduEdu Escola - Versão ${APP_VERSION} - Tempo de inicialização: ${execution_time}s"
}

# Chamada para a função principal
main "$@"
