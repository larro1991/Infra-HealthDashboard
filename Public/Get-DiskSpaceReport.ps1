function Get-DiskSpaceReport {
    <#
    .SYNOPSIS
        Reports disk space usage with configurable warning/critical thresholds.

    .DESCRIPTION
        Queries fixed disk volumes via CIM and reports capacity, free space, and
        percent used. Each volume is flagged as OK, Warning, or Critical based
        on configurable thresholds.

    .PARAMETER ComputerName
        Server to check. Defaults to the local computer.

    .PARAMETER WarningPercent
        Usage percentage to trigger Warning status. Defaults to 80.

    .PARAMETER CriticalPercent
        Usage percentage to trigger Critical status. Defaults to 90.

    .EXAMPLE
        Get-DiskSpaceReport -ComputerName "SERVER01"

    .EXAMPLE
        Get-DiskSpaceReport -ComputerName "SERVER01" -WarningPercent 75 -CriticalPercent 85
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('Name')]
        [string]$ComputerName = $env:COMPUTERNAME,

        [int]$WarningPercent = 80,

        [int]$CriticalPercent = 90
    )

    process {
        try {
            $volumes = Get-CimInstance -ComputerName $ComputerName -ClassName Win32_LogicalDisk -Filter "DriveType=3" -ErrorAction Stop

            foreach ($vol in $volumes) {
                $usedPercent = if ($vol.Size -gt 0) {
                    [math]::Round((($vol.Size - $vol.FreeSpace) / $vol.Size) * 100, 1)
                }
                else { 0 }

                $status = if ($usedPercent -ge $CriticalPercent) { 'Critical' }
                          elseif ($usedPercent -ge $WarningPercent) { 'Warning' }
                          else { 'OK' }

                [PSCustomObject]@{
                    ComputerName  = $ComputerName.ToUpper()
                    Drive         = $vol.DeviceID
                    VolumeName    = $vol.VolumeName
                    SizeGB        = [math]::Round($vol.Size / 1GB, 1)
                    FreeGB        = [math]::Round($vol.FreeSpace / 1GB, 1)
                    UsedPercent   = $usedPercent
                    Status        = $status
                }
            }
        }
        catch {
            Write-Warning "Failed to get disk info for $ComputerName : $_"
            [PSCustomObject]@{
                ComputerName = $ComputerName.ToUpper()
                Drive        = $null
                VolumeName   = $null
                SizeGB       = $null
                FreeGB       = $null
                UsedPercent  = $null
                Status       = "Error: $_"
            }
        }
    }
}
