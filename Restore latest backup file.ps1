$backupFolder="\\pdc1vfl002\systems\CIDA\Prod Backups\TEST"
[array]$latestBackupFile=Get-ChildItem -Path $backupFolder -Filter "DBA_Admin*.bak" | sort-object -Property LastWriteTime | Select-Object  -Last 1 | select name
Write-Host $latestBackupFile
$a=$latestBackupFile[0]

$backuploc=$backupFolder+"\"+$a.name
$server="UDC1SQL006"
$dbname="DBA_Admin_TEST"
Write-Host $backuploc

#Set execution policy to suppress warning when running script from remote loaction
Set-ExecutionPolicy Bypass

#Add SQL Snapins
if ( (Get-PSSnapin -Name sqlserverprovidersnapin100 -ErrorAction SilentlyContinue) -eq $null )
{
    add-pssnapin sqlserverprovidersnapin100
    Write-Host "sqlserverprovidersnapin100 added..."
}
if ( (Get-PSSnapin -Name sqlservercmdletsnapin100 -ErrorAction SilentlyContinue) -eq $null )
{
    add-pssnapin sqlservercmdletsnapin100
    Write-Host "sqlservercmdletssnapin100 added..."
}

#Run SQL Script
Invoke-Sqlcmd -Query "ALTER DATABASE $dbname SET SINGLE_USER WITH ROLLBACK IMMEDIATE; RESTORE DATABASE $dbname FROM DISK = N'$backuploc' WITH MOVE 'DBA_Admin_TEST' TO 'G:\Program Files\Microsoft SQL Server\MSSQL10_50.MSSQLSERVER\MSSQL\Data\DBA_Admin_TEST.mdf', MOVE 'DBA_Admin_TEST_log' TO 'F:\Program Files\Microsoft SQL Server\MSSQL10_50.MSSQLSERVER\MSSQL\Data\DBA_Admin_TEST_log.ldf', REPLACE, STATS = 10;" -ServerInstance $server -Database "master"


if($?)
{
   echo "command succeeded"
   exit 0
}
else
{
   echo "command failed"
   exit 1
}




