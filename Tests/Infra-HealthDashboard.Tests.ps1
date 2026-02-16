BeforeAll {
    $modulePath = Split-Path -Parent $PSScriptRoot
    Import-Module "$modulePath\Infra-HealthDashboard.psd1" -Force
}

Describe 'Infra-HealthDashboard Module' {

    Context 'Module Loading' {
        It 'Should import without errors' {
            { Import-Module "$PSScriptRoot\..\Infra-HealthDashboard.psd1" -Force } | Should -Not -Throw
        }

        It 'Should export exactly 5 public functions' {
            $commands = Get-Command -Module Infra-HealthDashboard
            $commands.Count | Should -Be 5
        }

        It 'Should export all expected functions' {
            $expected = @('Invoke-InfraHealthCheck', 'Get-ServerInventory', 'Get-DiskSpaceReport', 'Get-ServiceHealthReport', 'Get-PendingUpdates')
            foreach ($func in $expected) {
                Get-Command -Module Infra-HealthDashboard -Name $func | Should -Not -BeNullOrEmpty
            }
        }

        It 'Should not export private functions' {
            { Get-Command -Module Infra-HealthDashboard -Name _New-InfraHealthHtml -ErrorAction Stop } | Should -Throw
        }
    }

    Context 'Get-DiskSpaceReport Parameter Validation' {
        It 'Should have WarningPercent parameter' {
            (Get-Command Get-DiskSpaceReport).Parameters.ContainsKey('WarningPercent') | Should -BeTrue
        }

        It 'Should have CriticalPercent parameter' {
            (Get-Command Get-DiskSpaceReport).Parameters.ContainsKey('CriticalPercent') | Should -BeTrue
        }

        It 'Should accept pipeline input for ComputerName' {
            (Get-Command Get-DiskSpaceReport).Parameters['ComputerName'].Attributes.ValueFromPipeline | Should -Contain $true
        }

        It 'Should have Name alias for ComputerName' {
            (Get-Command Get-DiskSpaceReport).Parameters['ComputerName'].Aliases | Should -Contain 'Name'
        }
    }

    Context 'Get-DiskSpaceReport Mocked Execution' {
        BeforeAll {
            Mock -ModuleName Infra-HealthDashboard Get-CimInstance {
                @(
                    [PSCustomObject]@{
                        DeviceID   = 'C:'
                        VolumeName = 'System'
                        Size       = 107374182400   # 100 GB
                        FreeSpace  = 10737418240    # 10 GB = 90% used
                        DriveType  = 3
                    },
                    [PSCustomObject]@{
                        DeviceID   = 'D:'
                        VolumeName = 'Data'
                        Size       = 536870912000   # 500 GB
                        FreeSpace  = 375809638400   # 350 GB = 30% used
                        DriveType  = 3
                    }
                )
            }
        }

        It 'Should return objects for each disk' {
            $results = Get-DiskSpaceReport -ComputerName 'TESTSERVER'
            $results.Count | Should -Be 2
        }

        It 'Should calculate UsedPercent correctly' {
            $results = Get-DiskSpaceReport -ComputerName 'TESTSERVER'
            $cDrive = $results | Where-Object Drive -eq 'C:'
            $cDrive.UsedPercent | Should -Be 90.0
        }

        It 'Should flag Critical when above CriticalPercent' {
            $results = Get-DiskSpaceReport -ComputerName 'TESTSERVER' -CriticalPercent 85
            $cDrive = $results | Where-Object Drive -eq 'C:'
            $cDrive.Status | Should -Be 'Critical'
        }

        It 'Should flag Warning when above WarningPercent but below CriticalPercent' {
            $results = Get-DiskSpaceReport -ComputerName 'TESTSERVER' -WarningPercent 85 -CriticalPercent 95
            $cDrive = $results | Where-Object Drive -eq 'C:'
            $cDrive.Status | Should -Be 'Warning'
        }

        It 'Should flag OK when below WarningPercent' {
            $results = Get-DiskSpaceReport -ComputerName 'TESTSERVER'
            $dDrive = $results | Where-Object Drive -eq 'D:'
            $dDrive.Status | Should -Be 'OK'
        }

        It 'Should convert sizes to GB' {
            $results = Get-DiskSpaceReport -ComputerName 'TESTSERVER'
            $cDrive = $results | Where-Object Drive -eq 'C:'
            $cDrive.SizeGB | Should -Be 100
            $cDrive.FreeGB | Should -Be 10
        }

        It 'Should uppercase the ComputerName' {
            $results = Get-DiskSpaceReport -ComputerName 'testserver'
            $results[0].ComputerName | Should -BeExactly 'TESTSERVER'
        }
    }

    Context 'Get-ServerInventory Parameter Validation' {
        It 'Should accept pipeline input' {
            (Get-Command Get-ServerInventory).Parameters['ComputerName'].Attributes.ValueFromPipeline | Should -Contain $true
        }

        It 'Should have Name alias for ComputerName' {
            (Get-Command Get-ServerInventory).Parameters['ComputerName'].Aliases | Should -Contain 'Name'
        }
    }

    Context 'Get-ServiceHealthReport Parameter Validation' {
        It 'Should accept ComputerName parameter' {
            (Get-Command Get-ServiceHealthReport).Parameters.ContainsKey('ComputerName') | Should -BeTrue
        }

        It 'Should accept ServiceName parameter' {
            (Get-Command Get-ServiceHealthReport).Parameters.ContainsKey('ServiceName') | Should -BeTrue
        }

        It 'Should have default list of critical services' {
            (Get-Command Get-ServiceHealthReport).Parameters['ServiceName'].Attributes |
                Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] } | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Invoke-InfraHealthCheck Parameter Validation' {
        It 'Should validate DiskWarningPercent range 1-99' {
            $validate = (Get-Command Invoke-InfraHealthCheck).Parameters['DiskWarningPercent'].Attributes |
                Where-Object { $_ -is [System.Management.Automation.ValidateRangeAttribute] }
            $validate | Should -Not -BeNullOrEmpty
        }

        It 'Should validate DiskCriticalPercent range 1-99' {
            $validate = (Get-Command Invoke-InfraHealthCheck).Parameters['DiskCriticalPercent'].Attributes |
                Where-Object { $_ -is [System.Management.Automation.ValidateRangeAttribute] }
            $validate | Should -Not -BeNullOrEmpty
        }

        It 'Should have SendEmail switch' {
            (Get-Command Invoke-InfraHealthCheck).Parameters['SendEmail'].SwitchParameter | Should -BeTrue
        }

        It 'Should require EmailTo when SendEmail is used' {
            $emailTo = (Get-Command Invoke-InfraHealthCheck).Parameters['EmailTo']
            $emailTo.ParameterSets['Email'].IsMandatory | Should -BeTrue
        }
    }

    Context 'HTML Report Generation' {
        It 'Should generate valid HTML dashboard' {
            $mockResults = @{
                Inventory = @(
                    [PSCustomObject]@{ ComputerName = 'DC01'; OSName = 'Windows Server 2022 Std'; Manufacturer = 'Dell'; Model = 'R740'; CPU = 'Xeon'; RAMInstalledGB = 64; UptimeDays = 45 }
                )
                DiskSpace = @(
                    [PSCustomObject]@{ ComputerName = 'DC01'; Drive = 'C:'; SizeGB = 100; FreeGB = 52; UsedPercent = 48; Status = 'OK' }
                )
                Services = @()
                Offline  = [System.Collections.Generic.List[string]]::new()
            }

            $html = & (Get-Module Infra-HealthDashboard) {
                param($results)
                _New-InfraHealthHtml -Results $results -DiskWarning 80 -DiskCritical 90
            } $mockResults

            $html | Should -Match '<!DOCTYPE html>'
            $html | Should -Match 'Infrastructure Health Dashboard'
            $html | Should -Match 'DC01'
        }
    }
}
