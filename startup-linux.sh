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

# Função para bloquear a execução dentro de pastas do OneDrive
ensure_not_onedrive() {
    # Resolve o caminho absoluto real do projeto
    local project_dir
    project_dir="$(cd "$SCRIPT_DIR" &>/dev/null && pwd -P)"

    local inside=false

    # Detecta OneDrive pelas variáveis de ambiente (úteis no WSL/Windows)
    local root
    for root in "$OneDrive" "$OneDriveConsumer" "$OneDriveCommercial"; do
        if [ -n "$root" ]; then
            case "$project_dir" in
                "$root"|"$root"/*) inside=true ;;
            esac
        fi
    done

    # Fallback: detecta OneDrive pelo nome no caminho (ex.: "OneDrive", "OneDrive - Empresa")
    case "$project_dir" in
        */OneDrive|*/OneDrive/*|*/OneDrive\ -\ *) inside=true ;;
    esac

    if [ "$inside" = true ]; then
        printf "\n"
        printf "==================== ATENÇÃO ====================\n"
        printf "O projeto está sendo executado dentro de uma pasta do OneDrive:\n"
        printf "  %s\n\n" "$project_dir"
        printf "Instalar o EduEdu+ dentro do OneDrive NÃO é suportado e pode causar:\n"
        printf "  - Corrupção dos dados de Postgres/Mongo (a sincronização trava arquivos)\n"
        printf "  - Conflitos de sincronização e uso excessivo de banda/armazenamento\n"
        printf "  - Falhas nos bind mounts do Docker\n\n"
        printf "Mova a pasta do projeto para um caminho local fora do OneDrive e execute novamente.\n\n"

        if [ "$EDUEDU_ALLOW_ONEDRIVE" = "1" ]; then
            printf "EDUEDU_ALLOW_ONEDRIVE=1 definido. Prosseguindo por sua conta e risco...\n\n"
            return 0
        fi

        echo_fail "Instalação interrompida (projeto dentro do OneDrive)."
    fi
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

    docker-compose -f docker-compose.linux.yml build admin aluno &

    spinner $! 'Construindo imagens frontend' 'Imagens Frontend (Admin e Aluno)'

    echo "---------------------------------------------------------"
    echo ""
}

# Imagem usada nas verificações de Postgres (default igual ao do compose)
postgres_image() {
    printf "%s" "${POSTGRES_IMAGE:-postgres:17.6}"
}

# Testa exatamente o caminho que o backend usa: TCP, via rede do Docker,
# com usuário/senha/database do .env (valida senha, role e pg_hba.conf).
test_postgres_access() {
    local network
    network=$(docker inspect postgres --format '{{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}' 2>/dev/null | awk '{print $1}')
    [ -n "$network" ] || return 1

    docker run --rm --network "$network" -e PGPASSWORD="${POSTGRES_PASSWORD}" \
        --entrypoint psql "$(postgres_image)" \
        -h postgres -p 5432 -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -c "SELECT 1" >/dev/null 2>&1
}

# Não deixa migration/backend subirem sem o banco aceitar a conexão:
# sem isso o backend falha com "denied access on the database".
wait_postgres() {
    local attempt=1
    local max_retries=30

    while [ "$attempt" -le "$max_retries" ]; do
        if test_postgres_access; then
            echo_success "Postgres pronto (${POSTGRES_USER}@${POSTGRES_DB})"
            return 0
        fi

        printf "[ Tentativa %s/%s ] Postgres ainda não aceitou a conexão...\n" "$attempt" "$max_retries"
        sleep 3
        attempt=$((attempt + 1))
    done

    printf "\nO Postgres subiu mas recusou a conexão de %s em %s.\n" "${POSTGRES_USER}" "${POSTGRES_DB}"
    printf "Causa mais comum: diretório de dados de uma instalação anterior, com senha/database\n"
    printf "diferentes do .env atual (POSTGRES_DB/POSTGRES_USER/POSTGRES_PASSWORD só valem\n"
    printf "quando %s está vazio).\n\n" "${POSTGRES_DATA}"
    printf "Últimas linhas do log do Postgres:\n"
    docker logs postgres --tail 30

    echo_fail "Banco de dados inacessível. Instalação interrompida."
}

# Função para iniciar ou reiniciar os containers da aplicação
compose_containers() {
    echo "------- Inicialização dos Containers da Aplicação -------"

    cd "$SCRIPT_DIR" || exit

    docker-compose -f docker-compose.linux.yml up -d postgres
    wait_postgres

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
            docker rmi -f $(docker images -q eduedu-escola-admin) 2>/dev/null
            docker rmi -f $(docker images -q eduedu-escola-aluno) 2>/dev/null
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

    # Bloqueia execução dentro de pastas do OneDrive (antes de qualquer alteração)
    ensure_not_onedrive

    prerequisites
    
    source "$SCRIPT_DIR/.env"

    # Atualiza variáveis de URL no .env com o IP detectado
    sed -i "s|APP_URL=.*|APP_URL=http://${LOCAL_IP}|" .env
    sed -i "s|FILE_SERVER_URL=.*|FILE_SERVER_URL=http://${LOCAL_IP}:${API_PORT}/assets-data|" .env
    grep -q "^API_URL=" .env && sed -i "s|API_URL=.*|API_URL=http://${LOCAL_IP}:${API_PORT}|" .env || echo "API_URL=http://${LOCAL_IP}:${API_PORT}" >> .env
    grep -q "^ADMIN_URL=" .env && sed -i "s|ADMIN_URL=.*|ADMIN_URL=http://${LOCAL_IP}:${ADMIN_PORT}|" .env || echo "ADMIN_URL=http://${LOCAL_IP}:${ADMIN_PORT}" >> .env

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
