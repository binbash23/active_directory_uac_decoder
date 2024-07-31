
Decode the User Account Control number from the active directory LDAP and create multiple db columns from it


I export the AD data with a script (see and modify: ad_crawler.ps1) and import it into a database table with a visual studio SSIS project (which is not included here).

One of the LDAP columns/fields is "useraccountcontrol" which contains a number. The number holds encoded information about the accounts "User Account Control". 
If you want to know some detail about the encoding, have a look [here](https://jeremy-heer.github.io/uac-converter/uac-converter/).
If you want to decode the number into multiple flag-columns, you can do it with bitwise and operations like this:

```
select
         -- ... other AD columns 
         ,[useraccountcontrol] as [User Account Control]
	 ,case when (useraccountcontrol & 1) > 0 then 1 else 0 end as SCRIPT
	 ,case when (useraccountcontrol & 2) > 0 then 1 else 0 end as ACCOUNTDISABLE
	 ,case when (useraccountcontrol & 4) > 0 then 1 else 0 end as RESERVED
	 ,case when (useraccountcontrol & 8) > 0 then 1 else 0 end as HOMEDIR_REQUIRED
	 ,case when (useraccountcontrol & 16) > 0 then 1 else 0 end as LOCKOUT
	 ,case when (useraccountcontrol & 32) > 0 then 1 else 0 end as PASSWD_NOTREQD
	 ,case when (useraccountcontrol & 64) > 0 then 1 else 0 end as PASSWD_CANT_CHANGE
	 ,case when (useraccountcontrol & 128) > 0 then 1 else 0 end as ENCRYPTED_TEXT_PWD_ALLOWED
	 ,case when (useraccountcontrol & 256) > 0 then 1 else 0 end as TEMP_DUPLICATE_ACCOUNT
	 ,case when (useraccountcontrol & 512) > 0 then 1 else 0 end as NORMAL_ACCOUNT
	 ,case when (useraccountcontrol & 2048) > 0 then 1 else 0 end as INTERDOMAIN_TRUST_ACCOUNT
	 ,case when (useraccountcontrol & 4096) > 0 then 1 else 0 end as WORKSTATION_TRUST_ACCOUNT
	 ,case when (useraccountcontrol & 8192) > 0 then 1 else 0 end as SERVER_TRUST_ACCOUNT
	 ,case when (useraccountcontrol & 65536) > 0 then 1 else 0 end as DONT_EXPIRE_PASSWORD
	 ,case when (useraccountcontrol & 131072) > 0 then 1 else 0 end as MNS_LOGON_ACCOUNT
	 ,case when (useraccountcontrol & 262144) > 0 then 1 else 0 end as SMARTCARD_REQUIRED
	 ,case when (useraccountcontrol & 524288) > 0 then 1 else 0 end as TRUSTED_FOR_DELEGATION
	 ,case when (useraccountcontrol & 1048576) > 0 then 1 else 0 end as NOT_DELEGATED
	 ,case when (useraccountcontrol & 2097152) > 0 then 1 else 0 end as USE_DES_KEY_ONLY
	 ,case when (useraccountcontrol & 4194304) > 0 then 1 else 0 end as DONT_REQ_PREAUTH
	 ,case when (useraccountcontrol & 8388608) > 0 then 1 else 0 end as PASSWORD_EXPIRED
	 ,case when (useraccountcontrol & 16777216) > 0 then 1 else 0 end as TRUSTED_TO_AUTH_FOR_DELEGATION
	 ,case when (useraccountcontrol & 67108864) > 0 then 1 else 0 end as PARTIAL_SECRETS_ACCOUNT

from
         [your_table_that_stores_the_ad_information]

```
