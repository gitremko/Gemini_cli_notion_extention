Param(
  [int]$TopN = 5
)

$ErrorActionPreference = 'Stop'

function Get-EnvOrThrow($name) {
  $val = [Environment]::GetEnvironmentVariable($name, 'Process')
  if (-not $val) { $val = [Environment]::GetEnvironmentVariable($name, 'User') }
  if (-not $val) { $val = [Environment]::GetEnvironmentVariable($name, 'Machine') }
  if (-not $val) { throw "Missing environment variable: $name" }
  return $val
}

function Get-NotionGuidelinesText {
  $token = Get-EnvOrThrow 'NOTION_API_KEY'
  $pageId = [Environment]::GetEnvironmentVariable('NOTION_GUIDELINES_PAGE_ID','Process')
  if (-not $pageId) { $pageId = [Environment]::GetEnvironmentVariable('NOTION_GUIDELINES_PAGE_ID','User') }
  if (-not $pageId) { $pageId = [Environment]::GetEnvironmentVariable('NOTION_GUIDELINES_PAGE_ID','Machine') }

  if (-not $pageId) {
    # Fallback: search by title
    $q = 'gemini-cli-wordpress-artikel-richtlijnen'
    $searchBody = @{ query = $q } | ConvertTo-Json
    $resp = Invoke-RestMethod -Method Post -Uri 'https://api.notion.com/v1/search' -Headers @{ 'Authorization' = "Bearer $token"; 'Notion-Version' = '2022-06-28'; 'Content-Type' = 'application/json' } -Body $searchBody
    $pageId = ($resp.results | Where-Object { $_.object -eq 'page' } | Select-Object -First 1).id
    if (-not $pageId) { throw 'Notion page not found for guidelines.' }
  }

  $blocks = Invoke-RestMethod -Method Get -Uri ("https://api.notion.com/v1/blocks/{0}/children?page_size=100" -f $pageId) -Headers @{ 'Authorization' = "Bearer $token"; 'Notion-Version' = '2022-06-28' }
  $sb = New-Object System.Text.StringBuilder
  foreach ($b in $blocks.results) {
    switch ($b.type) {
      'paragraph' { $text = ($b.paragraph.rich_text | ForEach-Object { $_.plain_text }) -join '' ; if ($text) { [void]$sb.AppendLine($text) } }
      { $_ -like 'heading_*' } { $key = $b.type; $text = ($b.$key.rich_text | ForEach-Object { $_.plain_text }) -join ''; if ($text) { [void]$sb.AppendLine("# $text") } }
      default { }
    }
  }
  return $sb.ToString().Trim()
}

function Get-FutureToolsUrls {
  $html = Invoke-WebRequest -UseBasicParsing -Uri 'https://www.futuretools.io/newly-added'
  $content = $html.Content
  $matches = Select-String -InputObject $content -Pattern 'href=\"(/tool[s]?/[^\"#?]+)\"' -AllMatches | ForEach-Object { $_.Matches } | ForEach-Object { $_.Groups[1].Value }
  $urls = @()
  foreach ($m in $matches) {
    $u = "https://www.futuretools.io$m"
    if (-not ($urls -contains $u)) { $urls += $u }
  }
  return $urls | Select-Object -First $TopN
}

function Invoke-GeminiGenerate([string]$guidelines, [string[]]$toolUrls) {
  $gemini = 'gemini'
  $logsDir = Join-Path $PSScriptRoot 'logs'
  New-Item -ItemType Directory -Force -Path $logsDir | Out-Null
  $ts = Get-Date -Format 'yyyyMMdd_HHmmss'
  $prompt = @"
You are an autonomous content writer. Follow the provided editorial guidelines exactly. For each tool URL, research using the open web (use web_search and web_fetch if available) and write a standalone WordPress article in Dutch with:
- Title
- Excerpt (1–2 sentences)
- Body HTML (h2/h3, bullet lists, code snippets if relevant). Avoid first-person. Be factual.
- Tags (3–6)

Constraints:
- No questions to the user; make reasonable assumptions.
- Cite sources as a References section with links.
- Each article should target 600–900 words.

Guidelines:
${guidelines}

Tool URLs:
${($toolUrls -join "`n")}

Output strict JSON with this schema:
{
  "posts": [
    {
      "title": "...",
      "excerpt": "...",
      "content_html": "...",
      "tags": ["..."]
    }
  ]
}
"@

  $promptFile = Join-Path $logsDir ("rest_prompt_${ts}.txt")
  Set-Content -Encoding UTF8 -Path $promptFile -Value $prompt
  $outFile = Join-Path $logsDir ("rest_generated_${ts}.json")
  & $gemini -y -m gemini-2.5-flash -p (Get-Content -Raw $promptFile) --output-format json > $outFile
  if ($LASTEXITCODE -ne 0) { throw "Gemini CLI failed with exit code $LASTEXITCODE (primary). See $outFile and $promptFile" }
  $raw = Get-Content $outFile -Raw
  try {
    $parsed = $raw | ConvertFrom-Json -ErrorAction Stop
  } catch {
    $strict = $prompt + "`n`nIMPORTANT: Output ONLY valid JSON per the schema above. No markdown, no prose, no backticks."
    $promptFile2 = Join-Path $logsDir ("rest_prompt_${ts}_retry.txt")
    Set-Content -Encoding UTF8 -Path $promptFile2 -Value $strict
    $outFile2 = Join-Path $logsDir ("rest_generated_${ts}_retry.json")
    & $gemini -y -m gemini-1.5-flash -p (Get-Content -Raw $promptFile2) --output-format json > $outFile2
    if ($LASTEXITCODE -ne 0) { throw "Gemini CLI failed with exit code $LASTEXITCODE (retry). See $outFile2 and $promptFile2" }
    $raw = Get-Content $outFile2 -Raw
    try { $parsed = $raw | ConvertFrom-Json -ErrorAction Stop } catch { throw "Gemini returned non-JSON. See $outFile2 and $promptFile2" }
  }
  if (-not $parsed.posts -or $parsed.posts.Count -eq 0) { throw "Gemini returned no posts. See outputs in $logsDir" }
  return $parsed
}

function Publish-WordPress($posts) {
  $wpBase = Get-EnvOrThrow 'WP_BASE_URL' # e.g. https://example.com
  $wpUser = Get-EnvOrThrow 'WP_USER'
  $wpAppPass = Get-EnvOrThrow 'WP_APP_PASSWORD'
  $auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$wpUser`:$wpAppPass"))
  foreach ($p in $posts) {
    $body = @{ title = $p.title; excerpt = $p.excerpt; status = 'publish'; content = $p.content_html } |
      ConvertTo-Json -Depth 10
    $resp = Invoke-RestMethod -Method Post -Uri ("{0}/wp-json/wp/v2/posts" -f $wpBase) -Headers @{ Authorization = "Basic $auth"; 'Content-Type' = 'application/json' } -Body $body
    Write-Host ("Published: {0} -> {1}" -f $resp.title.rendered, $resp.link)
  }
}

try {
  $guidelines = Get-NotionGuidelinesText
  $urls = Get-FutureToolsUrls
  if (-not $urls -or $urls.Count -eq 0) { throw 'No tool URLs found on FutureTools newly-added.' }
  $result = Invoke-GeminiGenerate -guidelines $guidelines -toolUrls $urls
  if (-not $result.posts) { throw 'Gemini did not return posts' }
  Publish-WordPress -posts $result.posts
} catch {
  Write-Error $_
  exit 1
}
