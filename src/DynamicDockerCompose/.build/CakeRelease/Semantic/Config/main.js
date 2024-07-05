
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
        {%GITHUB%}
        {%NUGET%}
    ],
    "branches": ["master", "next", { name: 'beta', prerelease: true }, { name: 'alpha', prerelease: true }]
};