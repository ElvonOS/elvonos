# ElvonOS live ISO on QEMU for Windows (WHPX hardware acceleration).
#
# This is the fast test path for Windows workstations: QEMU runs natively on
# Windows and uses WHPX, so Android boots in well under a minute instead of the
# several minutes a TCG run inside WSL needs.  The VM uses a virtio-gl GPU and
# an egl-headless display; screenshots are taken inside the guest with grim.
#
#   powershell -ExecutionPolicy Bypass -File build\phase1\run-desktop-qemu-whpx.ps1
#
# SSH is forwarded to tcp/2222.  From WSL connect to the Windows host address:
#   ssh -p 2222 elvon@$(ip route show default | awk '{print $3}')
param(
    [string]$Iso      = (Join-Path $PSScriptRoot '..\out\ElvonOS-1.0.0-amd64.iso'),
    [int]$Memory      = 6144,
    [int]$Cpus        = 4,
    [int]$SshPort     = 2222,
    [int]$QmpPort     = 4444,
    [string]$SerialLog = (Join-Path $env:TEMP 'opencode\elvonos-serial.log'),
    [string]$QemuLog   = (Join-Path $env:TEMP 'opencode\elvonos-qemu.log')
)

$qemu = 'C:\Program Files\qemu\qemu-system-x86_64.exe'
if (-not (Test-Path $qemu)) { throw "QEMU not found: $qemu" }
if (-not (Test-Path $Iso)) { throw "ISO not found: $Iso" }

# QEMU on Windows cannot load -bios from a path containing spaces, so the
# firmware is copied next to the logs first.
$bios = Join-Path $env:TEMP 'opencode\edk2-x86_64-code.fd'
if (-not (Test-Path $bios)) {
    New-Item -ItemType Directory -Force -Path (Split-Path $bios) | Out-Null
    Copy-Item 'C:\Program Files\qemu\share\edk2-x86_64-code.fd' $bios -Force
}
Remove-Item $SerialLog, $QemuLog -ErrorAction SilentlyContinue

$arguments = @(
    '-accel', 'whpx',
    '-machine', 'q35',
    '-cpu', 'host',
    '-m', "$Memory",
    '-smp', "$Cpus",
    '-drive', "if=pflash,format=raw,readonly=on,file=$bios",
    '-vga', 'none',
    '-device', 'virtio-gpu-gl-pci,xres=1280,yres=800,edid=on',
    '-device', 'usb-ehci,id=ehci',
    '-device', 'usb-tablet',
    '-cdrom', $Iso,
    '-boot', 'd',
    '-no-reboot',
    '-display', 'egl-headless',
    '-chardev', "file,id=ser0,path=$SerialLog",
    '-serial', 'chardev:ser0',
    '-qmp', "tcp:127.0.0.1:$QmpPort,server=on,wait=off",
    '-netdev', "user,id=net0,hostfwd=tcp:0.0.0.0:${SshPort}-:22",
    '-device', 'e1000,netdev=net0'
)

Write-Host "Starting QEMU (WHPX): $Memory MB RAM, $Cpus vCPU, SSH $SshPort"
Write-Host "ISO: $Iso"
& $qemu @arguments *> $QemuLog
Write-Host "QEMU exited with $LASTEXITCODE"
