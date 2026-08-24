# EduEdu Setup Script em PowerShell
# ----------------- Configuracao Inicial -----------------

# Caminho absoluto do projeto (pasta acima de /scripts)
$projectRoot = Join-Path $PSScriptRoot ".."
Push-Location $projectRoot

# Caminho do .env
$envPath = Join-Path $projectRoot ".env"

Get-Content $envPath | ForEach-Object {
    if ($_ -match "^\s*([^#=]+)=(.*)$") {
        $name = $matches[1].Trim()
        $value = $matches[2].Trim().Trim('"') # remove aspas duplas
        Set-Item -Path "Env:$name" -Value $value
    }
}

$ip = ""

$hasDocker=$false
$hasWinget=$false
$hasWsl=$false

# "install" (limpa) ou "update" - definido em Ask-InstallOrUpdate
$installAction = "install"

# ----------------- Utilitarios -----------------

function Write-Color($Text, $Color="White") {
    Write-Host $Text -ForegroundColor $Color  
}

function Spinner-Run($ScriptBlock, $Message) {
    $chars = "/-\|"
    $jobDone = $false

    # Start script in background using a Runspace
    $ps = [powershell]::Create()
    $ps.AddScript($ScriptBlock) | Out-Null
    $asyncResult = $ps.BeginInvoke()

    while (-not $asyncResult.IsCompleted) {
        foreach ($c in $chars.ToCharArray()) {
            if ($asyncResult.IsCompleted) { break }
            Write-Host -NoNewline "`r[ $c ] $Message"
            Start-Sleep -Milliseconds 100
        }
    }

    $ps.EndInvoke($asyncResult)
    $ps.Dispose()

    Write-Host "`r[ OK ] $Message" -ForegroundColor Green
}

function Ask-YesNo($Question) {
    while ($true) {
        $response = Read-Host "$Question (S/N)"
        if ($response -match '^(S|s|Sim|sim)$') {
            return $true
        } elseif ($response -match '^(N|n|Nao|nao|Não|não)$') {
            return $false
        } else {
            Write-Host "Resposta invalida. Por favor, responda com S ou N." -ForegroundColor Yellow
        }
    }
}

# ----------------- Validacoes -----------------
function Ensure-NotOneDrive {
    # Resolve o caminho absoluto real do projeto
    $resolved = (Resolve-Path $projectRoot).Path

    # Coleta as raizes conhecidas do OneDrive a partir das variaveis de ambiente
    $oneDriveRoots = @(
        $env:OneDrive,
        $env:OneDriveConsumer,
        $env:OneDriveCommercial
    ) | Where-Object { $_ -and (Test-Path $_) } | ForEach-Object { (Resolve-Path $_).Path }

    $insideOneDrive = $false
    $sep = [System.IO.Path]::DirectorySeparatorChar

    foreach ($root in $oneDriveRoots) {
        if ($resolved -eq $root -or $resolved.StartsWith("$root$sep", [System.StringComparison]::OrdinalIgnoreCase)) {
            $insideOneDrive = $true
            break
        }
    }

    # Fallback: detecta pastas OneDrive pelo nome no caminho (ex.: "OneDrive", "OneDrive - Empresa")
    if (-not $insideOneDrive -and $resolved -match '(^|\\)OneDrive( -[^\\]*)?(\\|$)') {
        $insideOneDrive = $true
    }

    if ($insideOneDrive) {
        Write-Host ""
        Write-Color "==================== ATENCAO ====================" Red
        Write-Color "O projeto esta sendo executado dentro de uma pasta do OneDrive:" Red
        Write-Color "  $resolved" Yellow
        Write-Host ""
        Write-Color "Instalar o EduEdu+ dentro do OneDrive NAO e suportado e pode causar:" Red
        Write-Color "  - Corrupcao dos dados de Postgres/Mongo (a sincronizacao trava arquivos)" White
        Write-Color "  - Conflitos de sincronizacao e uso excessivo de banda/armazenamento" White
        Write-Color "  - Falhas nos bind mounts do Docker" White
        Write-Host ""
        Write-Color "Mova a pasta do projeto para um caminho local fora do OneDrive" Yellow
        Write-Color "(ex.: C:\eduedu) e execute a instalacao novamente." Yellow
        Write-Host ""

        if ($env:EDUEDU_ALLOW_ONEDRIVE -eq "1") {
            Write-Color "EDUEDU_ALLOW_ONEDRIVE=1 definido. Prosseguindo por sua conta e risco..." DarkYellow
            Write-Host ""
            return
        }

        Write-Color "Instalacao interrompida." Red
        Write-Host ""
        Write-Host "Pressione Enter para fechar..."
        Read-Host
        exit 1
    }
}

