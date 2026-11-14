# Instalacao do WSL, pre-requisito do Docker Desktop.
#
# Codigos de saida, lidos pelo Ensure-WSL do startup-windows.ps1:
#   0 = WSL pronto: a instalacao do EduEdu+ pode seguir
#   1 = falha: a mensagem de erro ja foi exibida por este script
#   2 = interrompido sem erro: o operador recusou a instalacao ou falta
#       reiniciar o computador
# Todo caminho termina com "exit" explicito: sem ele o $LASTEXITCODE visto pelo
# instalador seria o do ultimo programa executado aqui dentro.

# Versao minima do WSL exigida pelo Docker Desktop (requisitos de sistema em
# docs.docker.com/desktop/setup/install/windows-install)
$wslMinVersion = [version]"2.1.5"

# Relato de campo (EEP-671): numa escola cuja rede bloqueava o download, a
# instalacao do WSL falhou sem nenhum aviso e o instalador seguiu ate o Docker
# Desktop acusar "WSL not installed". A falha agora para aqui, dizendo o que
# aconteceu e o que fazer.
function Write-WslError([string[]]$Problema, [string[]]$Passos) {
    Write-Host ""
    Write-Host "===================== ERRO =====================" -ForegroundColor Red
    foreach ($linha in $Problema) {
        Write-Host $linha -ForegroundColor Red
    }
    Write-Host ""
    Write-Host "Como resolver:" -ForegroundColor Yellow
    $numero = 1
    foreach ($passo in $Passos) {
        Write-Host "  $numero. $passo" -ForegroundColor White
        $numero++
    }
    Write-Host ""
    Write-Host "O WSL e um pre-requisito obrigatorio: sem ele o EduEdu+ nao pode ser instalado." -ForegroundColor Red
}

# Roda o wsl.exe nesta mesma janela e devolve o codigo de saida. Antes ele abria
# em outra janela, que fechava sozinha ao terminar e levava a mensagem de erro junto.
function Invoke-WslExe([string]$Arguments) {
    $process = Start-Process $wslExe -ArgumentList $Arguments -Wait -NoNewWindow -PassThru
    return $process.ExitCode
}

# Consulta o wsl.exe sem mostrar nada na tela e sem depender do operador:
# - a entrada e fechada, para o wsl.exe nao ficar esperando uma tecla;
# - ha tempo limite, para um WSL travado nao travar o instalador;
# - a saida e lida byte a byte (Latin-1) e os bytes nulos sao removidos, porque
#   o wsl.exe escreve em UTF-16 ou em UTF-8 conforme a variavel WSL_UTF8. Os
#   numeros da versao ficam legiveis nos dois casos.
# Qualquer falha ao executar deixa ExitCode nulo, que e tratado como erro.
function Invoke-WslQuiet([string]$Arguments, [int]$TimeoutSec) {
    $result = @{ ExitCode = $null; Output = ""; TimedOut = $false }

    try {
        $latin1 = [System.Text.Encoding]::GetEncoding(28591)

        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName               = $wslExe
        $psi.Arguments              = $Arguments
        $psi.UseShellExecute        = $false
        $psi.CreateNoWindow         = $true
        $psi.RedirectStandardInput  = $true
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError  = $true
        $psi.StandardOutputEncoding = $latin1
        $psi.StandardErrorEncoding  = $latin1

        $process = [System.Diagnostics.Process]::Start($psi)
        $process.StandardInput.Close()
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()

        if (-not $process.WaitForExit($TimeoutSec * 1000)) {
            $result.TimedOut = $true
            try { $process.Kill() } catch { }
            return $result
        }

        $result.ExitCode = $process.ExitCode
        if ($stdout.Wait(5000)) {
            $result.Output = $stdout.Result -replace "`0", ""
        }
    }
    catch {
        # Nao conseguiu executar o wsl.exe: ExitCode fica nulo
    }

    return $result
}

