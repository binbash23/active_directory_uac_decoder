#
# 20240424 jens heine
# 20240521 jens heine: added db logging
#
# ad_crawler
#

#
# required modules:
# install-module sqlserver
#

$CONNECTION_STRING="Data Source=DB_SERVER_NAME;Initial Catalog=DATABASE_NAME;Integrated Security=True"

$ad_query_user_name="ad_query_username"
$secstr=convertto-securestring -String "secret_password" -AsPlainText -Force
$ldap_cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $ad_query_user_name, $secstr

$ldap_groups_file="ldapgroups.csv"
$ldap_groups_file_bak="ldapgroups.csv_"
$group_user_relation_file="group_user_relation.csv"
$group_user_relation_file_bak="group_user_relation.csv_"
$ldap_users_file="ldapusers.csv"
$ldap_csv_new_file="neu.csv"


# Add log entry into database log table
Write-Host "Creating log entry into database table..."
Invoke-Sqlcmd -ConnectionString $CONNECTION_STRING -Query "insert into [log] (text) values ('ad_crawler.ps1 - Starting')"


#
# Erst alle User in eine CSV Datei exportieren
#
Write-Output "Collecting ad user information from active directory. Please wait..."
Get-ADUser -Filter { samAccountName -like "*" } -SearchBase "DC=your_root,DC=de" -credential $ldap_cred -Properties *|`
  Select objectsid,name,displayname,cn,description,SAMAccountName,whencreated,whenchanged,useraccountcontrol,`
  distinguishedname,mail,c,l,st,postalcode,co,company,streetaddress,givenname,sn,PasswordLastSet,employeeID,homeMDB|`
  Export-CSV -encoding unicode -notype -Path $ldap_users_file  

Write-Output "Cleaning up ad user csv file. Please wait..."
# 20160406 jens heine: Alle Sonderheiten aus der ldapusers.csv datei entfernen (Doppelte Anfuehrungszeichen, Zeilenumbrueche etc)
if (Test-Path $ldap_csv_new_file) {
	Remove-Item $ldap_csv_new_file
}
$zeile='"objectsid","name","displayname","cn","description","SAMAccountName","whencreated","whenchanged","useraccountcontrol","distinguishedname","mail","c","l","st","postalcode","co","company","streetaddress","givenname","sn","PasswordLastSet","employeeID","homeMDB"'
add-content $ldap_csv_new_file $zeile -Encoding unicode


import-Csv $ldap_users_file|foreach-object { 
$Xname=$_.name -replace "`n", "" 
$Xname=$Xname -replace "`r", " "

$Xdisplayname=$_.displayname -replace "`n", "" 
$Xdisplayname=$Xdisplayname -replace "`r", " "

$Xcn=$_.cn -replace "`n", "" 
$Xcn=$Xcn -replace "`r", " "

$Xdescription=$_.description -replace "`n", "" 
$Xdescription=$Xdescription -replace "`r", " "
$Xdescription=$Xdescription -replace '"', ""

$XSAMAccountName=$_.SAMAccountName -replace "`n", "" 
$XSAMAccountName=$XSAMAccountName -replace "`r", " "

$Xdistinguishedname=$_.distinguishedname -replace "`n", "" 
$Xdistinguishedname=$Xdistinguishedname -replace "`r", " "

$Xcompany=$_.company -replace "`n", "" 
$Xcompany=$Xcompany -replace "`r", " "
$Xcompany=$Xcompany -replace '"', "'"

$Xgivenname=$_.givenname -replace "`n", "" 
$Xgivenname=$Xgivenname -replace "`r", " "

$Xsn=$_.sn -replace "`n", "" 
$Xsn=$Xsn -replace "`r", " "

$Xstreetaddress=$_.streetaddress -replace "`n", "" 
$Xstreetaddress=$Xstreetaddress -replace "`r", " "

$zeile='"'+$_.objectsid+'","'+$Xname+'","'+$Xdisplayname+'","'+$Xcn+'","'+$Xdescription+'","'+$XSAMAccountName+'","'+$_.whencreated+'","'+$_.whenchanged+'","'+$_.useraccountcontrol+'","'+$Xdistinguishedname+'","'+$_.mail+'","'+$_.c+'","'+$_.l+'","'+$_.st+'","'+$_.postalcode+'","'+$_.co+'","'+$Xcompany+'","'+$Xstreetaddress+'","'+$Xgivenname+'","'+$Xsn+'","'+$_.PasswordLastSet+'","'+$_.employeeID+'","'+$_.homeMDB+'"'
add-content $ldap_csv_new_file "$zeile" -Encoding unicode
}
move-item $ldap_csv_new_file $ldap_users_file -force
  
#
# LDAP Gruppenzugehoerigkeiten erfassen
#
# Alle Gruppen sammeln
Write-Output "Collecting ad group information from active directory. Please wait..."
get-adgroup -Filter { name -like "*" } -credential $ldap_cred | select -property DistinguishedName | export-csv -encoding unicode -notype -Path $ldap_groups_file
# Erste Zeile aus Gruppendatei loeschen
(Get-Content $ldap_groups_file | Select-Object -Skip 1) | Set-Content $ldap_groups_file

Write-Output "Cleaning up ad group csv file. Please wait..."
# Die bekloppten Anfuehrungszeichen raus
get-content -path $ldap_groups_file | foreach-object { $_ -replace "`"","" } | out-file $ldap_groups_file_bak  
move-item $ldap_groups_file_bak $ldap_groups_file -force

Write-Output "Collecting ad user-group information from active directory. Please wait..."
# Zu allen Gruppen die Members sammeln
$lines=get-content -path $ldap_groups_file

if (Test-Path $group_user_relation_file) {
	Remove-Item $group_user_relation_file
}

foreach ( $currentgroup in $lines ) { 
# prüfen -recursiv Abfrage, um Gruppen in Gruppen aufzulösen
  $currentusers=get-adgroupmember $currentgroup -credential $ldap_cred -Recursive|select -property distinguishedname; foreach ($currentuser in $currentusers) { 
    if ($currentuser) {
      add-content -path $group_user_relation_file -value $currentgroup" "$currentuser 
	}  
  }  
} 

Write-Output "Cleaning up ad user-group relations csv file. Please wait..."

# Jetzt noch die Zieldatei cleanen
get-content -path $group_user_relation_file | foreach-object { $_ -replace " @{distinguishedname=","|" -replace "}","" } | out-file $group_user_relation_file_bak
move-item $group_user_relation_file_bak $group_user_relation_file -force
  

# Copy all csv files to shared folder:
Copy-Item *.csv .\ldap_share

# Add log entry into database log table
Write-Host "Creating log entry into database table..."
Invoke-Sqlcmd -ConnectionString $CONNECTION_STRING -Query "insert into [log] (text) values ('ad_crawler.ps1 - Finished')"
# Update properties table
Write-Host "Creating properties entry into database table..."
Invoke-Sqlcmd -ConnectionString $CONNECTION_STRING -Query "update [properties] set value = getdate() where [property] = 'ad_crawler.ps1.last_execution_date'"
