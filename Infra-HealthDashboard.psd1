@{
    RootModule        = 'Infra-HealthDashboard.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = 'd4e5f6a7-b8c9-0123-def0-123456789abc'
    Author            = 'Larry Roberts'
    CompanyName       = 'Independent Consultant'
    Copyright         = '(c) 2026 Larry Roberts. All rights reserved.'
    Description       = 'Windows server infrastructure health dashboard. Monitors disk space, services, uptime, pending updates, and event log errors with HTML email reporting.'

    PowerShellVersion = '5.1'

    FunctionsToExport = @(
        'Invoke-InfraHealthCheck',
        'Get-ServerInventory',
        'Get-DiskSpaceReport',
        'Get-ServiceHealthReport',
        'Get-PendingUpdates'
    )

    CmdletsToExport   = @()
    VariablesToExport  = @()
    AliasesToExport    = @()

    PrivateData = @{
        PSData = @{
            Tags       = @('Infrastructure', 'Monitoring', 'Health', 'Dashboard', 'ServerInventory', 'DiskSpace')
            ProjectUri = 'https://github.com/larro1991/Infra-HealthDashboard'
        }
    }
}
