# Deployment references

- https://learn.microsoft.com/windows-hardware/manufacture/desktop/winpe-mount-and-customize
- https://learn.microsoft.com/windows-hardware/manufacture/desktop/winpeshlini-reference-launching-an-app-when-winpe-starts
- https://learn.microsoft.com/windows-hardware/drivers/devtest/bcdedit--bootsequence
- https://learn.microsoft.com/windows-hardware/manufacture/desktop/automate-windows-setup
- https://learn.microsoft.com/windows-hardware/customize/desktop/unattend/microsoft-windows-setup-diskconfiguration-disk
- https://learn.microsoft.com/windows/win32/api/winioctl/ns-winioctl-drive_layout_information_ex
- https://learn.microsoft.com/windows-hardware/customize/desktop/unattend/microsoft-windows-shell-setup-autologon-logoncount

The v10 identity guard had no write calls; see the v10.1 amendment below. Kernel API signatures are declared locally
because the Linux build environment has no Windows SDK. Source and host mock tests
are provided. Actual Windows/WinPE execution remains to be validated.

## v10.1
- https://learn.microsoft.com/windows-hardware/customize/desktop/unattend/microsoft-windows-setup-userdata-productkey-key
- https://learn.microsoft.com/windows-hardware/manufacture/desktop/windows-language-pack-default-values
- https://learn.microsoft.com/windows-hardware/manufacture/desktop/default-input-locales-for-windows-language-packs
- https://learn.microsoft.com/windows/win32/api/winioctl/ns-winioctl-get_disk_attributes
- Product.ini format inspected in OSDeploy's own sample: https://gist.github.com/OSDeploy/6c713ad4dafd2678e0e648b080cc17d0

v10.1 guard writes only two plan files on the source USB. It issues no raw disk
write IOCTL. DiskPart executes the isolation plan in WinPE; guard --verify
independently checks all other detected internal disks are offline, target online.

## 0.12
- https://www.microsoft.com/software-download/
- https://support.microsoft.com/en-gb/office/lifecycle/officeinstall/troubleshoot-installing-office
- https://learn.microsoft.com/windows/package-manager/winget/download