# Virtualizacao, sem a qual a maquina virtual do WSL 2 (e o Docker) nao inicia:
#   "ok"           = o hipervisor do Windows esta em execucao
#   "firmware"     = a virtualizacao esta desabilitada na BIOS/UEFI
#   "hipervisor"   = habilitada na BIOS/UEFI, mas o hipervisor nao esta em execucao
#                    (normal antes de habilitar os recursos do Windows e reiniciar)
#   "desconhecido" = o Windows nao informou
# O hipervisor e carregado na inicializacao do Windows, entao a ausencia dele
# vale ate a proxima reinicializacao. O Windows so informa o estado da BIOS/UEFI
# enquanto o hipervisor nao esta em execucao, por isso a ordem das consultas.
# Limite conhecido: dentro de uma maquina virtual o resultado e sempre "ok",
# porque o hipervisor detectado e o do computador hospedeiro.
function Get-VirtualizationState {
    try {
        $computer = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
        if ($null -eq $computer.HypervisorPresent) { return "desconhecido" }
        if ($computer.HypervisorPresent) { return "ok" }

        $processor = Get-CimInstance Win32_Processor -ErrorAction Stop | Select-Object -First 1
        if ($null -eq $processor.VirtualizationFirmwareEnabled) { return "desconhecido" }
        if ($processor.VirtualizationFirmwareEnabled) { return "hipervisor" }
        return "firmware"
    }
    catch {
        return "desconhecido"
    }
}

# Estado real do WSL. Os recursos do Windows habilitados nao bastam: quando o
# download falhava e o computador era reiniciado, a execucao seguinte mostrava
# "WSL OK" sem o WSL estar instalado (EEP-671). So e "ok" quando:
#   - "wsl --version" responde: so o pacote do WSL instalado tem esse comando,
#     o wsl.exe que vem com o Windows (sem o pacote) nao tem;
#   - a versao atende ao minimo do Docker Desktop;
#   - "wsl --status" responde: ele consulta o servico do WSL e termina com
#     erro quando o servico nao atende;
#   - o hipervisor do Windows esta em execucao: com o WSL instalado e a
#     virtualizacao desabilitada, tudo acima passa e o WSL 2 nao inicia.
# Na duvida (tempo esgotado, saida ilegivel, Windows sem informar) o estado NAO e "ok".
function Get-WslState {
    $state = @{ Status = "ausente"; Version = $null }

    $versionResult = Invoke-WslQuiet "--version" 30
    if ($versionResult.TimedOut -or $versionResult.ExitCode -ne 0) { return $state }
    if ($versionResult.Output -notmatch '(\d+\.\d+\.\d+(\.\d+)?)') { return $state }

    $state.Version = [version]$matches[1]
    if ($state.Version -lt $wslMinVersion) {
        $state.Status = "desatualizado"
        return $state
    }

    # O proprio wsl.exe espera ate 1 minuto por um servico que ainda esta subindo
    $statusResult = Invoke-WslQuiet "--status" 75
    if ($statusResult.TimedOut -or $statusResult.ExitCode -ne 0) {
        $state.Status = "sem-resposta"
        return $state
    }

    if ($virtualization -ne "ok") {
        $state.Status = "sem-virtualizacao"
        return $state
    }

    $state.Status = "ok"
    return $state
}

function Write-VirtualizationError($Virtualization) {
    switch ($Virtualization) {
        "firmware" {
            Write-WslError @(
                "A virtualizacao esta desabilitada na BIOS/UEFI deste computador.",
                "Sem ela o WSL e o Docker nao iniciam, mesmo instalados."
            ) @(
                "Reinicie o computador e entre na configuracao da BIOS/UEFI (em geral pelas teclas Del, F2, F10 ou Esc logo ao ligar)",
                "Habilite a virtualizacao: 'Intel Virtualization Technology' (VT-x) em processadores Intel ou 'SVM Mode' (AMD-V) em processadores AMD",
                "Salve, deixe o Windows iniciar e execute o Instalador-Windows.cmd novamente",
                "O guia de instalacao (docs\Windows.md) tem o link 'Como habilitar a virtualizacao de hardware'",
                $passosSuporte
            )
        }
        "hipervisor" {
            Write-WslError @(
                "A virtualizacao esta habilitada na BIOS/UEFI, mas o hipervisor do Windows nao esta em execucao.",
                "Sem ele o WSL e o Docker nao iniciam, mesmo instalados."
            ) @(
                "Reinicie o computador pelo menu Iniciar, na opcao 'Reiniciar' (nao use 'Desligar')",
                "Execute o Instalador-Windows.cmd novamente",
                $passosSuporte
            )
        }
        default {
            Write-WslError @(
                "Nao foi possivel confirmar se a virtualizacao esta habilitada neste computador.",
                "Sem ela o WSL e o Docker nao iniciam, mesmo instalados."
            ) @(
                "Reinicie o computador",
                "Execute o Instalador-Windows.cmd novamente",
                $passosSuporte
            )
        }
    }
}

