# Looking Glass Setup

[Looking Glass](https://looking-glass.io/) gives you near-zero latency display from your GPU-passthrough VM without needing a physical cable. It works by sharing the GPU's framebuffer via shared memory (IVSHMEM) between the VM and the Linux host.

This is the recommended display method after initial Windows setup via SPICE.

## How It Works

```
┌─────────────────────────────────────────┐
│              Linux Host                  │
│                                          │
│  ┌──────────────┐    ┌───────────────┐  │
│  │ Looking Glass│◄───│ IVSHMEM       │  │
│  │ Client       │    │ Shared Memory │  │
│  │ (displays    │    │ (/dev/shm/    │  │  
│  │  VM screen)  │    │  looking-glass│  │
│  └──────────────┘    └───────┬───────┘  │
│                              │          │
│                      ┌───────┴───────┐  │
│                      │ QEMU VM       │  │
│                      │ ┌───────────┐ │  │
│                      │ │ Windows   │ │  │
│                      │ │ Looking   │ │  │
│                      │ │ Glass Host│ │  │
│                      │ └───────────┘ │  │
│                      └───────────────┘  │
└─────────────────────────────────────────┘
```

## Prerequisites

- Working GPU passthrough VM (follow the main README first)
- Windows installed and NVIDIA drivers working inside the VM

## Step 1: Add IVSHMEM Device to VM

Edit your VM's XML (or add to DragonForge config):

```bash
sudo virsh edit win11-dragonforge
```

Add inside `<devices>`:

```xml
<shmem name='looking-glass'>
  <model type='ivshmem-plain'/>
  <size unit='M'>128</size>
</shmem>
```

The size should be calculated as:
```
width × height × 4 × 2 = bytes needed
Round up to nearest power of 2 in MB

Example for 1920×1080:
1920 × 1080 × 4 × 2 = 16,588,800 bytes ≈ 16 MB → use 32 MB
For 2560×1440: ≈ 29 MB → use 32 MB
For 3840×2160: ≈ 66 MB → use 128 MB
```

## Step 2: Configure Shared Memory Permissions

Create a tmpfiles config so the shared memory file has correct permissions:

```bash
echo "f /dev/shm/looking-glass 0660 $USER kvm -" | sudo tee /etc/tmpfiles.d/looking-glass.conf
sudo systemd-tmpfiles --create /etc/tmpfiles.d/looking-glass.conf
```

## Step 3: Install Looking Glass Host on Windows

1. Start your VM
2. Download the Looking Glass Host from [looking-glass.io/downloads](https://looking-glass.io/downloads)
3. Install it inside Windows
4. The host application will start on boot and capture the GPU framebuffer

## Step 4: Build Looking Glass Client on Linux

```bash
# Install build dependencies
# Fedora:
sudo dnf install cmake gcc gcc-c++ libglvnd-devel fontconfig-devel \
  spice-protocol libX11-devel libXfixes-devel libXi-devel \
  libXScrnSaver-devel libXinerama-devel wayland-devel \
  wayland-protocols-devel libXcursor-devel libXpresent-devel \
  libxkbcommon-x11-devel kernel-headers libpipewire-devel \
  libsamplerate-devel

# Arch:
sudo pacman -S cmake gcc libgl fontconfig spice-protocol \
  libx11 libxfixes libxi libxss libxinerama wayland \
  wayland-protocols libxcursor libxpresent libxkbcommon \
  pipewire libsamplerate

# Clone and build
git clone --recursive https://github.com/gnif/LookingGlass.git
cd LookingGlass
mkdir client/build
cd client/build
cmake ..
make -j$(nproc)

# Optional: install system-wide
sudo make install
```

## Step 5: Run

1. Start the VM: `./dragonforge vm-start`
2. Wait for Windows to boot and Looking Glass Host to start
3. Run the client:

```bash
looking-glass-client
```

Or with common options:
```bash
looking-glass-client -F            # Borderless fullscreen
looking-glass-client -s             # No screen saver inhibit
looking-glass-client -m 97          # Cursor sensitivity
```

## Step 6: Remove SPICE (Optional)

Once Looking Glass is working, you can remove the SPICE display and QXL video from the VM to avoid conflicts:

```bash
sudo virsh edit win11-dragonforge
```

Remove or comment out:
```xml
<!-- Remove these -->
<graphics type='spice' .../>
<video><model type='qxl' .../></video>
```

Keep the USB tablet and keyboard for input, or switch to evdev passthrough.

## Troubleshooting

### "Failed to open /dev/shm/looking-glass"

```bash
# Check permissions
ls -la /dev/shm/looking-glass

# Fix
sudo chown $USER:kvm /dev/shm/looking-glass
sudo chmod 0660 /dev/shm/looking-glass
```

### Black screen in Looking Glass

- Ensure the Windows Looking Glass Host application is running
- Check that NVIDIA drivers are installed and working in Windows
- The IVSHMEM device must be visible in Windows Device Manager

### Poor performance

- Ensure the IVSHMEM size is large enough for your resolution
- Check that the VM has enough CPU cores
- Looking Glass should run at the GPU's native refresh rate
