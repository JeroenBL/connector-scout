<#
.SYNOPSIS
    Summarises an OpenAPI/Swagger spec (JSON or YAML) per endpoint, or expands one route in detail.

.DESCRIPTION
    Digest mode:  one line per operation, optionally filtered by -Keyword and -Method.
    Detail mode:  -Route with one -Method per route; prints the operation with all $refs expanded.
    Output is text for the AI to read; this script writes no JSON result.
    Standalone: needs only PowerShell 7 (plus the powershell-yaml module for YAML specs).

    -OutFile writes the output to a file (UTF-8) and prints only a one-line summary, for long digests.
    Comma lists also work as one string ("user,account"), so the script can be called with pwsh -File.

.EXAMPLE
    ./tools/spec-digest.ps1 -SpecPath specs/ACME/ACME.yaml -Keyword user,account
    ./tools/spec-digest.ps1 -SpecPath specs/ACME/ACME.yaml -Route /oauth/token -Method POST
    pwsh -NoProfile -File ./tools/spec-digest.ps1 -SpecPath specs/ACME/ACME.yaml -OutFile digest.txt
#>
param(
    [Parameter(Mandatory)][string]$SpecPath,
    [string[]]$Keyword,
    [string[]]$Route,
    [string[]]$Method,
    [string]$OutFile,
    [switch]$Info
)

