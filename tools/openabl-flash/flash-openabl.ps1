# flash-openabl.ps1 - OpenABL 1.2 para AYN Odin 3 / Odin 3 Portal (SM8750)
#compatible con Windows PowerShell 5.1. Solo ASCII: no escribir acentos aqui.
#Escribe solo el slot inactivo y lo activa. Nunca toca el ABL de serie.

$ErrorActionPreference = 'Stop'

$VERSION = '1.2'
$ELF_NAME = 'abl_signed-SM8750.elf'
$ELF_SIZE = 532480
$ELF_SHA256 = '0dba7b90d1a36e13977c00fec87f4f5ccc8f49b98864ad495a1ed04d35e33c3a'
$TARBALL_URL = 'https://github.com/OpenHandheldCollective/OpenABL/releases/download/v1.2/openabl-v1.2.tar.gz'
$TARBALL_NAME = 'openabl-v1.2.tar.gz'
$ELF_IN_TAR = 'openabl-v1.2/SM8750/abl_signed-SM8750.elf'
$UdevRule = 'SUBSYSTEM=="usb", ATTR{idVendor}=="18d1", MODE="0666"'

$script:LogPath = $null
$script:CleanWorkDir = $false
$script:WorkDir = $null
$script:Fastboot = ''
$script:ElfPath = ''
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'

function Write-Log {
  param([string]$Message)
  Write-Host $Message
  if (-not [string]::IsNullOrEmpty($script:LogPath)) {
    try { Add-Content -LiteralPath $script:LogPath -Value $Message -ErrorAction Stop } catch { }
  }
}

function Write-LogOutput {
  param([string]$Text)
  if ([string]::IsNullOrEmpty($Text)) { return }
  foreach ($line in ($Text -split "\r?\n")) {
    if ($line.Length -gt 0) { Write-Log ('  | ' + $line.TrimEnd()) }
  }
}

function ConvertTo-QuotedArg {
  param([string]$Value)
  if ($Value -match '[\s"]') { return ('"' + $Value.Replace('"', '\"') + '"') }
  return $Value
}

function Invoke-WithTimeout {
  param([string]$FilePath, [string[]]$Arguments, [int]$TimeoutMs)
  $outFile = [System.IO.Path]::GetTempFileName()
  $errFile = [System.IO.Path]::GetTempFileName()
  $exitCode = 124
  $timedOut = $false
  try {
    $quoted = @()
    foreach ($one in $Arguments) { $quoted += (ConvertTo-QuotedArg $one) }
    $argLine = ($quoted -join ' ')
    try {
      $proc = Start-Process -FilePath $FilePath -ArgumentList $argLine -PassThru -NoNewWindow -RedirectStandardOutput $outFile -RedirectStandardError $errFile -ErrorAction Stop
    } catch {
      return [pscustomobject]@{ ExitCode = 1; TimedOut = $false; Output = ('No se pudo ejecutar fastboot: ' + $_.Exception.Message) }
    }
    $finished = $proc.WaitForExit($TimeoutMs)
    if (-not $finished) {
      $timedOut = $true
      try { $proc.Kill() } catch { }
      $proc.WaitForExit() | Out-Null
    } else {
      $proc.Refresh()
      $exitCode = $proc.ExitCode
    }
    $text = ''
    if (Test-Path -LiteralPath $outFile) { $text += [System.IO.File]::ReadAllText($outFile) }
    if (Test-Path -LiteralPath $errFile) { $text += [System.IO.File]::ReadAllText($errFile) }
    return [pscustomobject]@{ ExitCode = $exitCode; TimedOut = $timedOut; Output = $text }
  } finally {
    Remove-Item -LiteralPath $outFile -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $errFile -Force -ErrorAction SilentlyContinue
  }
}

function Finish-Script {
  param([int]$Code)
  if ($script:CleanWorkDir -and -not [string]::IsNullOrEmpty($script:WorkDir)) {
    Remove-Item -LiteralPath $script:WorkDir -Recurse -Force -ErrorAction SilentlyContinue
  }
  if (-not [string]::IsNullOrEmpty($script:LogPath)) {
    Write-Host ('Registro guardado en: ' + $script:LogPath)
  }
  exit $Code
}

