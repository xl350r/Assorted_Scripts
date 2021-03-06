##############################################
# Title: Trouble-shooting powershell profile
# Author : Daniel C. Hoberecht
# Last Revision : 2/12/2021
# Description : Powershell profile with commands, tools, and shell's paired with a custom propmt loop to assist in troubleshooting.
# Limitations : Many parts likely need the Language mode to be FullLanguage.
# Todos : INI file and parsing for configuration. More useful tools. win32_* gathering possibly. 
# Win32_functions : get-free, get-serial
##############################################
#start-transcript
# Custom Prompt
#$profile_config = "$(split-path $profile)\\profile_config.ini"

#if (test-path $profile_config) {
#    $profile_config = get-content $profile_config | ConvertFrom-StringData
#} else {
#    $profile_config = $null
#}

### notes ###
# if (Test-Connection server -Count 1 | Out-Null) { write-host "blah" } else {write-host "blah blah"}
####
function prompt
{
    # $Host is a variable defined by default
    # New nice WindowTitle
    $Host.UI.RawUI.WindowTitle = "PowerShell v" + (get-host).Version.Major + "." + (get-host).Version.Minor + " (" + $pwd.Provider.Name + ") " + $pwd.Path # adds path to window title
 
    # Admin ?
   if( (
        New-Object Security.Principal.WindowsPrincipal (
            [Security.Principal.WindowsIdentity]::GetCurrent())
        ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))

  {
        # Admin-mark in WindowTitle
        $Host.UI.RawUI.WindowTitle = "[Admin] " + $Host.UI.RawUI.WindowTitle
 
        # Admin-mark on prompt
        Write-Host "[" -nonewline -foregroundcolor DarkGray
        Write-Host "Admin" -nonewline -foregroundcolor Red
        Write-Host "] " -nonewline -foregroundcolor DarkGray
   }    
	#if(-not (
        #New-Object Security.Principal.WindowsPrincipal (
         #   	[Security.Principal.WindowsIdentity]::GetCurrent())
         #	).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))

    # Show short prompt if you are in FileSystem
        Write-Host PSv(get-host).Version.Major"."(get-host).Version.minor">" -separator "" -nonewline -foregroundcolor Green # gets and displays current Powershell version as prompt
    # $pwd a variable set by default on each directory change. It shows the current working directory
    # Show providername if you are outside FileSystem i.e. Registry, enviroment, WSMAN, VARIABLE, CERT, ALIAS, ETC.
    if ($pwd.Provider.Name -ne "FileSystem") { # check if current location is a filesystem.
        Write-Host "[" -nonewline -foregroundcolor DarkGray 
        Write-Host $pwd.Provider.Name -nonewline -foregroundcolor Gray # change prompt to current provider. ex: PSv5.1>[Registry] HKLM:\\
        Write-Host "] " -nonewline -foregroundcolor DarkGray
    	$pwd.Path.Split("\") | foreach {
            Write-Host $_ -nonewline -foregroundcolor Yellow
            Write-Host "\" -nonewline -foregroundcolor Gray
	    }
	}

    return " "
}

#Complex functions
function Get-ComObject { # get all or find specifix comobject(s)
    param(
        [Parameter(Mandatory=$true,
        ParameterSetName='FilterByName')]
        [string]$Filter,
 
        [Parameter(Mandatory=$true,
        ParameterSetName='ListAllComObjects')]
        [switch]$ListAll
    )
 
    $ListofObjects = Get-ChildItem HKLM:\Software\Classes -ErrorAction SilentlyContinue | Where-Object {
        $_.PSChildName -match '^\w+\.\w+$' -and (Test-Path -Path "$($_.PSPath)\CLSID")
    } | Select-Object -ExpandProperty PSChildName
 
    if ($Filter) {
        $ListofObjects | Where-Object {$_ -like $Filter}
    } else {
        $ListofObjects
    }
}

