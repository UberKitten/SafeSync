###########################################################
#
# SafeSync.ps1
#
# Copyright 2018 Astra West
#
# This script is not officially supported or endorsed by CyberArk, Inc.
#
# Licensed under the MIT License
#
###########################################################

# Change these properties for your Vault install:
$Vault = "vault.example.com"

# Location of cred file to use
$CredFile = "user.ini"

# Location of PACLI executable
$PACLIFolder = "PACLI"

# If you use a self-signed cert on the Vault, set this to true
$AllowSelfSignedCertificates = $false

# This will cause PACLI to rotate the password of the account in the cred file automatically
$AutoChangePassword = $true

# Below are optional settings that allow you to customize what users get safes created

# Set this to true to only scan for users from LDAP/RADIUS/etc
$ExternalUsersOnly = $true

# Advanced user selection criteria (mostly useful if including CyberArk users)
$Location = "\"
$IncludeSubLocations = $false
$BlackListLocations = "\System", "\Applications"
$BlacklistUsernameRegexes = "^Master$", "^Administrator$", "^Auditor$", "^Batch$", "^NotificationEngine$", "^PasswordManager.*$", "^PVWA.*$", "^PSM.*$", "^AIMWebService$"

# Safes are created and deleted in the following location (should not be \)
$SafeLocation = "\SafeSync"

# End settings

###########################################################

# The below function can be customized to meet your business needs

function CreateNewSafe( $token, $username ) {

    # These should not be changed
    Write-Host "Creating safe for $username"
    $token | New-PVSafe -safe $username -description "Created by SafeSync.ps1" -safeOptions 704 -location $SafeLocation
    $token | Open-PVSafe -safe $username
    $token | Add-PVSafeGWAccount -safe $username -gwAccount "PVWAGWAccounts"

    # The below is my recommendation for most organizations to allow vault admins to manage but not use accounts in personal safes

    # The following permissions are omitted to prevent admins from using or backdooring accounts:
    # -retrieve, -accessNoConfirmation, -usePassword, -initiateCPMChangeWithManualPassword, -moveFrom

    # The following permission is omitted to encourage managing safe permissions from this script instead:
    # -administer, -manageOwners

    # The following permissions are omitted because they are deprecated or not needed:
    # -monitor, -backup

    $token | Add-PVSafeOwner -safe $username -owner "Vault Admins" -store -delete -supervise -manageowners -list -updateObjectProperties -initiateCPMChange -createFolder -deleteFolder -viewAudit -viewPermissions -eventsList -addEvents -createObject -unlockObject -renameObject -moveInto

    # Allows the safe owner themself to access accounts
    $token | Add-PVSafeOwner -safe $username -owner $username -usePassword -retrieve -list -eventsList
    
    # These should not be changed
    $token | Close-PVSafe -safe $username
}

function DeleteOldSafe( $token, $safe ) {
    Write-Host "Attempting to delete Safe $safe"
    try {
        $token | Open-PVSafe -safe $safe
        $token | Remove-PVSafe -safe $safe
        Write-Host "Successfully deleted Safe $safe"
    }
    catch {
        Write-Host "Unable to delete Safe $safe"
    }
}

###########################################################

$ErrorActionPreference = "Stop"

# Get username from cred file
$Username = Select-String -Path  $CredFile -Pattern "Username=(\S*)" | % { $_.Matches.Groups[1].Value }

# Connect to Vault
Import-Module PoShPACLI
Initialize-PoShPACLI -pacliFolder $PACLIFolder
Start-PVPacli
New-PVVaultDefinition -vault "Vault" -address $Vault -preAuthSecuredSession -trustSSC:$AllowSelfSignedCertificates
$token = Connect-PVVault -vault "Vault" -user $Username -logonFile $CredFile -autoChangePassword:$AutoChangePassword

# Check for the Location and create it if needed
$Locations = $token | Get-PVLocation
if (($Locations | Select -ExpandProperty Location ) -notcontains $SafeLocation) {
    Write-Host "Creating Location $SafeLocation"
    $token | New-PVLocation -location $SafeLocation
}

$Users = $token | Get-PVUserList -location $Location -includeSubLocations:$IncludeSubLocations

# Remove blacklisted locations
$Users = $Users | Where { $BlackListLocations -notcontains $_.Location }

# Remove blacklisted usernames
$BlacklistUsernameRegex =  $BlacklistUsernameRegexes -join '|'
$Users = $Users | Where { $_.Username -notmatch $BlacklistUsernameRegex }

# Remove groups
$Users = $Users | Where { $_.Type -ne "GROUP" -and $_.Type -ne "EXTERNAL GROUP" -and $_.Template -eq "NO" } 

# Remove directory mapping templates
$Users = $Users | Where { $_.Template -eq "NO" } 

if ($ExternalUsersOnly) {
    $Users = $Users | Where-Object { $_.Type -eq "EXTERNAL USER" }
}

$Safes = $token | Get-PVSafeList -location $SafeLocation

# Find users who do not have safes and add them
$NewUsers = $Users | Where { ($Safes | select -ExpandProperty Safename) -notcontains $_.Username }
$NewUsers | % { CreateNewSafe $token $_.Username }

# Find safes we've created that do not have matching users and (attempt) to delete them
$OldSafes = $Safes | Where { ($Users | Select -ExpandProperty Username) -notcontains $_.Safename }
$OldSafes | % { DeleteOldSafe $token $_.Safename }

Disconnect-PVVault -vault "Vault" -user $Username
Stop-PVPacli