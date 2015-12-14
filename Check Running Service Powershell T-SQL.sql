

declare @value sql_variant;

set @value=(select value from sys.configurations where name='xp_cmdshell');

if @value=1
begin
	exec xp_cmdshell 'powershell.exe -noprofile -command "get-service | where-object {$_.name -like ''MSDtsServer*''}"'
end
else
begin
	exec sp_configure 'show advanced options',1;
	reconfigure;
	exec sp_configure 'xp_cmdshell',1;
	reconfigure;
	exec xp_cmdshell 'powershell.exe -noprofile -command "get-service | where-object {$_.name -like ''MSDtsServer*''}"'
	exec sp_configure 'xp_cmdshell',0;
	reconfigure;
end