function get-free() { # get free space from local or remote machine on network in GBs
    Param(
    [parameter(Position=0, mandatory=$false, helpmessage="Drive to check amount of free space")]
    #[ValidateNotNullorEmpty()]
    [string] $drive="all", #setting default drive to all
    [parameter(Position=1, mandatory=$False, helpmessage="List of computers to Check, must be comma seperated")]
    [ValidateNotNullorEmpty()]
    [array] $computer # arrays are iterable lists ex: 1,2,3,4,5
    )
    if ($drive.Length -eq 1) {
        $drive = "DeviceId='$($drive):'" # filter for if drive letter is passed
    }
    elseif ($drive -eq "all") {
        $drive='' # filter if "all" is passed
    }
    else {
        write-warning "Please only use a single drive letter, or indicate 'all'" # write warning if inappropriate parameter is passed
        break
    }

    try {
        if($computer.Length -eq 0) {
            Get-WmiObject -Class Win32_LogicalDisk -filter $drive | ft DeviceID, SystemName, @{name="Free"; Expression={[math]::round($($_.FreeSpace/1GB),2)}} -auto # wmi call for if no computer is passed (invokes on localmachine)
        }
        else { 
            Get-WmiObject -Class Win32_LogicalDisk -ComputerName $computer -filter $drive | ft DeviceID, SystemName, @{name="Free"; Expression={[math]::round($($_.FreeSpace/1GB),2)}} -auto   # wmi call for if a computer is called (invokes on machine provided (ip or computername))
        }
    }
    Catch {
    #You should never really run into an exception in normal usage
    Write-Warning "Failed to create WMI object"
    Write-Warning $_.exception.message
    }

}

function sync-files{ # sync files between two directories
    param ( # more complex definition of parameters
        [Parameter(mandatory=$true, position=0)]
        [String] $sourcedir,
        [Parameter(mandatory=$true, position=1)]
        [String] $destination,
        [Parameter(mandatory=$false, position=2)]
        [switch] $recurse # switch parameters are false when not used and true when used
    )

    if ($recurse) {
        $Source = Get-ChildItem -recurse -Path $sourcedir -file
    } else {
        $Source = $Source = Get-ChildItem -Path $sourcedir -File
    }
    ForEach($File in $Source){
        $Orig = $File | Get-FileHash | Select-Object Path,Hash # hash file and filter for Path and Hash from result
        $DestFile = "$destination\$File" # path definition
        If(-not(Test-Path $DestFile)){ # check if path exists
            Write-Output "Copying Missing File $DestFile" 
            Copy-Item $Orig.Path -Destination $DestFile # copy file over if file does not exists
            }
        $Dest = Get-FileHash -Path $DestFile | Select-Object Path,Hash # hash dest file

        If($Orig.Hash -ne $Dest.Hash){ # check if hashes of Origin and Destination are the same
            Copy-Item $Orig.Path -Destination $Dest.Path -Verbose # copy orig to dest if not equal
        }
        Else {
            Write-Output "Files are equal"
        }
    }
}

function convertfile-toarray() { # convert a file into an array of lines
    param(
    [parameter(Position=0,mandatory=$True, helpmessage="file to convert to array")]
    [ValidateNotNullorEmpty()]
    $path
    )
    if(-not ($path  | test-path)) { # check if path exits
        return @() # if path doesn't exists return empty array.
    } else {
        $array = @() # initialize array
        foreach ($line in $(get-content $path)) { # foreach line in file
            $array = $array + $line # append array with line
        }
        return $array # return array
    }
} 

function get-serial() { # get computer(s) serial number
    Param(
    [parameter(Position=0, mandatory=$False, helpmessage="List of computers to Check, must be comma seperated")]
    [ValidateNotNullorEmpty()]

    [array] $computers # arrays are iterable lists ex: 1,2,3,4,5
    )
    try { ## convert to foreach ???
        if($computers.Length -eq 0) { # if computer array length == 0;
            Get-WmiObject -Class Win32_bios | format-table PsComputerName, SerialNumber
        }
        else { # if computer array length > 0;
             Get-WmiObject -Class Win32_bios -ComputerName $computers | Format-Table PsComputerName, SerialNumber   # wmi call for if a computer is called (invokes on machine provided (ip or computername))
        }
    }
    Catch {
    #You should never really run into an exception in normal usage
    Write-Warning "Failed to create WMI object"
    Write-Warning $_.exception.message
    }
}


