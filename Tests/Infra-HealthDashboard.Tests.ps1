BeforeAll {
    $modulePath = Split-Path -Parent $PSScriptRoot
    Import-Module "$modulePath\Infra-HealthDashboard.psd1" -Force
}

Describe 'Infra-HealthDashboard Module' {
    Context 'Module Loading' {
        It 'Should import without errors' {
            { Import-Module "$PSScriptRoot\..\Infra-HealthDashboard.psd1" -Force } | Should -Not -Throw
        }

        It 'Should export Invoke-InfraHealthCheck' {
            Get-Command -Module Infra-HealthDashboard -Name Invoke-InfraHealthCheck | Should -Not -BeNullOrEmpty
        }

        It 'Should export Get-ServerInventory' {
            Get-Command -Module Infra-HealthDashboard -Name Get-ServerInventory | Should -Not -BeNullOrEmpty
        }

        It 'Should export Get-DiskSpaceReport' {
            Get-Command -Module Infra-HealthDashboard -Name Get-DiskSpaceReport | Should -Not -BeNullOrEmpty
        }

        It 'Should export Get-ServiceHealthReport' {
            Get-Command -Module Infra-HealthDashboard -Name Get-ServiceHealthReport | Should -Not -BeNullOrEmpty
        }

        It 'Should export Get-PendingUpdates' {
            Get-Command -Module Infra-HealthDashboard -Name Get-PendingUpdates | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Get-DiskSpaceReport' {
        It 'Should have WarningPercent parameter' {
            (Get-Command Get-DiskSpaceReport).Parameters.ContainsKey('WarningPercent') | Should -BeTrue
        }

        It 'Should have CriticalPercent parameter' {
            (Get-Command Get-DiskSpaceReport).Parameters.ContainsKey('CriticalPercent') | Should -BeTrue
        }

        It 'Should accept pipeline input for ComputerName' {
            (Get-Command Get-DiskSpaceReport).Parameters['ComputerName'].Attributes.ValueFromPipeline | Should -Contain $true
        }
    }

    Context 'Get-ServerInventory' {
        It 'Should accept pipeline input' {
            (Get-Command Get-ServerInventory).Parameters['ComputerName'].Attributes.ValueFromPipeline | Should -Contain $true
        }
    }

    Context 'Invoke-InfraHealthCheck' {
        It 'Should validate DiskWarningPercent range' {
            $validate = (Get-Command Invoke-InfraHealthCheck).Parameters['DiskWarningPercent'].Attributes |
                Where-Object { $_ -is [System.Management.Automation.ValidateRangeAttribute] }
            $validate | Should -Not -BeNullOrEmpty
        }
    }
}
