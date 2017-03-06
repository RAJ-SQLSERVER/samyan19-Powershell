param(
[Parameter(Mandatory=$true)][string]$username,
[Parameter(Mandatory=$true)][String]$password 
)


$username
$password=$password | ConvertTo-SecureString -AsPlainText -Force
