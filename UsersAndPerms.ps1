Param([string]$TargetServer,[string]$TargetDB)

# Using deprecated method to avoid looking up paths and versions
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo") | Out-Null

$server = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Server -ArgumentList $TargetServer

$database = $server.Databases[$TargetDB]

ForEach ($role in $Database.Roles)
{
  if (-not $role.IsFixedRole)
  {
    $roleName = $role.Name;
    $owner = $role.Owner;
    $PermScript = $PermScript  + "USE $database; IF NOT EXISTS (SELECT * FROM sys.database_principals where name = '$roleName' and type = 'R')" + [char]13  + [char]10 + "CREATE ROLE $role AUTHORIZATION [$owner];"  + [char]13  + [char]10
    $database.EnumDatabasePermissions($role.Name) | ForEach-Object  {
      if ($_.ObjectClass -eq "Database") 
      {
        $PermScript = $PermScript  + ('USE {0}; GRANT {1} TO [{2}];' -f $database, $_.PermissionType, $_.Grantee)  + [char]13  + [char]10
      }
      else 
      {
        $PermScript = $PermScript  + ('USE {0}; GRANT {1} ON [{2}] TO [{3}];' -f $database, $_.PermissionType, $_.ObjectName, $_.Grantee)  + [char]13  + [char]10
      }
    }
    $database.EnumObjectPermissions($role.Name) | ForEach-Object {
      if ($_.ObjectClass -eq "Schema") 
      {
        $PermScript = $PermScript  + ('USE {0}; IF SCHEMA_ID(''{2}'') IS NOT NULL GRANT {1} ON SCHEMA::[{2}] TO [{3}];' -f $database, $_.PermissionType, $_.ObjectName, $_.Grantee)  + [char]13  + [char]10
      }
      else 
      {
        # Doesn't persist custom permissions for public role.
        if ($role.Name -ne 'public')
        { 
          $PermScript = $PermScript  + ('USE {0}; IF OBJECT_ID(''[{3}].[{4}]'') IS NOT NULL {1} {2} ON [{3}].[{4}] TO [{5}];' -f $database, $_.PermissionState, $_.PermissionType, $_.ObjectSchema, $_.ObjectName, $_.Grantee)  + [char]13  + [char]10
        }
      }                                                                      
    }
  }
}

$users = $database.Users
                
ForEach ($user in $users)
{
  if (-not $user.IsSystemObject -and $user.Login)
  {
    $userName = $user.Name
    $Login = "[" + $user.Login + "]"
    $PermScript = $PermScript  + "USE $database; IF NOT EXISTS (SELECT * FROM sys.database_principals p WHERE name = '$userName') CREATE USER $user FOR LOGIN $Login;"  + [char]13  + [char]10
    ForEach ($role in $user.EnumRoles())
    {
      $PermScript = $PermScript  + "USE $database; EXEC sp_addrolemember N'$role', N'$userName'"  + [char]13  + [char]10
    }
    $database.EnumObjectPermissions($user.Name) | ForEach-Object {
      if ($_.ObjectClass -eq "Schema") 
      {
        $PermScript = $PermScript  + ('USE {0}; IF SCHEMA_ID(''{3}'') IS NOT NULL {1} {2} ON SCHEMA::[{3}] TO [{4}];' -f $database, $_.PermissionState, $_.PermissionType, $_.ObjectName, $_.Grantee)  + [char]13  + [char]10
      }
      else 
      {
        $PermScript = $PermScript  + ('USE {0}; IF OBJECT_ID(''{3}.{4}'') IS NOT NULL {1} {2} ON [{3}].[{4}] TO [{5}];' -f $database, $_.PermissionState, $_.PermissionType, $_.ObjectSchema, $_.ObjectName, $_.Grantee)  + [char]13  + [char]10
      }
    }
    $database.EnumDatabasePermissions($user.Name) | ForEach-Object {
      if ($_.ObjectClass -eq "Database") 
      {
        $PermScript = $PermScript  + ('USE {0}; {1} {2} TO [{3}];' -f $database, $_.PermissionState, $_.PermissionType, $_.Grantee)  + [char]13  + [char]10
      }
      else 
      {
        $PermScript = $PermScript  + ('USE {0}; {1} {2} ON [{3}] TO [{4}];' -f $database, $_.PermissionState, $_.PermissionType, $_.ObjectName, $_.Grantee)  + [char]13  + [char]10
      }
    }
    
    if ($user.LoginType -eq "sqlLogin")
    {
      $PermScript = $PermScript  + ('USE {0}; EXEC sp_change_users_login ''update_one'', ''{1}'', ''{2}'';' -f $database, $user.Name, $user.Name)  + [char]13  + [char]10
    }
  }
}

$PermScript
