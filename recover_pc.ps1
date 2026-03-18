#==============================================================================
# RECOVER_PC.ps1 — Emergency Recovery / Instructor Answer Key
# Undoes everything lockout_pc.ps1 did (HKLM + per-user)
#==============================================================================

$shellReg = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"

# --- Restore original shell (HKLM) ---
$backup = (Get-ItemProperty -Path $shellReg -Name "Shell_Backup" -ErrorAction SilentlyContinue).Shell_Backup
if ($backup) {
    Set-ItemProperty -Path $shellReg -Name "Shell" -Value $backup -Type String
    Remove-ItemProperty -Path $shellReg -Name "Shell_Backup" -ErrorAction SilentlyContinue
} else {
    Set-ItemProperty -Path $shellReg -Name "Shell" -Value "explorer.exe" -Type String
}
Write-Host "[+] Shell restored (HKLM)" -ForegroundColor Green

# --- Re-enable Task Manager (HKLM) ---
Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "DisableTaskMgr" -ErrorAction SilentlyContinue
Write-Host "[+] Task Manager re-enabled (HKLM)" -ForegroundColor Green

# --- Re-enable explorer options (HKLM) ---
Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "NoLogoff" -ErrorAction SilentlyContinue
Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "NoChangeStartMenu" -ErrorAction SilentlyContinue
Write-Host "[+] Ctrl+Alt+Del options restored (HKLM)" -ForegroundColor Green

# --- Clean up per-user entries (HKEY_USERS) ---
$loadedProfiles = Get-ChildItem "Registry::HKEY_USERS" -ErrorAction SilentlyContinue | Where-Object {
    $_.Name -match 'S-1-5-21-' -and $_.Name -notmatch '_Classes$'
}

foreach ($profile in $loadedProfiles) {
    $sid = $profile.PSChildName

    Remove-ItemProperty -Path "Registry::HKEY_USERS\$sid\Software\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "Shell" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path "Registry::HKEY_USERS\$sid\Software\Microsoft\Windows\CurrentVersion\Policies\System" -Name "DisableTaskMgr" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path "Registry::HKEY_USERS\$sid\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "NoLogoff" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path "Registry::HKEY_USERS\$sid\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "NoChangeStartMenu" -ErrorAction SilentlyContinue

    Write-Host "[+] User $sid cleaned" -ForegroundColor Green
}

# --- Kill lockscreen, restart Explorer ---
Stop-Process -Name mshta -Force -ErrorAction SilentlyContinue
Start-Process explorer.exe
Write-Host "[+] Explorer restarted" -ForegroundColor Green

# --- Remove scheduled task and files ---
Unregister-ScheduledTask -TaskName "CyberExercise_Lockout" -Confirm:$false -ErrorAction SilentlyContinue
Remove-Item -Path "C:\CyberExercise" -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "[+] Cleanup complete" -ForegroundColor Green

Write-Host ""
Write-Host "[*] PC FULLY RECOVERED" -ForegroundColor Green
