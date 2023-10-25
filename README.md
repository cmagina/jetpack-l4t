# jetpack-l4t

Creates a rootful container image with the specified JetPack firmware loaded.
It requires root access to install and run. The scripts expect `podman` to be
the container tool used. The containers can be used to flash a Jetson or IGX
and run `boardctl` commands.

## Installing jetpack-l4t

The setup.sh script downloads the `jetpack-l4t` gitrepo to
`$HOME/.local/share/jetpack-l4t` and installs the jetpack-l4t script to
`$HOME/.local/bin`. This is the script used to build images, flash,
run board control commands and drop into a shell with in the specified
firmware image.

```
./setup.sh -i
```

### Config

Inside of the `$HOME/.local/share/jetpack-l4t` install directory, is a
config file, `$HOME/.local/share/jetpack-l4t/config.sh`. To override or
extend the config contained in that file, create a new config file with
the changes at `$HOME/.config/jetpack-l4t.conf`.

## Uninstalling jetpack-l4t

```
./setup.sh -u
```

## Building the jetpack-l4t container

If the installation for the firmware requires something other then
`apply_binaries.sh` being run, you need to provide a shell script that runs
those commands and specify it using `-s /path/to/script.sh`. You can use the
`files/bsp-setup.sh` script as a starting point.

Firmware releases that are automatically supported:

- 35.4.1
- 35.3.1
- 35.2.1

### Building a jetpack-l4t image for a supported firmware release

```
jetpack-l4t -c build -f <firmware release, i.e. 35.4.1>
```

### Building a jetpack-l4t image for a user provided firmware release

Either download the JetPack Driver package or specify the URL to the
JetPack Driver package that contains the `Linux_for_Tegra` directory
and specify the location to the tarfile using `-d /uri/jetpack_driver.tarfile`.

```
jetpack-l4t -c build -f <firmware release, i.e. 35.4.1> -d /uri/jetpack_driver.tarfile
```

### Building a jetpack-l4t image with a BSP Overlay using a supported firmware release

Either download the BSP or specify the URL to the BSP you want to overlay
ontop of the `Linux_for_Tegra` directory and specify the location to the
tarfile using `-o /uri/bsp_overlay.tarfile`. This file is extracted over the
`Linux_for_Tegra` directory.

```
jetpack-l4t -c build -f <firmware release, i.e. 35.4.1> -o /uri/bsp_overlay.tarfile
```

### Building a jetpack-l4t image with a user provided root filesystem

Either download the root filesystem package or specify the URL to the
root filesystem package and specify the location to the tarfile using
`-m /uri/root_filesystem.tarfile`.

```
jetpack-l4t -c build -f <firmware release, i.e. 35.4.1> -m /uri/root_filesystem.tarfile
```

### Notes

Any of the above commands can be combined as needed.

The `-f <firmware release, i.e. 35.4.1>` argument will be used as the image tag
if one is not specified or vise versa, the `-t <image tag>` argument will be used
as the firmware release if one is not specified.

Use the `-t <image tag>` argument to set the `jetpack-l4t` image version to
something other then the firmware release.

If you do not want to include the Sample filesystem in the `Linux_for_Tegra`
directory, add the `-n` argument to your build commands. This will also not
run the `apply_binaries.sh` script. If you specify a setup script using the
`-s /path/to/script.sh` argument, it will be run even with the `-n` argument.

The default base image for the images is Ubuntu 20.04. If a different
version of Ubuntu is desired, one can be specified with
`-i <version, i.e. 22.04>`.

All firmware, overlay, and filesystem archives are copied to
`$HOME/.local/share/jetpack-l4t/<image tag>` as they need to be in the
container build directory. This directory is deleted after the build
completes. To keep the build artifacts, use the `-k` argument.

## Flashing a Jetson or IGX

Supported Platforms:

- agxorin
- igxorin
- orinnx
- orinnano
- xaviernx

The JetPack board config can be found in the `Linux_for_Tegra` directory,
i.e. jetson-agx-orin-devkit.conf. Drop the `.conf` file extension when
specifying which config flash should use.

```
jetpack-l4t -c flash -t <image tag> -p <platform> -b <jetpack board config>
```

The flash root device can be specified with `-r <rootdev, i.e. external>`.

```
jetpack-l4t -c flash -t <image tag> -p <platform> -b <jetpack board config> -r <rootdev>
```

The jetpack-l4t script checks for the NVIDIA USB device ID associated with the
recovery device for the specified platform before calling flash. If
the platform being flashed uses a different device ID then expected, one can
be passed to the jetpack-l4t script using `-u <usb device id, i.e. 7023>.`
The `-p <platform>` argument is not required if passing the usb recovery
device id.

```
jetpack-l4t -c flash -t <image tag> -u <usb device id> -b <jetpack board config>
```

## Running a board control command

Supported Board Control Platforms:

- agxorin

Board Control Commands:

- power_on
- power_off
- recovery
- reset
- status

```
jetpack-l4t -t <image tag> -p <platform> -c <board control command>
```

## Getting a shell for running manual commands

This will drop you into the specified jetpack-l4t container at the `Linux_for_Tegra` directory.

```
jetpack-l4t -t <image tag> -c shell
```

## Removing a jetpack-l4t container

```
jetpack-l4t -t <image tag> -c remove
```
