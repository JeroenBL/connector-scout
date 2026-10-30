# Best Practices — HelloID PowerShell V2

| ID | Rule | Required | Why |
|---|---|---|---|
| R1 | Build connectors for both cloud and on-premises environments, and test with both the cloud agent and local agent. | Yes | Ensures compatibility across supported deployment environments, particularly for error handling. |
| R2 | Surface the target web service's original error message in the audit log or error logging. | Yes | Vendor error messages often provide the most useful diagnostic information. |
| R3 | Perform a GET call in every lifecycle action to retrieve the latest account state before acting. | Yes | Prevents actions from relying on stale or outdated account data. |
| R4 (also R18) | Keep field mapping as close to 1:1 with the target API as possible and make it dynamic. Discuss deviations with the team first. | Yes | Preserves flexibility and reduces unnecessary custom mapping logic. |
| R5 (also R19) | Put required API fields that are not part of standard field mapping in a separate object, conventionally named `_extension`, rather than hardcoding them. | Conditional | Supports required target-specific fields without compromising standard mapping. |
| R6 (also R31) | If the target has no GET endpoint, perform an update instead of comparing against a known state. | Conditional | Avoids unreliable change detection when current state cannot be retrieved. |
| R7 | If no GET call exists for the user ID or external ID, evaluate whether a resource script or import script is more appropriate, particularly for reboarding. | No — judgement call | The best approach depends on user volume, API response times and reboarding requirements. |
| R8 | If the target API has no GET endpoint at all, raise this with the vendor instead of silently implementing a workaround. | Yes | Makes a significant API limitation visible and encourages a proper solution. |
| R9 | Design the connector to fit HelloID's model, including lifecycle actions, field mapping and references. | Yes | Ensures the connector behaves predictably within HelloID. |
| R10 | Consult Rick van den D. about connector-specific design decisions. | Yes | Aligns implementation choices with team expertise. |
| R11 | Consult Rick van den D. before finalizing connectors with many business rules. | Yes | Helps validate complex business logic before it becomes difficult to change. |
| R12 | Avoid mapping files where possible. | No — recommendation | Reduces unnecessary configuration overhead and maintenance. |
| R13 | Perform uniqueness checks for every field that must be unique in the target system. | Yes | Prevents duplicate accounts and conflicts with target-system constraints. |
| R14 | Validate mapping files and write invalid mappings to a separate audit log. | Conditional | Makes configuration errors visible and easier to troubleshoot. See `docs/conventions.md` §11. |
| R15 | Maintain a `changelog.md` documenting all connector changes over time. | Yes | Provides a traceable history of changes. |
| R16 | Do not use `$value -is [PSCustomObject]` to type-check values such as date strings. | Yes | Can produce unexpected results and misclassify values. |
| R17 | When HelloID is the primary target or system of record, ensure every relevant field is also populated in HelloID, not just in the external target. | Conditional | Prevents data inconsistencies between HelloID and the target system. |
| R20 | Source `UserName`, UPN and email from Microsoft AD where applicable, rather than deriving them again. | Conditional | Reuses authoritative values and avoids inconsistencies. |
| R21 | Map `lastName` using a complex mapping rather than a plain 1:1 field mapping. | Yes | Supports the team's required surname-mapping behavior. |
| R22 | Never put arrays in `$outputContext.Data`. | Yes | Ensures the output conforms to HelloID's expected data structure. See `docs/conventions.md` §7. |
| R23 | Ensure fields added to the mapping during implementation flow through automatically. If hardcoding is unavoidable, document the reason in the connector README. | Yes | Prevents future mapping additions from being silently ignored. |
| R24 | Always create accounts in a disabled state. | Yes | Prevents newly created accounts from becoming active before the appropriate lifecycle action. See `docs/conventions.md` §14. |
| R25 | Include `UserName`, UPN and email from Microsoft AD during account creation, where applicable. | Conditional | Preserves the authoritative identity attributes needed by the target. |
| R26 | If a GET or lookup can return multiple accounts, handle this through an explicit `MultipleFound` action. | Conditional | Provides clear audit logging instead of a generic failure. See `docs/conventions.md` §14. |
| R27 | Ensure `$outputContext.Data` contains exactly one object, never an array, during account creation. | Yes | Maintains the expected HelloID output contract. |
| R28 | If correlation is disabled, always create a new account. | Yes | Prevents unintended account reuse when correlation is explicitly disabled. |
| R29 | Account for the fact that HelloID does not send a create notification when `AccountCorrelated` is `$true`. | Yes | Prevents expected platform behavior from being mistaken for a defect. |
| R30 | Use the compare-account pattern in every update script. | Yes | Identifies actual changes and avoids unnecessary updates. See `docs/conventions.md` §15. |
| R32 | Do not include active or date fields in field mapping. Handle them directly in enable/disable action logic. | Yes | Separates lifecycle control from standard account data mapping. See `docs/conventions.md` §16. |
| R33 | Consider reconciliation behavior when designing field mapping, since the same mapping is used during reconciliation. | Yes | Prevents unexpected account changes or inconsistent reconciliation results. |
| R34 | Do not use arrays in entitlement-import account data objects. | Yes | Maintains the expected data structure for imported accounts. |
| R35 | During entitlement account import, populate an empty `UserName` with the account reference. | Conditional | Preserves the link back to the account object when no username is available. |
| R36 (also R43) | Design entitlement account imports and permission imports around the constraint that a snapshot can only be taken once per hour. | Yes | Prevents assumptions about snapshot frequency that HelloID cannot satisfy. |
| R37 | Use `Write-Error` in entitlement-import catch blocks. | Yes | Ensures snapshot failures are surfaced so incomplete imports fail cleanly and can be retried. |
| R38 | If memory becomes an issue during entitlement import, set processed account objects to `$null` after their data has been written back to HelloID. | Conditional | Reduces memory pressure during large imports. |
| R39 | Do not include `displayName` in the permission reference. | Yes | Keeps the permission reference compliant with the team's required structure. |
| R40 | Use `$actionContext.PermissionDisplayName` in grant/revoke logging. | Yes | Makes permission-related audit entries readable and identifiable. |
| R41 | Do not rely on `$actionContext.PermissionDisplayName` being available in preview mode. | Yes | Prevents logging or execution errors when the variable is unavailable. |
| R42 | Account for batching when importing permissions. | Yes | Prevents failures or incomplete imports when processing large permission sets. |
| R44 | Use `Write-Error` in permission-import catch blocks. | Yes | Ensures failed imports are surfaced and can be retried rather than silently succeeding with incomplete data. |
| R45 | If memory becomes an issue during permission import, set processed objects to `$null` after their data has been written back to HelloID. | Conditional | Reduces memory pressure during large imports. |
| R46 | Thoroughly test every action and process in HelloID, including reboarding. | Yes | Validates the complete lifecycle, including scenarios that can expose account-correlation issues. |
| R47 | Keep logging clear and consistent. | Yes | Makes connector behavior easier to understand, troubleshoot and audit. |
| R48 | For updates with no changes, log exactly `No changes`. | Yes | Clearly distinguishes a successful no-op from an actual update. |
| R49 | For updates with changes, correctly populate `$propertiesChanged` or its equivalent instead of logging only a generic `updated` message. | Yes | Identifies which properties changed and provides meaningful audit information. |

## Notes

- **Yes:** Mandatory rule.
- **Conditional:** Mandatory when the stated condition applies.
- **No — judgement call:** Use team judgement; the rule is not absolute.
- **R3 and R6 (also R31):** The GET requirement needs an explicit exception when the target provides no GET endpoint. R8 requires raising that limitation with the vendor.
- **Aliases:** R4 (also R18), R5 (also R19), R6 (also R31) and R36 (also R43) were duplicate rules and are merged. The old ID still points to the merged rule.
- **Source of truth:** Refer to `docs/conventions.md` for detailed implementation requirements and patterns.