$passosSuporte = "Se o erro continuar, execute o Suporte-Windows.cmd e envie o log ao suporte, junto com uma foto desta tela"

$passosDownload = @(
    "Verifique se este computador esta conectado a internet",
    "A rede da escola pode bloquear o download do WSL: se a internet funciona e o erro continua, peca a liberacao ao responsavel pela rede",
    "Execute o Instalador-Windows.cmd novamente",
    $passosSuporte
)

function Write-WslStateError($State) {
    switch ($State.Status) {
        "desatualizado" {
            Write-WslError @(
                "Nao foi possivel atualizar o WSL.",
                "A versao instalada ($($State.Version)) e mais antiga que a exigida pelo Docker Desktop ($wslMinVersion)."
            ) $passosDownload
        }
        "sem-resposta" {
            Write-WslError @(
                "O WSL esta instalado (versao $($State.Version)), mas o servico do WSL nao respondeu a verificacao."
            ) @(
                "Reinicie o computador",
                "Execute o Instalador-Windows.cmd novamente",
                $passosSuporte
            )
        }
        "sem-virtualizacao" {
            Write-VirtualizationError $virtualization
        }
        default {
            Write-WslError @(
                "O WSL nao foi instalado neste computador.",
                "O comando de instalacao terminou sem erro, mas o WSL continua ausente."
            ) $passosDownload
        }
    }
}

# 1. Verifica se o comando existe
$wslCommand = Get-Command wsl.exe -ErrorAction SilentlyContinue
if (-not $wslCommand) {
    Write-WslError @(
        "O WSL nao esta disponivel neste computador (comando wsl.exe nao encontrado)."
    ) @(
        "Confirme que o Windows e 10 ou 11 de 64 bits, versao 22H2 ou superior",
        "Instale as atualizacoes pendentes do Windows Update e reinicie o computador",
        "Execute o Instalador-Windows.cmd novamente",
        $passosSuporte
    )
    exit 1
}
$wslExe = $wslCommand.Source

# 2. Virtualizacao desabilitada na BIOS/UEFI: avisa antes de instalar qualquer
# coisa, porque so o operador resolve e nada do que vem a seguir funcionaria.
# Os outros estados sao avaliados no passo 4, depois das features.
$virtualization = Get-VirtualizationState
if ($virtualization -eq "firmware") {
    Write-VirtualizationError $virtualization
    exit 1
}

# 3. Verifica se as features do Windows estao habilitadas
$wslFeature = (Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux).State
$vmFeature  = (Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform).State
$featuresEnabled = ($wslFeature -eq "Enabled" -and $vmFeature -eq "Enabled")

