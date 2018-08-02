function get-free() { 
    Param(
    [parameter(Position=0, mandatory=$True, helpmessage="Drive to check amount of free space")]
    [ValidateNotNullorEmpty()]
    [string] $drive, 
    [parameter(Position=1, mandatory=$False, helpmessage="List of computers to Check, must be comma seperated")]
    [ValidateNotNullorEmpty()]
    [array] $computer
    )
    if ($drive.Length -eq 1) {
        $drive = "DeviceId='$($drive):'"
    }
    else {
        write-host "Please only use a single drive letter."
    }

    try {
        if($computer.Length -eq 0) {
            Get-WmiObject -Class Win32_LogicalDisk -filter $drive | ft SystemName, @{name="Free"; Expression={[math]::round($($_.FreeSpace/1GB),2)}} -auto
        }
        else { 
            Get-WmiObject -Class Win32_LogicalDisk -ComputerName $computer -filter $drive | ft SystemName, @{name="Free"; Expression={[math]::round($($_.FreeSpace/1GB),2)}} -auto   
        }
    }
    Catch {
    #You should never really run into an exception in normal usage
    Write-Warning "Failed to create WMI object"
    Write-Warning $_.exception.message
    }

}