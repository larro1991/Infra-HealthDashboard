# Infra-HealthDashboard

PowerShell module for Windows server infrastructure health monitoring. Generates color-coded HTML dashboards with email delivery support.

## What It Does

| Function | Purpose |
|----------|---------|
| `Invoke-InfraHealthCheck` | Run all checks and generate an HTML dashboard (with optional email) |
| `Get-ServerInventory` | Collect OS, CPU, RAM, manufacturer, model, uptime via CIM |
| `Get-DiskSpaceReport` | Report disk usage with configurable warning/critical thresholds |
| `Get-ServiceHealthReport` | Monitor critical Windows service status |
| `Get-PendingUpdates` | Check for pending Windows updates and reboot flags |

## Quick Start

```powershell
# Import the module
Import-Module .\Infra-HealthDashboard.psd1

# Check specific servers
Invoke-InfraHealthCheck -ComputerName "SERVER01","SERVER02","DC01"

# Auto-discover servers from AD and email the report
Invoke-InfraHealthCheck -SendEmail -EmailTo "team@contoso.com" -EmailFrom "monitor@contoso.com" -SmtpServer "smtp.contoso.com"

# Custom thresholds
Invoke-InfraHealthCheck -ComputerName "SQL01" -DiskWarningPercent 70 -DiskCriticalPercent 85

# Individual checks
Get-ServerInventory -ComputerName "SERVER01"
Get-DiskSpaceReport -ComputerName "SQL01" | Where-Object Status -ne 'OK'
Get-PendingUpdates -ComputerName "DC01"
```

## Scheduling as a Daily Report

```powershell
# Create a scheduled task for daily 7 AM reports
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument '-NoProfile -Command "Import-Module C:\Scripts\Infra-HealthDashboard; Invoke-InfraHealthCheck -SendEmail -EmailTo team@contoso.com -EmailFrom monitor@contoso.com -SmtpServer smtp.contoso.com"'
$trigger = New-ScheduledTaskTrigger -Daily -At 7am
Register-ScheduledTask -TaskName "DailyInfraHealth" -Action $action -Trigger $trigger -User "SYSTEM"
```

## Requirements

- PowerShell 5.1 or later
- CIM/WinRM access to target servers
- ActiveDirectory module (optional, for auto-discovery)

## Key Design Decisions

- **CIM over WMI**: Uses `Get-CimInstance` (modern) instead of `Get-WmiObject` (deprecated)
- **Single CIM session**: One session per server for efficiency
- **Graceful degradation**: Offline servers are reported, not errors
- **Pipeline support**: All functions accept `-ComputerName` from the pipeline

## Running Tests

```powershell
Invoke-Pester .\Tests\
```