function Show-HelpText {
  Write-Log 'Uso: flash-openabl.ps1 [opciones]'
  Write-Log ''
  Write-Log 'Instala OpenABL 1.2 en una AYN Odin 3 / Odin 3 Portal (SM8750) desde un PC,'
  Write-Log 'sin root y sin saber fastboot. Escribe SOLO el slot inactivo y lo activa:'
  Write-Log 'el ABL de serie del otro slot queda intacto.'
  Write-Log ''
  Write-Log 'Opciones:'
  Write-Log '  --help / -Help        Muestra esta ayuda.'
  Write-Log '  --dry-run / -DryRun   Muestra el plan sin descargar ni escribir nada en la consola.'
  Write-Log '  --elf <ruta> / -Elf   Usa un ELF local en vez de descargar el tarball oficial.'
  Write-Log '  --slot a|b / -Slot    Solo si no se puede leer el slot actual: indica cual es el activo.'
  Write-Log '  --yes / -Yes          No pide confirmar escribiendo FLASH. Solo para automatizar;'
  Write-Log '                        usalo unicamente si sabes lo que estas haciendo.'
  Write-Log ''
  Write-Log 'Ejemplo (doble clic en flash-openabl.cmd o desde PowerShell):'
  Write-Log '  .\flash-openabl.ps1 -DryRun'
  Write-Log '  .\flash-openabl.ps1 -Elf C:\ruta\abl_signed-SM8750.elf'
  Write-Log ''
  Write-Log 'Codigos de salida: 0 correcto, 1 error, 2 cancelado por ti, 3 falta algo antes de empezar.'
}

function Show-CableChecks {
  Write-Log 'Comprobaciones que suelen arreglarlo:'
  Write-Log '  1. Usa un cable corto de DATOS (los cables solo de carga no sirven).'
  Write-Log '  2. Enchufa directamente en un puerto del PC, sin hub ni alargador.'
  Write-Log '  3. Prueba otro cable y otro puerto (mejor trasero que frontal).'
  Write-Log '  4. Windows: instala el controlador "Android Bootloader Interface".'
  Write-Log '  5. En Linux haria falta esta regla udev (no aplica en Windows):'
  Write-Log ('     ' + $UdevRule)
}

function Show-FastbootHelp {
  Write-Log 'QUE HACER para entrar en fastboot:'
  Write-Log '  1. Apaga la consola del todo (no suspendida).'
  Write-Log '  2. Manten pulsado Volumen - y, sin soltar, enchufa el cable al PC.'
  Write-Log '  3. Suelta cuando aparezca la pantalla de fastboot.'
  Write-Log '  4. Si no entra: manten Power + Volumen - mientras enchufas el cable.'
  Write-Log 'Importante: debe ser el fastboot del ABL, no el fastbootd de recovery.'
}

# ------------------------------------------------------------ registro -------
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if ([string]::IsNullOrEmpty($scriptDir)) { $scriptDir = (Get-Location).Path }
$script:LogPath = Join-Path $scriptDir ('openabl-flash-' + $stamp + '.log')
try { [System.IO.File]::AppendAllText($script:LogPath, '') } catch { $script:LogPath = $null }
if ([string]::IsNullOrEmpty($script:LogPath)) {
  $script:LogPath = Join-Path ([System.IO.Path]::GetTempPath()) ('openabl-flash-' + $stamp + '.log')
  try { [System.IO.File]::AppendAllText($script:LogPath, '') } catch { $script:LogPath = $null }
}

$script:WorkDir = Join-Path ([System.IO.Path]::GetTempPath()) ('openabl-flash-' + $stamp)
try {
  New-Item -ItemType Directory -Path $script:WorkDir -Force -ErrorAction Stop | Out-Null
  $script:CleanWorkDir = $true
} catch {
  $script:WorkDir = [System.IO.Path]::GetTempPath()
}

Write-Log ('=== flash-openabl.ps1 - OpenABL ' + $VERSION + ' para SM8750 ===')

