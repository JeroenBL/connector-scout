<#
.SYNOPSIS
    Prepares a scout run in the working folder: creates reports/, reports/.scout/ and reports/history/,
    copies the report viewer to reports/report-viewer.html, hashes the spec, and copies an earlier report to reports/history/ before it is replaced.
.DESCRIPTION
    Prints one JSON object with what the report needs: spec (relative path or URL), specSha256,
    specLastModified, and the earlier report's frontmatter values, whether the spec changed since,
    and where the earlier report was archived.
    Run it once, at the start of the run. A second run doesn't archive the same report twice.
.EXAMPLE
    pwsh -NoProfile -File <skill>/scripts/prepare-run.ps1 -Target Example -Spec Example.yaml
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Target,
    [Parameter(Mandatory)][string]$Spec,
    [string]$WorkingFolder = (Get-Location).Path
)
$ErrorActionPreference = 'Stop'

$WorkingFolder = (Resolve-Path -LiteralPath $WorkingFolder).Path
$reports = Join-Path $WorkingFolder 'reports'
foreach ($d in $reports, (Join-Path $reports '.scout'), (Join-Path $reports 'history')) {
    if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Path $d | Out-Null }
}
# the viewer is static: it loads a report by file picker, drag-and-drop or paste
Copy-Item -LiteralPath (Join-Path $PSScriptRoot '..\report-viewer.html') -Destination (Join-Path $reports 'report-viewer.html') -Force

$out = [ordered]@{ target = $Target; spec = $null; specSha256 = $null; specLastModified = $null; earlierReport = $null }

if ($Spec -match '^https?://') {
    $out.spec = $Spec
} else {
    $specPath = if ([IO.Path]::IsPathRooted($Spec)) { $Spec } else { Join-Path $WorkingFolder $Spec }
    if (-not (Test-Path -LiteralPath $specPath -PathType Leaf)) { throw "Spec file not found: $specPath" }
    $item = Get-Item -LiteralPath $specPath
    # the report's spec path is relative to the working folder when the spec lives inside it
    $rel = [IO.Path]::GetRelativePath($WorkingFolder, $item.FullName)
    $out.spec = if ($rel.StartsWith('..') -or [IO.Path]::IsPathRooted($rel)) { $item.FullName -replace '\\', '/' } else { $rel -replace '\\', '/' }
    $out.specSha256 = (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash.ToLower()
    $out.specLastModified = $item.LastWriteTime.ToString('yyyy-MM-dd')
}

$reportPath = Join-Path $reports "$Target-feasibility.md"
if (Test-Path -LiteralPath $reportPath) {
    $text = [IO.File]::ReadAllText($reportPath, [Text.Encoding]::UTF8)
    $fm = [regex]::Match($text, '\A---\r?\n(.*?)\r?\n---', 'Singleline').Groups[1].Value
    function Get-Field($name) {
        $m = [regex]::Match($fm, "(?m)^${name}:\s*[`"']?([^`"'\r\n]*)[`"']?\s*$")
        if ($m.Success -and $m.Groups[1].Value -notin '', 'null', '~') { $m.Groups[1].Value } else { $null }
    }
    $earlier = [ordered]@{
        path = "reports/$Target-feasibility.md"
        reportDate = Get-Field 'reportDate'
        spec = Get-Field 'spec'
        specSha256 = Get-Field 'specSha256'
        verdict = Get-Field 'verdict'
        confidence = Get-Field 'confidence'
        specChanged = $null
        archivedTo = $null
    }
    $earlier.specChanged = if ($out.specSha256) { $earlier.specSha256 -ne $out.specSha256 } else { $earlier.spec -ne $out.spec }

    # copy to history, unless this exact report is already there
    $hash = (Get-FileHash -LiteralPath $reportPath -Algorithm SHA256).Hash
    $history = Join-Path $reports 'history'
    $same = Get-ChildItem -LiteralPath $history -Filter "$Target-feasibility-*.md" -File |
        Where-Object { (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash -eq $hash } | Select-Object -First 1
    if ($same) {
        $earlier.archivedTo = "reports/history/$($same.Name)"
    } else {
        $date = if ($earlier.reportDate) { $earlier.reportDate } else { (Get-Item -LiteralPath $reportPath).LastWriteTime.ToString('yyyy-MM-dd') }
        $name = "$Target-feasibility-$date.md"; $n = 2
        while (Test-Path -LiteralPath (Join-Path $history $name)) { $name = "$Target-feasibility-$date-$n.md"; $n++ }
        Copy-Item -LiteralPath $reportPath -Destination (Join-Path $history $name)
        $earlier.archivedTo = "reports/history/$name"
    }
    $out.earlierReport = $earlier
}

$out | ConvertTo-Json -Depth 5
