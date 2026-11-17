# Starts PostgreSQL 17 for DentaCloud
$dataDir = "C:\Program Files\PostgreSQL\17\data"
$pgCtl = "C:\Program Files\PostgreSQL\17\bin\pg_ctl.exe"
$psql = "C:\Program Files\PostgreSQL\17\bin\psql.exe"

Write-Host "Checking PostgreSQL on port 5432..." -ForegroundColor Cyan
$socket = New-Object System.Net.Sockets.TcpClient
$connected = $false
try {
    $socket.Connect("127.0.0.1", 5432)
    $connected = $true
    $socket.Close()
} catch {}

if ($connected) {
    Write-Host "PostgreSQL is already running on port 5432." -ForegroundColor Green
} else {
    Write-Host "Starting PostgreSQL server..." -ForegroundColor Yellow
    & $pgCtl start -D $dataDir
    Start-Sleep -Seconds 2
}

# Verify database connection
& $psql -U dentacloud_app -h 127.0.0.1 -d dentacloud -c "SELECT current_user, current_database(), version();"

