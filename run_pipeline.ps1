param(
  [string]$Db     = "olist",
  [string]$DbUser = "postgres",
  [string]$DbHost = "localhost",
  [int]   $Port   = 5432,
  [string]$Psql   = "C:\Program Files\PostgreSQL\18\bin\psql.exe"
)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot   # run from the repo root so relative paths work

if (-not (Test-Path $Psql)) { throw "psql not found at $Psql. Pass -Psql with the right path." }

if (-not $env:PGPASSWORD) {
  $secure = Read-Host "Postgres password" -AsSecureString
  $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
  $env:PGPASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
}

$files = Get-ChildItem sql -Recurse -Filter *.sql | Sort-Object FullName
$timer = [Diagnostics.Stopwatch]::StartNew()

foreach ($f in $files) {
  $rel = Resolve-Path -Relative $f.FullName
  Write-Host "==> $rel"
  & $Psql -h $DbHost -p $Port -U $DbUser -d $Db -v ON_ERROR_STOP=1 -q -f $f.FullName
  if ($LASTEXITCODE -ne 0) { throw "Pipeline failed at $rel" }
}

Write-Host "Row counts:"
& $Psql -h $DbHost -p $Port -U $DbUser -d $Db -c "SELECT 'dim_seller' AS tbl, count(*) FROM dwh.dim_seller UNION ALL SELECT 'fact_order_items', count(*) FROM dwh.fact_order_items;"

Write-Host "Pipeline finished in $([int]$timer.Elapsed.TotalSeconds) seconds."