# 4. Com as features habilitadas, confere se o WSL esta mesmo instalado, respondendo
# e com a virtualizacao ativa
if ($featuresEnabled) {
    Write-Host "Verificando o WSL..." -ForegroundColor Yellow
    $state = Get-WslState

    if ($state.Status -eq "ok") {
        Write-Host "WSL OK" -ForegroundColor Green
        exit 0
    }

    if ($state.Status -eq "sem-resposta" -or $state.Status -eq "sem-virtualizacao") {
        # Instalar de novo nao resolve servico parado nem virtualizacao inativa
        Write-WslStateError $state
        exit 1
    }

    if ($state.Status -eq "desatualizado") {
        Write-Host "O WSL instalado (versao $($state.Version)) e mais antigo que o exigido pelo Docker Desktop ($wslMinVersion). Deseja atualizar o WSL agora? (S/N)" -ForegroundColor Yellow
    } else {
        Write-Host "O WSL esta habilitado, mas ainda nao esta instalado neste computador. Deseja instalar o WSL agora? (S/N)" -ForegroundColor Yellow
    }
}
else {
    Write-Host "Voce nao possui WSL habilitado deseja habilitar o WSL agora? (S/N)" -ForegroundColor Yellow
}

$response = Read-Host
if ($response -notmatch '^(S|s|Sim|sim)$') {
    Write-Host "A instalacao sera interrompida. WSL e um pre-requisito obrigatorio, inicie o processo novamente se quiser instalar o EduEdu+" -ForegroundColor Yellow
    exit 2
}

# 5. Habilita os recursos do Windows (etapa local, nao depende de internet)
if (-not $featuresEnabled) {
    Write-Host "Instalando recursos necessarios..." -ForegroundColor Yellow

    try {
        Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart -All -ErrorAction Stop | Out-Null
        Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart -All -ErrorAction Stop | Out-Null
    }
    catch {
        Write-WslError @(
            "Nao foi possivel habilitar os recursos do Windows que o WSL precisa.",
            "Motivo informado pelo Windows: $($_.Exception.Message)"
        ) @(
            "Instale as atualizacoes pendentes do Windows Update e reinicie o computador",
            "Execute o Instalador-Windows.cmd novamente",
            $passosSuporte
        )
        exit 1
    }
}

# 6. Baixa e instala o pacote do WSL (o wsl.exe busca na internet)
Write-Host "Baixando e instalando o WSL. Esta etapa precisa de internet e pode demorar alguns minutos..." -ForegroundColor Yellow

# A atualizacao sozinha nao decide o resultado: ela pode falhar antes da
# reinicializacao mesmo quando a instalacao logo abaixo da certo
$updateExitCode  = Invoke-WslExe "--update"
$installExitCode = Invoke-WslExe "--install --no-distribution"

if ($installExitCode -ne 0) {
    Write-WslError @(
        "Nao foi possivel baixar ou instalar o WSL (codigo de saida $installExitCode).",
        "O motivo informado pelo Windows esta logo acima desta mensagem."
    ) $passosDownload
    exit 1
}

# 7. As features ja estavam habilitadas: nao ha reinicializacao pendente, entao o
# resultado e conferido agora. "WSL OK" so aparece se a verificacao passar.
if ($featuresEnabled) {
    Write-Host "Verificando o WSL..." -ForegroundColor Yellow
    $state = Get-WslState

    if ($state.Status -ne "ok") {
        Write-WslStateError $state
        exit 1
    }

    Write-Host "WSL OK" -ForegroundColor Green
    exit 0
}

if ($updateExitCode -ne 0) {
    Write-Host "Aviso: nao foi possivel atualizar o WSL agora (codigo de saida $updateExitCode). Ele sera conferido de novo depois da reinicializacao." -ForegroundColor Yellow
}

# 8. Features recem-habilitadas: so valem depois de reiniciar. A execucao seguinte
# do instalador confere o WSL de verdade (passo 4) antes de seguir para o Docker.
Write-Host "E necessario reiniciar o computador para concluir a configuracao do WSL." -ForegroundColor Yellow
Write-Host "Deseja reiniciar agora? (S/N)" -ForegroundColor Yellow
$response = Read-Host
if ($response -match '^(S|s|Sim|sim)$') {
    Write-Host "Reiniciando o computador..." -ForegroundColor Green
    Restart-Computer -Force
} else {
    Write-Host "Por favor, reinicie o computador manualmente para concluir a configuracao do WSL e depois execute o Instalador-Windows.cmd novamente." -ForegroundColor Yellow
}

# O Docker so pode ser instalado depois da reinicializacao
exit 2