function Ensure-Docker {
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        if(-not (Ask-YesNo "Docker nao encontrado. Deseja instalar agora?")) {
            Write-Color "Instalacao automatica interrompida. Docker e um pre-requisito obrigatorio, inicie o processo novamente se quiser instalar o EduEdu+" Red
            exit 1
        }

        Write-Color "Iniciando instalacao..." Red

        # Monta o caminho absoluto para o script de instalação
        $installScript = Join-Path $PSScriptRoot "docker-installation.ps1"

        if (Test-Path $installScript) {
            & $installScript

            Write-Color "Por favor, reinicie o processo de instalacao do projeto apos a instalacao do Docker." Yellow
            exit 0
        } else {
            Write-Color "Script de instalacao nao encontrado: $installScript" Red
            exit 1
        }
    } else {
        [void]($hasDocker = $true)
        Write-Color "Docker OK" Green
    }
}

function Ensure-WSL {
    # Monta o caminho absoluto para o script de instalação
    $installScript = Join-Path $PSScriptRoot "wsl-installation.ps1"
    if (Test-Path $installScript) {
        & $installScript
        [void]($hasWsl = $true)
    } else {
        Write-Color "Script de instalacao do WSL nao encontrado: $installScript" Red
        Write-Color "Instalacao automatica interrompida. Realize a instalacao manualmente." Red
        exit 1
    }
}

function Ensure-Winget {
    # Testa se o winget existe
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        if(-not (Ask-YesNo "WinGet nao encontrado. Deseja tentar instalar agora?")) {
            Write-Color "Instalacao automatica interrompida. Winget e um pre-requisito obrigatorio, inicie o processo novamente se quiser instalar o EduEdu+" Red
            exit 1
        }
        
        Write-Color "Tentando registrar o App Installer..." Yellow
        
        try {
            Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe
        }
        catch {
            Write-Color "Erro ao tentar registrar via FamilyName." DarkYellow
        }

        if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
            Write-Color "A primeira tentativa deu errado" Red
            Write-Color "Segunda tentativa de registrar o App Installer..." Yellow

            try {
                Install-PackageProvider -Name NuGet -Force | Out-Null
                Install-Module -Name Microsoft.WinGet.Client -Force -Repository PSGallery | Out-Null
                Repair-WinGetPackageManager -Force -Latest

                Write-Color "Registro via PSGallery concluido." Green
                Write-Color "Por favor, reinicie o processo de instalacao do projeto apos a instalacao do WinGet." Yellow
                
                Write-Host ""
                Write-Host "Pressione Enter para fechar..."
                Read-Host

                exit 0
            }
            catch {
                Write-Color "Erro ao tentar registrar winget pela segunda vez. Instalacao interrompida. `n" Red
                Write-Color "Verifique se o sistema suporta WinGet (Necessario Windows 10 1809 (17763) ou superior)." Red
                
                Write-Host ""
                Write-Host "Pressione Enter para fechar..."
                Read-Host

                exit 1
            }
            
        }
    }

    # Verificação final única
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Color "WinGet ainda nao disponivel. Necessario Windows 10 1809 (17763) ou superior." Red
        Write-Color "Instalacao interrompida." Red
        exit 1
    } else {
        [void]($hasWinget = $true)
        Write-Color "WinGet OK" Green
    }
}

