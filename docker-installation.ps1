Write-Host "Instalando Docker via WinGet..." -ForegroundColor Yellow

# Executa o winget de forma síncrona (espera terminar)
Start-Process winget -ArgumentList "install -e --id Docker.DockerDesktop --accept-source-agreements --accept-package-agreements" -Wait

Write-Host "Instalação concluída!" -ForegroundColor Green

# Configura Docker Desktop para iniciar junto com o Windows
Write-Host "Configurando Docker para iniciar com o Windows..." -ForegroundColor Yellow
$startupPath = [System.Environment]::GetFolderPath("Startup")
$dockerShortcut = Join-Path $startupPath "Docker Desktop.lnk"

if (-Not (Test-Path $dockerShortcut)) {
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($dockerShortcut)
    $shortcut.TargetPath = "C:\Program Files\Docker\Docker\Docker Desktop.exe"
    $shortcut.WorkingDirectory = "C:\Program Files\Docker\Docker\"
    $shortcut.WindowStyle = 1
    $shortcut.Description = "Inicia o Docker Desktop junto com o Windows"
    $shortcut.Save()
    Write-Host "Atalho adicionado à pasta de Inicialização (Startup)" -ForegroundColor Green
} else {
    Write-Host "Docker já está configurado para iniciar com o Windows." -ForegroundColor DarkYellow
}

# Inicia o Docker Desktop imediatamente
Write-Host "Iniciando Docker Desktop..." -ForegroundColor Yellow
Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"
