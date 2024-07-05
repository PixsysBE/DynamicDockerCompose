# Build and push package

To build a new version of the package, first update the nuspec file :

```
<version>0.0.1</version>
```

Then run 

```
dotnet pack
```


```
dotnet nuget push <nupkg folder> -s <nuget source folder>
```