# ------------------------------------------------------------- opciones ------
$dryRun = $false
$yes = $false
$showHelp = $false
$elfArg = ''
$slotArg = ''
$cliArgs = @($args)
$i = 0
while ($i -lt $cliArgs.Count) {
  $one = [string]$cliArgs[$i]
  if ($one -eq '--help' -or $one -eq '-Help') {
    $showHelp = $true
  } elseif ($one -eq '--dry-run' -or $one -eq '-DryRun') {
    $dryRun = $true
  } elseif ($one -eq '--yes' -or $one -eq '-Yes') {
    $yes = $true
  } elseif ($one -eq '--elf' -or $one -eq '-Elf') {
    $i++
    if ($i -ge $cliArgs.Count) {
      Write-Log 'ERROR: falta la ruta despues de --elf.'
      Show-HelpText
      Finish-Script 1
    }
    $elfArg = [string]$cliArgs[$i]
  } elseif ($one -eq '--slot' -or $one -eq '-Slot') {
    $i++
    if ($i -ge $cliArgs.Count) {
      Write-Log 'ERROR: falta a o b despues de --slot.'
      Show-HelpText
      Finish-Script 1
    }
    $slotArg = ([string]$cliArgs[$i]).ToLowerInvariant()
  } else {
    Write-Log ('ERROR: opcion desconocida: ' + $one)
    Show-HelpText
    Finish-Script 1
  }
  $i++
}

if ($slotArg -ne '' -and $slotArg -ne 'a' -and $slotArg -ne 'b') {
  Write-Log ('ERROR: --slot solo admite a o b (has escrito: ' + $slotArg + ').')
  Show-HelpText
  Finish-Script 1
}

if ($showHelp) {
  Show-HelpText
  Finish-Script 0
}

if ($dryRun) {
  Write-Log 'Modo de prueba (--dry-run): no se descarga nada y no se escribe en la consola.'
}

# El ELF local se comprueba antes de buscar fastboot para poder avisar siempre.
if (-not [string]::IsNullOrEmpty($elfArg)) {
  $elfExists = $false
  try { $elfExists = Test-Path -LiteralPath $elfArg -PathType Leaf -ErrorAction Stop } catch { $elfExists = $false }
  if (-not $elfExists) {
    Write-Log ('ERROR: el ELF indicado no existe: ' + $elfArg)
    Write-Log 'QUE HACER: revisa la ruta o quita -Elf para descargar el oficial.'
    Finish-Script 1
  }
}

# ------------------------------------------------------------- fastboot ------
$cmd = Get-Command fastboot -ErrorAction SilentlyContinue
if ($cmd -ne $null) {
  try { $script:Fastboot = [string]$cmd.Source } catch { $script:Fastboot = '' }
}
if ([string]::IsNullOrEmpty($script:Fastboot)) {
  $candidates = @()
  $envTargets = @(
    @('LOCALAPPDATA', 'Android\Sdk\platform-tools\fastboot.exe'),
    @('ANDROID_HOME', 'platform-tools\fastboot.exe'),
    @('ANDROID_SDK_ROOT', 'platform-tools\fastboot.exe'),
    @('ProgramFiles', 'platform-tools\fastboot.exe')
  )
  foreach ($target in $envTargets) {
    $baseValue = [System.Environment]::GetEnvironmentVariable([string]$target[0])
    if ([string]::IsNullOrEmpty($baseValue)) { continue }
    try {
      $candidatePath = Join-Path -Path $baseValue -ChildPath ([string]$target[1]) -ErrorAction Stop
      if (-not [string]::IsNullOrEmpty($candidatePath)) { $candidates += $candidatePath }
    } catch { }
  }
  foreach ($fixed in @('.\platform-tools\fastboot.exe')) {
    $candidates += $fixed
  }
  if (-not [string]::IsNullOrEmpty($scriptDir)) {
    try {
      $candidatePath = Join-Path -Path $scriptDir -ChildPath 'platform-tools\fastboot.exe' -ErrorAction Stop
      if (-not [string]::IsNullOrEmpty($candidatePath)) { $candidates += $candidatePath }
    } catch { }
  }
  foreach ($candidatePath in $candidates) {
    if ([string]::IsNullOrEmpty($candidatePath)) { continue }
    $exists = $false
    try { $exists = Test-Path -LiteralPath $candidatePath -PathType Leaf -ErrorAction Stop } catch { $exists = $false }
    if ($exists) { $script:Fastboot = $candidatePath; break }
  }
}
if ([string]::IsNullOrEmpty($script:Fastboot)) {
  Write-Log 'ERROR: no se encontro fastboot.exe. No se ha tocado ningun dispositivo.'
  Write-Log 'He mirado en el PATH, %LOCALAPPDATA%\Android\Sdk\platform-tools,'
  Write-Log '%ANDROID_HOME%\platform-tools, %ANDROID_SDK_ROOT%\platform-tools,'
  Write-Log '%ProgramFiles%\platform-tools y .\platform-tools.'
  Write-Log 'QUE HACER:'
  Write-Log '  1. Windows: descarga los platform-tools de Google (SDK Platform Tools).'
  Write-Log '  2. Extraelos en %LOCALAPPDATA%\Android\Sdk\platform-tools y anade esa'
  Write-Log '     carpeta al PATH; vuelve a abrir la terminal despues.'
  Write-Log '  3. Linux: sudo apt install android-tools-fastboot (o sudo pacman -S android-tools).'
  Write-Log '  4. macOS: brew install android-platform-tools.'
  Write-Log '  5. Comprueba con: fastboot --version'
  Finish-Script 3
}
Write-Log ('fastboot encontrado: ' + $script:Fastboot)

