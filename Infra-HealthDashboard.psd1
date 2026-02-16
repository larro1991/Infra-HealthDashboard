@{
    RootModule        = 'Infra-HealthDashboard.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = '7dfb54fd-26cd-4896-8df7-1e5dc79cf616'
    Author            = 'Larry Roberts'
    CompanyName       = 'Independent Consultant'
    Copyright         = '(c) 2026 Larry Roberts. All rights reserved.'
    Description       = 'Windows server infrastructure health dashboard. Monitors disk space, services, uptime, and pending updates via CIM. Generates color-coded HTML reports with optional email delivery.'

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
            LicenseUri = 'https://github.com/larro1991/Infra-HealthDashboard/blob/master/LICENSE'
            ProjectUri = 'https://github.com/larro1991/Infra-HealthDashboard'
        }
    }
}
