# RECOVER_PC.ps1 - Emergency Recovery v4
# Kills watchdog + HTA, cleans all user hives, restarts Explorer

# Kill watchdog and HTA first
Stop-Process -Name wscript -Force -ErrorAction SilentlyContinue
Stop-Process -Name mshta -Force -ErrorAction SilentlyContinue

# Clean all user hives
$profiles = Get-ChildItem "Registry::HKEY_USERS" -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'S-1-5-21-' -and $_.Name -notmatch '_Classes$' }

foreach ($p in $profiles) {
    $sid = $p.PSChildName
    $base = "Registry::HKEY_USERS\" + $sid

    Remove-ItemProperty -Path ($base + "\Software\Microsoft\Windows NT\CurrentVersion\Winlogon") -Name "Shell" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path ($base + "\Software\Microsoft\Windows\CurrentVersion\Policies\System") -Name "DisableTaskMgr" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path ($base + "\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer") -Name "NoRun" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path ($base + "\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer") -Name "NoLogoff" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path ($base + "\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer") -Name "NoChangeStartMenu" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path ($base + "\Software\Policies\Microsoft\Windows\System") -Name "DisableCMD" -ErrorAction SilentlyContinue

    Write-Host ("[+] User " + $sid + " cleaned") -ForegroundColor Green
}

# Restart Explorer
Start-Process explorer.exe
Write-Host "[+] Explorer restarted" -ForegroundColor Green

# Remove task and files
Unregister-ScheduledTask -TaskName "CyberExercise_Lockout" -Confirm:$false -ErrorAction SilentlyContinue
Remove-Item -Path "C:\CyberExercise" -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "[+] Files and task removed" -ForegroundColor Green

Write-Host "[*] PC RECOVERED" -ForegroundColor Green
