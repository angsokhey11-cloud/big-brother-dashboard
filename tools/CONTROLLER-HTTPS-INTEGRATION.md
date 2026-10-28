# BIG BROTHER Control Center V3.4: HTTPS add-on

This is a **non-destructive Caddy process helper**, not a replacement for V5/V6. It expects the existing trusted HTTPS config at `%USERPROFILE%\BIG_BROTHER_HTTPS\Caddyfile` and an installed caddy.exe.

## Test on the Local Brain PC
Copy `BB-HTTPS-Control.ps1` into the controller folder. Open PowerShell:

```powershell
& ".\BB-HTTPS-Control.ps1" -Action Doctor
& ".\BB-HTTPS-Control.ps1" -Action Status
```

After closing the manually-started Caddy terminal, and only when the gateway is safe to interrupt:

```powershell
& ".\BB-HTTPS-Control.ps1" -Action Start
& ".\BB-HTTPS-Control.ps1" -Action Status
```

## Integrate into Control Center V3.4

After the **existing Start V6 handler has succeeded**, invoke:

```powershell
& (Join-Path $PSScriptRoot 'BB-HTTPS-Control.ps1') -Action Start
```

Before stopping V6, invoke:

```powershell
& (Join-Path $PSScriptRoot 'BB-HTTPS-Control.ps1') -Action Stop
```

The controller's actual launcher source must be inspected before applying these example hooks; V3.4 may use a non-PowerShell language or different working directory.

The helper deliberately **refuses to kill another manually started Caddy**. No code changes are made to DB/Local Brain. Do not use `Clear credentials` on the tablet.
