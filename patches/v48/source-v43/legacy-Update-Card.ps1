[CmdletBinding()]
param([switch]$VerifyOnly)
$ErrorActionPreference='Stop'

function RegionHash([IO.FileStream]$Stream,[long]$Offset,[long]$Length,[string]$BackupPath='') {
    [void]$Stream.Seek($Offset,[IO.SeekOrigin]::Begin)
    $hash=[Security.Cryptography.SHA256]::Create()
    $backup=$null
    try {
        if($BackupPath){$backup=[IO.File]::Open($BackupPath,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)}
        $buffer=New-Object byte[] ([int][Math]::Min(8388608L,$Length))
        $left=$Length
        while($left -gt 0){
            $wanted=[int][Math]::Min([long]$buffer.Length,$left)
            $count=$Stream.Read($buffer,0,$wanted)
            if($count -le 0){throw 'Incomplete region read'}
            [void]$hash.TransformBlock($buffer,0,$count,$buffer,0)
            if($null -ne $backup){$backup.Write($buffer,0,$count)}
            $left-=$count
        }
        [void]$hash.TransformFinalBlock([byte[]]@(),0,0)
        if($null -ne $backup){$backup.Flush($true)}
        return ([BitConverter]::ToString($hash.Hash)).Replace('-','').ToLowerInvariant()
    } finally {if($null -ne $backup){$backup.Dispose()};$hash.Dispose()}
}


function Assert-AllocatedVendor([IO.FileStream]$Stream,[long]$Offset,$Ranges) {
    $previousEnd=0L
    if(@($Ranges).Count -lt 2){throw 'Incomplete vendor guard. No changes made.'}
    foreach($range in $Ranges){
        if($range.offset -lt $previousEnd -or $range.length -le 0 -or ($range.offset%4096) -ne 0 -or ($range.length%4096) -ne 0 -or ($range.offset+$range.length) -gt 536870912){throw 'Invalid vendor guard bounds. No changes made.'}
        if((RegionHash $Stream ($Offset+$range.offset) $range.length) -ne $range.sha256){throw ('Allocated vendor content differs at {0}. No changes made. Send this message.'-f $range.offset)}
        $previousEnd=$range.offset+$range.length
    }
}

