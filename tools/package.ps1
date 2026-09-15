$ErrorActionPreference='Stop'
# Standard packaging and the creative preview deliver the same current game.
& (Join-Path $PSScriptRoot 'package-creative.ps1')
