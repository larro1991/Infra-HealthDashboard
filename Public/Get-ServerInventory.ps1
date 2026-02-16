function Get-ServerInventory {
    <#
    .SYNOPSIS
        Collects hardware and OS inventory from a Windows server using CIM.

    .DESCRIPTION
        Gathers OS, CPU, RAM, disk, manufacturer, model, serial number, and uptime
        using CIM (not legacy WMI). Single CIM session per server for efficiency.

    .PARAMETER ComputerName
        The server to inventory. Defaults to the local computer.

    .EXAMPLE
        Get-ServerInventory -ComputerName "SERVER01"

    .EXAMPLE
        "SERVER01","SERVER02" | ForEach-Object { Get-ServerInventory -ComputerName $_ }
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('Name')]
        [string]$ComputerName = $env:COMPUTERNAME
    )

    process {
        try {
            $cimSession = New-CimSession -ComputerName $ComputerName -ErrorAction Stop

            $os   = Get-CimInstance -CimSession $cimSession -ClassName Win32_OperatingSystem
            $cs   = Get-CimInstance -CimSession $cimSession -ClassName Win32_ComputerSystem
            $cpu  = Get-CimInstance -CimSession $cimSession -ClassName Win32_Processor | Select-Object -First 1
            $bios = Get-CimInstance -CimSession $cimSession -ClassName Win32_BIOS

            $uptime = (Get-Date) - $os.LastBootUpTime

            [PSCustomObject]@{
                ComputerName  = $ComputerName.ToUpper()
                OSName        = $os.Caption -replace 'Microsoft ', ''
                OSVersion     = $os.Version
                Architecture  = $os.OSArchitecture
                Manufacturer  = $cs.Manufacturer
                Model         = $cs.Model
                SerialNumber  = $bios.SerialNumber
                CPU           = $cpu.Name.Trim()
                CPUCores      = $cpu.NumberOfCores
                RAMInstalledGB = [math]::Round($cs.TotalPhysicalMemory / 1GB, 1)
                LastBoot      = $os.LastBootUpTime
                UptimeDays    = [math]::Round($uptime.TotalDays, 1)
                Status        = 'Online'
            }

            Remove-CimSession $cimSession
        }
        catch {
            Write-Warning "Failed to inventory $ComputerName : $_"
            [PSCustomObject]@{
                ComputerName  = $ComputerName.ToUpper()
                OSName        = $null
                OSVersion     = $null
                Architecture  = $null
                Manufacturer  = $null
                Model         = $null
                SerialNumber  = $null
                CPU           = $null
                CPUCores      = $null
                RAMInstalledGB = $null
                LastBoot      = $null
                UptimeDays    = $null
                Status        = "Error: $_"
            }
        }
    }
}
