# Run all Vivarium headless test harnesses. Requires Godot 4.7 on PATH
# (override with $env:GODOT). Usage:  powershell -ExecutionPolicy Bypass -File tools\run_tests.ps1
#
# Note: godot.exe is a GUI-subsystem binary, so PowerShell must launch it via
# Start-Process -Wait to actually wait for it and read its exit code.
$ErrorActionPreference = "Continue"
Set-Location (Join-Path $PSScriptRoot "..")
$godot = if ($env:GODOT) { $env:GODOT } else { (Get-Command godot -ErrorAction SilentlyContinue).Source }
if (-not $godot) { Write-Host "Godot NOT found on PATH. Set `$env:GODOT to the godot.exe path."; exit 1 }
Write-Host "Godot: $godot"

function Invoke-Godot([string[]]$godotArgs) {
    $o = [System.IO.Path]::GetTempFileName()
    $e = [System.IO.Path]::GetTempFileName()
    $p = Start-Process -FilePath $godot -ArgumentList $godotArgs -Wait -PassThru -NoNewWindow `
        -RedirectStandardOutput $o -RedirectStandardError $e
    $out = (Get-Content $o -Raw) + (Get-Content $e -Raw)
    Remove-Item $o, $e -ErrorAction SilentlyContinue
    return [pscustomobject]@{ Code = $p.ExitCode; Out = $out }
}

Write-Host "Building class cache..."
Invoke-Godot @("--headless", "--import") | Out-Null

$fails = 0
foreach ($h in @("phase1", "phase2", "phase3", "phase4", "phase6", "phase7")) {
    $r = Invoke-Godot @("--headless", "--path", ".", "--script", "res://test/${h}_harness.gd")
    $line = ($r.Out -split "`n" | Select-String "RESULT" | Select-Object -First 1)
    "{0,-8} exit={1}  {2}" -f $h, $r.Code, ("$line").Trim()
    if ($r.Code -ne 0) { $fails++ }
}
Write-Host "--------------------------------------"
if ($fails -eq 0) { Write-Host "ALL PASS" } else { Write-Host "$fails harness(es) FAILED" }
exit $fails
