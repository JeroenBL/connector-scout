# Connector conventions (HelloID PowerShell V2)

These rules apply to every generated connector, for every action (create,
update, enable, disable, delete). Action-specific implementation is
covered in §14–§16 of this same file — there are no separate
conventions-<action>.md files anymore.

Separately, docs/bestPractices.md holds team best
practices that go beyond strict rules (design judgement calls,
performance/scale considerations, when to escalate to a person). Read
both files before generating or reviewing any connector.

If a rule conflicts with the API spec, follow the rule and list the
conflict in your summary.

## 1. File structure

Every script follows this order:

1. Header comment: `HelloID-Conn-Prov-Target-<System>-<Action>` and `PowerShell V2`
2. TLS 1.2 line
3. `#region functions` (helpers only, no logic)
4. Main `try { ... } catch { ... }`

File names: `create.ps1`, `update.ps1`, `disable.ps1`, `enable.ps1`, `delete.ps1`.
One folder per target: `generated/<target>/`.

## 2. Naming

- Helper functions: `Verb-<System>Thing` with approved verbs
  (e.g. `Resolve-<System>Error`, `Invoke-<System>Request`).
- Splatted parameter hashtables: `$splat<Purpose>Params`
  (e.g. `$splatRetrieveTokenParams`, `$splatGetAccountParams`).
- `<System>` is the PascalCase application name, used consistently in helper
  names, audit messages and log lines.

## 3. Configuration and secrets

- All URLs, client IDs, secrets and tenant values come from
  `$actionContext.Configuration.*`. Never hard-code them.
- Never write secrets, tokens, request bodies or full error records to any
  output stream (no `$_ | ConvertTo-Json | Write-Warning`).
- In examples, tests and prompts, use placeholders such as
  `<CLIENT_ID>`, never real values.

## 4. Authentication

- Authentication is a separate step that runs before any account lookup.
- The security scheme shown in a digest's "--- security ---" block
  (e.g. "Bearer", "ApiKey", "Basic") only describes how a credential is
  PRESENTED on each call. It never tells you where that credential
  comes from. Depending on the auth method, the source is one of:
  - OAuth2 (client credentials or similar): a token endpoint, typically
    tagged "OAuth" and found among the other operations (commonly
    POST .../token). Document its path, method, request fields, and
    response fields in endpoints.md.
  - Static API key: a value from $actionContext.Configuration (e.g. a
    header or query parameter). No token endpoint exists; document
    which header/query parameter name the spec expects.
  - Basic Auth: a username/password from $actionContext.Configuration,
    base64-encoded into the Authorization header. No token endpoint.
  - Any other scheme found in the spec: document exactly what is
    needed to construct it, even if it does not fit the patterns above.