# ------------------------------------------------------------------ ELF ------
if ($dryRun -and [string]::IsNullOrEmpty($elfArg)) {
  Write-Log ('Modo de prueba: se omitiria la descarga de ' + $TARBALL_NAME + '.')
} else {
  if (-not [string]::IsNullOrEmpty($elfArg)) {
    if (-not (Test-Path -LiteralPath $elfArg -PathType Leaf)) {
      Write-Log ('ERROR: el ELF indicado no existe: ' + $elfArg)
      Write-Log 'QUE HACER: revisa la ruta o quita -Elf para descargar el oficial.'
      Finish-Script 1
    }
    $script:ElfPath = $elfArg
    Write-Log ('Usando ELF local: ' + $script:ElfPath)
  } else {
    $tarballPath = Join-Path $script:WorkDir $TARBALL_NAME
    Write-Log ('Descargando el tarball oficial de OpenABL ' + $VERSION + '...')
    try {
      Invoke-WebRequest -Uri $TARBALL_URL -OutFile $tarballPath -UseBasicParsing -ErrorAction Stop
    } catch {
      Write-Log 'ERROR: no se pudo descargar el tarball oficial.'
      Write-Log ('Detalle: ' + $_.Exception.Message)
      Write-Log 'QUE HACER: comprueba la conexion o usa -Elf con un ELF local.'
      Finish-Script 1
    }
    if (-not (Test-Path -LiteralPath $tarballPath)) {
      Write-Log 'ERROR: no aparece el tarball descargado.'
      Write-Log 'QUE HACER: comprueba la conexion o usa -Elf con un ELF local.'
      Finish-Script 1
    }
    $tarCmd = $null
    $tarFound = Get-Command tar.exe -ErrorAction SilentlyContinue
    if ($tarFound -ne $null) {
      $tarCmd = [string]$tarFound.Source
    } else {
      $sysTar = Join-Path $env:WINDIR 'System32\tar.exe'
      if (Test-Path -LiteralPath $sysTar) { $tarCmd = $sysTar }
    }
    if ([string]::IsNullOrEmpty($tarCmd)) {
      Write-Log 'ERROR: no hay tar.exe para extraer el ELF del tarball.'
      Write-Log 'QUE HACER: extrae el ELF a mano y usa -Elf C:\ruta\abl_signed-SM8750.elf'
      Finish-Script 1
    }
    $tarOut = Join-Path $script:WorkDir 'tar-salida.txt'
    & $tarCmd -xzf $tarballPath -C $script:WorkDir $ELF_IN_TAR > $tarOut 2>&1
    if ($LASTEXITCODE -ne 0) {
      Write-Log ('ERROR: no se pudo extraer ' + $ELF_IN_TAR + ' del tarball.')
      Write-LogOutput ([System.IO.File]::ReadAllText($tarOut))
      Write-Log ('QUE HACER: extrae a mano ' + $ELF_NAME + ' y usa -Elf con su ruta.')
      Finish-Script 1
    }
    $script:ElfPath = Join-Path $script:WorkDir $ELF_IN_TAR
    Write-Log ('ELF extraido: ' + $script:ElfPath)
  }

  if (-not (Test-Path -LiteralPath $script:ElfPath -PathType Leaf)) {
    Write-Log ('ERROR: no aparece el fichero ELF esperado: ' + $script:ElfPath)
    Finish-Script 1
  }

  $item = Get-Item -LiteralPath $script:ElfPath
  $actualSize = [long]$item.Length
  $actualSha = (Get-FileHash -LiteralPath $script:ElfPath -Algorithm SHA256).Hash.ToLowerInvariant()
  Write-Log ('Comprobando ELF: tamano=' + $actualSize + ' bytes (esperado ' + $ELF_SIZE + ').')
  Write-Log ('Comprobando ELF: sha256=' + $actualSha)
  if ($actualSize -ne $ELF_SIZE -or $actualSha -ne $ELF_SHA256) {
    Write-Log 'ERROR: el ELF no es valido. No se ha tocado el dispositivo.'
    Write-Log ('  Tamano esperado: ' + $ELF_SIZE + ' bytes. Tamano obtenido: ' + $actualSize + ' bytes.')
    Write-Log ('  sha256 esperado: ' + $ELF_SHA256)
    Write-Log ('  sha256 obtenido: ' + $actualSha)
    Write-Log 'QUE HACER: vuelve a descargar el tarball oficial o pasa un ELF bueno con -Elf.'
    Finish-Script 1
  }
  Write-Log 'ELF correcto (tamano y sha256 coinciden).'
}