function monitor-computers() {
Param(
    [parameter(position=0, mandatory=$true, helpmessage="list of computers to monitor")]
    [ValidateNotNullorEmpty()]

    [array] $computers, # arrays are iterable lists ex: 1,2,3,4,5

    [parameter(position=1, mandatory=$false, helpmessage="time to sleep between checks")]
    $sleep = 5
)

    do {
    $table = New-Object pscustomobject -Property @{
      host = $ip
      status = $(get-computerstatus -address $ip)
    }
    $tables = @()

    foreach ($ip in $computers) 
    {
        $table = New-Object pscustomobject -Property @{
           host = $ip
           status = $(get-computerstatus -address $ip)
           }
           $tables += $table

        
        }
        clear
        write-output $table
        Start-Sleep $sleep
    } while ($true)
}

function New-IPRange ($start, $end)
    {
        # created by Dr. Tobias Weltner, MVP PowerShell
        $ip1 = ([System.Net.IPAddress]$start).GetAddressBytes()
        [Array]::Reverse($ip1)
        $ip1 = ([System.Net.IPAddress]($ip1 -join '.')).Address
        $ip2 = ([System.Net.IPAddress]$end).GetAddressBytes()
        [Array]::Reverse($ip2)
        $ip2 = ([System.Net.IPAddress]($ip2 -join '.')).Address
  
        for ($x=$ip1; $x -le $ip2; $x++)
            {
                $ip = ([System.Net.IPAddress]$x).GetAddressBytes()
                [Array]::Reverse($ip)
                $ip -join '.'
            }
    }

# windows shells and utilities for complex troubleshooting or scripting.
if ($ExecutionContext.SessionState.LanguageMode -eq "FullLanguage") { # check if FullLanguage is allowed on machine before attempting to set avoids errors
    $wshshell = new-object -comobject wscript.shell # assists in running programs, and sending keys.
    $netshell = New-Object -ComObject wscript.network # enum drives, Printers. add drives, printers. get username, domain, profile, computername, organization.
    $fscript  = new-object -ComObject Scripting.FileSystemObject # file system functions, check if file/folder exists, copy, move, open text files, build path, etc.
    $webclient = New-Object System.Net.webclient # Download/upload files faster and concurrently(async). Faster than invoke-webrequest.
}

#short/simple Functions listed below 
function get-fsize($path="./") { # get size of file or directory in MBs
    "{0:N2} MB" -f ((Get-ChildItem $path -Recurse | Measure-Object -Property Length -Sum -ErrorAction Stop).Sum / 1MB)
} 
function get-boots($newest=10) { # get newest (10) event logs for boot events
    Get-EventLog -LogName System -Newest $newest -InstanceId 12 #| where {$_.EventID -eq 12}
}
function get-logons($newest=10) { # get newest (10) logs for successful logon events
    Get-EventLog -LogName Security -InstanceId 4624 -Newest $newest #| where {$_.EventID -eq 4624}
}
function list-ips() { # gets list of non-null, non-apippa, and non-loopback ip addresses; associated with this computer, the alias of the interface it's on and how it obtained the ip (DHCP, Static, Wellknown)
    Get-NetIPAddress | Where-Object {($_.IpAddress -notlike "169.*.*.*") -and ($_.IPAddress -notlike "127.*.*.*") -and ($_.IPAddress -ne $null) -and ($_.IPAddress -ne "::1")} | Format-Table IPaddress, InterfaceAlias, PrefixOrigin
}
function get-arptable() { # gets arptable while skipping permanent entries, and zeroed macaddresses
    get-netneighbor |where {($_.state -ne "Permanent") -and ($_.LinkLayerAddress -notlike "00-00-00-00-00-00")} | format-table IpAddress, LinkLayerAddress, State -AutoSize
}
function get-computerstatus($address) {  # if comptuer is up $true else $false
    if (test-connection $address -Count 1 -ErrorAction SilentlyContinue ) {$true} else {$false}
}