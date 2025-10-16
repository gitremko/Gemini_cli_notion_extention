Param(
  [string]$Time = '06:00'
)

$taskName = 'GeminiAutoWordPress'
$scriptPath = Join-Path $PSScriptRoot 'autopost.ps1'

if (-not (Test-Path $scriptPath)) { throw "Script not found: $scriptPath" }

schtasks /Create /SC DAILY /TN $taskName /TR "powershell -ExecutionPolicy Bypass -File `"$scriptPath`"" /ST $Time /F | Out-Null
Write-Host "Scheduled task '$taskName' created to run daily at $Time"

