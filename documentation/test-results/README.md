# Test Results

This directory is the evidence log for ElvonOS. It exists so that no phase is declared complete based on assumptions.

---

## Rules

1. **Never invent a result.** If a command was not run, write `NOT RUN`.
2. Record the **date, host, kernel, and exact command** for every result.
3. Save the raw output (or a redacted excerpt) next to the summary.
4. A screenshot is not a substitute for a command output when a command can prove the claim.
5. Redact passwords, tokens, serial numbers, MAC addresses, and private keys.
6. Distinguish **PASS**, **FAIL**, **BLOCKED**, and **NOT RUN**.
7. Do not mark a phase complete if any required gate is `FAIL` or `BLOCKED`.
8. Virtual-machine results are supplementary. Hardware claims require physical hardware.
9. Software rendering is not GPU acceleration. Label it explicitly.
10. Do not commit build outputs, disk images, or large logs. Commit the summary and small text evidence.

---

## Current status

| Phase | Status | Evidence file |
|---|---|---|
| 0 — Inspection and reports | Complete (static inspection only) | `documentation/00`–`09` |
| 1 — Debian foundation | **NOT RUN** | `phase1.md` |
| 2 — Wayland/Hyprland | NOT RUN | `phase2.md` (to be created) |
| 3 — Android runtime | NOT RUN | `phase3.md` (to be created) |
| 4 — ElvonOS desktop | NOT RUN | `phase4.md` (to be created) |
| 5 — Android integration | NOT RUN | `phase5.md` (to be created) |
| 6 — Hardware integration | NOT RUN | `phase6.md` (to be created) |
| 7 — Installer and ISO | NOT RUN | `phase7.md` (to be created) |
| 8 — Stabilization | NOT RUN | `phase8.md` (to be created) |

Phase 0 is a **static** inspection. It did not boot the Debian kernel, run Hyprland, run Waydroid, or test hardware.

---

## Naming

```
documentation/test-results/
├── README.md
├── phase1.md
├── phase2.md
├── ...
└── logs/
    ├── 2026-11-01-phase1-check-host.txt
    └── ...
```

`logs/` is optional. Keep files small; do not commit multi-megabyte logs.

---

## Template

```markdown
## <Test name>

- Date:
- Host:
- OS:
- Kernel (`uname -r`):
- Hardware:
- Command:
- Expected:
- Result: PASS | FAIL | BLOCKED | NOT RUN
- Output / log:
- Notes:
```

---

## Evidence quality levels

| Level | Meaning |
|---|---|
| **Static** | Source, package metadata, or configuration inspected; nothing executed |
| **Build** | A build or package command ran and produced artifacts |
| **Runtime** | The artifact booted/ran on a kernel or desktop |
| **Hardware** | The runtime test ran on the physical target device |

A claim must name its evidence level. “Waydroid is compatible” requires **Runtime** or **Hardware** evidence, not **Static**.
