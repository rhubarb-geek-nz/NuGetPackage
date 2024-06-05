# rhubarb-geek-nz.NuGetPackage

`PowerShell` module for listing and downloading NuGet packages.

This was inspired by [Unable to install PowerShell Module from GitHub NuGet repository](https://github.com/PowerShell/PowerShell/issues/23834)

## Summary

The parameters are modelled on [Find-Package](https://learn.microsoft.com/en-us/powershell/module/packagemanagement/find-package) and [Save-Package](https://learn.microsoft.com/en-us/powershell/module/packagemanagement/save-package).

```
Find-NuGetPackage -Source <string> [-Name <string>] [-Credential <pscredential>] [-Filter <string>] [-RequiredVersion <string>] [-AllVersions]

Save-NuGetPackage -Source <string> -Name <string> [-Credential <pscredential>] [-Filter <string>] [-RequiredVersion <string>] [-Path <string>]
```

## Example

The following example downloads a `nupkg` from a `github` repository.

```
PS> Find-NuGetPackage -Source github -name rhubarb-geek-nz.SQLiteConnection

Version Name                             Source Description
------- ----                             ------ -----------
1.0.118 rhubarb-geek-nz.SQLiteConnection github SQLite Connection Tool

PS> Save-NuGetPackage -Source github -name rhubarb-geek-nz.SQLiteConnection -Verbose
VERBOSE: GET https://nuget.pkg.github.com/rhubarb-geek-nz/index.json
VERBOSE: Requested HTTP/1.1 GET with 0-byte payload
VERBOSE: Received HTTP/1.1 0-byte response of content type
VERBOSE: Requested HTTP/1.1 GET with 0-byte payload
VERBOSE: Received HTTP/1.1 1568-byte response of content type application/json
VERBOSE: Content encoding: utf-8
VERBOSE: GET https://nuget.pkg.github.com/rhubarb-geek-nz/query
VERBOSE: Requested HTTP/1.1 GET with 0-byte payload
VERBOSE: Received HTTP/1.1 response of content type application/json of unknown size
VERBOSE: Content encoding: utf-8
VERBOSE: GET https://nuget.pkg.github.com/rhubarb-geek-nz/rhubarb-geek-nz.SQLiteConnection/1.0.118.json
VERBOSE: Requested HTTP/1.1 GET with 0-byte payload
VERBOSE: Received HTTP/1.1 1087-byte response of content type application/json
VERBOSE: Content encoding: utf-8
VERBOSE: GET https://nuget.pkg.github.com/rhubarb-geek-nz/download/rhubarb-geek-nz.SQLiteConnection/1.0.118/rhubarb-geek-nz.SQLiteConnection.1.0.118.nupkg
VERBOSE: Requested HTTP/1.1 GET with 0-byte payload
VERBOSE: Received HTTP/1.1 10161994-byte response of content type application/octet-stream
VERBOSE: File Name: rhubarb-geek-nz.SQLiteConnection.1.0.118.nupkg
```

## Notes

The `Filter` argument is used as the `NuGet` query `q` argument so will be required when dealing with repositories of more than 20 or so packages. The tool does not dowmload multple pages of results. The repository definitions come from the user's `NuGet.Config` file. No attempt is made to deal with proxies.
