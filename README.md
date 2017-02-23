### Create (or change) SecureString password file:
1.) Login as the desired user (in this case svc_build)
2.) Execute the following:
read-host -assecurestring | convertfrom-securestring | out-file C:\BuildScripts\svc_build.password.securestring.txt
3.) Type the password and hit <enter>

###Read SecureString password file
$sspassword = cat C:\BuildScripts\svc_build.password.securestring.txt | convertto-securestring
$binpassword = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($sspassword)
$plainpassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($binpassword)