# -------------------------------------------------------------- dispositivo --
$res = Invoke-WithTimeout $script:Fastboot @('devices') 15000
$devicesOut = $res.Output
Write-Log ("Salida de 'fastboot devices' (codigo " + $res.ExitCode + '):')
Write-LogOutput $devicesOut

if ($devicesOut -match '(?i)no permissions') {
  Write-Log 'ERROR: fastboot ve el dispositivo pero no tiene permisos (no permissions).'
  Write-Log 'QUE HACER: en Linux crea /etc/udev/rules.d/51-android.rules con:'
  Write-Log ('  ' + $UdevRule)
  Write-Log 'Luego: sudo udevadm control --reload-rules && sudo udevadm trigger'
  Write-Log 'y desenchufa y vuelve a enchufar. En Windows instala el controlador'
  Write-Log '"Android Bootloader Interface" desde el Administrador de dispositivos.'
  Finish-Script 3
}

$deviceLines = @($devicesOut -split "\r?\n" | Where-Object { $_ -match '\S+\s+fastboot' })
$devCount = $deviceLines.Count
if ($res.TimedOut -or $res.ExitCode -ne 0) {
  Write-Log "ERROR: 'fastboot devices' agoto el tiempo de espera (15 s) o fallo."
  Show-FastbootHelp
  Show-CableChecks
  Finish-Script 3
}
if ($devCount -eq 0) {
  Write-Log 'ERROR: no hay ninguna consola en fastboot. No se ha escrito nada.'
  Show-FastbootHelp
  Show-CableChecks
  Finish-Script 3
}
if ($devCount -gt 1) {
  Write-Log ('ERROR: hay ' + $devCount + ' dispositivos en fastboot. No voy a adivinar cual es.')
  Write-Log 'QUE HACER: deja conectada solo la Odin 3 y vuelve a ejecutar el script.'
  Finish-Script 3
}
Write-Log 'Se ha encontrado exactamente una consola en fastboot.'