- If endpoints.md documents only the presentation scheme (e.g. "Bearer,
  JWT") without saying where the credential comes from, treat it as
  incomplete per §12 — regardless of which auth method applies.
- For OAuth-style flows: cache nothing between runs; request a token
  per execution. For static credentials (API key, Basic): read them
  from $actionContext.Configuration per execution; there is nothing to
  request or refresh.
- Every Invoke-RestMethod call made after the auth step must include
  the correct header (or query parameter) for whichever auth method is
  confirmed in endpoints.md — e.g. Headers = @{ Authorization = "Bearer
  $($token.access_token)" } for OAuth, or Headers = @{ "X-Api-Key" =
  $actionContext.Configuration.ApiKey } for an API key. A call missing
  this is incomplete, even if it would otherwise run successfully
  against a lenient test API.

## 5. Account lookup

- Create looks up the account by the correlation field (see §14).
  Every other action (update, enable, disable, delete) looks up the
  account by `$actionContext.References.Account` (the target system's
  internal ID), not by the correlation field.
- Every lifecycle action other than create must perform a fresh GET
  call to retrieve the current account state before acting — never
  assume the account's state from a previous step or from
  $actionContext.Data alone. See §15–§16 for the standard pattern.
- If the lookup returns nothing (account not found), follow the rule
  in the relevant action section below (§14–§16). Do not guess the
  right behavior.

## 6. Dry run

- When `$actionContext.DryRun -eq $true`, make no write calls
  (POST, PUT, PATCH, DELETE).
- Read calls (token, lookup) still run.
- Log a `[DryRun]` message describing what would have happened.

## 7. Output context

Set these on every successful path, for every action:

| Property | Rule |
|---|---|
| `$outputContext.Success` | Set explicitly to `$true` or `$false` on every path |
| `$actionContext.References.Account` / `$outputContext.AccountReference` | The target system's unique ID (set as AccountReference on create; read from References.Account on every other action) |
| `$outputContext.Data` | The account object returned by the API. Must NEVER be an array, even if the underlying API returns a collection — HelloID's field mapping does not support array values here. If an API call could return multiple matches, see §14's MultipleFound handling. |

Action-specific output fields (e.g. `AccountCorrelated` for create) are
listed in the matching action section below (§14–§16).

## 8. Audit logs

- Every path ends with exactly one `AuditLogs.Add`, with `Action`, `Message`
  and `IsError`.
- Success messages include the AccountReference:
  `"<Action> account was successful. AccountReference is: [<id>]"`.
- Error messages start with what failed, and ALWAYS include the error
  message returned by the target web service itself (not just a
  generic "something went wrong") — the vendor's own error text is
  often the only clue available during troubleshooting:
  `"Could not <action> <System> account. Error: <friendly message>"`.
- Audit messages contain no secrets and no personal data beyond IDs.

## 9. Error handling

- One `Resolve-<System>Error` helper per connector, returning
  `ScriptLineNumber`, `Line`, `ErrorDetails`, `FriendlyMessage`. Keep
  `[Parameter(Mandatory)]` on `$ErrorObject`, as in the templates.
- In the catch block, handle both `HttpResponseException` (PS 7) and
  `WebException` (PS 5.1).
- `Write-Information` for progress, `Write-Warning` for errors.
  No `Write-Host`.
- Build and test every connector for both cloud and on-premises
  agents. Error handling behaves differently between the two (e.g.
  exception types, response stream access) — never assume cloud-agent
  behavior covers the on-prem agent or vice versa.

## 10. HTTP calls

- Always use `Invoke-RestMethod` with a splatted hashtable.
- When sending a body, set `ContentType` to the media type the spec
  declares for that operation. Use `application/json` for a plain JSON
  body. A JSON Patch body (RFC 6902) is sent as
  `application/json-patch+json`. When the spec lists several, use the one
  that matches the body you send.
- Convert bodies with `ConvertTo-Json` (add `-Depth` if nested objects exist).
- Use the endpoints chosen from the spec digest; do not call endpoints that
  were not confirmed.
- Do not wrap calls inside functions.
- Never send a field marked readOnly in endpoints.md as part of a
  request body (e.g. an internal `Id` field on create).

## 11. Field mapping

- Map fields 1:1 to the target API wherever possible, keeping the
  mapping as dynamic as possible rather than hardcoding field names in
  the script. If the mapping must deviate from 1:1, raise it with the
  team before finalizing — do not decide this alone.
- If a field is required by the target API (e.g. for create) but isn't
  part of the standard field mapping, create a separate object for it
  — conventionally named `_extension` — rather than hardcoding it
  inline.
- Include UserName / UPN / email sourced from the Microsoft AD
  connector where applicable, rather than re-deriving it.
- Any field added to the field mapping during implementation should
  flow through automatically. If a hardcoded mapping is unavoidable,
  document why in the connector's README.
- Validate mapping files; log any invalid mapping entries to a
  separate audit log rather than failing silently or mixing them into
  the main audit log.
- Do not use `$value -is [PSCustomObject]` to test a mapped value's
  type (e.g. a date string) — this produces unreliable results. Use an
  explicit, type-appropriate check instead.

## 12. Known pitfalls (add to this list over time)

- `elseif ($obj)` is true for arrays of any size; check `.Count` before it.
- `-not($actionContext.DryRun -eq $true)` works, but keep the pattern
  identical across connectors so it is greppable.
- APIs often return 200 with an empty body for "not found"; check the body,
  not just the status code.
- Field names in the spec (e.g. client_id, access_token) do not always
  match the template's variable names (e.g. ClientId, token). Always
  verify against the digest, never assume the template is still correct.
- An endpoints.md auth section that only lists the security scheme
  (e.g. "Bearer, JWT") without a token endpoint, request fields, and
  response fields is incomplete and will silently produce a connector
  with no Authorization header. Always confirm the full token flow.
- A generic content-type rule must never override the media type the API
  requires. A JSON Patch sent as `application/json` was rejected in a
  HelloID test of the Example connector (2026-10-24); see §10.

## 13. Action-specific implementation — general approach

The sections below (§14–§16) define the standard shape for each
action. Even so, before implementing any action:

1. Inspect the corresponding template in `templates/`.
2. Inspect relevant implementations in `generated/` for the same
   connector type.
3. Confirm the target API actually supports the required operation
   (per the confirmed endpoints in endpoints.md).
4. Resolve any ambiguity in behavior before generating code.

Existing connectors in `generated/` are implementation references, not
guaranteed-correct implementations — the hard rules in this document
always take precedence over what a prior connector happened to do.

If essential behavior cannot be established from the API
specification, these conventions, or existing implementations, stop
and ask rather than inventing behavior.

## 14. Create

### Correlation lookup — must be a real API call

Before evaluating the decision logic below, you MUST perform the
actual GET call to the correlation-lookup endpoint confirmed in
endpoints.md (e.g. GET /api/users/employeeid/{employeeid}), using
Invoke-RestMethod with the Authorization header set from the auth step
(§4).

```powershell
$splatGetAccountParams = @{
    Uri     = "$($actionContext.Configuration.BaseUrl)/api/users/employeeid/$correlationValue"
    Method  = 'GET'
    Headers = @{ Authorization = "Bearer $($token.access_token)" }
}
try {
    $correlatedAccount = Invoke-RestMethod @splatGetAccountParams
} catch {
    if ($_.Exception.Response.StatusCode -eq 'NotFound') {
        $correlatedAccount = $null
    } else {
        throw
    }
}
```

(Adjust the URI, field name, and response handling to match what is
actually confirmed in endpoints.md — the example above shows the shape
of what is required, not literal values to copy unchanged.)

Template comments such as "# Example to replace the placeholder code
with..." are instructions to implement, not acceptable final content.
Leaving a hardcoded value (e.g. New-Guid, a literal test object) in
place of this call is a failure to follow conventions, not an
acceptable draft — see §17.

### Correlation decision

If `$actionContext.CorrelationConfiguration.Enabled` is `$false`,
always create a new account — do not attempt correlation at all.

If correlation is enabled, validate both `AccountField` and
`PersonFieldValue` first. Throw a clear message if either is empty.

Check for multiple matches first, then null, then a single match:

```powershell
if ($correlatedAccount.Count -gt 1) {
    throw "Multiple accounts found for person where $correlationField is: [$correlationValue]"
} elseif ($null -eq $correlatedAccount) {
    $action = 'CreateAccount'
} else {
    $action = 'CorrelateAccount'
}
```

If the lookup call itself can return multiple accounts (e.g. because
the target API only supports a filtered search rather than an exact
match), add an explicit `MultipleFound` branch that logs this clearly,
rather than letting `.Count -gt 1` throw a generic error — the audit
log should make it obvious this needs manual investigation.

### Create call

- Always create the account in a **disabled** state, unless the
  target API has no concept of an active/disabled flag at all.
- Include UserName / UPN / email sourced from Microsoft AD where the
  target system expects an identifier of that shape.

### Output context

- `$outputContext.AccountCorrelated`: set to `$true` only when
  correlating an existing account, `$false` (or omitted) when
  creating a new one.
- Be aware: when `AccountCorrelated` is `$true`, HelloID does not send
  a create notification. This is expected HelloID behavior, not a bug
  in the connector.

## 15. Update

Always perform a fresh GET call first to retrieve the account's
current state in the target system (per §5) — never diff against
stale or assumed data.

Then compare the retrieved account against the incoming field mapping
to decide whether an update is actually needed:

```powershell
if ($null -ne $correlatedAccount) {
    $splatCompareProperties = @{
        ReferenceObject  = @($correlatedAccount.PSObject.Properties)
        DifferenceObject = @($actionContext.Data.PSObject.Properties)
    }
    $propertiesChanged = Compare-Object @splatCompareProperties -PassThru |
        Where-Object { $_.SideIndicator -eq '=>' }
    if ($propertiesChanged) {
        $lifecycleProcess = 'UpdateAccount'
    } else {
        $lifecycleProcess = 'NoChanges'
    }
} else {
    $lifecycleProcess = 'NotFound'
}
```

Log clearly and consistently based on the outcome:
- `NoChanges`: log that no changes were needed — do not call the
  update endpoint at all.
- `UpdateAccount`: log the update and make sure `$propertiesChanged`
  (or equivalent) is populated so the audit log reflects what actually
  changed, not just that "an update happened".

**How the actual update call itself must be shaped (full payload vs.
partial/PATCH, which fields are required even when unchanged, etc.)
depends entirely on the target API** — this cannot be assumed from
this convention alone. Confirm it against endpoints.md; if the target
offers no GET endpoint to compare against in the first place, always
perform the update unconditionally rather than guessing at a
comparison. If the API's update semantics are unclear or only
partially documented, stop and ask rather than picking a shape that
seems reasonable.

If the target has no GET call for the account/user ID or external ID
at all, consider whether a resource script is more appropriate than
handling this inline — raise this with the team rather than deciding
unilaterally, since it affects more than just this one script.

## 16. Enable / Disable / Delete

Always perform a fresh GET call first to verify the account still
exists, before taking any action. Treat "not found" as an expected,
non-error outcome rather than letting it bubble up as a failure:

```powershell
try {
    Write-Information 'Verifying if a <System> account exists'
    $splatGetUserParams = @{
        Uri     = "$($actionContext.Configuration.BaseUrl)/user?id=$($actionContext.References.Account)"
        Method  = 'GET'
        Headers = $headers
    }
    $correlatedAccount = Invoke-RestMethod @splatGetUserParams
} catch {
    $errorObj = Resolve-<System>Error -ErrorObject $PSItem
    if ($errorObj.FriendlyMessage -notmatch 'account not found') {
        throw
    }
}

if ([string]::IsNullOrEmpty($actionContext.References.Account)) {
    throw 'The account reference could not be found'
}
```

Then branch on whether the account was found:

```powershell
if ($null -ne $correlatedAccount) {
    $lifecycleProcess = 'DisableAccount'   # or EnableAccount / DeleteAccount
} else {
    $lifecycleProcess = 'NotFound'
}

switch ($lifecycleProcess) {
    'DisableAccount' {
        if (-not($actionContext.DryRun -eq $true)) {
            Write-Information "Disabling <System> account with accountReference: [$($actionContext.References.Account)]"

            if ($actionContext.Origin -eq 'reconciliation') {
                # personContext / actionContext.Data may not be available
                # during reconciliation — hardcoded values may be required
            } else {
                # normal lifecycle logic
            }

            $splatDisableParams = @{
                Uri         = "$($actionContext.Configuration.BaseUrl)/user"
                Method      = 'POST'
                Headers     = $headers
                ContentType = 'application/json'
                Body        = $body | ConvertTo-Json -Depth 10
            }
            $null = Invoke-RestMethod @splatDisableParams
        } else {
            Write-Information "[DryRun] Disable <System> account with accountReference: [$($actionContext.References.Account)], will be executed during enforcement"
        }

        $outputContext.Success = $true
        $outputContext.AuditLogs.Add([PSCustomObject]@{
            Message = "Disable account: [$($actionContext.References.Account)] was successful. Action initiated by: [$($actionContext.Origin)]"
            IsError = $false
        })
        break
    }

    'NotFound' {
        Write-Information "<System> account: [$($actionContext.References.Account)] could not be found, indicating that it may have been deleted"
        $outputContext.Success = $true
        $outputContext.AuditLogs.Add([PSCustomObject]@{
            Message = "<System> account: [$($actionContext.References.Account)] could not be found, indicating that it may have been deleted. Action initiated by: [$($actionContext.Origin)]"
            IsError = $false
        })
        break
    }
}
```

Rules specific to this family of actions:
- `NotFound` is treated as a successful, non-error outcome — the
  account being already gone achieves the same end state the action
  was trying to reach (idempotency), so this must not fail the action.
- The exact HTTP method/endpoint/body shape for the enable/disable/
  delete call itself depends on the target API; confirm it against
  endpoints.md rather than assuming the POST-based example above
  applies universally.
- Status/active/date fields are taken into account directly within
  the action's own logic — never include them in the standard field
  mapping (see §11; keep reconciliation behavior in mind when deciding
  this, since the mapping is also used there).
- Apply the same reconciliation-origin handling shown above (checking
  `$actionContext.Origin`) consistently across enable, disable, and
  delete.

## 17. No placeholder implementations

- Every HTTP call described or implied by a template — including calls
  only sketched as a comment (e.g. "# Example to replace the
  placeholder code with...") — must be fully implemented with
  Invoke-RestMethod, using the confirmed endpoint and fields from
  endpoints.md.
- A comment describing what should happen is not a finished
  implementation. Hardcoded or fabricated values (e.g. New-Guid,
  literal test data, a stub object) in place of a real API call are
  never acceptable output, even as a "draft" — treat them the same as
  a missing feature and either implement the real call or stop and ask.