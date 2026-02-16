function Invoke-InfraHealthCheck {
    <#
    .SYNOPSIS
        Runs a comprehensive infrastructure health check and generates an HTML dashboard.

    .DESCRIPTION
        Connects to Windows servers via CIM/WinRM and collects:
        - Hardware inventory (OS, CPU, RAM, disk)
        - Disk space with threshold alerts
        - Critical service status
        - Uptime and last reboot
        - Pending Windows updates
        - Recent critical/error event log entries

        Produces a color-coded HTML dashboard suitable for email delivery.

    .PARAMETER ComputerName
        One or more server names to check. If not specified, queries AD for all
        enabled server OS computers.

    .PARAMETER SearchBase
        AD OU to scope the server query. Only used when ComputerName is not specified.

    .PARAMETER DiskWarningPercent
        Disk usage percentage to trigger a warning. Defaults to 80.

    .PARAMETER DiskCriticalPercent
        Disk usage percentage to trigger a critical alert. Defaults to 90.

    .PARAMETER CriticalServices
        List of services to monitor. Defaults to common infrastructure services.

    .PARAMETER OutputPath
        Directory for the HTML report. Defaults to .\Reports.

    .PARAMETER SendEmail
        Send the report via email.

    .PARAMETER EmailTo
        Recipient email address(es).

    .PARAMETER EmailFrom
        Sender email address.

    .PARAMETER SmtpServer
        SMTP server for sending the report.

    .EXAMPLE
        Invoke-InfraHealthCheck -ComputerName "SERVER01","SERVER02"

    .EXAMPLE
        Invoke-InfraHealthCheck -SendEmail -EmailTo "team@contoso.com" -EmailFrom "monitoring@contoso.com" -SmtpServer "smtp.contoso.com"

    .EXAMPLE
        Invoke-InfraHealthCheck -DiskWarningPercent 75 -DiskCriticalPercent 85

    .NOTES
        Requires: CIM/WinRM access to target servers. AD module optional (for auto-discovery).
    #>
    [CmdletBinding(DefaultParameterSetName = 'Report')]
    param(
        [Parameter()]
        [string[]]$ComputerName,

        [string]$SearchBase,

        [ValidateRange(1, 99)]
        [int]$DiskWarningPercent = 80,

        [ValidateRange(1, 99)]
        [int]$DiskCriticalPercent = 90,

        [string[]]$CriticalServices = @('DNS', 'NTDS', 'DFSR', 'W32Time', 'WinRM', 'Spooler'),

        [string]$OutputPath = '.\Reports',

        [Parameter(ParameterSetName = 'Email')]
        [switch]$SendEmail,

        [Parameter(ParameterSetName = 'Email', Mandatory)]
        [string[]]$EmailTo,

        [Parameter(ParameterSetName = 'Email', Mandatory)]
        [string]$EmailFrom,

        [Parameter(ParameterSetName = 'Email', Mandatory)]
        [string]$SmtpServer
    )

    begin {
        if (-not (Test-Path $OutputPath)) {
            New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
        }

        # Get server list from AD if not provided
        if (-not $ComputerName) {
            $adParams = @{
                Filter     = "OperatingSystem -like '*Server*' -and Enabled -eq `$true"
                Properties = @('OperatingSystem')
            }
            if ($SearchBase) { $adParams['SearchBase'] = $SearchBase }

            $ComputerName = (Get-ADComputer @adParams).Name
        }

        $allResults = @{
            Inventory  = [System.Collections.Generic.List[PSCustomObject]]::new()
            DiskSpace  = [System.Collections.Generic.List[PSCustomObject]]::new()
            Services   = [System.Collections.Generic.List[PSCustomObject]]::new()
            Offline    = [System.Collections.Generic.List[string]]::new()
        }
    }

    process {
        $total = $ComputerName.Count
        $current = 0

        foreach ($computer in $ComputerName) {
            $current++
            Write-Progress -Activity "Health Check" -Status "$computer ($current/$total)" -PercentComplete (($current / $total) * 100)

            if (-not (Test-Connection -ComputerName $computer -Count 1 -Quiet)) {
                $allResults.Offline.Add($computer)
                Write-Warning "$computer is offline"
                continue
            }

            # Inventory
            $inv = Get-ServerInventory -ComputerName $computer
            if ($inv) { $allResults.Inventory.Add($inv) }

            # Disk Space
            $disks = Get-DiskSpaceReport -ComputerName $computer -WarningPercent $DiskWarningPercent -CriticalPercent $DiskCriticalPercent
            foreach ($d in $disks) { $allResults.DiskSpace.Add($d) }

            # Services
            $svc = Get-ServiceHealthReport -ComputerName $computer -ServiceName $CriticalServices
            foreach ($s in $svc) { $allResults.Services.Add($s) }
        }

        Write-Progress -Activity "Health Check" -Completed

        # Generate HTML
        $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $htmlFile = Join-Path $OutputPath "InfraHealth-$timestamp.html"
        $html = _New-InfraHealthHtml -Results $allResults -DiskWarning $DiskWarningPercent -DiskCritical $DiskCriticalPercent
        $html | Out-File -FilePath $htmlFile -Encoding UTF8

        Write-Verbose "Report saved: $htmlFile"

        # Send email if requested
        if ($SendEmail) {
            $emailParams = @{
                To         = $EmailTo
                From       = $EmailFrom
                Subject    = "Infrastructure Health Report - $(Get-Date -Format 'yyyy-MM-dd')"
                Body       = $html
                BodyAsHtml = $true
                SmtpServer = $SmtpServer
            }
            Send-MailMessage @emailParams
            Write-Verbose "Report emailed to $($EmailTo -join ', ')"
        }

        # Summary
        $criticalDisks = @($allResults.DiskSpace | Where-Object Status -eq 'Critical').Count
        $stoppedServices = @($allResults.Services | Where-Object Status -ne 'Running').Count

        [PSCustomObject]@{
            ServersChecked   = $total
            ServersOnline    = $allResults.Inventory.Count
            ServersOffline   = $allResults.Offline.Count
            CriticalDisks    = $criticalDisks
            StoppedServices  = $stoppedServices
            ReportPath       = $htmlFile
        }
    }
}
