# +--------------------------------------------------------------------------------------------------+
# |  __     __  ____  ____  _  _    ____  _  _  __ _  ____  __    ____  ____                         |
# | (  )   / _\(_  _)(  __)( \/ )  (  _ \/ )( \(  ( \(    \(  )  (  __)/ ___)                        |
# | / (_/\/    \ )(   ) _)  )  (    ) _ () \/ (/    / ) D (/ (_/\ ) _) \___ \                        |
# | \____/\_/\_/(__) (____)(_/\_)  (____/\____/\_)__)(____/\____/(____)(____/                        |
# +--------------------------------------------------------------------------------------------------+
# |                                                                                                  |
# |   Copyright (C) 2025 KirbyNel0                                                                   |
# |                                                                                                  |
# |   This program is free software: you can redistribute it and/or modify                           |
# |   it under the terms of the GNU General Public License as published by                           |
# |   the Free Software Foundation, either version 3 of the License, or                              |
# |   (at your option) any later version.                                                            |
# |                                                                                                  |
# |   This program is distributed in the hope that it will be useful,                                |
# |   but WITHOUT ANY WARRANTY; without even the implied warranty of                                 |
# |   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the                                  |
# |   GNU General Public License for more details.                                                   |
# |                                                                                                  |
# |   You should have received a copy of the GNU General Public License                              |
# |   along with this program.  If not, see <https://www.gnu.org/licenses/>.                         |
# |                                                                                                  |
# +--------------------------------------------------------------------------------------------------+

# +--------------------------------------------------------------------------------------------------+
# | ARGUMENTS                                                                                        |
# +--------------------------------------------------------------------------------------------------+

param (
	[switch] $Install,
	[switch] $Uninstall,
	[string] $ConfigFile = [string] "texbundle.json"
)

# Exit on error
$ErrorActionPreference = "Stop"

if (!($Install -or $Uninstall)) {
	Write-Error "Please specify either -Install or -Uninstall"
	Exit 1
}

# Debugging on linux
$env:AppData = "/tmp"

# +--------------------------------------------------------------------------------------------------+
# | WORKING DIRECTORY                                                                                |
# +--------------------------------------------------------------------------------------------------+

$ConfigFile = [IO.Path]::GetFullPath("$ConfigFile")

# Directory of the config file
$Root = Split-Path "$ConfigFile" -Parent

Set-Location "$Root"

# +--------------------------------------------------------------------------------------------------+
# | READ CONFIG FILE                                                                                 |
# +--------------------------------------------------------------------------------------------------+

# File where package information is stored
# $ConfigFile

# The dictionary storing all configuration
$Config = Get-Content "$ConfigFile" | ConvertFrom-Json -AsHashTable

if (!$Config) {
	Write-Error "Cannot read config file $ConfigFile"
	Exit 1
}

function Get-Value {
	param (
		$Mapping,
		[string] $Key,
		[boolean] $Required,
		$Default = ""
	)
	
	if (!$Mapping[$Key]) {
		if ($Required) {
			Write-Error "Missing required key: $Key"
			Exit 1
		} else {
			return $Default
		}
	}
	
	return $Mapping[$Key]
}

# The name of the package. Used for texmf file paths.
$PackageName = Get-Value $Config -Key "name" -Required 1

# A list of all .sty of this package.
$PackageList = Get-Value $Config -Key "sty" -Required 0 -Default @()

# A list of all .cls of this package.
$ClassList = Get-Value $Config -Key "cls" -Required 0 -Default @()

# A list of all other files of this package.
$ResourceList = Get-Value $Config -Key "res" -Required 0 -Default @()

# The directory where all .sty source files must be located.
$TeXmfStySourceDir = Get-Value $Config -Key "sty-dir" -Required 0 -Default "texmf"

if (!(Test-Path "$TeXmfStySourceDir" -PathType "Container")) {
	Write-Error "Must be a directory: $TeXmfStySourceDir"
	Exit 1
}

# The directory where all .cls source files must be located.
$TeXmfClsSourceDir = Get-Value $Config -Key "cls-dir" -Required 0 -Default "texmf"

if (!(Test-Path "$TeXmfClsSourceDir" -PathType "Container")) {
	Write-Error "Must be a directory: $TeXmfClsSourceDir"
	Exit 1
}

# The directory where all resource files must be located. (optional)
$ResourceSourceDir = Get-Value $Config -Key "res-dir" -Required 0 -Default "resources"

