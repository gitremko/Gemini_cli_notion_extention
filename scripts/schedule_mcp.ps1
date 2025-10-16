Param(
  [string]$Time = '06:00',
  [int]$TopN = 5,
  [string]$GuidelinesPageTitle = 'gemini-cli-wordpress-artikel-richtlijnen',
  [string]$Model = 'gemini-2.5-flash',
  [switch]$Yolo
)

$taskName = 'GeminiAutoWordPress_MCP'
$scriptPath = Join-Path $PSScriptRoot 'autopost_mcp.ps1'
if (-not (Test-Path $scriptPath)) { throw "Script not found: $scriptPath" }

$modelArg = ''
if ($Model -and $Model.Trim()) { $modelArg = " -Model `"$Model`"" }
$yArg = if ($Yolo) { ' -Yolo' } else { '' }
$escaped = "powershell -ExecutionPolicy Bypass -File `"$scriptPath`" -TopN $TopN -GuidelinesPageTitle `"$GuidelinesPageTitle`"$modelArg$yArg"
schtasks /Create /SC DAILY /TN $taskName /TR $escaped /ST $Time /F | Out-Null
Write-Host "Scheduled task '$taskName' created to run daily at $Time"
