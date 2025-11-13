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

# ----------------- Containers -----------------
function Build-Frontend {
    # Diretório onde está o script
    $scriptDir = $PSScriptRoot
    $composeFile = Join-Path $projectRoot "docker-compose.yml"

    if (-not (Test-Path $composeFile)) {
        Write-Host "[ ERRO ] docker-compose.yml nao encontrado em $scriptDir" -ForegroundColor Red
        exit 1
    }

    Write-Color "------------ Build Frontend ------------" Cyan
    Spinner-Run {
       docker-compose build admin aluno `
        --build-arg ARG_VITE_API_URL="http://$($ip):$( $env:API_PORT )/" `
        --build-arg ARG_VITE_ASSETS="LOCAL" `
        --build-arg API_URL="http://$( $ip ):$( $env:API_PORT )/" `
        --build-arg ADMIN_URL="http://$( $ip ):$( $env:ADMIN_PORT )/login" `
        --build-arg ARG_VITE_APP_VERSION="$( $env:APP_VERSION )" `
        --quiet
    } "Imagens Frontend (Admin e Aluno)"
    Write-Color "---------------------------------------" Cyan
}

function Compose-Containers {
    Push-Location $projectRoot
    
    Write-Color "------- Subindo Containers -------" Cyan

    docker volume create pgdata

    docker compose up -d postgres --quiet-pull
    docker cp ./postgres-data/. postgres:/var/lib/postgresql/data/
    docker exec -it postgres bash -c "chown -R postgres:postgres /var/lib/postgresql/data"
    docker restart postgres

    docker compose up -d mongo --quiet-pull
    Start-Sleep -Seconds 15
    docker compose up -d --quiet-pull

    Write-Color "----------------------------------" Cyan
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
function Stop-CurrentContainers($Action) {
    switch ($Action) {
        "install" {
            Write-Color "Parando containers e removendo imagens" Yellow
            docker-compose down --rmi all -v
        }
        "update" {
            Write-Color "Parando containers e limpando volumes" Yellow
            docker-compose down --volumes --remove-orphans
            docker rmi -f (docker images -q us-east1-docker.pkg.dev/edueduescola-teste/eduedu-escola-setup/eduedu-escola-admin)
            docker rmi -f (docker images -q us-east1-docker.pkg.dev/edueduescola-teste/eduedu-escola-setup/eduedu-escola-aluno)
            docker rmi -f (docker images -q us-east1-docker.pkg.dev/edueduescola-teste/eduedu-escola-setup/eduedu-escola-backend)
        }
        default {
            Write-Color "Acao invalida" Red
            exit 1
        }
    }
}

function Ask-InstallOrUpdate {
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
                if ($c -eq "s") { Stop-CurrentContainers install }
                else { exit 0 }
            }
            "2" { Stop-CurrentContainers update }
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

    # Atualiza MONGO_URI
    Update-EnvFile ".env" "MONGO_URI" "mongodb://${env:MONGO_USER}:${env:MONGO_PASSWORD}@mongo:${env:MONGO_PORT}/?authSource=admin"


    # Atualiza DATABASE_URL
    Update-EnvFile ".env" "DATABASE_URL" "postgresql://${env:POSTGRES_USER}:${env:POSTGRES_PASSWORD}@postgres:${env:POSTGRES_PORT}/${env:POSTGRES_DB}?schema=public"

    Prerequisites
    Ask-InstallOrUpdate

    $ip = Get-MachineIP
    Write-Color "IP detectado: $ip" Yellow
    Update-EnvFile ".env" "FILE_SERVER_URL" "http://${ip}:$($env:API_PORT)/assets-data"

    Build-Frontend
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
