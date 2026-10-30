---
name: connector-scout
description: Research a target application's API for a HelloID provisioning target connector and write a feasibility report to reports/<target>-feasibility.md in the current folder (plus reports/report-viewer.html, a static viewer to open it in the browser), covering the connector type, capabilities, the baseline (account or access) and conventions comparison, the HelloID reference connectors, and proposed endpoints per provisioning action. Works from any folder. Research only; never writes connector code.
argument-hint: [<spec file path or public docs/spec URL>] [--target <name>] [--answers <file>]
context: fork
allowed-tools:
  - "Bash(pwsh -NoProfile -File ${CLAUDE_SKILL_DIR}/scripts/*)"
  - "PowerShell(pwsh -NoProfile -File */connector-scout/scripts/*)"
  - "Edit(./reports/**)"
  - "WebFetch"
---

# Connector Scout

Standalone version of the ConnectorX scout skill. It works from any folder: everything it needs is bundled in this skill's folder, except the reference connectors, which it fetches from GitHub (the base directory shown when the skill loads, written `<skill>` below).

| Bundled | What |
|---|---|
| `<skill>/references/conventions.md` | Binding connector conventions (the § numbers below point here) |
| `<skill>/references/bestPractices.md` | Team best practices (Yes = mandatory, Conditional = mandatory when the condition applies) |
| `<skill>/references/baseline.md` | Baseline account API |
| `<skill>/references/baselineAccess.md` | Baseline for physical-access targets |
| `<skill>/references/report.schema.json` | Report frontmatter schema |
| `<skill>/scripts/spec-digest.ps1` | OpenAPI/Swagger digest tool (PowerShell 7) |
| `<skill>/scripts/prepare-run.ps1` | Creates the report folders, copies the viewer, hashes the spec, archives an earlier report (PowerShell 7) |
| `<skill>/report-viewer.html` | The static report viewer that `prepare-run.ps1` copies to `reports/` |
| Reference connectors (fetched with WebFetch, not bundled) | REST account lifecycle: `https://github.com/Tools4everBV/HelloID-Conn-Prov-Target-Caseware`. REST access system: `https://github.com/Tools4everBV/HelloID-Conn-Prov-Target-Iprotect`. SCIM: `https://github.com/Tools4everBV/HelloID-Conn-Prov-Target-Generic-Scim` |
| `<skill>/assets/scout.png` | The Scout logo |

