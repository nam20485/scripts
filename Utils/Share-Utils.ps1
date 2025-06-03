$PRECISION5820_SHARE = "\\PRECISION5820\SHARE"


function Get-ShareUsers {
    param (
        [string]$Path
    )

    # Get the ACL for the share
    $acl = Get-Acl $Path

    # Filter the access rules and display users and their permissions
    $acl.Access | Where-Object { $_.AccessControlType -eq "Allow" } | ForEach-Object {
        Write-Host "User: $($_.IdentityReference)"
        Write-Host "Access: $($_.FileSystemRights)"
        Write-Host ""
    }

    #return $acl
}

function Add-ShareUser {
    param (
        [string]$Path,
        [string]$User,
        [string]$Permission
    )

    # Get the current ACL
    $acl = Get-Acl $Path

    # Define the new rule
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($User, $Permission, "Allow")

    # Add the new rule to the ACL
    $acl.SetAccessRule($rule)

    # Apply the updated ACL to the share
    Set-Acl -Path $Path -AclObject $acl

    Write-Host "Added user $User with permission $Permission to share $Path"

    #return $acl
}