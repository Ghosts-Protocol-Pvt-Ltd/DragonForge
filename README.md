# DragonForge

GPU passthrough toolkit for running a Windows gaming VM on a Linux host with near-native GPU performance. Uses QEMU/KVM with libvirt for a single-GPU or dual-GPU laptop/desktop setup.

Pass your discrete NVIDIA or AMD GPU through to a Windows VM while keeping your Linux desktop running on the integrated GPU (or a second discrete GPU).

## What It Does

- **Auto-detects** your GPU, IOMMU groups, ISOs, and generates config automatically
- **Configures** VFIO modules and libvirt hooks in one command
- **Creates** a Windows 11 VM with UEFI, Secure Boot, TPM 2.0, VirtIO storage/network
- **Manages** GPU bind/unbind at VM start/stop — no manual `modprobe` needed
- **Works on laptops** — uses device-level unbind instead of kernel module unloading, so it doesn't crash your desktop when other processes (VS Code, compositor) are using the nvidia driver
- **Self-healing** — 30s watchdog timer prevents stuck hooks, GPU temp checks refuse passthrough if overheating

## Requirements

- Linux host with IOMMU support (Intel VT-d or AMD-Vi)
- A discrete GPU for passthrough (NVIDIA or AMD)
- An integrated GPU (or second discrete GPU) for the host display
- QEMU/KVM, libvirt, OVMF (UEFI), swtpm (TPM 2.0)

### Tested On

| Distro | GPU | Status |
|--------|-----|--------|
| Fedora 43 KDE | RTX 4060 Max-Q (laptop) | ✓ Working |

## Quick Start

```bash
# 1. Clone
git clone https://github.com/Ghosts-Protocol-Pvt-Ltd/DragonForge.git
cd DragonForge

# 2. Make executable
chmod +x dragonforge

# 3. Install (auto-detects GPU, generates config, installs hook)
sudo ./dragonforge setup

# 4. Reboot to load VFIO modules
sudo reboot

# 5. Create and start the VM
dragonforge create
dragonforge start
dragonforge viewer
```

No manual config editing required — `setup` auto-detects your GPU, finds Windows/VirtIO ISOs in `~/Downloads`, and generates everything. Edit `config/dragonforge.conf` after if you want to tweak anything.

## Commands

Hyphens are optional. `vm-start`, `vmstart`, and `start` all work.

| Command | Description |
|---------|-------------|
| `dragonforge detect` | Detect GPU, IOMMU groups, system info |
| `dragonforge setup` | Install hook, configure VFIO, create symlink (sudo) |
| `dragonforge status` | Check current passthrough state |
| `dragonforge create` | Create Windows 11 VM from config |
| `dragonforge start` | Start the VM (with pre-flight checks) |
| `dragonforge stop` | Gracefully shut down the VM |
| `dragonforge kill` | Force stop the VM |
| `dragonforge viewer` | Open SPICE viewer |
| `dragonforge reset` | Emergency: return GPU to host (sudo) |
| `dragonforge logs` | Show DragonForge log history |
| `dragonforge uninstall` | Remove hook and VFIO config (sudo) |

## How GPU Passthrough Works

```
┌─────────────────────────────────┐
│          Linux Host             │
│                                 │
│  ┌──────────┐  ┌─────────────┐  │
│  │ Intel iGPU│  │ NVIDIA dGPU │  │
│  │ (host)   │  │ (passthru)  │  │
│  └────┬─────┘  └──────┬──────┘  │
│       │               │         │
│  ┌────┴─────┐  ┌──────┴──────┐  │
│  │ i915     │  │ vfio-pci    │  │
│  │ driver   │  │ driver      │  │
│  └──────────┘  └──────┬──────┘  │
│                       │         │
│               ┌───────┴───────┐ │
│               │ QEMU/KVM VM   │ │
│               │ ┌───────────┐ │ │
│               │ │ Windows 11│ │ │
│               │ │ + NVIDIA  │ │ │
│               │ │   drivers │ │ │
│               │ └───────────┘ │ │
│               └───────────────┘ │
└─────────────────────────────────┘
```

### The Hook Script

When you start the VM, libvirt calls our hook script which:

1. **Checks** GPU temperature — refuses passthrough if above the configured limit (default 85°C)
2. **Starts** a 30-second watchdog timer — if the hook hangs, it self-terminates to prevent libvirtd lockups
3. **Unbinds** the GPU from the nvidia driver at the PCI device level
4. **Sets** `driver_override` to `vfio-pci` and binds the GPU
5. QEMU starts with the GPU passed through to Windows

When you stop the VM:

1. **Unbinds** the GPU from `vfio-pci`
2. **Clears** the driver override
3. **Rescans** the PCI bus so nvidia can reclaim the GPU
4. **Verifies** the nvidia driver re-attached successfully
5. **Reloads** nvidia modules (best-effort)

The key difference from most guides: we use `driver_override` + device unbind instead of `modprobe -r nvidia`. This means the hook **never hangs** even when other processes are using the nvidia driver. Plus the watchdog timer guarantees it can't deadlock libvirtd.

## Configuration

Config is **auto-generated** when you run `dragonforge setup` (or any command that needs it). It detects:

- Your first NVIDIA/AMD discrete GPU + audio device
- Vendor:Device IDs from sysfs
- Half your RAM (rounded to nearest GB, capped 4–16 GB)
- Half your CPU threads (minimum 2)
- Windows and VirtIO ISOs in `~/Downloads`

To override, edit `config/dragonforge.conf` or create one from the example:

```bash
cp config/dragonforge.conf.example config/dragonforge.conf
nano config/dragonforge.conf
```

