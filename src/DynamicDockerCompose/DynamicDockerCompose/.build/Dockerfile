#See https://aka.ms/containerfastmode to understand how Visual Studio uses this Dockerfile to build your images for faster debugging.

# Get Base Image (Full .NET core SDK)
FROM mcr.microsoft.com/dotnet/sdk:7.0 AS build
WORKDIR /src

# Copy and restore
COPY [".", "."]
ARG SLN_PATH
RUN dotnet restore $SLN_PATH

FROM build AS publish
ARG CSPROJ_PATH
RUN dotnet publish $CSPROJ_PATH -c Release -o /app/publish

# Generate runtime image
FROM mcr.microsoft.com/dotnet/aspnet:7.0 AS base
WORKDIR /app
EXPOSE 80
EXPOSE 443

COPY --from=publish /app/publish .

# Copy and make executable the endpoint shell script
ARG ENTRYPOINT_SCRIPT_PATH
COPY ${ENTRYPOINT_SCRIPT_PATH} "./entrypoint.sh"
RUN chmod +x ./entrypoint.sh
ARG SOLUTION_NAME
ENV DLLNAME="${SOLUTION_NAME}.dll"
ENTRYPOINT ["./entrypoint.sh"]