function Prerequisites {
    Write-Color "------------ Pre-requisitos ------------" Cyan
    Ensure-Winget
    Ensure-WSL
    Ensure-Docker
    Write-Color "----------------------------------------" Cyan
}

# ----------------- Funções Auxiliares -----------------
function Get-MachineIP {
    # Tenta pegar um IP na faixa 192.168.x.x
    $ip = Get-NetIPAddress -AddressFamily IPv4 |
        Where-Object { $_.IPAddress -match '^192\.168\.\d{1,3}\.\d{1,3}$' } |
        Select-Object -First 1 -ExpandProperty IPAddress

    # Se não achar, tenta 10.x.x.x
    if (-not $ip) {
        $ip = Get-NetIPAddress -AddressFamily IPv4 |
            Where-Object { $_.IPAddress -match '^10\.\d{1,3}\.\d{1,3}\.\d{1,3}$' } |
            Select-Object -First 1 -ExpandProperty IPAddress
    }

    # Se ainda não achar, tenta 172.16–31.x.x
    if (-not $ip) {
        $ip = Get-NetIPAddress -AddressFamily IPv4 |
            Where-Object { $_.IPAddress -match '^172\.(1[6-9]|2[0-9]|3[0-1])\.\d{1,3}\.\d{1,3}$' } |
            Select-Object -First 1 -ExpandProperty IPAddress
    }

    return $ip
}


function Update-EnvFile($Path, $Key, $Value) {
    $content = Get-Content $Path
    $new = @()
    $found = $false
    foreach ($line in $content) {
        if ($line -match "^$Key=") {
            $new += "$Key=$Value"
            $found = $true
        } else {
            $new += $line
        }
    }
    if (-not $found) { $new += "$Key=$Value" }
    $new | Set-Content $Path
}

# ----------------- Build de Imagens -----------------

function Build-Images {
    Write-Color "------- Buildando Imagens -------" Cyan

    Write-Color "Buildando backend ($env:APP_VERSION)..." Yellow
    docker build -t "eduedu-escola-backend:$env:APP_VERSION" `
        "https://github.com/instituto-abcd/eduedu-escola-backend.git#$env:APP_VERSION"

    Write-Color "Buildando admin ($env:APP_VERSION)..." Yellow
    docker build -t "eduedu-escola-admin:$env:APP_VERSION" `
        --build-arg "API_URL=$env:API_URL" `
        --build-arg "APP_VERSION=$env:APP_VERSION" `
        "https://github.com/instituto-abcd/eduedu-escola-admin.git#$env:APP_VERSION"

    Write-Color "Buildando aluno ($env:APP_VERSION)..." Yellow
    docker build -t "eduedu-escola-aluno:$env:APP_VERSION" `
        --build-arg "API_URL=$env:API_URL" `
        --build-arg "ADMIN_URL=$env:ADMIN_URL" `
        --build-arg "APP_VERSION=$env:APP_VERSION" `
        "https://github.com/instituto-abcd/eduedu-escola-aluno.git#$env:APP_VERSION"

    Write-Color "---------------------------------" Cyan
}

# ----------------- Containers -----------------

function Get-PostgresImage {
    if ($env:POSTGRES_IMAGE) { return $env:POSTGRES_IMAGE }
    return "postgres:17.6"   # mantenha em sincronia com o default do docker-compose.yml
}

# Descobre o volume que o compose realmente monta em /var/lib/postgresql/data.
# O compose prefixa volumes nomeados com o nome do projeto (ex.: setup_pgdata),
# por isso o nome nunca deve ser assumido como "pgdata".
function Get-PostgresVolume {
    docker compose create postgres 2>&1 | Out-Null
    $volume = docker inspect postgres --format '{{range .Mounts}}{{if eq .Destination "/var/lib/postgresql/data"}}{{.Name}}{{end}}{{end}}'
    return ($volume | Out-String).Trim()
}

