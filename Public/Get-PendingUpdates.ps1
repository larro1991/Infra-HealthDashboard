function Get-PendingUpdates {
    <#
    .SYNOPSIS
        Checks for pending Windows updates on remote servers.

    .DESCRIPTION
        Uses CIM to detect pending reboot flags and the Windows Update COM object
        to enumerate pending updates.

    .PARAMETER ComputerName
        Server to check. Defaults to the local computer.

    .EXAMPLE
        Get-PendingUpdates -ComputerName "SERVER01"

    .EXAMPLE
        "SERVER01","SERVER02","SERVER03" | ForEach-Object { Get-PendingUpdates -ComputerName $_ }
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('Name')]
        [string]$ComputerName = $env:COMPUTERNAME
    )

    process {
        try {
            # Check pending reboot flags via registry
            $pendingReboot = Invoke-Command -ComputerName $ComputerName -ErrorAction Stop -ScriptBlock {
                $rebootPending = $false
                $reasons = @()

                # Component Based Servicing
                if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') {
                    $rebootPending = $true
                    $reasons += 'CBS'
                }

                # Windows Update
                if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') {
                    $rebootPending = $true
                    $reasons += 'WindowsUpdate'
                }

                # Pending file rename operations
                $pfro = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name PendingFileRenameOperations -ErrorAction SilentlyContinue
                if ($pfro.PendingFileRenameOperations) {
                    $rebootPending = $true
                    $reasons += 'FileRename'
                }

                # Get pending update count via COM
                try {
                    $updateSession = New-Object -ComObject Microsoft.Update.Session
                    $searcher = $updateSession.CreateUpdateSearcher()
                    $searchResult = $searcher.Search("IsInstalled=0")
                    $pendingCount = $searchResult.Updates.Count
                    $criticalCount = @($searchResult.Updates | Where-Object { $_.MsrcSeverity -eq 'Critical' }).Count
                }
                catch {
                    $pendingCount = -1
                    $criticalCount = -1
                }

                [PSCustomObject]@{
                    RebootPending  = $rebootPending
                    RebootReasons  = $reasons -join '; '
                    PendingUpdates = $pendingCount
                    CriticalUpdates = $criticalCount
                }
            }

            [PSCustomObject]@{
                ComputerName    = $ComputerName.ToUpper()
                PendingUpdates  = $pendingReboot.PendingUpdates
                CriticalUpdates = $pendingReboot.CriticalUpdates
                RebootPending   = $pendingReboot.RebootPending
                RebootReasons   = $pendingReboot.RebootReasons
                Status          = if ($pendingReboot.CriticalUpdates -gt 0) { 'Critical' }
                                  elseif ($pendingReboot.RebootPending) { 'RebootNeeded' }
                                  elseif ($pendingReboot.PendingUpdates -gt 0) { 'UpdatesAvailable' }
                                  else { 'Current' }
            }
        }
        catch {
            Write-Warning "Failed to check updates on $ComputerName : $_"
            [PSCustomObject]@{
                ComputerName    = $ComputerName.ToUpper()
                PendingUpdates  = $null
                CriticalUpdates = $null
                RebootPending   = $null
                RebootReasons   = $null
                Status          = "Error: $_"
            }
        }
    }
}
