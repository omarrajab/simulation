# Cyber Exercise — Deployment Guide (Windows 10)

## What Changed (v2 Fix)

The original script used `HKCU:\` registry paths. When running as SYSTEM (via scheduled task), HKCU points to SYSTEM's registry — not the student's. The fix:

- **HKLM** (machine-wide) registry keys → affects ALL users regardless of who runs the script
- **HKEY_USERS\<SID>** per-user entries → catches the currently logged-in student's session
- **Session-aware HTA launch** → pushes the lockscreen into the active user's desktop session

---

## Quick Start

### 1. Edit IPs
Open `deploy_all.ps1`, change the `$TargetPCs` list to your 7 PC IPs.

### 2. Deploy
```powershell
.\deploy_all.ps1 -Username "Administrator" -Password "YourPassword"
```

### 3. At 14:30 — all PCs lock automatically

### 4. If needed — emergency recovery
```powershell
.\deploy_all.ps1 -Action recover -Username "Administrator" -Password "YourPassword"
```

---

## Single PC Test

To test on one PC before the exercise:

**Lock it:**
```powershell
# Run as Administrator on the test PC
Set-ExecutionPolicy Bypass -Scope Process
.\lockout_pc.ps1
```

**Recover it (Safe Mode):**
```cmd
reg delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v Shell_Backup /f
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v Shell /t REG_SZ /d explorer.exe /f
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v DisableTaskMgr /f
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoLogoff /f
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoChangeStartMenu /f
schtasks /delete /tn CyberExercise_Lockout /f
rmdir /s /q C:\CyberExercise
shutdown /r /t 0
```

---

## Recovery Path for IT Students

Students need to figure this out themselves. Expected steps:

1. **Boot into Safe Mode** — force-shutdown 3 times to trigger Recovery → Safe Mode with Command Prompt
2. **Fix shell (HKLM):**
   ```cmd
   reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v Shell /t REG_SZ /d explorer.exe /f
   ```
3. **Re-enable Task Manager:**
   ```cmd
   reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v DisableTaskMgr /f
   ```
4. **Remove scheduled task:**
   ```cmd
   schtasks /delete /tn CyberExercise_Lockout /f
   ```
5. **Clean up:**
   ```cmd
   rmdir /s /q C:\CyberExercise
   ```
6. **Reboot:**
   ```cmd
   shutdown /r /t 0
   ```

---

## All Commands Summary

| Command | Effect |
|---------|--------|
| `.\deploy_all.ps1` | Arm all 7 PCs for 14:30 today |
| `.\deploy_all.ps1 -AttackTime "15:00"` | Custom time |
| `.\deploy_all.ps1 -AttackDate "2026-03-20"` | Custom date |
| `.\deploy_all.ps1 -Action trigger` | Fire NOW on all PCs |
| `.\deploy_all.ps1 -Action cancel` | Abort before trigger |
| `.\deploy_all.ps1 -Action recover` | Emergency undo all PCs |

Always add `-Username "Admin" -Password "Pass"` if not domain-joined.
