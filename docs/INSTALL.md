# Installing Vernet on desktop

Back to [Vernet](../README.md).

Vernet is available for Linux, Windows and macOS. Linux and Windows builds come
in both **x64** and **arm64**.

| Platform | Architectures | Install from |
|---|---|---|
| Linux | x64, arm64 | [Snap Store](https://snapcraft.io/vernet) or [GitHub releases](https://github.com/osociety/vernet/releases/latest) |
| Windows | x64, arm64 | [Microsoft Store](https://apps.microsoft.com/detail/9N1170N3PHMM) or [GitHub releases](https://github.com/osociety/vernet/releases/latest) |
| macOS | Apple silicon and Intel | [GitHub releases](https://github.com/osociety/vernet/releases/latest) |

Not sure which architecture you have? On Linux, run `uname -m`: `x86_64` means
x64 and `aarch64` means arm64. On Windows, open **Settings > System > About**
and check "System type".

## Linux

### Option 1: Snap Store (recommended)

```bash
sudo snap install vernet --beta
```

The network access the app needs to discover devices and read your Wi-Fi signal
is connected automatically on install, so there is nothing you have to set up by
hand. One optional connection, below, adds richer mDNS device names.

`snap install` picks the right build for your architecture (x64 or arm64)
automatically.

#### Optional: connect Avahi for mDNS device names

The snap ships `avahi-browse`, which Vernet asks for the list of mDNS service
types to browse — so a gadget advertising an unusual service gets a name instead
of a bare IP. It reads the host's Avahi daemon over a socket snapd only hands
out on request:

```bash
sudo snap connect vernet:avahi-observe
```

Confirm it stuck, then run a host scan:

```bash
snap connections vernet | grep avahi
```

This needs Avahi running on the host (`systemctl status avahi-daemon`), because
the snap talks to the system daemon rather than starting its own. Without the
connection everything still works: the scan finds the same devices and names them
from reverse DNS, using Vernet's built-in list of about ninety service types.

### Option 2: Download from GitHub

1. Star this repository.
2. Install the `net-tools` package for the `arp` command, otherwise the app will
   not run.
   ```bash
   sudo apt install net-tools
   ```
3. Download the zip for your architecture from
   [releases](https://github.com/osociety/vernet/releases/latest):
   - `Vernet-<version>-linux-x64.zip` for x64
   - `Vernet-<version>-linux-arm64.zip` for arm64
4. Extract the downloaded zip file. The executable sits at the top level of the
   archive, next to `lib/` and `data/`, so use the folder you extracted into —
   there is no `bundle/` subfolder.
5. Double click `vernet`, or run it from a terminal to see any error output:
   ```bash
   ./vernet
   ```

The database needs SQLite, and the archive carries its own copy in
`lib/libsqlite3.so`, so nothing has to be installed for it. If a startup error
names `libsqlite3.so`, your loader is not searching the extracted `lib/`
directory; point it there and start again:

```bash
LD_LIBRARY_PATH="$PWD/lib" ./vernet
```

## Windows

### Option 1: Microsoft Store (recommended)

Install Vernet from the
[Microsoft Store](https://apps.microsoft.com/detail/9N1170N3PHMM). The Store
installs the right build for your device (x64 or arm64) and keeps it updated.

### Option 2: Download from GitHub

1. Star this repository.
2. Download the zip for your architecture from
   [releases](https://github.com/osociety/vernet/releases/latest):
   - `Vernet-<version>-windows-x64.zip` for x64
   - `Vernet-<version>-windows-arm64.zip` for arm64
3. Extract the downloaded zip file.
4. Run `vernet.exe`.
5. Click on **More info**, then tap **Run anyway**.
6. Give permission if asked.

## macOS

Note: the macOS build hasn't been notarized yet.

1. Star this repository.
2. Download `Vernet-<version>-macos.zip` (or the `.dmg`) from
   [releases](https://github.com/osociety/vernet/releases/latest).
3. Extract the downloaded zip file, or open the `.dmg`.
4. Copy the app to the Applications folder.
5. Go to the Applications folder.
6. Hold down Cmd and click on Vernet.
7. In the context menu, click **Open**.