# pwsh -File passes "a,b" as one string: split it, so both call styles behave the same
$Keyword = @($Keyword | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$Method = @($Method | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$Route = @($Route | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })

$raw = Get-Content $SpecPath -Raw
if ($SpecPath -match '\.ya?ml$') {
    if (-not (Get-Module -ListAvailable powershell-yaml)) {
        throw 'The powershell-yaml module is required for YAML specs. Install it with: Install-Module powershell-yaml -Scope CurrentUser'
    }
    Import-Module powershell-yaml
    $spec = $raw | ConvertFrom-Yaml | ConvertTo-Json -Depth 100 | ConvertFrom-Json
} else {
    $spec = $raw | ConvertFrom-Json
}

# -Info: just the spec's identity, so the caller can name the target from it
if ($Info) {
    "title: $($spec.info.title)"
    "version: $($spec.info.version)"
    "server: $(@($spec.servers.url, $spec.host) | Where-Object { $_ } | Select-Object -First 1)"
    return
}

function Resolve-Pointer($ref, $spec) {
    $t = $spec
    foreach ($p in ($ref -replace '^#/', '' -split '/')) {
        $p = $p -replace '~1', '/' -replace '~0', '~'
        $t = $t.$p
    }
    $t
}

# Full expansion of $refs (detail mode)
function Expand-Refs($node, $spec, $depth = 0, $seen = @()) {
    if ($null -eq $node) { return $null }
    if ($depth -gt 5) { return '<max depth>' }

    if ($node -is [System.Management.Automation.PSCustomObject]) {
        if ($node.'$ref') {
            if ($seen -contains $node.'$ref') {
                return "<circular $($node.'$ref')>"
            }
            return Expand-Refs (Resolve-Pointer $node.'$ref' $spec) $spec ($depth + 1) ($seen + $node.'$ref')
        }

        $o = [ordered]@{}
        foreach ($p in $node.PSObject.Properties) {
            $o[$p.Name] = Expand-Refs $p.Value $spec $depth $seen
        }
        return $o
    }

    if ($node -is [System.Collections.IEnumerable] -and $node -isnot [string]) {
        return @($node | ForEach-Object { Expand-Refs $_ $spec $depth $seen })
    }

    $node
}

# Top-level field names only (digest mode)
function Get-Fields($node, $spec, $seen = @()) {
    if ($null -eq $node) { return @() }

    if ($node.'$ref') {
        if ($seen -contains $node.'$ref') { return @() }
        return Get-Fields (Resolve-Pointer $node.'$ref' $spec) $spec ($seen + $node.'$ref')
    }

    if ($node.type -eq 'array' -and $node.items) {
        return Get-Fields $node.items $spec $seen
    }

    $fields = @()
    foreach ($s in @($node.allOf)) {
        if ($s) { $fields += Get-Fields $s $spec $seen }
    }

    if ($node.properties) {
        foreach ($p in $node.properties.PSObject.Properties) {
            $star = if ($node.required -contains $p.Name) { '*' } else { '' }
            $fields += "$($p.Name)$star"
        }
    }

    $fields
}

function Get-BodySchema($op) {
    if ($op.requestBody) {
        return $op.requestBody.content.'application/json'.schema
    }

    ($op.parameters | Where-Object { $_.in -eq 'body' } | Select-Object -First 1).schema
}

function Get-ResponseSchema($op) {
    foreach ($code in '200', '201') {
        $r = $op.responses.$code
        if ($r) {
            if ($r.content) {
                return $r.content.'application/json'.schema
            } else {
                return $r.schema
            }
        }
    }
}

$run = {
# Normalize methods so filtering is case-insensitive.
$methods = @()
if ($Method) {
    $methods = @($Method | Where-Object { $null -ne $_ } | ForEach-Object { $_.ToLowerInvariant() })
}

# Detail mode: one or more -Route / -Method pairs, matched by position.
# Supports exact routes, wildcards such as */Users/{identifier},
# and suffixes such as Users or Users/{identifier}.
if ($Route) {
    if (-not $Method -or $Route.Count -ne $Method.Count) {
        throw "Provide exactly one -Method value per -Route value (same count, same order). Got $($Route.Count) route(s) and $(@($Method).Count) method(s)."
    }

    for ($i = 0; $i -lt $Route.Count; $i++) {
        $r = $Route[$i]
        $m = $methods[$i]

        # Git Bash rewrites /api/x into C:/Program Files/Git/api/x: map it back to the longest spec path it ends with
        if ($r -match '^[A-Za-z]:[\\/]') {
            $norm = $r -replace '\\', '/'
            $orig = $spec.paths.PSObject.Properties.Name |
                Where-Object { $norm.EndsWith($_, [System.StringComparison]::OrdinalIgnoreCase) } |
                Sort-Object Length -Descending | Select-Object -First 1
            if ($orig) {
                Write-Warning "Route '$r' looks rewritten by Git Bash; using '$orig'"
                $r = $orig
            }
        }

        $pathProps = @()

        # Exact route takes precedence.
        $exactPath = $spec.paths.PSObject.Properties[$r]

        if ($exactPath) {
            $pathProps = @($exactPath)
        } elseif ($r -match '[*?]') {
            # Wildcard route, e.g. */Users/{identifier}
            $pathProps = @(
                $spec.paths.PSObject.Properties |
                    Where-Object { $_.Name -like $r }
            )
        } elseif ($r.StartsWith('/')) {
            # Slash-prefixed route.
            $pathProps = @(
                $spec.paths.PSObject.Properties |
                    Where-Object { $_.Name -like $r }
            )
        } else {
            # Suffix match, e.g. Users or Users/{identifier}.
            $suffix = '/' + $r.Trim('/')
            $pathProps = @(
                $spec.paths.PSObject.Properties |
                    Where-Object {
                        $_.Name.TrimEnd('/').EndsWith(
                            $suffix,
                            [System.StringComparison]::OrdinalIgnoreCase
                        )
                    }
            )
        }

        if (-not $pathProps) {
            Write-Warning "Route not found in spec: $r"
            continue
        }

        $found = $false

        foreach ($pathProp in $pathProps) {
            $opProp = $pathProp.Value.PSObject.Properties[$m]

            if (-not $opProp) {
                continue
            }

            $found = $true
            "--- $($m.ToUpperInvariant()) $($pathProp.Name) ---"
            Expand-Refs $opProp.Value $spec | ConvertTo-Json -Depth 20
        }

        if (-not $found) {
            Write-Warning "Method '$m' not found for matching route(s): $r"
        }
    }

    return
}

# Digest mode
$verbs = 'get', 'post', 'put', 'patch', 'delete'

foreach ($pathItem in $spec.paths.PSObject.Properties) {
    foreach ($m in $pathItem.Value.PSObject.Properties | Where-Object {
        $_.Name -in $verbs -and
        (-not $methods -or $_.Name -in $methods)
    }) {
        $op = $m.Value

        $params = @($pathItem.Value.parameters) + @($op.parameters) |
            Where-Object { $_ -and $_.in -in 'path', 'query' } |
            ForEach-Object { "$($_.in):$($_.name)" }

        $body = (Get-Fields (Get-BodySchema $op) $spec | Select-Object -First 12) -join ','
        $resp = (Get-Fields (Get-ResponseSchema $op) $spec | Select-Object -First 12) -join ','

        $line = '{0,-6} {1} | tags:{2} | params:{3} | body:{4} | resp:{5} | "{6}"' -f `
            $m.Name.ToUpperInvariant(), $pathItem.Name, ($op.tags -join ','), ($params -join ','), $body, $resp, $op.summary

        if (-not $Keyword -or ($Keyword | Where-Object { $line -match [regex]::Escape($_) })) {
            $line
        }
    }
}

# Security info, so auth can be cross-checked against the human-supplied auth type.
'--- security ---'
($spec.components.securitySchemes, $spec.securityDefinitions | Where-Object { $_ }) | ConvertTo-Json -Depth 6
}

if ($OutFile) {
    $lines = @(& $run)
    $dir = Split-Path -Parent $OutFile
    if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $lines | Out-File -LiteralPath $OutFile -Encoding utf8
    "Wrote $($lines.Count) lines to $((Resolve-Path -LiteralPath $OutFile).Path)"
} else {
    & $run
}