$stream=$null
$vendorVolume=$null
$vendorLocked=$false
try {
    $principal=New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if(-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){throw 'Right-click UPDATE-CARD.cmd and choose Run as administrator.'}
    Write-Host 'RG34XX SP v35: storage expansion runtime and Windows MTP identification (vendor only)'
    $expected=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'expected-card.json') -Raw|ConvertFrom-Json
    $image=Join-Path $PSScriptRoot 'RG34XXSP-v35-vendor.img'
    if((Get-Item -LiteralPath $image).Length -ne 536870912 -or
       (Get-FileHash -LiteralPath $image -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expected.new_vendor_sha256){throw 'Missing or damaged vendor image. No changes made.'}
    $cards=@(Get-Disk|Where-Object {$_.BusType -eq 'USB' -and $_.Size -eq 64021856256 -and $_.PartitionStyle -eq 'GPT'})
    if($cards.Count -ne 1){throw 'Exactly one matching spare 64 GB USB card is required.'}
    $card=$cards[0]
    if($card.IsBoot -or $card.IsSystem -or $card.IsReadOnly){throw 'This is not a writable spare card.'}
    $bounds=@{1=@(37748736L,134217728L);2=@(171966464L,33554432L);3=@(205520896L,16777216L);4=@(222298112L,67108864L);5=@(289406976L,2147483648L);6=@(2436890624L,536870912L);7=@(2973761536L,536870912L);8=@(3510632448L,8589934592L)}
    $partitions=@(Get-Partition -DiskNumber $card.Number)
    if($partitions.Count -ne 8){throw 'Unexpected partition count. No changes made.'}
    $dataPart=@($partitions|Where-Object PartitionNumber -eq 8)
    $expanded=[long]([Math]::Floor(($card.Size-1536)/1048576)*1048576)-3510632448L
    if($dataPart.Count -ne 1 -or $dataPart[0].Size -notin @(8589934592L,$expanded)){throw "Unexpected Android storage size. No changes made."}
    $bounds[8][1]=[long]$dataPart[0].Size
    foreach($p in $partitions){$b=$bounds[[int]$p.PartitionNumber];if($null -eq $b -or $p.Offset -ne $b[0] -or $p.Size -ne $b[1]){throw 'Unexpected partition layout. No changes made.'}}
    Write-Host ('Checking spare card Disk {0}...'-f $card.Number)
    $access=if($VerifyOnly){[IO.FileAccess]::Read}else{[IO.FileAccess]::ReadWrite}
    $stream=[IO.File]::Open(('\\.\PhysicalDrive{0}'-f $card.Number),[IO.FileMode]::Open,$access,[IO.FileShare]::ReadWrite)
    if((RegionHash $stream 222298112 67108864) -ne $expected.boot_sha256){throw 'The v34 boot fix is required first. No changes made.'}
    if((RegionHash $stream 171966464 33554432) -ne $expected.resources_sha256){throw 'Unexpected boot resources. No changes made.'}
    if((RegionHash $stream 205520896 16777216) -ne $expected.env_sha256){throw 'Unexpected boot environment. No changes made.'}
    Write-Host 'Checking the existing vendor filesystem (512 MB)...'
    $oldHash=RegionHash $stream 2436890624 536870912
    if($oldHash -notin @($expected.accepted_vendor_sha256)){
        Write-Host 'Comparing all allocated vendor data and filesystem metadata...'
        Assert-AllocatedVendor $stream 2436890624 $expected.old_vendor_ranges
        Write-Host 'Allocated content matches exactly; only unused blocks differ.'
    }
    if($VerifyOnly){Write-Host 'All checks passed. No changes made.'}
    else {
        $written=0;$backup=$null
        if($oldHash -eq $expected.new_vendor_sha256){Write-Host 'Vendor already matches v35; no rewrite needed.'}
        else {
            $backup=Join-Path $PSScriptRoot ('previous-vendor-{0}.img'-f [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss-fff'))
            Write-Host 'Saving and verifying the previous vendor filesystem...'
            if((RegionHash $stream 2436890624 536870912 $backup) -ne $oldHash){throw 'Vendor changed during backup. No update written.'}
            if((Get-FileHash -LiteralPath $backup -Algorithm SHA256).Hash.ToLowerInvariant() -ne $oldHash){throw 'Backup verification failed. No update written.'}
            if(-not ('RG34XXVolumeControl' -as [type])) {
                Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;
public static class RG34XXVolumeControl {
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, ExactSpelling=true, SetLastError=true)]
    private static extern SafeFileHandle CreateFileW(string path, uint access,
        uint share, IntPtr security, uint disposition, uint flags, IntPtr template);
    public static SafeFileHandle OpenVolume(string path) {
        SafeFileHandle handle=CreateFileW(path, 0xc0000000u, 3, IntPtr.Zero, 3,
                                         0x80000000u, IntPtr.Zero);
        if (handle.IsInvalid) {
            int error=Marshal.GetLastWin32Error(); handle.Dispose();
            throw new Win32Exception(error);
        }
        return handle;
    }
    [DllImport("kernel32.dll", SetLastError=true)]
    private static extern bool DeviceIoControl(SafeFileHandle handle, uint code,
        IntPtr input, uint inputSize, IntPtr output, uint outputSize,
        out uint returned, IntPtr overlapped);
    public static void Apply(SafeFileHandle handle, uint code) {
        uint returned;
        if (!DeviceIoControl(handle, code, IntPtr.Zero, 0, IntPtr.Zero, 0,
                             out returned, IntPtr.Zero))
            throw new Win32Exception(Marshal.GetLastWin32Error());
    }
}
'@
            }
            Write-Host 'Obtaining exclusive access to the vendor partition...'
            $volumePath='\\?\GLOBALROOT\Device\Harddisk{0}\Partition6' -f $card.Number
            $volumeHandle=[RG34XXVolumeControl]::OpenVolume($volumePath)
            try {$vendorVolume=New-Object IO.FileStream($volumeHandle,[IO.FileAccess]::ReadWrite,4096,$false)}
            catch {$volumeHandle.Dispose();throw}
            [RG34XXVolumeControl]::Apply($vendorVolume.SafeFileHandle,0x00090018)
            $vendorLocked=$true
            [RG34XXVolumeControl]::Apply($vendorVolume.SafeFileHandle,0x00090020)
            # Writes use the locked physical disk, bounded to the first512MB; no extended filesystem command is needed.
            if((RegionHash $stream 2436890624 536870912) -ne $oldHash){throw 'Vendor changed before write. No update written.'}
            Write-Host 'Writing the verified vendor update...'
            $vendorSourceStream=[IO.File]::OpenRead($image)
            try {
                if($vendorSourceStream.Length -ne 536870912 -or
                   (RegionHash $vendorSourceStream 0 536870912) -ne $expected.new_vendor_sha256){throw 'Update image changed. No update written.'}
                [void]$vendorSourceStream.Seek(0,[IO.SeekOrigin]::Begin)
                [void]$stream.Seek(2436890624,[IO.SeekOrigin]::Begin)
                $buffer=New-Object byte[] (8*1024*1024)
                while($written -lt 536870912){
                    $wanted=[int][Math]::Min([long]$buffer.Length,536870912L-$written)
                    $count=$vendorSourceStream.Read($buffer,0,$wanted)
                    if($count -le 0){throw 'Incomplete source image read. Keep the backup and send this message.'}
                    $stream.Write($buffer,0,$count);$written+=$count
                    if(($written % 33554432) -eq 0){Write-Host ('Writing vendor: {0:P0}'-f ($written/536870912.0))}
                }
            } finally {$vendorSourceStream.Dispose()}
            if($written -ne 536870912){throw 'Vendor write length mismatch. Keep the backup and send this message.'}
            $stream.Flush($true)
            Write-Host 'Reading back the complete vendor update...'
            if((RegionHash $stream 2436890624 536870912) -ne $expected.new_vendor_sha256){throw 'Vendor read-back failed. Keep the backup and send this message.'}
        }
        [ordered]@{Result='PASS';Version=35;NativeBootVersion=34;DiskNumber=$card.Number;WrittenBytes=$written;Offset=2436890624L;VendorSHA256=$expected.new_vendor_sha256;Backup=$backup;UtcTime=[DateTime]::UtcNow.ToString('o')}|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $PSScriptRoot 'UPDATE-RESULT.txt') -Encoding utf8
        Write-Host 'SUCCESS: v35 vendor update verified.' -ForegroundColor Green
        Write-Host 'Safely eject, boot in TF1 and allow up to 15 minutes for offline storage expansion. Do not interrupt the first boot.'
    }
} catch {Write-Host ('STOPPED: '+$_.Exception.Message) -ForegroundColor Red;Write-Host ('Location: '+$_.InvocationInfo.PositionMessage);exit 1}
finally {
    if($null -ne $vendorVolume){
        if($vendorLocked){try {[RG34XXVolumeControl]::Apply($vendorVolume.SafeFileHandle,0x0009001c)}catch {}}
        $vendorVolume.Dispose()
    }
    if($null -ne $stream){$stream.Dispose()}
}
