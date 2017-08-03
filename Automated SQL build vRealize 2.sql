Param(
$vm_name,
$admin_user_name,
$admin_user_password,
$SQLDBEUserName,
$SQLDBEPassword,
$SQLAGTUserName,
$SQLAGTPassword
)

$Secpasswd = ConvertTo-SecureString $admin_user_password -AsPlainText -Force
$Credential = New-Object System.Management.Automation.PSCredential ($admin_user_name, $secpasswd)

$SecDBEpasswd = ConvertTo-SecureString $SQLDBEPassword -AsPlainText -Force
$SQLDBECredential = New-Object System.Management.Automation.PSCredential ($SQLDBEUserName, $SecDBEpasswd)

$SecAGTpasswd = ConvertTo-SecureString $SQLAGTPassword -AsPlainText -Force
$SQLAGTCredential = New-Object System.Management.Automation.PSCredential ($SQLAGTUserName, $SecAGTpasswd)
 
#Connect-VIServer $vcenterserver -Credential $vccredential | Out-Null

<#
Option 1 Enter-PSSession cmdlet (One-to-One Remoting)
Option 2 Invoke-Command cmdlet, which allows you to run remote commands on multiple computers (which is why it is called One-to-Many Remoting).
Option 3 Use a cmdlet that offer a ComputerName parameter.
#>


Invoke-Command -Authentication Credssp -Credential $Credential -Computername $vm_name -ScriptBlock { 

#Create network drive for configuration file and scriptroot path
New-PSDrive –Name “Y” –PSProvider FileSystem –Root “\\internal.closebrothers.com\infrastructure$\SoftwareLibrary\Microsoft\SQL Server" –Persist

$ImagePath = '\\internal.closebrothers.com\infrastructure$\SoftwareLibrary\Microsoft\SQL Server\SQL 2012\SW_DVD9_SQL_Svr_Developer_Edtn_2012w_SP3_64Bit_English_MLF_X20-71004.iso'
Mount-DiskImage -ImagePath $ImagePath -StorageType ISO
$ISODrive = (Get-DiskImage -ImagePath $ImagePath | Get-Volume).DriveLetter


#SQLInstall_2012_DBE.ps1
#Sam Yanzu

#This script is to install SQL Server 2012 database engine only
#PRE-REQUISITES
#1. SQL Server Request Form and required actions have been completed
#2. Map '\\internal.closebrothers.com\infrastructure$\SoftwareLibrary\Microsoft\SQL Server' as the Z drive
#3. Mount SQL Server 2012 Media to VM and assign as E drive 

#Set policy to suppress warnings when running remote scripts
Set-ExecutionPolicy Bypass

#Default variables - do not amend
$CONFIGURATIONFILE="Y:\Automated-Install\Config-Files\ConfigurationFile_2012_DBE.ini"
$SETUPPATH="$($ISODrive):\Setup.exe"
$ScriptRoot="Y:\Automated-Install\SQL-Setup-Scripts"
$Version="SQL2012"

#-----------------Set user variables-----------------------

#Set folder locations
$SQLUSERDBDIR="F:\SQLData"
$SQLUSERDBLOGDIR="G:\SQLLogs"
$SQLTEMPDBDIR="I:\SQLTempDB"
$SQLBACKUPDIR="F:\SQLBackups"
$SQLARCHIVEDBACKUPS="F:\SQLBackups\ArchivedBackups\SystemDatabases"
$SQLMAINTENANCELOGS="D:\Program Files\Microsoft SQL Server\SQL.MAINTENANCE.LOGS"

#Set instance name
$INSTANCENAME="MSSQLSERVER"

#Set service accounts
#$d= Get-Credential 'DBE service account'
#$SQLSVCACCOUNT=$admin_user_name
#$SQLSVCPASSWORD=$admin_user_password
$SQLSVCACCOUNT=$SQLDBECredential.UserName
$SQLSVCPASSWORD=$SQLDBECredential.GetNetworkCredential().Password

#$a= Get-Credential 'AGT service account'
#$AGTSVCACCOUNT=$Credential.UserName
#$AGTSVCPASSWORD=$Credential.GetNetworkCredential().Password
$AGTSVCACCOUNT=$SQLAGTCredential.UserName
$AGTSVCPASSWORD=$SQLAGTCredential.GetNetworkCredential().Password

#Set sql settings
$SQLSYSADMINACCOUNTS="CLOSEBROTHERSGP\ROLE-G-SQL-SysAdmins"
$SQLCOLLATION="Latin1_General_CI_AS"

#----------------end setting user variables-----------------

#Set power plan to High Performance
powercfg -setactive scheme_min

#create SQL folders
Write-Host "Creating SQL directories..."
New-Item -ItemType directory -Path $SQLUSERDBDIR
New-Item -ItemType directory -Path $SQLUSERDBLOGDIR
New-Item -ItemType directory -Path $SQLTEMPDBDIR
New-Item -ItemType directory -Path $SQLBACKUPDIR
New-Item -ItemType directory -Path $SQLARCHIVEDBACKUPS
New-Item -ItemType directory -Path $SQLMAINTENANCELOGS

#Start installation
Write-Host "SQL install starting..."
$process=(Start-Process -Verb runas -FilePath $SETUPPATH -ArgumentList  "/CONFIGURATIONFILE=$CONFIGURATIONFILE /INSTANCENAME=$INSTANCENAME /INSTANCEID=$INSTANCENAME /SQLSVCACCOUNT=$SQLSVCACCOUNT /SQLSVCPASSWORD=$SQLSVCPASSWORD /AGTSVCACCOUNT=$AGTSVCACCOUNT /AGTSVCPASSWORD=$AGTSVCPASSWORD /SQLUSERDBDIR=$SQLUSERDBDIR /SQLUSERDBLOGDIR=$SQLUSERDBLOGDIR /SQLBACKUPDIR=$SQLBACKUPDIR /SQLTEMPDBDIR=$SQLTEMPDBDIR /SQLSYSADMINACCOUNTS=$SQLSYSADMINACCOUNTS /SQLCOLLATION=$SQLCOLLATION /IACCEPTSQLSERVERLICENSETERMS /Q /TCPENABLED=1" -Wait -PassThru)

#configure SQL if build successful
if($process.ExitCode -eq 0)
{
    Write-Host "SQL install complete..."
    
    Write-Host "Apply configuring scripts starting..."
    Invoke-Expression "\\internal.closebrothers.com\infrastructure$\SoftwareLibrary\Microsoft\SQL Server\Automated-Install\ConfigureSQL.ps1 $INSTANCENAME $ScriptRoot $Version"
    
    Write-Host "SQL build complete"
}
else
{
    Write-Host "SQL install failed. Please check C:\Program Files\Microsoft SQL Server\110\Setup Bootstrap\Log\Summary.txt for further information. Exit code:" $process.ExitCode
}

}