# Restaura um snapshot de ./postgres-data ANTES do primeiro start do Postgres.
# Copiar arquivos com o container no ar sobrescreve o cluster durante o initdb e
# quebra roles/pg_hba.conf - foi o que gerava o erro "denied access on the database".
function Restore-PostgresSnapshot {
    $snapshot = Join-Path (Resolve-Path $projectRoot).Path "postgres-data"

    if (-not (Test-Path $snapshot)) { return }

    if ($script:installAction -eq "install") {
        Write-Color "Instalacao limpa: snapshot em ./postgres-data sera ignorado (banco criado do zero)." Yellow
        Write-Color "Se quiser aproveitar esses dados, escolha a opcao de atualizacao." Yellow
        return
    }

    if (-not (Test-Path (Join-Path $snapshot "PG_VERSION"))) {
        Write-Color "A pasta ./postgres-data existe mas nao contem um cluster valido (PG_VERSION ausente)." DarkYellow
        Write-Color "Restauracao ignorada - o Postgres sera inicializado do zero." DarkYellow
        return
    }

    $image  = Get-PostgresImage
    $volume = Get-PostgresVolume

    if (-not $volume) {
        Write-Color "Nao foi possivel identificar o volume de dados do Postgres. Restauracao ignorada." DarkYellow
        return
    }

    # Nao sobrescreve um cluster existente (caminho de atualizacao)
    $hasCluster = (docker run --rm -v "${volume}:/target" --entrypoint sh $image -c "[ -f /target/PG_VERSION ] && echo yes || echo no" | Out-String).Trim()
    if ($hasCluster -eq "yes") {
        Write-Color "Volume $volume ja possui um cluster. Snapshot de ./postgres-data ignorado (dados atuais preservados)." Yellow
        return
    }

    # Major version do snapshot precisa casar com a da imagem
    $snapshotMajor = (Get-Content (Join-Path $snapshot "PG_VERSION") -Raw).Trim()
    $imageMajor    = ((docker run --rm --entrypoint postgres $image --version | Out-String) -replace '[^0-9\. ]', '').Trim().Split(' ')[-1].Split('.')[0]

    if ($snapshotMajor -ne $imageMajor) {
        Write-Color "Snapshot em ./postgres-data e do PostgreSQL $snapshotMajor, mas a imagem e a $imageMajor." Red
        Write-Color "Restaurar dados entre versoes maiores diferentes nao funciona." Red
        Write-Color "Opcoes: definir POSTGRES_IMAGE=postgres:$snapshotMajor no .env, ou remover/renomear ./postgres-data." Yellow
        exit 1
    }

    Write-Color "Restaurando snapshot de ./postgres-data no volume $volume..." Yellow
    docker run --rm -v "${volume}:/target" -v "${snapshot}:/snapshot:ro" --entrypoint sh $image `
        -c "cp -a /snapshot/. /target/ && chown -R postgres:postgres /target && chmod 700 /target"

    if ($LASTEXITCODE -ne 0) {
        Write-Color "Falha ao restaurar o snapshot do Postgres." Red
        exit 1
    }
}

# Testa exatamente o caminho que o backend usa: TCP, via rede do Docker,
# com usuario/senha/database do .env (valida senha, role e pg_hba.conf).
function Test-PostgresAccess {
    $network = (docker inspect postgres --format '{{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}' | Out-String).Trim().Split(' ')[0]
    if (-not $network) { return $false }

    $null = docker run --rm --network $network -e "PGPASSWORD=$env:POSTGRES_PASSWORD" --entrypoint psql (Get-PostgresImage) `
        -h postgres -p 5432 -U $env:POSTGRES_USER -d $env:POSTGRES_DB -c "SELECT 1" 2>&1

    return ($LASTEXITCODE -eq 0)
}

