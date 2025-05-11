$VMName = "kali-linux-2025.1a-hyperv-amd64"
$PCIRootLocationPath = "PCIROOT(90)#PCI(0000)#PCI(0000)#PCI(0000)#PCI(0000)"


# "AMD Radeon RX 6700 XT"
# PCI Slot 2 (PCI bus 147, device 0, function 0)
# PCIROOT(90)#PCI(0000)#PCI(0000)#PCI(0000)#PCI(0000)
# ACPI(_SB_)#ACPI(PC02)#ACPI(BR2A)#ACPI(PEGP)#PCI(0000)#PCI(0000)



# Configure the "Automatic Stop Action" of a VM to TurnOff.

Set-VM -VMName $VMName -AutomaticStopAction TurnOff

# Enable Write-Combining on the CPU.

Set-VM -VMName $VMName -GuestControlledCacheTypes $true

# Configure the 32-bit MMIO space.

Set-VM -VMName $VMName -LowMemoryMappedIoSpace 128Mb

# Configure greater than 32-bit MMIO space.

Set-VM -VMName $VMName -HighMemoryMappedIoSpace 18000Mb

# Dismount the device.

Dismount-VMHostAssignableDevice -force -LocationPath "$PCIRootLocationPath"

# "The operation failed.  The current configuration does not allow for OS control of the PCI Express bus. Please check your BIOS or UEFI settings."

# Assign the device to the VM.

Add-VMAssignableDevice -VMName $VMName -LocationPath "$PCIRootLocationPath"

# "The specified device 'PCIROOT(90)#PCI(0000)#PCI(0000)#PCI(0000)#PCI(0000)' was not found on server 'PRECISION5820'."