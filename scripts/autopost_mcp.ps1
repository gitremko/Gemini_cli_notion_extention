Param(
  [int]$TopN = 5,
  [string]$GuidelinesPageTitle = 'gemini-cli-wordpress-artikel-richtlijnen',
  [string]$Model = 'gemini-2.5-flash',
  [string[]]$FallbackModels = @('gemini-1.5-flash','gemini-1.5-flash-8b'),
  [string]$AllowExtensions = 'not used',
  [switch]$Yolo,
  [switch]$PrintCommand
)

$ErrorActionPreference = 'Stop'

$prompt = @"
Act as an autonomous agent with access to MCP tools (Notion, WordPress, web_fetch, web_search). Do not ask questions. Proceed end-to-end.

Authoring policy:
- Read editorial guidelines from the Notion page with title "${GuidelinesPageTitle}" and FOLLOW THEM STRICTLY.
- Do not impose any additional rules (length, tone, structure, tags, images) beyond what the guidelines state.
- If guidelines specify word counts, headings, tags, or references, use exactly that. Otherwise, use reasonable defaults.
 - Do NOT use any local filesystem tools such as read_file; you must rely only on MCP tools (Notion, WordPress, web_fetch, web_search) and your own context.

Tasks:
1) Fetch guidelines from Notion (search by exact title; if multiple, pick best match) and extract readable text.
2) Parse https://www.futuretools.io/newly-added to collect the latest ${TopN} unique tool links (use web_fetch).
3) For each candidate tool, first check for duplicates in WordPress:
   - List/search existing posts via WordPress MCP; look for titles that contain the tool name or URL slug.
   - If a matching post already exists, SKIP this tool and proceed to the next.
   - Optionally maintain/consult a Notion log/database of processed tools (by canonical URL) to avoid re-posting.
4) For non-duplicates only: research with web_search + web_fetch (≥ 3 reputable sources when feasible). Summarize features, use cases, pricing, pros/cons, comparisons per the guidelines.
5) Write a Dutch WordPress article per non-duplicate tool, formatted per the guidelines (title/excerpt/body/tags/images/references only if guidelines require them).
6) Publish each article via the WordPress MCP tools (status=publish). If a capability (e.g., tags) is unsupported, publish without it.

Execution rules:
- Fully autonomous; never ask for input. Retry failed tool calls with reasonable alternatives.
- Log concise progress updates as assistant messages.

Implementation hints (you must list tools to find exact names):
- Notion: search by page title, read blocks → plain text guidelines.
- FutureTools: web_fetch the listing page; extract tool detail links; de-duplicate; cap at ${TopN}.
- Research: web_search "<tool name> review | pricing | comparison" and web_fetch sources.
- WordPress: use the available post-create/publish tool; set title/excerpt/content; include tags/images only if guidelines specify.

Deliverable:
- Publish the posts. Then provide a final assistant message listing the published titles + URLs, and which tools were skipped because an article already exists.
"@

# Run Gemini CLI headless with robust logging
$logsDir = Join-Path $PSScriptRoot 'logs'
New-Item -ItemType Directory -Force -Path $logsDir | Out-Null
$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$promptFile = Join-Path $logsDir "prompt_$timestamp.txt"
Set-Content -Encoding UTF8 -Path $promptFile -Value $prompt
# Read prompt text to pass as actual -p content (not as a file path)
$promptText = Get-Content -Raw -Encoding UTF8 -Path $promptFile
# Escape embedded quotes for command line
$promptEsc = $promptText -replace '"','\"'

$outFile = Join-Path $logsDir "gemini_$timestamp.out.log"
$errFile = Join-Path $logsDir "gemini_$timestamp.err.log"

$geminiCmd = Get-Command gemini -ErrorAction SilentlyContinue
if ($null -eq $geminiCmd) { throw "Gemini CLI 'gemini' not found in PATH. Open a new terminal after installing, or provide full path." }
$geminiPath = $geminiCmd.Path

# Use cmd.exe to execute the shim (.cmd/.ps1/.exe agnostic) and redirect to files
function Invoke-GeminiOnce([string]$cmd, [string]$stdoutPath, [string]$stderrPath) {
  # Force the working directory to the user profile so MCP approvals persist and match
  $wd = $env:USERPROFILE
  $p = Start-Process -FilePath $env:ComSpec -ArgumentList '/c', $cmd -PassThru -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath -WindowStyle Hidden -WorkingDirectory $wd
  $p.WaitForExit()
  return $p.ExitCode
}

function Invoke-GeminiWithFallbacks([string]$promptContentEscaped, [string]$primaryModel, [string[]]$fallbacks, [string]$stdoutPath, [string]$stderrPath) {
  $attempts = @()
  if ([string]::IsNullOrWhiteSpace($primaryModel)) { $attempts += @('') } else { $attempts += @($primaryModel) }
  if ($fallbacks) { $attempts += $fallbacks }
  $i = 0
  if ($PrintCommand) {
    Write-Host "WorkingDirectory: $($env:USERPROFILE)" -ForegroundColor DarkCyan
    Write-Host "Prompt file: $promptFile" -ForegroundColor DarkGray
    Write-Host "----- PROMPT BEGIN -----" -ForegroundColor DarkGray
    Write-Host $promptText
    Write-Host "----- PROMPT END -----" -ForegroundColor DarkGray
  }
  foreach ($m in $attempts) {
    $i++
    $label = ("attempt {0}/{1}" -f $i, $attempts.Count)
    if ([string]::IsNullOrWhiteSpace($m)) {
      Write-Host "Running with default model ($label)" -ForegroundColor Cyan
      $yArg = if ($Yolo) { ' -y' } else { '' }
      $cmd = "gemini$yArg -p `"$promptContentEscaped`""
    } else {
      Write-Host ("Running with model '{0}' ({1})" -f $m, $label) -ForegroundColor Cyan
      $yArg = if ($Yolo) { ' -y' } else { '' }
      $cmd = "gemini$yArg -m $m -p `"$promptContentEscaped`""
    }
    if ($PrintCommand) { Write-Host "Command: $cmd" -ForegroundColor Yellow }
    $code = Invoke-GeminiOnce -cmd $cmd -stdoutPath $stdoutPath -stderrPath $stderrPath
    if ($code -eq 0) { return 0 }
    $errTail = (Get-Content $stderrPath -ErrorAction SilentlyContinue | Select-Object -Last 50) -join "`n"
    $isQuota = $errTail -match 'Quota exceeded' -or $errTail -match '429'
    if (-not $isQuota) {
      Write-Warning "Gemini failed (non-quota). See logs: $stdoutPath, $stderrPath"
      return $code
    }
    $currModelName = if ([string]::IsNullOrWhiteSpace($m)) { 'default' } else { $m }
    Write-Warning ("Quota 429 on model '{0}'. Trying next..." -f $currModelName)
    # rotate log file names so the last attempt logs don't overwrite previous
    $stdoutPath = $stdoutPath -replace '\.out\.log$', ('.{0}.out.log' -f $i)
    $stderrPath = $stderrPath -replace '\.err\.log$', ('.{0}.err.log' -f $i)
  }
  return 1
}

$exit = Invoke-GeminiWithFallbacks -promptContentEscaped $promptEsc -primaryModel $Model -fallbacks $FallbackModels -stdoutPath $outFile -stderrPath $errFile
if ($exit -ne 0) {
  throw "Gemini CLI failed after model fallbacks. See logs in $logsDir. Prompt: $promptFile"
}