function Wait-Postgres {
    Write-Host "`n[ - ] Aguardando o Postgres aceitar conexoes:" -ForegroundColor Yellow

    $maxRetries = 30
    $attempt = 1

    while ($attempt -le $maxRetries) {
        if (Test-PostgresAccess) {
            Write-Host "[ OK ] Postgres pronto ($env:POSTGRES_USER@$env:POSTGRES_DB)`n" -ForegroundColor Green
            return
        }

        Write-Host "[ Tentativa $attempt/$maxRetries ] Postgres ainda nao aceitou a conexao..." -ForegroundColor Yellow
        Start-Sleep -Seconds 3
        $attempt++
    }

    Write-Host ""
    Write-Color "[ ERRO ] O Postgres subiu mas recusou a conexao de $env:POSTGRES_USER em $env:POSTGRES_DB." Red
    Write-Color "Sem isso o backend falha com 'denied access on the database'. Instalacao interrompida." Red
    Write-Host ""
    Write-Color "Causa mais comum: volume de dados de uma instalacao anterior, com senha/database diferentes" Yellow
    Write-Color "do .env atual (POSTGRES_DB/POSTGRES_USER/POSTGRES_PASSWORD so valem quando o volume esta vazio)." Yellow
    Write-Color "Para recriar o banco do zero (apaga os dados atuais): docker compose down -v" Yellow
    Write-Host ""
    Write-Color "Ultimas linhas do log do Postgres:" Yellow
    docker logs postgres --tail 30

    exit 1
}

function Compose-Containers {
    Push-Location $projectRoot

    Write-Color "------- Subindo Containers -------" Cyan

    Restore-PostgresSnapshot

    docker compose up -d postgres --quiet-pull
    Wait-Postgres

    docker compose up -d mongo --quiet-pull
    Start-Sleep -Seconds 15

    # migration e backend esperam o healthcheck do postgres (docker-compose.yml)
    docker compose up -d --quiet-pull

    Write-Color "----------------------------------" Cyan

    Pop-Location
}

# ----------------- Validações HTTP -----------------
function Validate-Service($Name, $Url) {
    Write-Host "`n[ - ] Verificando $( $Name ):" -ForegroundColor Yellow
    $maxRetries = 20 
    $attempt = 1

    while ($attempt -le $maxRetries) {
        try {
            $response = Invoke-WebRequest -Uri $Url -TimeoutSec 10 -UseBasicParsing
            if ($response.StatusCode -eq 200) {
                Write-Host "[ Tentativa $attempt/$maxRetries ] $Name requisicao concluida com sucesso" -ForegroundColor Yellow
                Write-Host "[ OK ] $Name `n" -ForegroundColor Green
                return
            }
        } catch {
            Write-Host "[ Tentativa $attempt/$maxRetries ] $Name ainda nao respondeu..." -ForegroundColor Yellow
        }

        Start-Sleep -Seconds 5
        $attempt++
    }

    Write-Host "[ ERRO ] $Name nao respondeu em $Url `n" -ForegroundColor Red
    exit 1
}

function Init-Services {
    Write-Color "------- Validacao de Servicos -------" Cyan
    
    Validate-Service "Backend API"    "http://127.0.0.1:$env:API_PORT/swagger"
    Validate-Service "Portal Admin"   "http://127.0.0.1:$env:ADMIN_PORT"
    Validate-Service "Portal Aluno"   "http://127.0.0.1:$env:ALUNO_PORT"

    Write-Color "-------------------------------------" Cyan
}

# ----------------- Instalação/Atualização -----------------
function Remove-ImageIfExists($Repository) {
    $ids = docker images -q $Repository
    if ($ids) { docker rmi -f $ids | Out-Null }
}

function Stop-CurrentContainers($Action) {
    # Sempre "docker compose" (plugin v2). O binario legado "docker-compose" nao existe
    # em instalacoes recentes do Docker Desktop: se ele falhar aqui, os volumes antigos
    # sobrevivem a uma instalacao limpa e o banco continua com a senha/database anteriores.
    switch ($Action) {
        "install" {
            Write-Color "Parando containers e removendo imagens e volumes" Yellow
            docker compose down --rmi all --volumes --remove-orphans

            if ($LASTEXITCODE -ne 0) {
                Write-Color "Falha ao remover containers/volumes da instalacao anterior." Red
                Write-Color "Prosseguir manteria o banco antigo e causaria erro de acesso no backend." Red
                Write-Color "Rode 'docker compose down --rmi all --volumes --remove-orphans' manualmente e tente de novo." Yellow
                exit 1
            }
        }
        "update" {
            Write-Color "Parando containers e removendo imagens" Yellow
            docker compose down --remove-orphans

            if ($LASTEXITCODE -ne 0) {
                Write-Color "Falha ao parar os containers atuais." Red
                exit 1
            }

            Remove-ImageIfExists "eduedu-escola-admin"
            Remove-ImageIfExists "eduedu-escola-aluno"
        }
        default {
            Write-Color "Acao invalida" Red
            exit 1
        }
    }
}

