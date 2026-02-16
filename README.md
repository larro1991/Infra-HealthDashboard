# Infra-HealthDashboard

PowerShell module for Windows server infrastructure health monitoring. Collects server inventory, disk space, service status, and pending updates across your environment. Generates color-coded HTML dashboards with optional email delivery.

## The Problem

You find out a drive is full when the application crashes. You find out a service stopped when users start calling. You find out a server needs patching when the vulnerability scanner flags it. A daily health check catches all of this before it becomes an incident.

## What This Module Does

| Function | Purpose |
|----------|---------|
| `Invoke-InfraHealthCheck` | Run all checks, generate an HTML dashboard, optionally email it |
| `Get-ServerInventory` | Collect OS, CPU, RAM, manufacturer, model, serial, uptime via CIM |
| `Get-DiskSpaceReport` | Report disk usage with configurable warning/critical thresholds |
| `Get-ServiceHealthReport` | Monitor critical Windows services (auto-start services that aren't running) |
| `Get-PendingUpdates` | Check for pending Windows updates and reboot flags |

## Quick Start

```powershell
Import-Module .\Infra-HealthDashboard.psd1

# Check specific servers
Invoke-InfraHealthCheck -ComputerName "SERVER01","SERVER02","DC01"

# Auto-discover from AD and email the report
Invoke-InfraHealthCheck -SendEmail `
    -EmailTo "team@contoso.com" `
    -EmailFrom "monitor@contoso.com" `
    -SmtpServer "smtp.contoso.com"

# Custom disk thresholds
Get-DiskSpaceReport -ComputerName "SQL01" -WarningPercent 70 -CriticalPercent 85

# Just the inventory
Get-ServerInventory -ComputerName "SERVER01"
```

## Example Output

**Server Inventory:**
```
ComputerName  OSName                    Manufacturer  Model            CPU                  RAM     UptimeDays
------------  ------                    ------------  -----            ---                  ---     ----------
DC01          Windows Server 2022 Std   Dell Inc.     PowerEdge R740   Xeon Gold 6248R      64 GB   45.2
SQL01         Windows Server 2022 Std   Dell Inc.     PowerEdge R750   Xeon Gold 6338       256 GB  12.8
```

**Disk Space:**
```
ComputerName  Drive  SizeGB  FreeGB  UsedPercent  Status
------------  -----  ------  ------  -----------  ------
SQL01         E:     500     22.5    95.5         Critical
EXCH01        D:     1000    45.0    95.5         Critical
FILE01        D:     4000    680.0   83.0         Warning
DC01          C:     100     52.3    47.7         OK
```

**HTML Dashboard:**

See [`Samples/sample-report.html`](Samples/sample-report.html) for the full dashboard with visual disk usage bars and color-coded alerts.

## Scheduling as a Daily Report

```powershell
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument @"
-NoProfile -Command "Import-Module C:\Scripts\Infra-HealthDashboard; Invoke-InfraHealthCheck -SendEmail -EmailTo team@contoso.com -EmailFrom monitor@contoso.com -SmtpServer smtp.contoso.com"
"@
$trigger = New-ScheduledTaskTrigger -Daily -At 7am
Register-ScheduledTask -TaskName "DailyInfraHealth" -Action $action -Trigger $trigger -User "SYSTEM"
```

## Installation

```powershell
Copy-Item -Path .\Infra-HealthDashboard -Destination "$env:USERPROFILE\Documents\PowerShell\Modules\" -Recurse
```

## Requirements

- PowerShell 5.1+
- CIM/WinRM access to target servers
- ActiveDirectory module (optional -- for auto-discovery of server objects)

## Design Decisions

- **CIM over WMI** -- uses `Get-CimInstance` and `New-CimSession` instead of the deprecated `Get-WmiObject`. Single CIM session per server for efficiency (one connection, multiple queries).
- **Graceful degradation** -- offline servers are logged and reported in the dashboard, not thrown as terminating errors. The rest of the environment still gets checked.
- **Configurable thresholds** -- disk warning (default 80%) and critical (default 90%) are parameters, not hardcoded. Different environments have different standards.
- **Pending reboot detection** -- checks three sources: Component Based Servicing, Windows Update, and Pending File Rename Operations registry keys. Also enumerates pending update count and critical update count via COM.
- **Email delivery** -- `Send-MailMessage` with the HTML report as the body. Subject line includes the date for easy inbox filtering.
- **Pipeline support** -- all functions accept `-ComputerName` from pipeline, so you can pipe from `Get-ADComputer` or a text file.

## Project Structure

```
Infra-HealthDashboard/
├── Infra-HealthDashboard.psd1         # Module manifest
├── Infra-HealthDashboard.psm1         # Root module
├── Public/
│   ├── Invoke-InfraHealthCheck.ps1    # Orchestrator with email support
│   ├── Get-ServerInventory.ps1        # CIM-based hardware inventory
│   ├── Get-DiskSpaceReport.ps1        # Disk space with thresholds
│   ├── Get-ServiceHealthReport.ps1    # Service monitoring
│   └── Get-PendingUpdates.ps1         # Update and reboot detection
├── Private/
│   └── _New-InfraHealthHtml.ps1       # Dashboard HTML generator
├── Tests/
│   └── Infra-HealthDashboard.Tests.ps1 # Pester tests
└── Samples/
    └── sample-report.html              # Example dashboard output
```

## Running Tests

```powershell
Invoke-Pester .\Tests\ -Output Detailed
```

## License

MIT
