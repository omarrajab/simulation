# Cyber Exercise — Deployment Guide (v3 — Windows 10 Tested)

## What's New in v3

Based on real testing on your Dell Windows 10 PCs:

- Script ONLY writes to **user hives** (never HKLM) — avoids breaking the system shell
- Recovery instructions use **`reg load`** to mount real hives — because WinRE's `HKLM` is NOT the real Windows registry
- `schtasks` doesn't exist in WinRE — we delete the task file from disk instead
- HTA encoding set to ASCII for Windows 10 compatibility

---

## Files

```
scripts/
├── deploy_all.ps1      ← Run from YOUR admin PC (controls everything)
├── lockout_pc.ps1      ← Payload (auto-pushed to each PC)
├── recover_pc.ps1      ← Emergency recovery (used by deploy_all.ps1 -Action recover)
└── PsExec64.exe        ← Download from Microsoft Sysinternals, place here
```

---

## Setup (One Time)

1. Download **PsExec64.exe** from https://learn.microsoft.com/en-us/sysinternals/downloads/psexec → put in `scripts/` folder

2. Open `deploy_all.ps1` and edit the `$TargetPCs` list with your 7 PC IPs

3. Verify admin share access from your admin PC:
   ```
   dir \\192.168.1.11\C$
   ```
   If access denied, on each PC run:
   ```powershell
   Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "LocalAccountTokenFilterPolicy" -Value 1
   ```

---

## Commands (All from Your Admin PC)

| Command | Effect |
|---------|--------|
| `.\deploy_all.ps1 -Username "Admin" -Password "Pass"` | Arm all 7 PCs for today 14:30 |
| `.\deploy_all.ps1 -Action trigger -Username "Admin" -Password "Pass"` | Fire NOW |
| `.\deploy_all.ps1 -Action cancel -Username "Admin" -Password "Pass"` | Abort before trigger |
| `.\deploy_all.ps1 -Action recover -Username "Admin" -Password "Pass"` | Emergency undo all PCs |

Custom time: add `-AttackTime "15:00"` or `-AttackDate "2026-03-20"`

---

## Single PC Test

**Lock it (run on the test PC as Admin):**
```powershell
Set-ExecutionPolicy Bypass -Scope Process
.\lockout_pc.ps1
```

**Recover it — see WinRE Recovery below.**

---

## WinRE Recovery (the CORRECT way)

This is the only recovery method that works when a PC is locked.

### Getting into WinRE

Force-shutdown 3 times (hold power button until off, turn on, repeat) → Windows Recovery appears → **Troubleshoot → Advanced Options → Command Prompt**

### IMPORTANT: Why normal `HKLM` doesn't work here

In WinRE, `HKLM` points to the recovery environment's own registry — NOT the real Windows registry on disk. You must **load the real hive from disk** using `reg load`.

### Recovery Commands

Replace `Orion` with the actual username on the PC. To check: `dir C:\Users`

```cmd
reg load HKU\Fix C:\Users\Orion\NTUSER.DAT

reg delete "HKU\Fix\Software\Microsoft\Windows NT\CurrentVersion\Winlogon" /v Shell /f

reg delete "HKU\Fix\Software\Microsoft\Windows\CurrentVersion\Policies\System" /v DisableTaskMgr /f

reg delete "HKU\Fix\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoLogoff /f

reg delete "HKU\Fix\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoChangeStartMenu /f

reg unload HKU\Fix

rmdir /s /q C:\CyberExercise

del /f C:\Windows\System32\Tasks\CyberExercise_Lockout
```

Ignore any "not found" errors — they just mean that key wasn't set.

### Verify Before Rebooting

```cmd
reg load HKU\Fix C:\Users\Orion\NTUSER.DAT

reg query "HKU\Fix\Software\Microsoft\Windows NT\CurrentVersion\Winlogon" /v Shell

reg unload HKU\Fix
```

Should say **"not found"** — that's correct. It means Windows will use its default shell (explorer.exe).

### Reboot

Hold the power button to restart. PC should boot to a normal desktop.

---

## IT Student Recovery Path (What They Need to Figure Out)

Students don't get the commands above. They need to work through it:

1. **Get into recovery** — force-shutdown 3 times → Troubleshoot → Command Prompt
2. **Find the username** — `dir C:\Users`
3. **Load the user's registry** — `reg load HKU\Fix C:\Users\<USERNAME>\NTUSER.DAT`
4. **Find what's wrong** — look at the Winlogon Shell value:
   `reg query "HKU\Fix\Software\Microsoft\Windows NT\CurrentVersion\Winlogon" /v Shell`
5. **Fix it** — delete the Shell override so Windows falls back to explorer.exe
6. **Also check** — Task Manager disabled? Explorer policies?
7. **Unload, clean up files, reboot**

The breadcrumbs:
- `C:\CyberExercise` folder is visible and contains the HTA file
- The scheduled task name is `CyberExercise_Lockout` (visible if they boot to Safe Mode)
- The HTA title bar shows the file path

---

## Exercise Timeline

| Time | Event |
|------|-------|
| Morning | Deploy from admin PC — confirm 7/7 armed |
| 14:00 | Students start working on PCs |
| **14:30** | **Lockout fires on all 7 PCs** |
| 14:30+ | Medical students → pen & paper |
| 14:30+ | IT students start recovery |
| End | Use `deploy_all.ps1 -Action recover` for any remaining PCs |

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `dir \\PC\C$` access denied | Run LocalAccountTokenFilterPolicy fix (see Setup) |
| PsExec hangs | Add -Username and -Password explicitly |
| Task didn't fire | Check PC clock; use `-Action trigger` to fire manually |
| Student closed HTA | Reboot relocks them (shell is replaced in registry) |
| Black screen after recovery | Shell value is wrong — reload hive and verify it says "not found" or "explorer.exe" |
| `reg add` seems to work but doesn't stick | You're in WinRE — must use `reg load` to mount the real hive first |
| `schtasks` not recognized | Normal in WinRE — use `del /f C:\Windows\System32\Tasks\CyberExercise_Lockout` instead |
