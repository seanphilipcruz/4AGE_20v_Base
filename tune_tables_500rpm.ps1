$ErrorActionPreference = 'Stop'
$tunePath = Join-Path $PSScriptRoot 'CurrentTune.msq'
$sourcePath = Join-Path $PSScriptRoot 'CurrentTune.before-500rpm-tables.msq'
if (-not (Test-Path -LiteralPath $sourcePath)) { throw "Original tune backup not found: $sourcePath" }
$targetRpm = @(500,1000,1500,2000,2500,3000,3500,4000,4500,5000,5500,6000,6500,7000,7500,8000)
$afrLoad = @(0,2,4,6,8,10,16,20,30,40,50,60,70,80,90,100)
$inv = [Globalization.CultureInfo]::InvariantCulture

function Get-Values([string]$xml,[string]$name) {
  $p = '(?s)<constant\b[^>]*\bname="'+[regex]::Escape($name)+'"[^>]*>(.*?)</constant>'
  $m = [regex]::Match($xml,$p); if (-not $m.Success) { throw "Missing $name" }
  @([regex]::Matches($m.Groups[1].Value,'-?\d+(?:\.\d+)?') | ForEach-Object {[double]::Parse($_.Value,$inv)})
}
function To-Rows([double[]]$v) {
  if ($v.Count -ne 256) { throw "Expected 256 values; found $($v.Count)" }
  $a = foreach($r in 0..15){,@($v[($r*16)..(($r*16)+15)])}; ,$a
}
function Interpolate-Row([double[]]$row,[double[]]$old,[double[]]$new) {
  $a = foreach($rpm in $new) {
    if($rpm -le $old[0]){$row[0];continue}; if($rpm -ge $old[-1]){$row[-1];continue}
    for($i=0;$i -lt $old.Count-1;$i++) { if($rpm -ge $old[$i] -and $rpm -le $old[$i+1]) {
      $f=($rpm-$old[$i])/($old[$i+1]-$old[$i]); $row[$i]+(($row[$i+1]-$row[$i])*$f); break
    }}
  }; ,@($a)
}
function Resample([object[]]$rows,[double[]]$old,[double[]]$new) {
  $a=foreach($row in $rows){,(Interpolate-Row $row $old $new)}; ,$a
}
function Format-Vector([double[]]$v,[int]$d) {
  ($v|ForEach-Object{'         '+$_.ToString("F$d",$inv)+' '}) -join "`r`n"
}
function Format-Table([object[]]$rows,[int]$d) {
  ($rows|ForEach-Object{'         '+(($_|ForEach-Object{$_.ToString("F$d",$inv)})-join ' ')+' '}) -join "`r`n"
}
function Replace-Constant([string]$xml,[string]$name,[string]$body) {
  $p='(?s)(<constant\b[^>]*\bname="'+[regex]::Escape($name)+'"[^>]*>).*?(</constant>)'
  $r=[regex]::Replace($xml,$p,{param($m)$m.Groups[1].Value+"`r`n"+$body+"`r`n      "+$m.Groups[2].Value},1)
  if($r -eq $xml){throw "Missing $name"}; $r
}

$source=[IO.File]::ReadAllText($sourcePath)
$ve=Resample (To-Rows (Get-Values $source 'veTable')) (Get-Values $source 'rpmBins') $targetRpm
$spark=Resample (To-Rows (Get-Values $source 'advTable1')) (Get-Values $source 'rpmBins2') $targetRpm
$afr=Resample (To-Rows (Get-Values $source 'afrTable')) (Get-Values $source 'rpmBinsAFR') $targetRpm
$lambda=foreach($row in $afr){,@($row|ForEach-Object{$_/14.7})}


# Start from the complete pre-change tune; only resample the requested RPM dimensions.
$xml=$source
$xml=Replace-Constant $xml 'veTable' (Format-Table $ve 0)
$xml=Replace-Constant $xml 'rpmBins' (Format-Vector $targetRpm 0)
$xml=Replace-Constant $xml 'advTable1' (Format-Table $spark 0)
$xml=Replace-Constant $xml 'rpmBins2' (Format-Vector $targetRpm 0)
$xml=Replace-Constant $xml 'lambdaTable' (Format-Table $lambda 3)
$xml=Replace-Constant $xml 'afrTable' (Format-Table $afr 1)
$xml=Replace-Constant $xml 'rpmBinsAFR' (Format-Vector $targetRpm 0)

# Repair the source AFR-load constant: its closing tag is missing and it has extra values.
$p='(?s)(<constant\b[^>]*\bname="loadBinsAFR"[^>]*>).*?(?=</page>)'
if(-not [regex]::IsMatch($xml,$p)){throw 'Missing loadBinsAFR'}
$xml=[regex]::Replace($xml,$p,{param($m)$m.Groups[1].Value+"`r`n"+(Format-Vector $afrLoad 1)+"`r`n      </constant>`r`n"},1)
[IO.File]::WriteAllText($tunePath,$xml,[Text.Encoding]::GetEncoding('ISO-8859-1'))
[xml]$validated=[IO.File]::ReadAllText($tunePath)
Write-Output 'Restored original maps and resampled them to 500-RPM bins.'