# ---------------------------------------------------------------- getvars ----
$res = Invoke-WithTimeout $script:Fastboot @('getvar', 'unlocked') 12000
Write-Log ("Salida de 'getvar unlocked' (codigo " + $res.ExitCode + '):')
Write-LogOutput $res.Output
$match = [regex]::Match($res.Output, '(?im)^unlocked:\s*(\S+)')
$unlockedVal = ''
if ($match.Success) { $unlockedVal = $match.Groups[1].Value }
if ($unlockedVal -ne '') {
  if ($unlockedVal -eq 'no') {
    Write-Log 'ERROR: el bootloader esta BLOQUEADO (unlocked: no).'
    Write-Log 'QUE HACER: desbloquealo tu desde los ajustes de Android antes de seguir.'
    Write-Log 'Advertencia: desbloquear borra los datos de la consola.'
    Write-Log 'Este script NUNCA desbloquea el bootloader por su cuenta.'
    Finish-Script 3
  } elseif ($unlockedVal -eq 'yes') {
    Write-Log 'Bootloader desbloqueado (unlocked: yes).'
  } else {
    Write-Log ('Aviso: no se entiende la respuesta de getvar unlocked (' + $unlockedVal + ').')
    Write-Log 'Siguiendo con cuidado; si el flash falla, comprueba el desbloqueo.'
  }
} else {
  Write-Log 'Aviso: no se pudo leer getvar unlocked. Siguiendo: no es obligatorio'
  Write-Log 'para este metodo, pero si el flash falla comprueba el desbloqueo.'
}

$res = Invoke-WithTimeout $script:Fastboot @('getvar', 'current-slot') 12000
Write-Log ("Salida de 'getvar current-slot' (codigo " + $res.ExitCode + '):')
Write-LogOutput $res.Output
$match = [regex]::Match($res.Output, '(?im)^current-slot:\s*(\S+)')
$currentSlot = ''
if ($match.Success) { $currentSlot = $match.Groups[1].Value.ToLowerInvariant() }
if ($currentSlot -ne 'a' -and $currentSlot -ne 'b') { $currentSlot = '' }

if ($currentSlot -ne '') {
  if ($slotArg -ne '' -and $slotArg -ne $currentSlot) {
    Write-Log ('Aviso: se ha leido el slot actual (' + $currentSlot + '), asi que se ignora -Slot ' + $slotArg + '.')
  }
} elseif ($slotArg -ne '') {
  Write-Log ('Aviso: no se pudo leer el slot actual; usando -Slot ' + $slotArg + ' como indicaste.')
  $currentSlot = $slotArg
} else {
  Write-Log 'ERROR: no se pudo leer el slot actual con getvar current-slot.'
  Write-Log 'Es un fallo conocido: en estas consolas fastboot getvar all se cuelga'
  Write-Log 'mientras que flash funciona. Por seguridad no adivinamos el slot.'
  Write-Log 'QUE HACER: vuelve a ejecutar con -Slot a o -Slot b indicando cual es'
  Write-Log 'el slot activo (por ejemplo: .\flash-openabl.ps1 -Slot a).'
  Finish-Script 3
}

if ($currentSlot -eq 'a') { $targetSlot = 'b' } else { $targetSlot = 'a' }

# ------------------------------------------------------------------- plan ----
Write-Log ''
Write-Log 'PLAN (nada se ha escrito todavia):'
Write-Log ('  Slot activo ahora:            ' + $currentSlot)
Write-Log ('  Slot donde se escribira:      ' + $targetSlot + ' (el inactivo)')
Write-Log ('  ABL de serie:                 queda intacto en el slot ' + $currentSlot)
Write-Log ('  Version a instalar:           OpenABL ' + $VERSION + ' (SM8750)')
Write-Log ('  Fichero:                      ' + $ELF_NAME + ', ' + $ELF_SIZE + ' bytes')
Write-Log ('  sha256:                       ' + $ELF_SHA256)
Write-Log ''

if ($dryRun) {
  Write-Log 'Fin del modo de prueba: no se ha descargado nada cuando no se pidio'
  Write-Log 'y no se ha escrito ni activado ningun slot. No se reinicia la consola.'
  Finish-Script 0
}

