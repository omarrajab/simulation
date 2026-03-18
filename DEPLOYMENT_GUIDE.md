# Cyber Exercise - Deployment Guide v4

## What's New in v4

- **Watchdog process** (VBScript) runs in background every 2 seconds, kills explorer, cmd, powershell, taskmgr, regedit, and relaunches HTA if closed
- **Win+R disabled** via NoRun registry
- **cmd.exe disabled** via DisableCMD registry
- **Win+L still works** so students can lock/unlock the PC
- Students literally cannot do anything except look at the red screen
- Only way out: WinRE recovery or Safe Mode

---

## Files

```
scripts/
├── deploy_all.ps1      <- Run from YOUR admin PC
├── lockout_pc.ps1      <- Payload (pushed to each PC)
├── recover_pc.ps1      <- Emergency recovery (via PsExec or local admin)
└── PsExec64.exe        <- Download from Microsoft Sysinternals
```

---

## Setup

1. Download PsExec64.exe -> put in scripts/ folder
2. Edit $TargetPCs in deploy_all.ps1 with your 7 PC IPs
3. Verify: `dir \\192.168.1.11\C$` from admin PC

---

## Commands (from Admin PC)

| Command | Effect |
|---------|--------|
| `.\deploy_all.ps1 -Username "Admin" -Password "Pass"` | Arm all PCs for 14:30 |
| `.\deploy_all.ps1 -Action trigger -Username "Admin" -Password "Pass"` | Fire NOW |
| `.\deploy_all.ps1 -Action cancel -Username "Admin" -Password "Pass"` | Abort |
| `.\deploy_all.ps1 -Action recover -Username "Admin" -Password "Pass"` | Undo all |

---

## Single PC Test

Lock it (PowerShell as Admin):
```powershell
Set-ExecutionPolicy Bypass -Scope Process
.\lockout_pc.ps1
```

---

## WinRE Recovery (when PC is locked)

### Get into WinRE
Force-shutdown 3 times -> Troubleshoot -> Advanced Options -> Command Prompt

### Recovery Commands

Replace Orion with the actual username. Check with: `dir C:\Users`

```cmd
reg load HKU\Fix C:\Users\Orion\NTUSER.DAT

reg delete "HKU\Fix\Software\Microsoft\Windows NT\CurrentVersion\Winlogon" /v Shell /f

reg delete "HKU\Fix\Software\Microsoft\Windows\CurrentVersion\Policies\System" /v DisableTaskMgr /f

reg delete "HKU\Fix\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoRun /f

reg delete "HKU\Fix\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoLogoff /f

reg delete "HKU\Fix\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoChangeStartMenu /f

reg delete "HKU\Fix\Software\Policies\Microsoft\Windows\System" /v DisableCMD /f

reg unload HKU\Fix

rmdir /s /q C:\CyberExercise

del /f C:\Windows\System32\Tasks\CyberExercise_Lockout
```

Ignore "not found" errors. They are harmless.

### Verify

```cmd
reg load HKU\Fix C:\Users\Orion\NTUSER.DAT

reg query "HKU\Fix\Software\Microsoft\Windows NT\CurrentVersion\Winlogon" /v Shell

reg unload HKU\Fix
```

Must say "not found". Then hold power button to reboot.

---

## IT Student Recovery Path

What they need to figure out on their own:

1. Nothing works on the locked screen - no keyboard shortcuts, no task manager
2. They must force-shutdown 3 times to reach Windows Recovery
3. Open Command Prompt from recovery
4. Find the username: `dir C:\Users`
5. Load the user registry: `reg load HKU\Fix C:\Users\<USER>\NTUSER.DAT`
6. Investigate what is wrong: check Shell value, look for policy keys
7. Fix the registry entries
8. Delete exercise files from C:\CyberExercise
9. Delete scheduled task file
10. Unload hive and reboot

Breadcrumbs for students:
- C:\CyberExercise folder is visible and contains HTA + watchdog files
- Task name is CyberExercise_Lockout
- HTA title bar shows file path briefly

---

## Exercise Timeline

| Time | Event |
|------|-------|
| Morning | Deploy from admin PC - confirm 7/7 armed |
| 14:00 | Students start on PCs |
| 14:30 | Lockout fires on all 7 PCs |
| 14:30+ | Medical students use pen and paper |
| 14:30+ | IT students start recovery |
| End | deploy_all.ps1 -Action recover for remaining PCs |

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Script parse error | Make sure file is saved as ASCII/ANSI, not UTF-8 with BOM |
| PsExec access denied | Add -Username and -Password |
| Task didnt fire | Check PC clock or use -Action trigger |
| Black screen after recovery | Shell still wrong - reload hive and check with reg query |
| schtasks not recognized in WinRE | Use: del /f C:\Windows\System32\Tasks\CyberExercise_Lockout |
| Student somehow killed watchdog | Reboot relocks them (shell replacement in registry) |
