Write-Host "=== Verificando se o WinGet está instalado ===" -ForegroundColor Cyan

# Testa se o winget existe
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host "WinGet não encontrado. Tentando registrar o App Installer..." -ForegroundColor Yellow
    
    try {
        Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe
        Write-Host "Registro solicitado. Aguardando 10 segundos..." -ForegroundColor Gray
        Start-Sleep -Seconds 10
    }
    catch {
        Write-Host "Erro ao tentar registrar o WinGet. Verifique se o App Installer está instalado pela Microsoft Store." -ForegroundColor Red
        exit 1
    }

    # Verifica novamente
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Host "WinGet ainda não está disponível. Reinicie o sistema ou abra a Microsoft Store." -ForegroundColor Red
        exit 1
    }
}

Write-Host "=== Instalando Git via WinGet ===" -ForegroundColor Cyan
winget install --id Git.Git -e --source winget

Write-Host "=== Instalação concluída! ===" -ForegroundColor Green

# Mantém a janela aberta até que o usuário pressione uma tecla
Write-Host "`nPressione qualquer tecla para sair..."
[void][System.Console]::ReadKey($true)