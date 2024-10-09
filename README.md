[![Nuget](https://img.shields.io/nuget/v/DynamicDockerCompose.svg)](https://www.nuget.org/packages/DynamicDockerCompose)
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

## Local certificates for development purposes

I recommend using [DockerMkcertForLocalSSL](https://github.com/PixsysBE/DockerMkcertForLocalSSL) to easily take care of local SSL certificates. Copy/Paste the required files into the .config folder and follow instructions from the installation section.

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

Environment variables will be dynamically generated and passed to your Dockerfile and docker-compose.yaml to build your containers.