if (!(Test-Path "$ResourceSourceDir" -PathType "Container")) {
	$ResourceSourceDir = $Null
	if (!($ResourceList.Length -eq 0)) {
		$ResourceList = $Null
		Write-Host "[!] Resource directory not found, ignoring all resources"
	}
}

# The directory where all .cwl source files must be located. (optional)
$CWLSourceDir = Get-Value $Config -Key "cwl-dir" -Required 0 -Default "autocompletion"

if (!(Test-Path "$CWLSourceDir" -PathType "Container")) {
	$CWLSourceDir = $Null
}

# +--------------------------------------------------------------------------------------------------+
# | TARGET DIRECTORIES                                                                               |
# +--------------------------------------------------------------------------------------------------+

# The directory where all .sty and .cls source files should be copied to.
$TeXmfDir = ""

# The directory where all .cwl source files should be copied to.
$TeXStudioDir = ""

if ($IsLinux) {
	$TeXmfDir = Join-Path "$env:HOME" "texmf" "tex" "latex" "$PackageName"
	$TeXStudioDir = Join-Path "$env:HOME" ".config" "texstudio" "completion" "user"
} elseif ($IsWindows) {
	$TeXmfDir = Join-Path "$env:AppData" "MiKTeX" "latex" "$PackageName"
	$TeXStudioDir = Join-Path "$env:AppData" "texstudio" "completion" "user"
} elseif ($IsMacOS) {
	$TeXmfDir = Join-Path "$env:HOME" "Library" "texmf" "tex" "latex" "$PackageName"
	$TeXStudioDir = Join-Path "$env:HOME" ".config" "texstudio" "completion" "user"
}

New-Item -ItemType "Directory" -Path "$TeXmfDir" -Force | Out-Null
New-Item -ItemType "Directory" -Path "$TeXStudioDir" -Force | Out-Null

# +--------------------------------------------------------------------------------------------------+
# | METHOD SELECTION                                                                                 |
# +--------------------------------------------------------------------------------------------------+

# On windows, only Admins can create symbolic links. For simplicity, this feature is ignored here.

function Install-File {
	param (
		$FromFile,
		$ToFile
	)
	
	Copy-Item -Path "$Source" -Destination "$Dest"
}

# +--------------------------------------------------------------------------------------------------+
# | ACTION                                                                                           |
# +--------------------------------------------------------------------------------------------------+

function Iter-Files {
	param (
		$Name,
		$Files,
		$From,
		$To,
		$Suffix
	)
	
	if ($From -eq $Null -or $Files.Length -eq 0) {
		return
	}
	
	Write-Host
	Write-Host "==> $Name"
	Write-Host "From: $From"
	Write-Host "To:   $To"
	
	foreach ($Name in $Files) {
		$Source = Join-Path "$From" "$Name$Suffix"
		$Dest = Join-Path "$To" "$Name$Suffix"
		
		$Source = [IO.Path]::GetFullPath("$Source")
		$Dest = [IO.Path]::GetFullPath("$Dest")
		
		# Create possible directories
		$ParentDir = Split-Path "$Dest" -Parent
		
		if ($Install) {
			if (!(Test-Path "$Source" -PathType "Leaf")) {
				continue
			}
			
			Write-Host " + $Name"
			
			New-Item -ItemType "Directory" -Path "$ParentDir" -Force | Out-Null
			Install-File -FromFile "$Source" -ToFile "$Dest"
		} elseif ($Uninstall) {
			if (!(Test-Path "$Dest" -PathType "Leaf")) {
				continue
			}
			
			Write-Host " - $Name"
			Remove-Item -Path "$Dest"
		}
	}
}

if ($Install) {
	Write-Host "[ Install $PackageName ]"
} elseif ($Uninstall) {
	Write-Host "[ Uninstall $PackageName ]"
}

Iter-Files "LaTeX packages" $PackageList -From "$TeXmfStySourceDir" -To "$TeXmfDir" -Suffix ".sty"

Iter-Files "LaTeX document classes" $ClassList -From "$TeXmfClsSourceDir" -To "$TeXmfDir" -Suffix ".cls"

Iter-Files "Resource files" $ResourceList -From "$ResourceSourceDir" -To "$TeXmfDir" -Suffix ""

Iter-Files "TeXStudio autocompletion files" $($PackageList; $ClassList) -From "$CWLSourceDir" -To "$TeXStudioDir" -Suffix ".cwl"
