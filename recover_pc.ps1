#==============================================================================
# RECOVER_PC.ps1 — Emergency Recovery (runs from normal Windows or via PsExec)
# Cleans all user hives via HKEY_USERS, kills HTA, restarts Explorer
# NOTE: This does NOT work from WinRE — see DEPLOYMENT_GUIDE for WinRE commands
#==============================================================================

# --- Clean all user hives ---
$userProfiles = Get-ChildItem "Registry::HKEY_USERS" -ErrorAction SilentlyContinue | Where-Object {
    $_.Name -match 'S-1-5-21-' -and $_.Name -notmatch '_Classes$'
}

foreach ($profile in $userProfiles) {
    $sid = $profile.PSChildName

    Remove-ItemProperty -Path "Registry::HKEY_USERS\$sid\Software\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "Shell" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path "Registry::HKEY_USERS\$sid\Software\Microsoft\Windows\CurrentVersion\Policies\System" -Name "DisableTaskMgr" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path "Registry::HKEY_USERS\$sid\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "NoLogoff" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path "Registry::HKEY_USERS\$sid\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "NoChangeStartMenu" -ErrorAction SilentlyContinue

    Write-Host "[+] User $sid cleaned" -ForegroundColor Green
}

# --- Kill HTA and restart Explorer ---
Stop-Process -Name mshta -Force -ErrorAction SilentlyContinue
Start-Process explorer.exe
Write-Host "[+] Explorer restarted" -ForegroundColor Green

# --- Remove scheduled task and files ---
Unregister-ScheduledTask -TaskName "CyberExercise_Lockout" -Confirm:$false -ErrorAction SilentlyContinue
Remove-Item -Path "C:\CyberExercise" -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "[+] Task and files removed" -ForegroundColor Green

Write-Host "`n[*] PC RECOVERED" -ForegroundColor Green
