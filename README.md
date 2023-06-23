# jetson-l4t

A rootful container that is setup to run `boardctl` commands or flash a jetson
using the l4t environment. It requires root access to install and run.
The scripts expect `podman` to be the container tool used.

## Installing the jetson-l4t runtime script

A script, `jetson-l4t`, will be installed to `$HOME/.local/bin`. This is the
script used to flash, run board control commands and drop into a shell.

```
./setup.sh -i
```

## Uninstalling the jetson-l4t runtime script

```
./setup.sh -u
```

## Building the jetson-l4t container

If the installation for the firmware requires something other then `apply_binaries.sh`
being run, you need to provide a shell script that runs those commands and
specify it using `-s /path/to/script.sh`. You can use the `files/setup.sh`
script as a starting point.

Firmware releases that are automatically supported:

- 35.3.1
- 35.2.1

### Building a jetson-l4t container for a supported firmware release

```
./setup.sh -b -f <firmware release, i.e. 35.3.1> -t <container version tag, i.e. 35.3.1>
```

### Building a jetson-l4t container for a user provided firmware release

Either download the Jetson Driver package or specify the URL to the
Jetson Driver package that contains the `Linux_for_Tegra` directory
and specify the location to the tarfile using `-d /uri/jetson_driver.tarfile`.

```
./setup.sh -b -f <firmware release> -t <container version tag> -d /uri/jetson_driver.tarfile
```

### Building a jetson-l4t container with a BSP Overlay using a supported firmware release

Either download the BSP or specify the URL to the BSP you want to overlay
ontop of the `Linux_for_Tegra` directory and specify the location to the
tarfile using `-p /uri/bsp_overlay.tarfile`.

```
./setup.sh -b -f <firmware release> -t <container version tag> -p /uri/bsp_overlay.tarfile
```

### Building a jetson-l4t container with a BSP Overlay using a user provided firmware release

Combine the previous two commands:

```
./setup.sh -b -f <firmware release> -t <container version tag> -d /uri/jetson_driver.tarfile -p /uri/bsp_overlay.tarfile
```

### Notes

If you do not want to include the Sample filesystem in the `Linux_for_Tegra`
directory, add the `-n` argument to your build commands. This will also not
run the `apply_binaries.sh` script.

When building the container, if you want to automatically clean up the build
artifacts, add `-c` to the `./setup.sh` command.

## Removing a jetson-l4t container

```
./setup.sh -r -t <container version tag>
```

## Flashing a Jetson

Supported Jetson boards:

- agxorin
- igxorin
- orinnx
- orinnano
- xaviernx

The Jetson board config can be found in the `Linux_for_Tegra` directory,
i.e. jetson-agx-orin-devkit.conf. Drop the `.conf` file extension when
specifying which config flash should use. The flash root device can be
specified with `-d <rootdev, i.e. external>`.

```
jetson-l4t -t <container version tag> -j <jetson board> -c flash -b <jetson board config> -d <rootdev>
```

## Running a board control command

Board control commands:

- power_on
- power_off
- recovery
- reset
- status

The board control commands are currently only supported for the AGX Orin.

```
jetson-l4t -t <container version tag> -j <jetson board> -c <board control command>
```

## Getting a shell for running manual commands

This will drop you into the specified jetson-l4t container at the `Linux_for_Tegra` directory.

```
jetson-l4t -t <container version tag> -c shell
```
