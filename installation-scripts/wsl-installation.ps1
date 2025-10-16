# 1. Verifica se o comando existe
$wslCommand = Get-Command wsl.exe -ErrorAction SilentlyContinue
if (-not $wslCommand) {
    Write-Host "WSL nao esta disponivel neste sistema." -ForegroundColor Red
    exit 1
}

# 2. Verifica se as features do Windows estão habilitadas
$wslFeature = (Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux).State
$vmFeature  = (Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform).State
$isEnabled  = ($wslFeature -eq "Enabled" -and $vmFeature -eq "Enabled")

if (-not $isEnabled) {

    Write-Host "Voce nao possui WSL habilitado deseja habilitar o WSL agora? (S/N)" -ForegroundColor Yellow
    $response = Read-Host
    if ($response -notmatch '^(S|s|Sim|sim)$') {
        Write-Host "A instalacao sera interrompida. WSL e um pre-requisito obrigatorio, inicie o processo novamente se quiser instalar o EduEdu+" -ForegroundColor Yellow
        exit 0
    }
    Write-Host "Instalando recursos necessarios..." -ForegroundColor Yellow

    Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart -All | Out-Null
    Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart -All | Out-Null
    Start-Process "wsl.exe" -ArgumentList "--update" -Wait
    Start-Process "wsl.exe" -ArgumentList "--install --no-distribution" -Wait
    $needsReboot = $true
    [void]($isEnabled = $true)
}
else {
    Write-Host "WSL OK" -ForegroundColor Green
}


# Avisa da reinicialização
if ($needsReboot) {
    Write-Host "E necessario reiniciar o computador para concluir a configuracao do WSL." -ForegroundColor Yellow
    Write-Host "Deseja reiniciar agora? (S/N)" -ForegroundColor Yellow
    $response = Read-Host
    if ($response -match '^(S|s|Sim|sim)$') {
        Write-Host "Reiniciando o computador..." -ForegroundColor Green
        Restart-Computer -Force
    } else {
        Write-Host "Por favor, reinicie o computador manualmente mais tarde para concluir a configuracao do WSL." -ForegroundColor Yellow
        exit 0
    }
}   