function Ask-InstallOrUpdate {
    $script:installAction = "install"

    $containers = docker ps -q
    $images = docker images -q
    if ($containers -or $images) {
        Write-Color "Foram encontrados containers ou imagens no Docker" Yellow
        Write-Color "1. Instalacao limpa" White
        Write-Color "2. Atualizacao" White
        Write-Color "3. Sair" White
        $opt = Read-Host "Escolha uma opcao"
        switch ($opt) {
            "1" {
                $c = Read-Host "Tem certeza que deseja prosseguir? (s/n)"
                if ($c -eq "s") { $script:installAction = "install"; Stop-CurrentContainers install }
                else { exit 0 }
            }
            "2" { $script:installAction = "update"; Stop-CurrentContainers update }
            "3" { exit 0 }
            default { Write-Color "Opcao invalida" Red; exit 1 }
        }
    } else {
        Write-Color "Nenhum container ou imagem existente encontrado. Prosseguindo com a instalacao" Green
    }
}

# ----------------- Main -----------------
function Main {
    $start = Get-Date

    # Bloqueia execucao dentro de pastas do OneDrive (antes de qualquer alteracao)
    Ensure-NotOneDrive

    # MONGO_URI e DATABASE_URL sao usadas de dentro da rede do Docker, onde as portas
    # sao sempre as internas (27017 e 5432). POSTGRES_PORT/MONGO_PORT valem apenas
    # para o mapeamento no host.

    # Atualiza MONGO_URI
    Update-EnvFile ".env" "MONGO_URI" "mongodb://${env:MONGO_USER}:${env:MONGO_PASSWORD}@mongo:27017/eduedu?authSource=admin"


    # Atualiza DATABASE_URL
    Update-EnvFile ".env" "DATABASE_URL" "postgresql://${env:POSTGRES_USER}:${env:POSTGRES_PASSWORD}@postgres:5432/${env:POSTGRES_DB}?schema=public"

    Prerequisites
    Ask-InstallOrUpdate

    $ip = Get-MachineIP
    Write-Color "IP detectado: $ip" Yellow
    Update-EnvFile ".env" "FILE_SERVER_URL" "http://${ip}:$($env:API_PORT)/assets-data"
    Update-EnvFile ".env" "APP_ADDRESS" "${ip}"
    Update-EnvFile ".env" "APP_URL"       "http://${ip}"
    Update-EnvFile ".env" "API_URL"       "http://${ip}:$($env:API_PORT)"
    Update-EnvFile ".env" "ADMIN_URL"     "http://${ip}:$($env:ADMIN_PORT)"

    
    Get-Content $envPath | ForEach-Object {
        if ($_ -match "^\s*([^#=]+)=(.*)$") {
            $name = $matches[1].Trim()
            $value = $matches[2].Trim().Trim('"')
            Set-Item -Path "Env:$name" -Value $value
        }
    }

    Build-Images
    Compose-Containers
    Init-Services

    $end = Get-Date
    $execTime = [math]::Round(($end - $start).TotalSeconds, 2)

    Write-Color "EduEdu Escola - Versao $env:APP_VERSION - Tempo: $execTime s `n" Green
    Write-Color "`n--> Link de acesso Portal Admin: http://$( $ip ):$env:ADMIN_PORT" White
    Write-Color "--> Link de acesso portal Aluno: http://$( $ip ):$env:ALUNO_PORT `n" White
}

Main
Write-Host ""
Write-Host "Pressione Enter para fechar..."
Read-Host
