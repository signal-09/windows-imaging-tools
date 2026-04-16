# Windows Imaging Tools

This project is **a reduced and simplified version** of the [Windows Imaging Tools](https://github.com/cloudbase/windows-imaging-tools) project by **Cloudbase Solutions Srl**.

Only a subset of files from the original repository have been extracted and modified to create a minimal version of the toolset.  
The aim is to provide a lighter and more straightforward implementation for specific use cases.

## Important Notice

For **complete documentation, advanced usage, and additional features**, please refer to the **original project**:

🔗 [Cloudbase - Windows Imaging Tools](https://github.com/cloudbase/windows-imaging-tools)

---

**Disclaimer:**  
This repository is based on and adapted from the work of Cloudbase, licensed under the same terms as the original project.  
All credit for the original development belongs to the Cloudbase team.

## Requirements

These scripts need root privileges and relies the following packages:

* bash
* coreutils (`truncate`)
* genisoimage (`mkisofs`)
* qemu-system-x86 (`qemu-system-x86_64`)
* qemu-utils (`qemu-img`)

KVM is not mandatory but highly recommended.

## Example

To create a Windows 2022 Server compressed image, with latest updates, and VNC connection for inspection and debug:

```shell
> ./create-windows-image.sh --vnc --no-prompt --standard --compress --updates 2022

Downloading Windows 2022 (win2k22.iso)...
Image found: Windows Server 2022 SERVERSTANDARD
Create custom ISO image...
Windows ISO image: win2k22.iso
Create Autounattend floppy image...
Autounattend floppy image: win2k22.vfd
Create driver iso image...
virtIO ISO image: virtio-win.iso
Install Windows from ISO...
VNC server running on 0.0.0.0:5900
Complete Windows installation from disk...
VNC server running on 0.0.0.0:5900
Convert and compress Windows disk image (win2k22.qcow2)...
```
