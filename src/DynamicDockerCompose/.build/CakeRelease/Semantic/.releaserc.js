
module.exports = {
    "plugins": [
        "@semantic-release/commit-analyzer",
        "@semantic-release/release-notes-generator",
        // Set of semantic-release plugins for creating or updating a changelog file.
        [
            "@semantic-release/changelog",
            {
                "changelogFile": "docs/CHANGELOG.md"
            }
        ],
        //"@semantic-release/npm",

        // Git plugin is need so the changelog file will be committed to the Git repository and available on subsequent builds in order to be updated.
        [
            "@semantic-release/git",
            {
              "assets": ["docs/CHANGELOG.md"]
            }
        ],
        
                // Exec plugin uses to call dotnet nuget push to push the packages from
        // the artifacts folder to NuGet
        [
            "@semantic-release/exec", {
                "publishCmd": ".\\Scripts\\publishPackageToNuget.sh --token ${process.env.NUGET_TOKEN} --source ${process.env.PUBLISH_PACKAGE_TO_NUGET_SOURCE}"
            }
        ]
    ],
    "branches": ["master", "next", { name: 'beta', prerelease: true }, { name: 'alpha', prerelease: true }]
};
