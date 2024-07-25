# Dynamic Docker Compose

Dynamic Docker Compose allows you to dynamically retrieve values required by your [Docker Compose](https://docs.docker.com/compose/) and Dockerfile.

It will look in different locations and set new environment variables so they can be used when creating your container.

The variables values can be retrieved in 3 different ways:

- By passing them as dynamic parameters when calling the Powershell script 
- By storing them in a .env file
- By selecting [one of the available templates](#looking-for-some-paths-in-the-templates), the script will try to find related paths

> This tool is suited to quickly dockerize .net core applications, but you can customize scripts depending on your needs.

## Application General Structure

.Net Core Web Applications generally have this structure:

```
├── /src
│   ├── <Project Name>
│   │   ├── Project.sln
│   │   ├── <Project Name>
│   │   │   ├── Project.csproj
│   │   ├── <Tests Project Name>
```

By installing the package, you will create new folders **.build** and **.config** at the root of your project.

```
├── /src
│   ├── <Project Name>
----- inserted -----
│   │   ├── /.build
│   │   │   ├── /DynamicDockerCompose
│   │   │   │   ├── dynamic-docker-compose.ps1
│   │   │   │   ├── dynamic-docker-compose.functions.ps1
│   │   │   ├── docker-compose.yaml
│   │   │   ├── Dockerfile
│   │   ├── /.config
│   │   │   ├── docker-dev.env
----- inserted -----
│   │   ├── Project.sln
│   │   ├── <Project Name>
│   │   │   ├── Project.csproj
│   │   ├── <Tests Project Name>
```

## Setting up your variables

Let's say you want to add some customs arguments as described here:

```
version: '3'
services: 
  frontend:
    image: ...
    build: 
      context: ...
      dockerfile: ...
      args:  
        - CUSTOM_PATH=${CUSTOM_PATH}
        - IS_DEV_ENVIRONMENT=${SWITCHPARAM}
```

You can add as much dynamic variables as you need when calling the script. These can be string (=they have a value) or switch (boolean). 

Here is an example:

```powershell
.\dynamic-docker-compose.ps1 -env-name dev -CUSTOM_PATH "C:\Test" -SWITCHPARAM -list
```

This will create the 2 following variables:
| Name | Value | Type | Location
|----------|----------|------------|------------|
| CUSTOM_PATH | C:\Test | string | parameter
| SWITCHPARAM | True | switch | parameter

> Please note that by design, only the uppercase variable names will be set as environment variables.

## Setting up your environment file

You can create a .env file to substitute your variables, where all variables with an uppercase name will be transformed into environment variables later. Here is a file example:

```
COMPOSE_PROJECT_NAME=my-project # project name, will be used to generate containers names
HTTP_PORT=8006
HTTPS_PORT=8007
ENV=docker-dev
TAG=local
secretstore_password_path=C:\Automation\secretstorepasswd.xml
secretstore_vault_name=MyVaultName
ROOT_PATH=../../../../../ # your solution folder
```

All your .env files must be placed inside your .config folder. You will then use the **-env-name** parameter to use the one you want with the **Dynamic Docker Compose** Powershell script.

## Looking for some paths in the templates

Some projects may require specific variables depending on the project type (for instance, you may require the path to your .csproj file in a ASP.NET Core Web App). 

If needed variables are not defined by one of the two first methods, it will start to look in specific locations described below. All paths found will always be relative from the root path.

### Template dotnet-webapp

| Name | Variable Name | Default location | Description|
|----------|----------|------------|------------|
|Root Path|ROOT_PATH|"../../../" from script location|The path to your root folder
|Docker Compose Yaml Path|DOCKER_COMPOSE_YAML_PATH|"./.build/docker-compose.yaml"| The path to your Docker compose yaml file
|Dockerfile Path|DOCKER_FILE_PATH|"./.build/Dockerfile"| The path to your Dockerfile 
|csproj Path|CSPROJ_PATH|"./**/*.csproj"| The path to your .csproj
|sln Path|SLN_PATH|"./*.sln"| The path to your .sln
|Entrypoint Script Path|ENTRYPOINT_SCRIPT_PATH|"./.build/DynamicDockerCompose/Scripts/entrypoint.sh"| The path to the entrypoint shell bash
|Certificate Path|CERTIFICATE_PATH|SecretStore|The path to your valid HTTPS certificate
|Certificate Password|CERTIFICATE_PASSWORD|SecretStore|The HTTPS certificate password

## Local certificates for development purposes

If you don't already have one, create your trusted HTTPS development certificate:

```powershell

  PM > dotnet dev-certs https --clean
  //Cleaning HTTPS development certificates from the machine. A prompt might get displayed to confirm the removal of some of the certificates.
  //HTTPS development certificates successfully removed from the machine.

  PM > dotnet dev-certs https -ep $env:USERPROFILE\.aspnet\https\aspnetapp.pfx --trust
  //Trusting the HTTPS development certificate was requested.A confirmation prompt will be displayed if the certificate was not previously trusted.Click yes on the prompt to trust the certificate.
  //Successfully created and trusted a new HTTPS certificate.

  PM > dotnet dev-certs https --check
  //A valid certificate was found: C40087E6CA2F2A811F3BF78E3C5FE6BA8FA2XXXX - CN = localhost - Valid from 2023 - 01 - 27 23:21:10Z to 2024 - 01 - 27 23:21:10Z - IsHttpsDevelopmentCertificate: true - IsExportable: true
  //Run the command with both--check and --trust options to ensure that the certificate is not only valid but also trusted.

```

Once the certificate is created, we will store its path and password as secrets in the PowerShell [SecretManagement and SecretStore](https://learn.microsoft.com/en-us/powershell/utility-modules/secretmanagement/how-to/using-secrets-in-automation?view=ps-modules) modules.

> More info available here : [Use the SecretStore in automation](https://learn.microsoft.com/en-us/powershell/utility-modules/secretmanagement/how-to/using-secrets-in-automation?view=ps-modules)

```powershell
Install-Module -Name Microsoft.PowerShell.SecretStore -Repository PSGallery -Force
Install-Module -Name Microsoft.PowerShell.SecretManagement -Repository PSGallery -Force
Import-Module Microsoft.PowerShell.SecretStore
Import-Module Microsoft.PowerShell.SecretManagement
```
 Get the identification information of the username 'SecureStore':

```powershell
PS> $credential = Get-Credential -UserName 'SecureStore'

PowerShell credential request
Enter your credentials.
Password for user SecureStore: **************
```

Once you set the password you can export it to an XML file, encrypted by Windows Data Protection (DPAPI).

```powershell
$securePasswordPath = 'C:\automation\passwd.xml'
$credential.Password |  Export-Clixml -Path $securePasswordPath
```

### Configure your vault

Next you must configure the SecretStore vault. The configuration sets user interaction to None, so that SecretStore never prompts the user. The configuration requires a password, and the password is passed in as a SecureString object. The -Confirm:false parameter is used so that PowerShell does not prompt for confirmation.

```powershell
Register-SecretVault -Name YourVaultName -ModuleName Microsoft.PowerShell.SecretStore
$password = Import-CliXml -Path $securePasswordPath

$storeConfiguration = @{
    Authentication = 'Password'
    PasswordTimeout = 3600 # 1 hour
    Interaction = 'None'
    Password = $password
    Confirm = $false
}
Set-SecretStoreConfiguration @storeConfiguration
```

Set your secrets

```powershell
Unlock-SecretStore -Password $password
Set-Secret -Name CERTIFICATE_PATH -Secret "/root/.aspnet/https/aspnetapp.pfx" -Vault TestPixsysPackages.DEV -Metadata @{Purpose="Certificate Path"}	
Set-Secret -Name CERTIFICATE_PASSWORD -Secret "Password1" -Vault TestPixsysPackages.DEV -Metadata @{Purpose="Certificate Password"}	
```

To get the list of all of your secrets, you can run:
```powershell
Get-SecretInfo -Name CERTIFICATE_PATH  -Vault YourVaultName  | Select Name, Type, VaultName, Metadata
```
To remove your vault, run:
```powershell
Unregister-SecretVault -Name YourVaultName
```

Then, reference the secret store password location and the vault name in the .env file [as showed above](#setting-up-your-environment-file):
```
secretstore_password_path=E:\Automation\securestorepasswd.xml
secretstore_vault_name=TestPixsysPackages.DEV
```

The script will try to unlock the specified vault with the provided password to get the HTTPS certificate path and password.

## Compose your application
> Make sure Docker Desktop is running first

Run the **Dynamic Docker Compose** Powershell script located in your .build folder with only one of these parameters: 

|   Name       | Description   |
|----------|----------|
| -up | Creates and starts the container |
| -down | Removes the container |
| -list | List all variables and their values |

Optional parameters :
|   Name       | Description   |
|----------|----------|
| -env-name  | the name of the .env file to be used |
| -template  | the name of the template to be used |

Example :

```powershell
.\.build\DynamicDockerCompose\dynamic-docker-compose.ps1 -env-name docker-dev -template dotnet-webapp -up
```

Environment variables will be dynamically generated and passed to Dockerfile and docker-compose.yaml to build your containers.