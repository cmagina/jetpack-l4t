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

If the installation for the firmware requires something other then
`apply_binaries.sh` being run, you need to provide a shell script that runs
those commands and specify it using `-s /path/to/script.sh`. You can use the
`files/setup.sh` script as a starting point.

Firmware releases that are automatically supported:

- 35.4.1
- 35.3.1
- 35.2.1

### Building a jetson-l4t container for a supported firmware release

```
./setup.sh -b -f <firmware release, i.e. 35.4.1>
```

### Building a jetson-l4t container for a user provided firmware release

Either download the Jetson Driver package or specify the URL to the
Jetson Driver package that contains the `Linux_for_Tegra` directory
and specify the location to the tarfile using `-d /uri/jetson_driver.tarfile`.

```
./setup.sh -b -f <firmware release, i.e. 35.4.1> -d /uri/jetson_driver.tarfile
```

### Building a jetson-l4t container with a BSP Overlay using a supported firmware release

Either download the BSP or specify the URL to the BSP you want to overlay
ontop of the `Linux_for_Tegra` directory and specify the location to the
tarfile using `-p /uri/bsp_overlay.tarfile`. This file is extracted over the
`Linux_for_Tegra` directory.

```
./setup.sh -b -f <firmware release, i.e. 35.4.1> -p /uri/bsp_overlay.tarfile
```

### Building a jetson-l4t container with a BSP Overlay using a user provided firmware release

Combine the previous two commands:

```
./setup.sh -b -f <firmware release, i.e. 35.4.1> -d /uri/jetson_driver.tarfile -p /uri/bsp_overlay.tarfile
```

### Notes

The `-f <firmware release, i.e. 35.4.1>` argument is used as the image tag
and must be specified for building or removing containers.

If you do not want to include the Sample filesystem in the `Linux_for_Tegra`
directory, add the `-n` argument to your build commands. This will also not
run the `apply_binaries.sh` script. If you specify a setup script using the
`-s /path/to/script.sh` argument, it will be run even with the `-n` argument.

In order to make the firmware files available to the container build, they
must be copied to the container build root. If you want this cleaned up after
the build completes, use the `-c` argument.

## Flashing a Jetson

Supported Jetson boards:

- agxorin
- igxorin
- orinnx
- orinnano
- xaviernx

The Jetson board config can be found in the `Linux_for_Tegra` directory,
i.e. jetson-agx-orin-devkit.conf. Drop the `.conf` file extension when
specifying which config flash should use.

```
jetson-l4t -c flash -f <firmware release, i.e. 35.4.1> -j <jetson board> -b <jetson board config>
```

The flash root device can be specified with `-d <rootdev, i.e. external>`.

```
jetson-l4t -c flash -f <firmware release, i.e. 35.4.1> -j <jetson board> -b <jetson board config> -d <rootdev>
```

The jetson-l4t checks for the NVIDIA USB device ID associated with the
recovery device for the specified Jetson board before calling flash. If
the board being flashed uses a different device ID then expected, one can
be passed to the jetson-l4t script using `-i <usb device id, i.e. 7023>.`
The `-j <jetson board>` argument is not required if passing the usb recovery
device id.

```
jetson-l4t -c flash -f <firmware release, i.e. 35.4.1> -i <usb device id> -b <jetson board config>
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
jetson-l4t -f <firmware release, i.e. 35.4.1> -j <jetson board> -c <board control command>
```

## Getting a shell for running manual commands

This will drop you into the specified jetson-l4t container at the `Linux_for_Tegra` directory.

```
jetson-l4t -f <firmware release, i.e. 35.4.1> -c shell
```

## Removing a jetson-l4t container

```
jetson-l4t -f <firmware release, i.e. 35.4.1> -c remove
```
