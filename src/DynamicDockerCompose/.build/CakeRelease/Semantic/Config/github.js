
    // Set of Semantic-release plugins for publishing a GitHub release.
    // Includes the packages from the artifacts folder as assets
    [
        '@semantic-release/github',
        {
            "assets": [
                { "path": "Artifacts/*.nupkg" }
            ]
        }
    ],