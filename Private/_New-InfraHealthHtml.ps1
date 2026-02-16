function _New-InfraHealthHtml {
    param(
        [hashtable]$Results,
        [int]$DiskWarning,
        [int]$DiskCritical
    )

    $css = @"
    <style>
        body { font-family: Segoe UI, Arial, sans-serif; margin: 20px; background: #f5f5f5; }
        h1 { color: #2c3e50; border-bottom: 3px solid #27ae60; padding-bottom: 10px; }
        h2 { color: #34495e; margin-top: 30px; border-bottom: 1px solid #bdc3c7; padding-bottom: 5px; }
        .meta { color: #7f8c8d; margin-bottom: 20px; }
        .dashboard { display: flex; gap: 15px; flex-wrap: wrap; margin-bottom: 20px; }
        .card { background: #fff; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); min-width: 150px; text-align: center; }
        .card .number { font-size: 36px; font-weight: bold; }
        .card .label { color: #7f8c8d; font-size: 12px; margin-top: 5px; }
        .card.danger .number { color: #e74c3c; }
        .card.warning .number { color: #e67e22; }
        .card.ok .number { color: #27ae60; }
        table { border-collapse: collapse; width: 100%; background: #fff; box-shadow: 0 1px 3px rgba(0,0,0,0.1); margin-bottom: 20px; }
        th { background: #27ae60; color: #fff; padding: 10px 8px; text-align: left; font-size: 11px; }
        td { padding: 8px; border-bottom: 1px solid #ecf0f1; font-size: 11px; }
        tr:nth-child(even) { background: #f9f9f9; }
        .critical { background: #fadbd8 !important; color: #c0392b; font-weight: bold; }
        .warning { background: #fdebd0 !important; color: #e67e22; }
        .offline { background: #f5b7b1 !important; }
        .bar { height: 18px; border-radius: 3px; display: inline-block; }
        .bar-bg { background: #ecf0f1; width: 100px; display: inline-block; border-radius: 3px; }
        .bar-fill-ok { background: #27ae60; }
        .bar-fill-warn { background: #e67e22; }
        .bar-fill-crit { background: #e74c3c; }
    </style>
"@

    $onlineCount = $Results.Inventory.Count
    $offlineCount = $Results.Offline.Count
    $criticalDisks = @($Results.DiskSpace | Where-Object Status -eq 'Critical').Count
    $warningDisks = @($Results.DiskSpace | Where-Object Status -eq 'Warning').Count
    $stoppedSvc = @($Results.Services | Where-Object NeedsAttention -eq $true).Count

    # Inventory rows
    $invRows = ($Results.Inventory | ForEach-Object {
        "<tr><td>$($_.ComputerName)</td><td>$($_.OSName)</td><td>$($_.Manufacturer)</td><td>$($_.Model)</td><td>$($_.CPU)</td><td>$($_.RAMInstalledGB) GB</td><td>$($_.UptimeDays) days</td></tr>"
    }) -join "`n"

    # Offline rows
    $offlineRows = ($Results.Offline | ForEach-Object {
        "<tr class='offline'><td>$_</td><td colspan='6'>OFFLINE - Cannot connect</td></tr>"
    }) -join "`n"

    # Disk rows with visual bars
    $diskRows = ($Results.DiskSpace | Sort-Object UsedPercent -Descending | ForEach-Object {
        $rowClass = switch ($_.Status) { 'Critical' { " class='critical'" }; 'Warning' { " class='warning'" }; default { '' } }
        $barClass = switch ($_.Status) { 'Critical' { 'bar-fill-crit' }; 'Warning' { 'bar-fill-warn' }; default { 'bar-fill-ok' } }
        $barWidth = [math]::Min($_.UsedPercent, 100)
        "<tr$rowClass><td>$($_.ComputerName)</td><td>$($_.Drive)</td><td>$($_.SizeGB) GB</td><td>$($_.FreeGB) GB</td><td><div class='bar-bg'><div class='bar $barClass' style='width:${barWidth}px'></div></div> $($_.UsedPercent)%</td><td>$($_.Status)</td></tr>"
    }) -join "`n"

    # Service rows
    $svcRows = ($Results.Services | Where-Object NeedsAttention -eq $true | ForEach-Object {
        "<tr class='critical'><td>$($_.ComputerName)</td><td>$($_.DisplayName)</td><td>$($_.Status)</td><td>$($_.StartMode)</td></tr>"
    }) -join "`n"

    @"
<!DOCTYPE html>
<html>
<head><title>Infrastructure Health Dashboard</title>$css</head>
<body>
    <h1>Infrastructure Health Dashboard</h1>
    <div class="meta">Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm') | Thresholds: Warning ${DiskWarning}% / Critical ${DiskCritical}%</div>

    <div class="dashboard">
        <div class="card ok"><div class="number">$onlineCount</div><div class="label">Servers Online</div></div>
        <div class="card $(if($offlineCount -gt 0){'danger'}else{'ok'})"><div class="number">$offlineCount</div><div class="label">Servers Offline</div></div>
        <div class="card $(if($criticalDisks -gt 0){'danger'}elseif($warningDisks -gt 0){'warning'}else{'ok'})"><div class="number">$criticalDisks</div><div class="label">Critical Disks</div></div>
        <div class="card $(if($stoppedSvc -gt 0){'danger'}else{'ok'})"><div class="number">$stoppedSvc</div><div class="label">Stopped Services</div></div>
    </div>

    <h2>Server Inventory</h2>
    <table>
        <tr><th>Server</th><th>OS</th><th>Manufacturer</th><th>Model</th><th>CPU</th><th>RAM</th><th>Uptime</th></tr>
        $invRows
        $offlineRows
    </table>

    <h2>Disk Space</h2>
    <table>
        <tr><th>Server</th><th>Drive</th><th>Size</th><th>Free</th><th>Used</th><th>Status</th></tr>
        $diskRows
    </table>

    $(if($stoppedSvc -gt 0){
    "<h2>Stopped Services (Needs Attention)</h2>
    <table>
        <tr><th>Server</th><th>Service</th><th>Status</th><th>Start Mode</th></tr>
        $svcRows
    </table>"
    })
</body>
</html>
"@
}