The bundled files come from the ConnectorX repository. Where they mention `docs/`, `schemas/`, `templates/`, `generated/`, or `endpoints.md`, read: the matching file in `<skill>/references/`, or nothing (the last three don't apply to scout).

**Requirements** (installation steps in `<skill>/README.md`):

- PowerShell 7 (`pwsh`) for the scripts.
- The `powershell-yaml` module, for YAML specs: `Install-Module powershell-yaml -Scope CurrentUser`. If it's missing, the scripts stop with that command; tell the user, and don't read a YAML spec raw instead.
- The permission rules in `<skill>/README.md`, so a run needs no approvals. Run shell commands only through the scout scripts, so every call matches those rules.

**The working folder** is the folder you were started in. Specs are read from there, and the report is written there.

**Running as a subagent.** This skill runs in its own subagent (`context: fork`). Your final message is the only thing the user sees. If you can't ask the user something (AskUserQuestion is not available), don't guess: where a step says to ask, stop before writing the report if the answer is essential (which spec file, or the connector type), and say exactly what the user should pass on the next run (for example the spec path). Otherwise record it as an open question in the report.

## Ground rules

- Research only. The only files scout writes, all in the working folder, are `reports/<target>-feasibility.md`, `reports/report-viewer.html` (copied by `prepare-run.ps1`, Step 1.4), a copy of the previous report in `reports/history/` (Step 1.4), and digest output files under `reports/.scout/` (Step 2). Never write or change connector code, and never touch `generated/` or `templates/`. The task ends when the report is delivered.
- Never call the target application's live environment. You may fetch public documentation and shared specification or response examples.
- Scout doesn't search published connectors on GitHub. The only github.com fetches allowed are the three reference connectors in Step 3c.
- If authentication, endpoints, correlation fields, or other essential API behavior is unclear, ask. Don't invent it.
- Report a step or file as done only after checking it yourself. A subagent's or tool's summary is not proof.

## Step 0: Logo

Before anything else, show the logo `<skill>/assets/scout.png` to the user, with the caption "Scout: <target>". Use a tool that displays a file in the conversation (for example SendUserFile with `display: render`). If no such tool exists, for example in a plain terminal, skip this step silently. Never let it block the run.

## Step 1: Inputs

1. Parse `$ARGUMENTS` for an optional spec: an `https://` URL of public docs or a spec, or a path to a local file. `--target <name>` overrides the target name (Step 1.3). `--answers <file>` makes this a follow-up run (Step 1.4). The connector type is not an argument: scout determines it in Step 2. If a type word (`rest`, `scim`, `soap`, `other`) is given anyway, treat it as a hint only and compare it with what you find.
2. **Spec.**
   - **A URL in the arguments is the source.** Don't look for a file or ask for one. Fetch it (Step 2). The report's `spec` is the URL and `specSha256` is `null`.
   - **A file path in the arguments is the source.** Resolve it against the working folder and check that it exists.
   - Otherwise look in the working folder: spec-like files in the folder itself (`*.json`, `*.yaml`, `*.yml`, `*.wsdl`, `*.pdf`, `*.docx`), then `specs/**`. Skip `endpoints.md`, `reports/`, and JSON that is not an OpenAPI/Swagger spec (no `openapi` or `swagger` key).
     - If exactly one file matches, use it.
     - Otherwise, ask the user to pick one with AskUserQuestion.
     - If there is no file, ask for one: an OpenAPI JSON/YAML, a WSDL, a PDF, a DOCX, or a public docs URL.
   **Target name** (part of step 2, so the later step numbers stay). Use `--target` if given. Otherwise take it from the spec:
   - OpenAPI/Swagger: run `pwsh -NoProfile -File <skill>/scripts/spec-digest.ps1 -SpecPath <spec> -Info` and use `title`. Fall back to the server host, then the file name.
   - PDF, DOCX, WSDL or URL: the product name in the title or first page, or the URL's host.
   - Keep the vendor and product words, drop filler (`API`, `REST`, `Swagger`, `OpenAPI`, `Documentation`, version numbers). Use it as the file-name slug: letters, digits and `-` only (`Topdesk API v3` becomes `Topdesk`).
   - State the name you derived and its source in your reply. In a run that can't ask, don't stop for it; the user can correct it with `--target`.
3. Read `<skill>/references/conventions.md` and `<skill>/references/bestPractices.md`. Step 3b needs them.

4. **Earlier report and follow-up runs.**
   - **Prepare the run** once the spec is known, before you write anything:
     ```
     pwsh -NoProfile -File <skill>/scripts/prepare-run.ps1 -Target <target> -Spec <spec path or URL>
     ```
     It creates `reports/`, `reports/.scout/` and `reports/history/`, and it prints JSON: `spec` (as the report should write it), `specSha256`, `specLastModified`, and `earlierReport` (its verdict, confidence, `specChanged`, and `archivedTo`). When an earlier report exists, the script copies it to `reports/history/`. Use these values; don't compute the hash or copy files yourself. Never edit or delete files in `reports/history/`.
   - **`--answers <file>`** is a follow-up run: the answers to the open questions of the earlier report, from the vendor or the requester. The file can be any text (Markdown, a pasted email, a list). Resolve its path against the working folder.
     - It needs an earlier report. If there is none, stop and say so: a first run takes no answers.
     - Read the earlier report and the answers. Match each answer to an open question by its number or its subject. An answer you can't match is a new finding: note it in the Summary, and don't drop it.
     - **Same spec** (`earlierReport.specChanged` is false): don't redo the whole research. Keep the earlier findings, and run the digest (detail mode) again only for the endpoints the answers touch.     - **Changed spec** (`specChanged` is true): do a full run, and use the answers as an extra source.
     - **How an answer counts:** an answer that settles behavior the spec doesn't document makes that area "Confirmed (answer from <who>, <file>)". An answer that contradicts the spec doesn't overrule it: record both in section 6, and keep the question open with its blocking status.
     - **Report changes:** in section 8, move answered questions to a table "Answered" under the open ones (`# | Question | Answer | Who | Source`), keeping their numbers. Open the Summary with a list "Changes since <earlier reportDate>": the questions answered, what changed in sections 3–6, and the old and new verdict and confidence. Name the answers file in section 2. Set the verdict and confidence again by the Step 4 rules; don't carry them over.

## Step 2: Research the API

**Reading the source**

- **JSON/YAML.** Always start with the digest tool instead of reading the raw spec. Call every scout script in this one form, from the Bash or the PowerShell tool alike. It matches the allow rules in `<skill>/README.md`, so it runs without a permission prompt. Write `<skill>` as the absolute path with forward slashes. Comma lists (`user,account`) work in this form.
  ```
  pwsh -NoProfile -File <skill>/scripts/spec-digest.ps1 -SpecPath <spec> -Keyword user,account,employee,person,group
  pwsh -NoProfile -File <skill>/scripts/spec-digest.ps1 -SpecPath <spec> -Keyword token,auth,oauth,login,credential
  pwsh -NoProfile -File <skill>/scripts/spec-digest.ps1 -SpecPath <spec> -Route '<path>' -Method <verb>
  ```
  - Use the Bash tool for these calls. The PowerShell tool can fail before it runs anything ("The command line is too long"); use it only when there is no Bash tool. Git Bash rewrites an argument that starts with `/` into a Windows path (`/api/oauth/token` becomes `C:/Program Files/Git/api/oauth/token`). `spec-digest.ps1` maps such a route back to the spec path and warns ("looks rewritten by Git Bash"), so that's harmless. Don't put `MSYS_NO_PATHCONV=1` in front: then the command no longer matches the allow rules.
  - One script per call, with nothing chained after it (no `; head`, no `| grep`): read long output with `-OutFile` and the Read tool. Don't run other shell commands, and don't look at folders outside the working folder and `<skill>`.
  - Quote a route that has `{}` in it (`-Route '/api/users/{id}'`): PowerShell reads bare braces as a script block. Several routes go in one call as `-Route '/a,/b/{id}' -Method get,patch`, paired by position.
  - **Long output** (a full digest without `-Keyword`, or many detail routes): add `-OutFile reports/.scout/<target>-digest.txt` and read that file with the Read tool. The command line stays short, and the result isn't cut off.
  - If a script fails because the command line is too long, or with a shell error, don't fall back to reading the raw spec. Shorten the call (fewer routes per call, `-OutFile`), and say in section 2 what failed.
  - YAML specs need the `powershell-yaml` module; the script says so if it's missing.
  - If the keyword results look incomplete, run it again without `-Keyword`.
  - Run detail mode (`-Route`, `-Method`) for every endpoint you propose.
- **PDF.** Read it with `pages`.
- **DOCX.** Use the docx skill.
- **Public vendor docs.** You may fetch them. Never call the target's live environment.

**Connector type.** Determine it yourself from what you read, and record it with its evidence. Never assume it, and never copy it from the arguments.

| Type | Evidence |
|---|---|
| `scim` | A server URL or path with a `scim` segment (`/scim`, `/scim/v2`, `/v2/scim`), together with `/Users` or `/Groups`, `ServiceProviderConfig`, `Schemas`, `ResourceTypes`, a `urn:ietf:params:scim:schemas:` schema, or `application/scim+json` |
| `soap` | A WSDL, SOAP envelopes or bindings, `SOAPAction`, an `.asmx` or `?wsdl` address |
| `rest` | A resource-based HTTP API (an OpenAPI/Swagger spec, or docs that describe routes and JSON bodies) with none of the evidence above |
| `other` | None of the above: for example LDAP, a database, file or SFTP exchange, or a vendor SDK or PowerShell module |

- A SCIM API is also HTTP and JSON. When the SCIM evidence is there, the type is `scim`, not `rest`.
- Evidence for more than one type, or for none: ask the user with AskUserQuestion. In a run that can't ask (headless), stop without writing a report and say what is unclear.
- Record the type and the evidence in section 3 (for example "Type: scim. Evidence: server `https://x/scim/v2`, `/Users`, `/ServiceProviderConfig`"). The header table gets the type too.
- If the arguments gave a different type word, say so in section 3, and keep the type you found.

**What to establish.** Give each area a status and the evidence for it: `METHOD /path` plus fields, or a doc page or section.

| Area | Establish |
|---|---|
| Authentication | Where the credential **comes from**: the token endpoint with its request and response fields, the API key header or parameter, or Basic. The presentation scheme alone is not enough (§4, §12). In an OpenAPI spec, start from `components.securitySchemes` (and `security`, which says which scheme applies where) and derive it from the type and flow, as below. |
| List accounts | Full export and pagination, needed for reconciliation and governance. |
| Correlation lookup | Lookup by employeeId or a similar field. Is it an exact match or a filter? Can it return more than one result (§14)? |
| Get by internal ID | Required for every action except create (§5). Which response field is the AccountReference? |
| Create | Required, read-only, and unique fields. Can the account be created disabled (§14)? |
| Update | PUT or PATCH. Which fields are required even when unchanged? Which are immutable (§15)? |
| Enable / disable | A dedicated endpoint, or a status field set through update. |
| Delete | Hard or soft delete. |
| Permissions | A permission is anything the target grants a person: a group, role, access level, team, license, door, zone, or key. List **each kind separately**. For each kind: how to list it, how to grant and revoke it (a dedicated route, a field on the user, or an assignment resource), the reference field, and whether it can be imported. Only if the API has them. |
| Constraints | Filtering, rate limits, uniqueness. Does the error response carry the vendor's error text (§8)? |

**Authentication from the security scheme.** Record the scheme's type, flow, `tokenUrl` and scopes, then derive the credential source:

| Scheme in the spec | Credential source | Status |
|---|---|---|
| `oauth2` + `clientCredentials` + `tokenUrl` | Client id and secret; `POST tokenUrl`, form-encoded, `grant_type=client_credentials`, `scope` = the listed scopes; the response carries `access_token` (RFC 6749 §4.4) | Confirmed. Ask (non-blocking) how the client sends id and secret, Basic header or form body, only when the docs don't say |
| `oauth2` + `password` + `tokenUrl` | A service account's username and password, plus a client id (and secret); `grant_type=password` | Confirmed, plus a risk: a stored user password, and many providers are dropping this flow |
| `oauth2` + `authorizationCode` (or `implicit`) only | A person logs in interactively: unusable for an unattended connector. A refresh token doesn't solve it: HelloID has no place to store a token between runs, let alone one that rotates, so it would need a store outside HelloID | Not found for unattended use: a **blocking** question. As the only scheme it means no authentication a connector can use: verdict Not feasible, and a case for refine (for example client credentials from the vendor, or a token store outside HelloID) |
| `openIdConnect` + `openIdConnectUrl` | The discovery document names the token endpoint; the flow still has to be client credentials for a connector | Potential until the flow is known |
| `apiKey` + `in` + `name` | A static key in the named header, query parameter or cookie, read from the configuration | Confirmed. Where the key is issued comes from the docs or a question |
| `http` + `basic` | A username and password from the configuration | Confirmed |
| `http` + `bearer` (with no oauth2 scheme next to it) | Only how the token is sent: where it comes from isn't in the scheme. Look for a token endpoint in the paths or the docs | Potential at best: a **blocking** question if nothing is found (§4, §12) |

No security scheme, or a PDF or prose source: take authentication from the text, and give it a status by what the text actually shows.

**Statuses**

- **Confirmed:** documented in the source you read: the route, its request and its response. A standard the spec declares in machine-readable form counts as documented, for example an OpenAPI `securitySchemes` entry with `type: oauth2`, a flow (`clientCredentials`) and a `tokenUrl`: the request and response then follow from that standard.
- **Potential:** possible through a documented endpoint or field, but not verified. This includes a standard the docs only *mention* in prose ("we use OAuth") without declaring the flow and token URL: that's Potential, never Confirmed.
- **Not found:** not found in the sources read. This does not prove the operation is impossible.
- **Unclear:** the evidence is insufficient.

**Type-specific checks**

- **SCIM** (when the type is `scim`):
  - `/Users` and `/Groups` endpoints
  - Filter operators (RFC 7644)
  - PATCH add, replace, and remove
  - Bulk operations and pagination
  - Read-only and immutable attributes
  - Schema extensions
  - `ServiceProviderConfig` and `Schemas`, if documented

  Keep standard SCIM behavior separate from vendor-specific behavior.

**Rules**

- Map operations to actions by path, parameters, and fields, not by operation names or summaries.
- Don't drop an action just because the API uses an unfamiliar name for it.
- Don't stop at groups and roles for permissions. Check every resource a user can be given or linked to.
- Report what the API does; don't give implementation advice (which content type to send, which field to use). Where a choice is open, record the options and ask.
- If authentication, correlation, or another essential behavior stays unclear, record it as a blocking open question. Don't invent it.

**Physical access check.** The target is a **physical-access target** if the spec has resources for opening doors or areas: doors, locks, readers, access levels or zones, encoders, cards or badges, keys that open something, RFID, or mobile keys. A bare "key" or "token" is not enough, because it may be an API key. Record the answer and the evidence (the resources that show it). Step 3 depends on it.


## Step 3: Compare

**3a. Baseline.** Compare the target with `<skill>/references/baselineAccess.md` for a physical-access target, and with `<skill>/references/baseline.md` otherwise. `baselineAccess.md` contains the same user lifecycle as `baseline.md` plus roles, role authorizations and access keys, so use only one of them. Label each baseline capability as one of:

- **Equivalent:** names or paths may differ.
- **Different shape:** for example, a filter where the baseline has a dedicated lookup.
- **Missing.**
- **Beyond baseline:** for example, bulk operations or extra resource types.

At minimum, cover:

- Auth flow
- User create, read, update, and delete
- Lookup by employeeId versus lookup by internal ID
- Roles and authorizations
- Schema completeness
- Full-list retrieval

For a physical-access target also cover:

- Roles that map to areas, and how a person is linked to a role (role authorizations: list, add, remove)
- Access keys per user: list, revoke, and the active state of a key
- Keys being revoked when the user is disabled or deleted

The goal is to size the gap, not to judge the target.

**3b. Conventions fit.** List each place where the target makes a convention hard or impossible to follow. Common cases:

- No GET by ID (§5). Per the best practices, raise this with the vendor or consider a resource script.
- No way to create accounts disabled (§14).
- A lookup that can return more than one account.
- No vendor error text (§8).
- Unclear update semantics (§15).
- An undocumented credential source (§4).
- Physical access only: a disable or delete that leaves a key active, or a disable that only takes effect after a card is updated.

**3c. Reference connectors.** Use the reference connectors from the table at the top only, chosen by the type you determined in Step 2, and read them with WebFetch. Fetch the repo URL for the README, and `https://raw.githubusercontent.com/Tools4everBV/<repo>/main/<path>` for each script (try `master` if `main` fails). Fetch only the files you need.

- If there is no reference connector for the type (`soap`, `other`), say so. Never substitute a connector of another type.
- If WebFetch fails for a reference connector, say so in the report and carry on without it. Don't guess its contents.
- For a physical-access target of type `rest`, the reference is `https://github.com/Tools4everBV/HelloID-Conn-Prov-Target-Iprotect`, instead of Caseware. Read its README first (the Remarks on access keys, linked keys, delete and permissions), then only the scripts the baseline comparison points at: correlation in `create`, key handling in `enable`, `disable` and `delete`, and `permissions/`. Do not read every line of it.
- For any other target, read the scripts, not just the README: `create`, `update`, `enable`, `disable`, `delete`, `import`, and `permissions/`.
- Note how they handle auth, correlation, requests and responses, errors, pagination, retries, and workarounds.
- Treat them as references, not as proven-correct implementations.

## Step 4: Propose endpoints and verdict

**Endpoints.** Propose one endpoint per action. Give each the method and path, the key request and response fields, a status, and the evidence. The actions are:

- Token
- Correlation lookup
- Create
- Get by ID
- Update
- Enable
- Disable
- Delete
- List (for import)
- Permissions, if present: one set of rows (list, grant and revoke, import) **per permission kind**

**Per proposed endpoint, always record**, from the spec (state "not documented" when the spec is silent; never fill it in from general knowledge):

- **Request content types** the spec accepts, in the spec's order. If the listed types and the body don't match (for example `application/json-patch+json` listed first, but the body schema is a plain object), record both and add an open question for the vendor. Don't pick one.
- **Response shape and status codes:** the success body (is the created object returned, or only an id or a string?), and what happens on not found and on errors. If only some codes are documented, say which.
- **Fields:** required, read-only, unique, and length limits where given.
- **Twin fields:** a field documented in two forms (for example `userActivation` and `userActivationString`): record both and ask which one to send.

Name each unsupported action and the reason. These are proposals, to be confirmed with the user before any connector is built.

**Verdict.** The yardstick is the baseline used in Step 3a. The minimum is that a connector can create an account. Choose the verdict by this rule, not by feel:

| Verdict | When |
|---|---|
| Feasible | The target matches the baseline: every baseline action is documented and Confirmed, and no blocking question remains. |
| Feasible with caveats | Accounts can be created, but the target deviates from the baseline: an action is missing, has a different shape, needs a workaround or is not Confirmed, or a blocking question remains. |
| Not feasible | The docs show that accounts cannot be created (no create, or no authentication a connector can use). |
| Insufficient information | The docs do not say enough to tell whether accounts can be created. |

**Confidence.** How sure you are of that verdict. Choose by this rule:

| Confidence | When |
|---|---|
| High | A machine-readable spec (OpenAPI), every proposed endpoint checked in it, and no open question that could change the verdict. |
| Medium | The verdict rests on something not documented, the docs contradict themselves, or a blocking question could change the verdict. |
| Low | The evidence is mostly prose or a PDF, or authentication or the account lookup is unclear. |

State both in the Summary with the reason, in the form "Verdict: Feasible with caveats, because …" and "Confidence: Medium, because …".

## Step 5: Write the report

Save the report to `reports/<target>-feasibility.md` in the working folder with the Write tool (`prepare-run.ps1` already created `reports/`). It starts with YAML frontmatter that matches `<skill>/references/report.schema.json`; the ConnectorX gen skill uses it to decide whether the report is still current.

```markdown
---
target: <target>
spec: specs/<target>/<file>          # path relative to the working folder, or the public docs URL
specSha256: <hash>                   # null when the spec is a URL
reportDate: yyyy-MM-dd
verdict: feasible-with-caveats
confidence: medium
---

# <Target> feasibility report

| Target | Connector type | Source spec | Spec last modified | Report date | Verdict |
|---|---|---|---|---|---|
| <target> | <type> | specs/... | yyyy-MM-dd | yyyy-MM-dd | <verdict> (<confidence>) |
```

Take `spec`, `specSha256` and the header's "Spec last modified" from the `prepare-run.ps1` output (Step 1.4). Quote `reportDate` if your YAML writer would otherwise turn it into a date.

The report has these sections:

1. **Summary:** why this verdict, plus 3–5 points for the product owner: the main risks, the blocking questions, and the reference connectors.
2. **Sources:** the specs, URLs and example files actually read.
3. **API overview:** the type with its evidence (Step 2), the resources, authentication (where the credential comes from and how it is sent), the correlation candidates, and the constraints. State "Physical access: yes" or "no" with the evidence from the physical access check, and list the permission kinds found and how each is granted.
4. **Capabilities and proposed endpoints:** one table with the columns `Action | Status | Method & path | Key fields | Evidence`. Include the unsupported actions. Permissions get their own rows per kind, named `Permissions: <kind>`.
5. **Baseline comparison:** the findings from Step 3a. Name the baseline file used.
6. **Conventions fit and risks:** Step 3b, plus pagination, rate limits, immutable fields, and quirks.
7. **Reference connectors:** the reference connectors read in Step 3c, with file paths, patterns worth reusing, and workarounds. End with one line: "Published connectors on GitHub were not checked; check them before building."
8. **Open questions:** who should answer each one (requester or vendor), and whether it is **blocking** or **non-blocking**. A question is **blocking** when its answer is needed for authentication, for correlation or the AccountReference, or for how create, update, enable, disable or delete works; or when it decides which interface or route the connector uses. Otherwise it's **non-blocking**. For permissions: blocking for permissions, non-blocking for the account lifecycle. When the target has more than one permission kind, always ask the requester which kinds are in scope (non-blocking for the account lifecycle, blocking for permissions).

When you write the report:

- Back every material finding with evidence.
- Keep facts, interpretations, and unknowns visibly separate.
- Paraphrase the docs instead of copying them.
- Fill gaps with "Unclear" and an open question, never with a guess.

The viewer, `reports/report-viewer.html`, was copied there by `prepare-run.ps1` at the start of the run. It holds no report: the user opens the report in it with "Open file…", drag-and-drop or Paste.

## Step 6: Deliver

1. Read the report back yourself: the frontmatter matches `<skill>/references/report.schema.json`, the spec hash is right, the title and header table are there, sections 1–8 are present, and the Summary states the Verdict and Confidence.
2. Your final message is the answer: the full report, with the path it was written to and the viewer as a `file:///` link (for example `file:///C:/Temp/Reports/reports/report-viewer.html`), and tell the user to open the report in it (Open file…, drag-and-drop or Paste). If the viewer is missing, say so; the `.md` report is still the deliverable. If something in the read-back is still wrong and you can't fix it, list it at the top of the message. In a follow-up run, start with the "Changes since" list, and name the copy in `reports/history/`.
3. Stop. Don't generate connector code.
