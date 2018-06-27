# SafeSync
This script will auto create and delete personal safes for users in CyberArk Enterprise Password Vault.

The script requires a CyberArk user stored in a cred file. 

The following features are currently supported:
- Filter by external users only (LDAP/RADIUS/etc)
- Filter by user location
- Filter by username regular expression
- Auto rotate password stored in cred file

Safes are created with the following properties:
- The safe user is given permission to see, use (PSM Connect), and retrieve (Copy Password) accounts
- The safe user is not allowed to manage accounts or permissions
- Vault Admins are given permission to see, add, and manage accounts
- Vault Admins are not allowed to use/retrieve accounts or manage permissions
- Safes are created in the SafeSync location by default

## Install Instructions
First, we need to install [PoShPACLI](https://github.com/pspete/PoShPACLI/) to the machine's PowerShell Modules:
1. Download the [PoShPACLI zip](https://github.com/pspete/PoShPACLI/archive/master.zip)
2. Run `$env:PSModulePath` in PowerShell
3. Save the PoShPACLI in its own folder under one of the locations listed. Be aware that if you save it under your user's Modules folder and run the script under a different user, it will not work. I recommend putting it in `C:\Program Files\WindowsPowerShell\Modules` because of this.
4. Run `Import-Module PoShPACLI` in PowerShell and verify there are no errors

Next, we need the v7.2 PACLI executable:
1. Download the [latest v7.1 PACLI](https://support.cyberark.com/SFE/directaccess.ashx?pageid=statefolders&pageStartGrid=0&isExpended=True&selectedNodePath=%2froot%2fCyberArk+PAS+Archive%2fv7.2%2fPAS+Components%2fAPIs+CD+Image&serviceID=0&treeID=wstree)
2. Extract it to a permanent location

Next, we need the credential file the script will use:
1. Create a new CyberArk authentication user, i.e. "SafeSync", and add it to the Vault Admins group
2. If running on a server with a CyberArk component installed, you can use the built in `CreateCredFile.exe`. If running on a different machine, you will need to copy the `CreateCredFile.exe` and its dependent files over from an existing CyberArk install. This utility is not included in the PACLI files.
3. Run `CreateCredFile.exe Password user.ini`
4. Provide the new username and password, then hit enter to all the other questions
5. Store this in a permanent location

Now you can configure and run the script:
1. Download the [SafeSync.ps1 script](https://raw.githubusercontent.com/T3hUb3rK1tten/SafeSync/master/SafeSync.ps1)
2. Store this in a permanent location and edit it
3. Provide your Vault IP/hostname and specify the path to the PACLI folder and cred file if needed
4. By default the script will only work on external users from LDAP/RADIUS/etc. If desired, change this or the other user filter settings.
5. Test the script by running in PowerShell `.\SafeSync.ps1`
6. The script should create the \SafeSync location and create new safes for each user in this location. Note it will error if there are already safes for those users not in SafeSync.

Once that's finished, just schedule the script from Task Manager to run as often as you like:
- Program: `powershell`
- Arguments: `-File SafeSync.ps1 -ExecutionPolicy Bypass`
- Start in: The location of the script
