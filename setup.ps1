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

<#
.SYNOPSIS
Installation tool for LaTeX bundles.

.DESCRIPTION
This script can be used to install a bunch of LaTeX files from a configuration file, usually named
"texbundle.json". This configuration file defines a LaTeX bundle which will be installed for the
current user.

A LaTeX bundle is just a bunch of LaTeX files, like packages and document classes, which LaTeX
should always be able to find when compiling your documents.

Installation simply includes copying the files of the bundle to predefined places in your file
system, which LaTeX searches by default.

.PARAMETER Install
If provided, will install the current bundle.

.PARAMETER Uninstall
If provided, will uninstall the current bundle. Note that, if the configuration changed, some files
of the bundle may not be uninstalled properly. If provided with -Install, the bundle is installed
instead.

.PARAMETER ConfigFile
Defines the configuration file to use, defaults to "texbundle.tex". The bundle defined in that
file is referred to as "current bundle".

.PARAMETER SymLink
Create symbolic links instead of copying files. Recommended for git repostories.
Requires admin privileges on windows.
#>

# +--------------------------------------------------------------------------------------------------+
# | ARGUMENTS                                                                                        |
# +--------------------------------------------------------------------------------------------------+

param (
	[switch] $Install,
	[switch] $Uninstall,
	[string] $ConfigFile = [string] "texbundle.json",
	[switch] $SymLink
)

# Exit on error
$ErrorActionPreference = "Stop"

if (!($Install -or $Uninstall)) {
	Write-Error "Please specify either -Install or -Uninstall"
	Exit 1
}

# +--------------------------------------------------------------------------------------------------+
# | WORKING DIRECTORY                                                                                |
# +--------------------------------------------------------------------------------------------------+

# Resolve path relative to $Root, even if it does not exist
function Resolve-FullPath {
	param(
		$Path
	)
	
	if ([IO.Path]::IsPathRooted("$Path")) {
		# Path is already absolute
		return "$Path"
	}
	# Resolve relative to $Root
	return [IO.Path]::GetFullPath("$Path", "$Root")
}

if (!(Test-Path "$ConfigFile")) {
	Write-Error "Configuration file is missing: $ConfigFile"
	Exit 1
}

# Resolve config file relative to working directory
$ConfigFile = Resolve-Path "$ConfigFile"

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
$BundleName = Get-Value $Config -Key "name" -Required 1

# A list of all .sty of this package.
$StyList = Get-Value $Config -Key "sty" -Required 0 -Default @()

# A list of all .cls of this package.
$ClsList = Get-Value $Config -Key "cls" -Required 0 -Default @()

# A list of all other files of this package.
$ResList = Get-Value $Config -Key "res" -Required 0 -Default @()

# The directory where all .sty source files must be located.
$StySourceDir = Get-Value $Config -Key "sty-dir" -Required 0 -Default "texmf"

if ($StyList.Length -gt 0 -and !(Test-Path "$StySourceDir" -PathType "Container")) {
	Write-Error "Must be a directory: $StySourceDir"
	Exit 1
}

# The directory where all .cls source files must be located.
$ClsSourceDir = Get-Value $Config -Key "cls-dir" -Required 0 -Default "texmf"

if ($ClsList.Length -gt 0 -and !(Test-Path "$ClsSourceDir" -PathType "Container")) {
	Write-Error "Must be a directory: $ClsSourceDir"
	Exit 1
}

# The directory where all resource files must be located. (optional)
$ResSourceDir = Get-Value $Config -Key "res-dir" -Required 0 -Default "resources"

if (!(Test-Path "$ResSourceDir" -PathType "Container")) {
	$ResSourceDir = $Null
	if (!($ResList.Length -eq 0)) {
		$ResList = $Null
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
	$TeXmfDir = Join-Path "$env:HOME" "texmf" "tex" "latex" "$BundleName"
	$TeXStudioDir = Join-Path "$env:HOME" ".config" "texstudio" "completion" "user"
} elseif ($IsWindows) {
	$TeXmfDir = Join-Path "$env:AppData" "MiKTeX" "latex" "$BundleName"
	$TeXStudioDir = Join-Path "$env:AppData" "texstudio" "completion" "user"
} elseif ($IsMacOS) {
	$TeXmfDir = Join-Path "$env:HOME" "Library" "texmf" "tex" "latex" "$BundleName"
	$TeXStudioDir = Join-Path "$env:HOME" ".config" "texstudio" "completion" "user"
} else {
	Write-Error "Unknown operating system"
	Exit 1
}

New-Item -ItemType "Directory" -Path "$TeXmfDir" -Force | Out-Null
New-Item -ItemType "Directory" -Path "$TeXStudioDir" -Force | Out-Null

# +--------------------------------------------------------------------------------------------------+
# | METHOD SELECTION                                                                                 |
# +--------------------------------------------------------------------------------------------------+

# On windows, only Admins can create symbolic links. For simplicity, this feature is ignored here.
if ($Symlink) {
	if ($IsWindows) {
		$User = [Security.Principal.WindowsIdentity]::GetCurrent();
		$IsAdmin = (New-Object Security.Principal.WindowsPrincipal $User).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
		
		if (!($IsAdmin)) {
			Write-Error "Admin privileges are required to create symlinks on windows."
			Exit 1
		}
	}
	
	function Install-File {
		param (
			$FromFile,
			$ToFile
		)
		if (Test-Path "$ToFile" -PathType "Leaf") {
			Remove-Item "$ToFile"
		}
		
		New-Item -Value "$Source" -Path "$Dest" -ItemType SymbolicLink | Out-Null
	}
}

else {
	function Install-File {
		param (
			$FromFile,
			$ToFile
		)
		
		if (Test-Path "$ToFile" -PathType "Leaf") {
			Remove-Item "$ToFile"
		}
		
		Copy-Item -Path "$Source" -Destination "$ToFile"
	}
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
		
		$Source = Resolve-FullPath "$Source"
		$Dest = Resolve-FullPath "$Dest"
		
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
	Write-Host "[ Install $BundleName ]"
} elseif ($Uninstall) {
	Write-Host "[ Uninstall $BundleName ]"
}

Iter-Files "LaTeX packages" $StyList -From "$StySourceDir" -To "$TeXmfDir" -Suffix ".sty"

Iter-Files "LaTeX document classes" $ClsList -From "$ClsSourceDir" -To "$TeXmfDir" -Suffix ".cls"

Iter-Files "Resource files" $ResList -From "$ResSourceDir" -To "$TeXmfDir" -Suffix ""

Iter-Files "TeXStudio autocompletion files" $($StyList; $ClsList) -From "$CWLSourceDir" -To "$TeXStudioDir" -Suffix ".cwl"
