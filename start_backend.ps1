# Starts DentaCloud Spring Boot Backend on Port 8095
$java = "C:\Program Files\Java\jdk-22\bin\java.exe"
$jarPath = "C:\Users\sujan\Downloads\Dentacloud-main\Dentacloud-main\backend\build\libs\backend-0.1.0.jar"

if (-not (Test-Path $jarPath)) {
    Write-Host "Building backend jar..." -ForegroundColor Yellow
    $env:JAVA_HOME = "C:\Program Files\Java\jdk-22"
    Push-Location "C:\Users\sujan\Downloads\Dentacloud-main\Dentacloud-main"
    .\gradlew.bat :backend:bootJar --console=plain
    Pop-Location
}

Write-Host "Starting DentaCloud Backend on port 8095..." -ForegroundColor Cyan
& $java -Xmx1536m -jar $jarPath --server.port=8095

