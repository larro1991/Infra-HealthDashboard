function Get-ServiceHealthReport {
    <#
    .SYNOPSIS
        Checks the status of critical Windows services on remote servers.

    .DESCRIPTION
        Queries specified services on target servers and reports their status.
        Services set to Automatic start that are not running are flagged.

    .PARAMETER ComputerName
        Server to check. Defaults to the local computer.

    .PARAMETER ServiceName
        One or more service names to check. Defaults to common infrastructure services.

    .EXAMPLE
        Get-ServiceHealthReport -ComputerName "SERVER01"

    .EXAMPLE
        Get-ServiceHealthReport -ComputerName "DC01" -ServiceName "NTDS","DNS","DFSR"
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('Name')]
        [string]$ComputerName = $env:COMPUTERNAME,

        [string[]]$ServiceName = @('DNS', 'NTDS', 'DFSR', 'W32Time', 'WinRM', 'Spooler', 'EventLog', 'LanmanServer')
    )

    process {
        foreach ($svc in $ServiceName) {
            try {
                $service = Get-CimInstance -ComputerName $ComputerName -ClassName Win32_Service -Filter "Name='$svc'" -ErrorAction Stop

                if ($service) {
                    $shouldRun = $service.StartMode -eq 'Auto'
                    $isRunning = $service.State -eq 'Running'
                    $needsAttention = $shouldRun -and -not $isRunning

                    [PSCustomObject]@{
                        ComputerName   = $ComputerName.ToUpper()
                        ServiceName    = $service.Name
                        DisplayName    = $service.DisplayName
                        Status         = $service.State
                        StartMode      = $service.StartMode
                        NeedsAttention = $needsAttention
                    }
                }
                # Service not installed on this server - skip silently
            }
            catch {
                Write-Verbose "Could not check service $svc on $ComputerName : $_"
            }
        }
    }
}
