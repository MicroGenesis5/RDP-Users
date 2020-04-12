<#
  Lists the Remote Desktop Protocol (RDP) users connected to the Windows Terminal Server. 
  
  Details include the user's Active Directory username and the IP address and hostname of their remote computer (which 
  is typically a thin client).

  Script must be run with Administrator privileges since it accesses Event Viewer logs and Registry keys.
#>


# Step 1: Get a list of IP addresses connected to the server via RDP. This information is found via the Get-NetTCPConnection cmdlet.

$ipArrayDynamic = Get-NetTCPConnection | Where-Object {$_.LocalPort -eq 3389 -and $_.State -eq "Established"} | Sort-Object
$ipArray = @() # Get-NetTCPConnection is dynamic (constantly changes) so you must put the IP's into a static array 

if ($ipArrayDynamic.length -eq 0) {
    echo "There are no RDP sessions."
    Exit
} elseif ($ipArrayDynamic.length -lt 0) { # a single RDP connection
    $ipArray += $ipArrayDynamic.RemoteAddress
} else {
    for ($i = 0; $i -lt $ipArrayDynamic.length; $i++) {
        $ipArray += $ipArrayDynamic[$i].RemoteAddress
    }
}    


# Step 2: Get the user's Active Directory (AD) username from their IP. This information is found in Windows Event Viewer logs.

$usersArray = @()
$usersLongestStr = 0 # for console printing formatting purposes

for ($i = 0; $i -lt $ipArray.length; $i++) {
    $eventLoginIP =
        Get-EventLog -LogName Security | # Event ID: 4624 and Logon Type: 10
        Where-Object {$_.EventID -eq 4624 -and $_.ReplacementStrings[8] -eq 10 -and $_.ReplacementStrings[18] -eq $ipArray[$i]} | 
        select -First 1
    
    $username = $eventLoginIP.ReplacementStrings[5] # username of user that logged in with the specified IP
    $usersArray += $username
    if ($usersArray[$i].length -gt $usersLongestStr) { $usersLongestStr = $usersArray[$i].length }        
}


# Step 3: Get the computer hostname of remote user's thin client/PC from their AD username. This information is found in the Registry.

# create an empty array of predetermined length 
$hostnameArray = (0..($usersArray.length-1))

$sid = Get-ChildItem Registry::HKEY_USERS -Name

for ($i = 0; $i -lt $sid.length; $i++) {
    $sidRegPath = "Registry::HKEY_USERS\" + $sid[$i] + "\Volatile Environment"

    if (Test-Path $sidRegPath) {
        $user = Get-ItemProperty $sidRegPath
        for ($j = 0; $j -lt $usersArray.length; $j++) {
            if ($user.USERNAME -eq $usersArray[$j]) {
                $hostnameRegPath = Get-ItemProperty ($sidRegPath + "\*")
                $hostnameArray[$j] = $hostnameRegPath.CLIENTNAME
                break
            }
        }
    }
}


# varibles for console printing formatting
$headerColumnSpaces1 = " " * ($usersLongestStr)
$headerColumnSpaces2 = " " * 20
$entryNumColumnSpaces1 = 0
$entryNumColumnSpaces2 = 0

# Print results to console
Write-Host ""
Write-Host ("  User{0}IP{1}Hostname" -f $headerColumnSpaces1, $headerColumnSpaces2) 
Write-Host ("  ----{0}--{1}--------" -f $headerColumnSpaces1, $headerColumnSpaces2)
for ($i = 0; $i -lt $usersArray.length; $i++) {
    $entryNumColumnSpaces1 = $usersLongestStr - $usersArray[$i].length + 4
    $entryNumColumnSpaces2 = 15 - $ipArray[$i].length + 7
    Write-Host ("  $($usersArray[$i]){0}$($ipArray[$i]){1}$($hostnameArray[$i])" -f ( " " * $entryNumColumnSpaces1), ( " " * $entryNumColumnSpaces2))
}
Write-Host ""
