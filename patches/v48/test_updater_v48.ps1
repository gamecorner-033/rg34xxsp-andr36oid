$ErrorActionPreference='Stop'
$workspace=$PSScriptRoot
$folder=Join-Path $workspace 'RG34XXSP-v48-video-playback-fix-after-v43'
$scriptFile=Join-Path $folder 'Update-Card.ps1'
$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile($scriptFile,[ref]$tokens,[ref]$errors)
if($errors.Count){throw 'Updater syntax error'}
foreach($function in $ast.FindAll({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst]},$true)){
    . ([scriptblock]::Create($function.Extent.Text))
}
$csharp=$ast.FindAll({param($node) $node -is [Management.Automation.Language.StringConstantExpressionAst] -and $node.Value.StartsWith('using System;')},$true)
if($csharp.Count -ne 1){throw 'Missing lock helper'}
Add-Type -TypeDefinition $csharp[0].Value
$expected=Get-Content (Join-Path $folder 'expected-card.json') -Raw|ConvertFrom-Json
if($expected.vendor_offset -ne 2436890624L -or $expected.vendor_bytes -ne 536870912L){throw 'Incorrect vendor bounds'}
$source=Join-Path $folder 'RG34XXSP-v48-vendor.img'
if((Get-Item $source).Length -ne $expected.vendor_bytes -or (Get-FileHash $source -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expected.new_vendor_sha256){throw 'Damaged payload'}
$text=Get-Content $scriptFile -Raw
foreach($old in @('9818865664','2235564032','2185232384','2218786816','0x00090083')){if($text.Contains($old)){throw ('Obsolete offset or invalid RAW control: '+$old)}}
foreach($required in @('0x00090018','0x00090020','536870912L-$written','RegionHash $stream 2436890624 536870912 $backup','Vendor changed before write','Vendor read-back failed')){if(-not $text.Contains($required)){throw ('Missing guard: '+$required)}}
if($text.IndexOf('Saving and verifying the previous vendor filesystem') -ge $text.IndexOf('Writing the verified vendor update')){throw 'Backup must precede writes'}
$oldSource=Join-Path $workspace 'source-v43/vendor.img'
$s=[IO.File]::OpenRead($oldSource)
try{Assert-AllocatedVendor $s 0 $expected.old_vendor_ranges}finally{$s.Dispose()}
Write-Output 'V48_UPDATER_SYNTAX_NATIVE_HELPER_REGION_GUARDS_BACKUP_AND_SOURCE_HASH_TESTS_PASS'