```bash
# Find your GPU's PCI address and IDs
lspci -nn | grep -iE "nvidia|amd"
# Example output:
# 01:00.0 3D controller [0302]: NVIDIA Corporation AD107M [GeForce RTX 4060 Max-Q] [10de:28a0]
# 01:00.1 Audio device [0403]: NVIDIA Corporation [10de:22be]
```

Key settings:
- `GPU_PCI` — PCI address of the GPU (e.g., `0000:01:00.0`)
- `GPU_AUDIO` — PCI address of GPU audio (e.g., `0000:01:00.1`)
- `GPU_VENDOR_ID` / `GPU_DEVICE_ID` — from the `[xxxx:xxxx]` in lspci output
- `WIN_ISO_PATH` — path to your Windows 11 ISO
- `VIRTIO_ISO_PATH` — path to the [VirtIO drivers ISO](https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso)

## Prerequisites Setup

### Enable IOMMU

Add to your kernel command line (via GRUB or systemd-boot):

**Intel:**
```
intel_iommu=on iommu=pt
```

**AMD:**
```
amd_iommu=on iommu=pt
```

**Fedora (GRUB):**
```bash
sudo grubby --update-kernel=ALL --args="intel_iommu=on iommu=pt"
sudo reboot
```

**Arch (systemd-boot):**
```bash
# Edit /boot/loader/entries/*.conf and add to the options line
```

### Install Packages

**Fedora:**
```bash
sudo dnf install qemu-kvm libvirt virt-manager virt-viewer swtpm edk2-ovmf
sudo systemctl enable --now libvirtd
sudo usermod -aG libvirt $USER
```

**Arch:**
```bash
sudo pacman -S qemu-full libvirt virt-manager virt-viewer swtpm edk2-ovmf
sudo systemctl enable --now libvirtd
sudo usermod -aG libvirt $USER
```

**Ubuntu/Debian:**
```bash
sudo apt install qemu-kvm libvirt-daemon-system virt-manager virt-viewer swtpm ovmf
sudo systemctl enable --now libvirtd
sudo usermod -aG libvirt $USER
```

### Download VirtIO Drivers

Windows doesn't include VirtIO drivers. Download the ISO:

```bash
wget https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso
```

During Windows install, when it can't find a disk, click "Load driver" and browse to the VirtIO ISO → `viostor/w11/amd64`.

## Windows Installation Notes

1. Boot the VM — it will boot from the Windows ISO via SPICE display
2. When Windows asks for a disk and finds none, click **Load driver**
3. Browse to the VirtIO CD → `viostor` → `w11` → `amd64` → select the driver
4. The VirtIO disk will appear — install Windows to it
5. After Windows installs, install the **NVIDIA GeForce drivers** for your GPU
6. Install **VirtIO guest tools** from the VirtIO ISO for network/balloon drivers

## Troubleshooting

### "IOMMU group is not isolated"

Your GPU shares an IOMMU group with other devices. Options:
- Use the ACS override patch (risky)
- Check if your BIOS has options to change PCI slot assignments
- Some laptops have isolated IOMMU groups by default

### VM starts but no display on GPU

- Ensure NVIDIA drivers are installed inside Windows
- Check that KVM is hidden: `<kvm><hidden state='on'/></kvm>`
- Check vendor_id is spoofed: `<vendor_id state='on' value='GenuineIntel'/>`
- NVIDIA drivers refuse to load if they detect a hypervisor

### Hook hangs on VM start

This shouldn't happen with DragonForge's device-level approach, but if it does:
```bash
# Check for stuck hook processes
ps aux | grep "hooks/qemu"

# Kill them
sudo pkill -9 -f "hooks/qemu"

# Restart libvirtd
sudo systemctl restart libvirtd

# Check VM state
sudo virsh list --all
```

### GPU not returning to host after VM shutdown

```bash
# Use the built-in emergency reset
sudo dragonforge reset

# Or manually:
echo "0000:01:00.0" | sudo tee /sys/bus/pci/devices/0000:01:00.0/driver/unbind
echo "" | sudo tee /sys/bus/pci/devices/0000:01:00.0/driver_override
echo 1 | sudo tee /sys/bus/pci/rescan
sudo modprobe nvidia
```

## Project Structure

```
DragonForge/
├── dragonforge                    # Main CLI tool (~1100 lines)
├── hooks/
│   └── qemu                      # Libvirt QEMU hook (watchdog, temp check)
├── config/
│   ├── dragonforge.conf.example   # Example configuration
│   └── dragonforge.conf           # Auto-generated local config (git-ignored)
├── docs/
│   ├── LAPTOP_GUIDE.md            # Laptop-specific passthrough guide
│   └── LOOKING_GLASS.md           # Looking Glass setup guide
├── CONTRIBUTING.md
├── LICENSE                        # MIT License
└── README.md
```

## Roadmap

- [ ] Looking Glass integration (IVSHMEM shared memory display)
- [ ] USB device hotplug (pass controllers/keyboards to VM on-the-fly)
- [ ] Evdev input passthrough (share keyboard/mouse without USB passthrough)
- [ ] Scream audio (low-latency audio from VM to host over network)
- [ ] CPU governor switching (performance mode while VM is running)
- [ ] Automated Windows driver installation
- [ ] Multi-GPU support (pass through multiple GPUs)

## Credits

Built by [Ghosts Protocol](https://ghosts.lk). Inspired by the VFIO community, the Arch Wiki, and countless forum posts from people who've been doing this since 2015.

## License

MIT — see [LICENSE](LICENSE).
