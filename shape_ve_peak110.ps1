$ErrorActionPreference = 'Stop'
$tunePath = Join-Path $PSScriptRoot 'CurrentTune.msq'
if (-not (Test-Path -LiteralPath $tunePath)) { throw "Active tune not found: $tunePath" }

$rows = @(
  @(42,44,46,46,45,44,43,42,42,42,42,42,42,42,42,42),
  @(43,45,47,47,46,45,44,43,43,43,43,43,43,43,43,43),
  @(44,46,48,49,49,48,47,46,46,46,46,46,46,46,46,46),
  @(45,47,49,50,51,51,51,51,51,51,51,51,51,50,50,49),
  @(46,48,50,52,53,54,55,56,56,57,57,57,56,55,54,53),
  @(47,49,52,54,56,58,60,62,63,64,64,64,63,62,61,60),
  @(48,50,54,57,60,63,66,69,71,72,72,72,71,70,68,67),
  @(49,51,55,59,63,67,71,74,76,77,78,78,77,76,74,72),
  @(50,52,57,62,67,72,77,81,84,86,87,87,86,85,83,80),
  @(51,53,59,65,71,77,82,87,91,94,95,95,94,92,89,86),
  @(52,54,61,68,74,81,87,92,96,99,101,101,100,98,95,92),
  @(53,55,63,70,77,84,90,95,99,102,104,105,104,102,99,96),
  @(54,56,65,72,79,86,92,97,101,104,106,107,107,105,102,99),
  @(55,57,67,74,81,88,94,99,103,106,108,109,109,107,104,101),
  @(56,58,69,76,83,90,96,101,105,108,109,110,110,108,105,102),
  @(57,60,71,78,85,92,98,103,107,109,110,110,110,109,107,104)
)

$body = ($rows | ForEach-Object { '         ' + ($_ -join '.0 ') + '.0 ' }) -join "`r`n"
$xml = [IO.File]::ReadAllText($tunePath)
$pattern = '(?s)(<constant\b[^>]*\bname="veTable"[^>]*>).*?(</constant>)'
if (-not [regex]::IsMatch($xml, $pattern)) { throw 'veTable not found' }
$xml = [regex]::Replace($xml, $pattern, { param($m) $m.Groups[1].Value + "`r`n" + $body + "`r`n      " + $m.Groups[2].Value }, 1)
[IO.File]::WriteAllText($tunePath, $xml, [Text.Encoding]::GetEncoding('ISO-8859-1'))
[xml]$validated = [IO.File]::ReadAllText($tunePath)
Write-Output 'Installed the shaped 110-peak VE surface into the active tune.'
