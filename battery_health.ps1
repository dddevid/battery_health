[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$lang = (Get-Culture).TwoLetterISOLanguageName
$isIt = ($lang -eq 'it')

$T = @{
    Title        = if ($isIt) { "STATO DELLA BATTERIA" } else { "BATTERY HEALTH REPORT" }
    MaxCap       = if ($isIt) { "Capacita massima" } else { "Maximum Capacity" }
    Condition    = if ($isIt) { "Stato generale" } else { "Condition" }
    Cycles       = if ($isIt) { "Cicli di ricarica" } else { "Cycle Count" }
    Current      = if ($isIt) { "Carica attuale" } else { "Current Charge" }
    DesignCap    = if ($isIt) { "Capacita nominale" } else { "Design Capacity" }
    FullCap      = if ($isIt) { "Piena carica" } else { "Full Charge Capacity" }
    Device       = if ($isIt) { "Dispositivo" } else { "Device" }
    Chemistry    = if ($isIt) { "Chimica" } else { "Chemistry" }
    Normal       = if ($isIt) { "Normale" } else { "Normal" }
    Service      = if ($isIt) { "Assistenza consigliata" } else { "Service Recommended" }
    StatusDis    = if ($isIt) { "In scarica" } else { "Discharging" }
    StatusChg    = if ($isIt) { "In carica / Alimentata" } else { "Charging / AC Power" }
    StatusFull   = if ($isIt) { "Completamente carica" } else { "Fully Charged" }
    StatusUnk    = if ($isIt) { "Sconosciuto" } else { "Unknown" }
    NoBattery    = if ($isIt) { "Nessuna batteria rilevata." } else { "No battery detected." }
    ErrReport    = if ($isIt) { "Errore nella generazione del report." } else { "Failed to generate report." }
}

$tempReport = "$env:TEMP\bat_rep_$PID.xml"
powercfg /batteryreport /xml /output $tempReport | Out-Null

if (-not (Test-Path $tempReport)) {
    Write-Host "`n [!] $($T.ErrReport)`n" -ForegroundColor Red
    exit
}

[xml]$xml = Get-Content $tempReport
Remove-Item $tempReport -Force -ErrorAction SilentlyContinue

$bat = $xml.BatteryReport.Batteries.Battery | Select-Object -First 1
if (-not $bat) {
    Write-Host "`n [!] $($T.NoBattery)`n" -ForegroundColor Yellow
    exit
}

$design = [double]$bat.DesignCapacity
$full   = [double]$bat.FullChargeCapacity
$cycles = if ($bat.CycleCount) { $bat.CycleCount } else { "N/D" }
$health = [math]::Round(($full / $design) * 100, 1)

$condText = if ($health -ge 80) { $T.Normal } else { $T.Service }
$condColor = if ($health -ge 80) { "Green" } else { "Yellow" }

$live = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue
$currPct = if ($live) { $live.EstimatedChargeRemaining } else { 0 }
$statusText = switch ($live.BatteryStatus) {
    1 { $T.StatusDis }
    2 { $T.StatusChg }
    3 { $T.StatusFull }
    default { $T.StatusUnk }
}

$boxTL = [char]0x250C
$boxTR = [char]0x2510
$boxBL = [char]0x2514
$boxBR = [char]0x2518
$boxH  = [char]0x2500
$boxV  = [char]0x2502
$boxML = [char]0x251C
$boxMR = [char]0x2524
$barF  = [char]0x2588
$barE  = [char]0x2591

$barFilled = [math]::Max(0, [math]::Min(20, [math]::Round($health / 5)))
$barEmpty  = 20 - $barFilled
$bar = ("$barF" * $barFilled) + ("$barE" * $barEmpty)

# ─── LAYOUT E STAMPA RIGOROSAMENTE MATEMATICA ───
$innerW  = 56
$lineSep = "$boxH" * $innerW

Write-Host ""
Write-Host " $boxTL$lineSep$boxTR" -ForegroundColor Cyan

Write-Host " $boxV " -NoNewline -ForegroundColor Cyan
Write-Host "$($T.Title.PadRight(54))" -NoNewline -ForegroundColor White
Write-Host " $boxV" -ForegroundColor Cyan

Write-Host " $boxML$lineSep$boxMR" -ForegroundColor Cyan

$barStr = "$([math]::Round($health))% [$bar]"
Write-Host " $boxV  " -NoNewline -ForegroundColor Cyan
Write-Host "$($T.MaxCap.PadRight(20))" -NoNewline -ForegroundColor DarkGray
Write-Host " : " -NoNewline -ForegroundColor DarkGray
Write-Host "$($barStr.PadRight(30))" -NoNewline -ForegroundColor $condColor
Write-Host " $boxV" -ForegroundColor Cyan

Write-Host " $boxV  " -NoNewline -ForegroundColor Cyan
Write-Host "$($T.Condition.PadRight(20))" -NoNewline -ForegroundColor DarkGray
Write-Host " : " -NoNewline -ForegroundColor DarkGray
Write-Host "$($condText.PadRight(30))" -NoNewline -ForegroundColor $condColor
Write-Host " $boxV" -ForegroundColor Cyan

Write-Host " $boxV  " -NoNewline -ForegroundColor Cyan
Write-Host "$($T.Cycles.PadRight(20))" -NoNewline -ForegroundColor DarkGray
Write-Host " : " -NoNewline -ForegroundColor DarkGray
Write-Host "$("$cycles".PadRight(30))" -NoNewline -ForegroundColor White
Write-Host " $boxV" -ForegroundColor Cyan

Write-Host " $boxML$lineSep$boxMR" -ForegroundColor Cyan

$currStr = "$currPct% ($statusText)"
if ($currStr.Length -gt 30) { $currStr = $currStr.Substring(0, 27) + "..." }
Write-Host " $boxV  " -NoNewline -ForegroundColor Cyan
Write-Host "$($T.Current.PadRight(20))" -NoNewline -ForegroundColor DarkGray
Write-Host " : " -NoNewline -ForegroundColor DarkGray
Write-Host "$($currStr.PadRight(30))" -NoNewline -ForegroundColor White
Write-Host " $boxV" -ForegroundColor Cyan

Write-Host " $boxV  " -NoNewline -ForegroundColor Cyan
Write-Host "$($T.FullCap.PadRight(20))" -NoNewline -ForegroundColor DarkGray
Write-Host " : " -NoNewline -ForegroundColor DarkGray
Write-Host "$("$([int]$full) mWh".PadRight(30))" -NoNewline -ForegroundColor White
Write-Host " $boxV" -ForegroundColor Cyan

Write-Host " $boxV  " -NoNewline -ForegroundColor Cyan
Write-Host "$($T.DesignCap.PadRight(20))" -NoNewline -ForegroundColor DarkGray
Write-Host " : " -NoNewline -ForegroundColor DarkGray
Write-Host "$("$([int]$design) mWh".PadRight(30))" -NoNewline -ForegroundColor White
Write-Host " $boxV" -ForegroundColor Cyan

$hwInfo = "$($bat.Manufacturer) $($bat.DeviceName)".Trim()
if ($hwInfo.Length -gt 30) { $hwInfo = $hwInfo.Substring(0, 27) + "..." }
Write-Host " $boxV  " -NoNewline -ForegroundColor Cyan
Write-Host "$($T.Device.PadRight(20))" -NoNewline -ForegroundColor DarkGray
Write-Host " : " -NoNewline -ForegroundColor DarkGray
Write-Host "$($hwInfo.PadRight(30))" -NoNewline -ForegroundColor White
Write-Host " $boxV" -ForegroundColor Cyan

$chem = "$($bat.Chemistry)".Trim()
if ($chem.Length -gt 30) { $chem = $chem.Substring(0, 27) + "..." }
Write-Host " $boxV  " -NoNewline -ForegroundColor Cyan
Write-Host "$($T.Chemistry.PadRight(20))" -NoNewline -ForegroundColor DarkGray
Write-Host " : " -NoNewline -ForegroundColor DarkGray
Write-Host "$($chem.PadRight(30))" -NoNewline -ForegroundColor White
Write-Host " $boxV" -ForegroundColor Cyan

Write-Host " $boxBL$lineSep$boxBR" -ForegroundColor Cyan
Write-Host ""
