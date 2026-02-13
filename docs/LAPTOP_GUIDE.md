# Laptop GPU Passthrough Guide

GPU passthrough on laptops is trickier than desktops because:

1. The discrete GPU often has no physical video output (it renders to the iGPU's framebuffer via NVIDIA Optimus / AMD Switchable Graphics)
2. IOMMU grouping can be poor on some laptop chipsets
3. The GPU might not have a separate HDMI audio device
4. Power management (hybrid sleep, suspend) can break passthrough

This guide covers the laptop-specific considerations.

## Checking Your Laptop's Compatibility

### 1. IOMMU Group Isolation

```bash
# Check IOMMU groups
for d in /sys/kernel/iommu_groups/*/devices/*; do
    n=$(basename $(dirname $(dirname $d)))
    echo "IOMMU Group $n: $(lspci -nns ${d##*/})"
done
```

**Good:** Your GPU and its audio device are alone in their IOMMU group.

**Bad:** Your GPU shares a group with USB controllers, SATA controllers, etc. You'd need to pass all of them through or use the ACS override patch.

### 2. GPU Type

```bash
lspci -nn | grep -iE "nvidia|amd"
```

Laptop NVIDIA GPUs are typically listed as:
- `3D controller` — This is a render-only GPU (Optimus). **This is fine for passthrough.** You just won't get output on the laptop's screen from the VM — use SPICE, Looking Glass, or an external monitor via a dock.
- `VGA compatible controller` — This GPU can drive a display directly. Even better.

### 3. MUX Switch

Some gaming laptops have a MUX switch (in BIOS) that lets you bypass Optimus and connect the dGPU directly to the display. If you have one:
- Set it to **dGPU mode** for the best passthrough experience (the GPU gets full display output)
- Or leave it on hybrid and use Looking Glass

## The Optimus Problem

On most laptops, the NVIDIA GPU renders frames but sends them to the Intel iGPU's framebuffer for display. This means:

- The NVIDIA GPU has **no direct video output** on the laptop screen
- When you pass it to a VM, the VM can render on it but you need another way to see the output:
  - **SPICE** — Works for setup but is slow for gaming
  - **Looking Glass** — Copies the GPU framebuffer to shared memory, displayed by a lightweight Linux client. Near-zero latency. Best option.
  - **External monitor** — If you have a Thunderbolt/USB-C dock that connects to the dGPU, you can plug a monitor into it

## DragonForge's Laptop-Safe Approach

Most GPU passthrough tutorials tell you to run `modprobe -r nvidia` before starting the VM. On a laptop, this will:
- Kill your display compositor if it's using the nvidia GPU for anything
- Hang if any process has `/dev/nvidia*` open (VS Code, Firefox with hardware acceleration, etc.)
- Potentially freeze your system

DragonForge instead uses **device-level unbind**:

```bash
# Instead of:
modprobe -r nvidia_drm nvidia_modeset nvidia_uvm nvidia  # ← DANGEROUS on laptops

# We do:
echo "0000:01:00.0" > /sys/bus/pci/devices/0000:01:00.0/driver/unbind
echo "vfio-pci" > /sys/bus/pci/devices/0000:01:00.0/driver_override
echo "0000:01:00.0" > /sys/bus/pci/drivers/vfio-pci/bind
```

This detaches the **specific PCI device** from the nvidia driver without unloading the entire nvidia kernel module. The nvidia driver stays loaded (in case other devices or processes reference it), but the GPU itself is now owned by vfio-pci.

## Power Management

### Suspend/Resume

GPU passthrough VMs don't survive host suspend well. Before suspending:

```bash
./dragonforge vm-stop   # or vm-kill if it won't shut down
```

### Battery Impact

The discrete GPU draws power even when passed through to a VM. If you're on battery:
- GPU passthrough is not recommended on battery
- The VM + GPU will drain your battery fast

## Recommended Laptop Workflow

1. **Plug in power**
2. Start the VM: `./dragonforge vm-start`
3. Open viewer: `./dragonforge vm-viewer` (SPICE for now, Looking Glass later)
4. Game in the VM
5. Stop the VM: `./dragonforge vm-stop`
6. GPU returns to Linux automatically

## Known Working Laptops

| Laptop | CPU | GPU | IOMMU | Notes |
|--------|-----|-----|-------|-------|
| ASUS TUF F15 | i5-12500H | RTX 4060 Max-Q | Group 16 (isolated) | Optimus, no MUX |

If you've tested DragonForge on your laptop, please submit a PR to add it here.
