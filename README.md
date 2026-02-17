# kwimy-iso

Live ISO build inputs and tooling

### Structure

- `build-iso.sh`: main archiso build script
- `build/`: helper scripts + offline package lists
- `airootfs/`: live filesystem overlay
- `grub/`, `syslinux/`: bootloader assets

### Build the ISO

Requirements:
- `archiso` package installed

```sh
sudo ./kwimy-iso/build/build.sh
```

Optional copy destination:

```sh
ISO_COPY_DIR=/path/to/isos sudo ./kwimy-iso/build/build.sh
```

### Update only the installer binary in the ISO

```sh
./kwimy-iso/copy-binary.sh
```

### Resolve offline packages

Use the stable mirror without changing system pacman config:

```sh
RESOLVE_MIRROR_URL=https://mirror.kwimy.com/stable 
sudo ./kwimy-iso/build/resolve-offline-deps.sh
```

Skip sync if needed:

```sh
RESOLVE_SKIP_SYNC=1 ./kwimy-iso/build/resolve-offline-deps.sh
```

### Offline repo health

```sh
./kwimy-iso/build/offline-repo-health.sh
```

### Create a test VM from the latest ISO

```sh
sudo ./kwimy-iso/build/create-vm.sh
```

### Live ISO debug login

- User: `root`
- Password: `root`

### Dev SSH (optional)

The live ISO enables SSH for development. Root login and password auth are allowed

To remove for release:
- Remove `openssh` from `kwimy-iso/packages.x86_64`
- Remove `kwimy-iso/airootfs/etc/ssh/sshd_config.d/kwimy-dev.conf`
- Remove `kwimy-iso/airootfs/etc/systemd/system/multi-user.target.wants/sshd.service`
