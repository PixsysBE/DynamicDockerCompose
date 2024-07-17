# Dynamic Docker Compose

Dynamic Docker Compose allows you to dynamically retrieve values of your custom variables before passing them to [Docker Compose](https://docs.docker.com/compose/).
Variables values are passed as parameters in your Powershell script or can be stored in your in your .env file.

> This tool is suited to quickly dockerize .net core applications, but you can customize scripts for your needs.

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


## Setting up your environment file

You can create a .env file to substitute your variables. Here is a file example:

```
COMPOSE_PROJECT_NAME=my-project # project name, will be used to generate containers names
HTTP_PORT=8006
HTTPS_PORT=8007
ENV=docker-dev
TAG=local
ROOT_PATH=../../../../../ # your solution folder
```

All your .env files must be placed inside your .config folder. You will then use the **-env-name** parameter to use the one you want with the Dynamic **Dynamic Docker Compose** Powershell script.

## Setting up your variables

Some variables can be defined either when calling the **Dynamic Docker Compose** Powershell script or in the env file.If not defined, the default location will be used. All variables paths must be set from the root path.

| Variable | Env File | Default location | Description|
|----------|----------|------------|------------|
|rootPath|ROOT_PATH|Defined from script location|The path to your root folder
|dockerComposeYamlPath|DOCKER_COMPOSE_YAML_PATH|"./.build/docker-compose.yaml"| The path to your Docker compose yaml file
|dockerFilePath|DOCKER_FILE_PATH|"./.build/Dockerfile"| The path to your Dockerfile 
|csprojPath|CSPROJ_PATH|"./**/*.csproj"| The path to your .csproj
|slnPath|SLN_PATH|"./*.sln"| The path to your .sln
|entrypointScriptPath|ENTRYPOINT_SCRIPT_PATH|"./.build/DynamicDockerCompose/Scripts/entrypoint.sh"| The path to the entrypoint shell bash


## Compose your application
> Make sure Docker Desktop is running first

Run the **Dynamic Docker Compose** Powershell script located in your .build folder with minimum 2 parameters: the .env file name and the up (or down) command:

```powershell
.\.build\DynamicDockerCompose\dynamic-docker-compose.ps1 -env-name docker-dev -up
```

Environment variables will be dynamically generated and passed to Dockerfile and docker-compose.yaml to build your containers.