Param(
  [int]$TopN = 5,
  [string]$GuidelinesPageTitle = 'gemini-cli-wordpress-artikel-richtlijnen',
  [string]$Model = 'gemini-2.5-flash',
  [switch]$Yolo,
  [switch]$PrintCommand
)

$ErrorActionPreference = 'Stop'

# Build a single here-string prompt that drives MCP tools end-to-end.
$prompt = @"
Begin nu, geen vragen. Je hebt toegang tot MCP-servers: notion, remkokoster-wordpress, web_fetch, google_web_search.
Volg deze stappen strikt en autonoom (geen vragen stellen):

1) Richtlijnen ophalen uit Notion
   - Zoek de pagina met exacte titel: "$GuidelinesPageTitle" via notion_search.
   - Neem de best-match, haal de blokken op via notion_list_blocks, en construeer leesbare tekst.

2) FutureTools newly-added ophalen
   - Gebruik web_fetch op https://www.futuretools.io/newly-added.
   - Extraheer de meest recente $TopN unieke toollinks (vermijd duplicaten).

3) Duplicaat-check in WordPress
   - Gebruik remkokoster-wordpress (get_posts of search_site) om te controleren of er al posts bestaan met dezelfde toolnaam/slug.
   - Sla bestaande items over en ga door met de rest.

4) Onderzoek per tool (alleen niet-duplicaten)
   - Gebruik google_web_search + web_fetch om minimaal 3 betrouwbare bronnen op te halen.
   - Vat features, use-cases, pricing, voor-/nadelen en vergelijkingen samen.

5) Artikel schrijven en image maken volgens de Notion-richtlijnen (Nederlands)

6) Publiceren op WordPress
   - Maak per tool een post (create_post) met status=publish.
   - Zet tags/categorieën indien ondersteund; anders publiceren zonder.
   - Zet de image over en zet als featured image voor de bijbehorende post.

7) Rapporteren
   - Geef een korte lijst met gepubliceerde titels + URLs en welke tools zijn overgeslagen wegens duplicaten.

Constraints:
- Werk volledig autonoom en robuust; retry bij mislukte tool-calls.
- Geen lokale bestandslezing; gebruik alleen MCP-tools en context.
"@

# Logging + execution
$logsDir = Join-Path $PSScriptRoot 'logs'
New-Item -ItemType Directory -Force -Path $logsDir | Out-Null
$ts = Get-Date -Format 'yyyyMMdd_HHmmss'
$promptFile = Join-Path $logsDir ("mcp_simple_prompt_${ts}.txt")
Set-Content -Encoding UTF8 -Path $promptFile -Value $prompt

$outFile = Join-Path $logsDir ("mcp_simple_${ts}.out.log")
$errFile = Join-Path $logsDir ("mcp_simple_${ts}.err.log")

$gemini = 'gemini'

# Build argument array to avoid quoting issues and Windows cmdline limits
$args = @()
if ($Yolo) { $args += '-y' }
$args += @('-m', $Model, '-p', (Get-Content -Raw $promptFile))

if ($PrintCommand) {
  Write-Host "WorkingDirectory: $($env:USERPROFILE)" -ForegroundColor DarkCyan
  $joined = ($args | ForEach-Object { if($_ -match '\s') { '"' + $_ + '"' } else { $_ } }) -join ' '
  Write-Host "Command: gemini $joined" -ForegroundColor Yellow
  Write-Host "Prompt file: $promptFile" -ForegroundColor DarkGray
  Write-Host "----- PROMPT BEGIN -----" -ForegroundColor DarkGray
  Write-Host $prompt
  Write-Host "----- PROMPT END -----" -ForegroundColor DarkGray
}

# Run from the user profile so MCP approvals persist and match your interactive workspace.
Push-Location $env:USERPROFILE
& $gemini @args 1> $outFile 2> $errFile
$exit = $LASTEXITCODE
Pop-Location

Write-Host "Done. ExitCode=$exit" -ForegroundColor Cyan
Write-Host "Stdout: $outFile" -ForegroundColor DarkGray
Write-Host "Stderr: $errFile" -ForegroundColor DarkGray

if ($exit -ne 0) {
  Write-Warning "Headless run failed. Tail of stderr:"
  Get-Content $errFile -Last 50 | ForEach-Object { Write-Warning $_ }
  exit $exit
}