# ------------------------------------------------------------ confirmacion ---
if ($yes) {
  Write-Log 'Opcion -Yes: se omite la confirmacion (solo para automatizar).'
} else {
  Write-Log 'Escribe exactamente FLASH (mayusculas) para autorizar el flash:'
  $answer = Read-Host '>'
  Write-Log ('Has escrito: ' + $answer)
  if ($answer -cne 'FLASH') {
    Write-Log ('Cancelado: no se ha escrito ni activado nada. El slot activo sigue siendo ' + $currentSlot + '.')
    Finish-Script 2
  }
}

# ------------------------------------------------------------------ flash ----
Write-Log ('Flasheando abl_' + $targetSlot + ' (puede tardar hasta 3 minutos)...')
$fbArgs = @('flash', ('abl_' + $targetSlot), $script:ElfPath)
$res = Invoke-WithTimeout $script:Fastboot $fbArgs 180000
Write-Log ("Salida de 'flash abl_" + $targetSlot + "' (codigo " + $res.ExitCode + '):')
Write-LogOutput $res.Output
if ($res.TimedOut -or $res.ExitCode -ne 0 -or $res.Output -match '(?i)FAILED' -or $res.Output -notmatch '(?i)(OKAY|Finished)') {
  if ($res.TimedOut) {
    Write-Log 'ERROR: el flash agoto el tiempo de espera (180 s).'
  } else {
    Write-Log ('ERROR: el flash no termino correctamente (codigo ' + $res.ExitCode + ').')
  }
  Write-Log ('El slot activo NO se ha tocado: sigue siendo ' + $currentSlot + '.')
  Write-Log 'No se ha ejecutado --set-active.'
  Show-CableChecks
  Finish-Script 1
}
Write-Log ('Flash correcto: OpenABL esta escrito en abl_' + $targetSlot + '.')

# -------------------------------------------------------------- set-active ---
Write-Log ('Activando el slot ' + $targetSlot + '...')
$res = Invoke-WithTimeout $script:Fastboot @("--set-active=$targetSlot") 30000
Write-Log ("Salida de '--set-active=" + $targetSlot + "' (codigo " + $res.ExitCode + '):')
Write-LogOutput $res.Output
if ($res.TimedOut -or $res.ExitCode -ne 0 -or $res.Output -match '(?i)FAILED' -or $res.Output -notmatch '(?i)(OKAY|Finished|set to)') {
  Write-Log ('ERROR: no se pudo activar el slot ' + $targetSlot + ' (codigo ' + $res.ExitCode + ').')
  Write-Log ('OpenABL SI esta escrito en abl_' + $targetSlot + ', pero todavia no esta activo.')
  Write-Log 'QUE HACER: puedes activarlo despues desde fastboot con:'
  Write-Log ('  fastboot --set-active=' + $targetSlot)
  Write-Log ('El slot activo sigue siendo ' + $currentSlot + ' por ahora.')
  Finish-Script 1
}
Write-Log ('Slot ' + $targetSlot + ' activado correctamente.')

# ---------------------------------------------------------------- resumen ----
Write-Log ''
Write-Log '=== HECHO ==='
Write-Log ('  Version instalada:  OpenABL ' + $VERSION)
Write-Log ('  sha256 (corto):     ' + $ELF_SHA256.Substring(0, 12))
Write-Log ('  Slot escrito:       ' + $targetSlot)
Write-Log ('  Slot activo:        ' + $targetSlot)
Write-Log ('  Slot de serie:      ' + $currentSlot + ' (intacto)')
Write-Log ''
Write-Log 'Pasos siguientes en la consola:'
Write-Log '  1. Desconecta el cable USB.'
Write-Log '  2. Enciende manteniendo Volumen - para abrir el menu de OpenABL.'
Write-Log '  3. Elige Device model: AYN Odin 3 o AYN Odin 3 Portal (segun tu modelo).'
Write-Log '  4. Elige Boot mode: Linux.'
Write-Log '  5. Elige el origen: SD o Internal.'
Write-Log '  6. Pulsa Start. Si es la primera vez y no eliges modelo, la pantalla queda negra.'
Write-Log ('La vuelta atras: desde fastboot, fastboot --set-active=' + $currentSlot + ',')
Write-Log "o en el menu de OpenABL elige 'Boot other slot'."
Write-Log 'Este script no reinicia ni apaga la consola.'
Finish-Script 0
