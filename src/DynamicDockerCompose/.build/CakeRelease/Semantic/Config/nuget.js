        // Exec plugin uses to call dotnet nuget push to push the packages from
        // the artifacts folder to NuGet
        [
            "@semantic-release/exec", {
                "publishCmd": ".\\Scripts\\publishPackageToNuget.sh --token ${process.env.NUGET_TOKEN} --source ${process.env.PUBLISH_PACKAGE_TO_NUGET_SOURCE}"
            }
        ]