# Copyright (c) 2024 Roger Brown.
# Licensed under the MIT License.

function NuGetPackage
{
	[CmdletBinding(PositionalBinding=$False)]

	Param(
		[Parameter(Mandatory=$True)][string]$Source,
		[PSCredential]$Credential,
		[string]$Filter,
		[string]$Name,
		[string]$RequiredVersion,
		[switch]$AllVersions,
		[bool]$SaveVerb
	)

	Process
	{
		if ($PSVersionTable.PSEdition -eq 'Desktop')
		{
			$IsWindows = $True
		}

		if ($IsWindows)
		{
			$NuGetConfigPath = "$env:APPDATA\NuGet\NuGet.Config"
		}
		else
		{
			$NuGetConfigPath = "$env:HOME/.nuget/NuGet/NuGet.Config", "$env:HOME/.config/NuGet/NuGet.Config"
		}

		$NuGetConfig = $Null

		foreach ($NuGetConfigFile in $NuGetConfigPath)
		{
			if (Test-Path -LiteralPath $NuGetConfigFile)
			{
				[xml]$NuGetConfig = Get-Content -LiteralPath $NuGetConfigFile

				break
			}
		}

		if (-not $NuGetConfig)
		{
			Write-Error "NuGet.Config not found"
		}

		$PackageSource = (Select-Xml -Xml $NuGetConfig -XPath "/configuration/packageSources/add[@key='$Source']").Node

		if (-not $PackageSource)
		{
			Write-Error "NuGet source $Source not found"
		}

		$PackageSourceUrl = $PackageSource.value

		if (-not $PackageSourceUrl)
		{
			Write-Error "No Source URL for $Source"
		}

		$args = @{
			Uri = $PackageSourceUrl
		}

		$SourceUri = New-Object -TypeName 'System.Uri' -ArgumentList $PackageSourceUrl

		$PackageFilename = "$Name.$RequiredVersion.nupkg"

		if ($SourceUri.IsFile)
		{
			$FilePath = Join-Path -Path $SourceUri.LocalPath -ChildPath $PackageFilename

			if (Test-Path -LiteralPath $FilePath)
			{
				$PackageContent = "$PackageSourceUrl/$PackageFilename"
			}
			else
			{
				Write-Error "$FilePath not found"
			}
		}
		else
		{
			try
			{
				if ($Credential)
				{
					$args['Credential'] = $Credential
				}

				Write-Verbose "GET $PackageSourceUrl"

				$Index = Invoke-RestMethod @args
			}
			catch
			{
				$Response = $PSItem.Exception.Response

				if ($Response.StatusCode.Value__ -and ( -not $Credential ))
				{
					switch ($Response.StatusCode.Value__)
					{
						401 {
							$UserName = (Select-Xml -Xml $NuGetConfig -XPath "/configuration/packageSourceCredentials/$Source/add[@key='Username']").Node
							$Password = (Select-Xml -Xml $NuGetConfig -XPath "/configuration/packageSourceCredentials/$Source/add[@key='ClearTextPassword']").Node

							if ($UserName -and $Password)
							{
								[securestring]$secStringPassword = ConvertTo-SecureString $Password.value -AsPlainText -Force

								$Credential = New-Object -TypeName 'System.Management.Automation.PSCredential' -ArgumentList $UserName.value, $secStringPassword
							}
							else
							{
								$Message = "Provide credentials for NuGet source '$Source'"

								$WWWAuthenticate = $Response.Headers | Where-Object { $_.Key -eq 'WWW-Authenticate' } | ForEach-Object { $_.Value }

								if ($WWWAuthenticate)
								{
									$Realm = (Select-String -InputObject $WWWAuthenticate -Pattern 'realm="(.*?)"').Matches.Groups[1].value

									if ($Realm)
									{
										$Message = "Provide credentials for '$Realm'"
									}
								}

								$Credential = Get-Credential -Message $Message
							}

							if ($Credential)
							{
								try
								{
									$args['Credential'] = $Credential

									$Index = Invoke-RestMethod @args
								}
								catch
								{
									Write-Error $PSItem
								}
							}
							else
							{
								Write-Error "No credentials for $Source found"
							}
						}

						default {
							Write-Error $PSItem
						}
					}
				}
				else
				{
					Write-Error $PSItem
				}
			}

			$SearchQueryService = $Null

			foreach ($Resource in $Index.resources)
			{
				switch ($Resource.'@type')
				{
					{ @('SearchQueryService', 'SearchQueryService/3.0.0-beta') -contains $_ } {
						$SearchQueryService = $Resource.'@id'

						if ($Filter -and $SearchQueryService)
						{
							$args['Body'] = @{
								q = $Filter
							}
						}
					}
				}

				if ($SearchQueryService)
				{
					break
				}
			}

			if (-not $SearchQueryService)
			{
				Write-Error "SearchQueryService not found"
			}

			$args['Uri'] = $SearchQueryService

			if ($Filter)
			{
				Write-Verbose "GET $($SearchQueryService)?q=$Filter"
			}
			else
			{
				Write-Verbose "GET $SearchQueryService"
			}

			$QueryResult = Invoke-RestMethod @args

			$args.Remove('Body')

			$VersionInfo = $Null
			$PackageContent = $Null

			foreach ($Data in $QueryResult.Data)
			{
				if (($Data.id -eq $Name) -or (-not $Name))
				{
					if ($SaveVerb -and ( -not $RequiredVersion ))
					{
						$RequiredVersion = $Data.version
					}

					if ($RequiredVersion -and $Name)
					{
						foreach ($Version in $Data.versions)
						{
							if ($Version.version -eq $RequiredVersion)
							{
								if ($SaveVerb)
								{
									$Uri = $Version.'@id'
									$args['Uri'] = $Uri

									Write-Verbose "GET $Uri"

									$VersionInfo = Invoke-RestMethod @args

									$PackageContent = $VersionInfo.packageContent

									$PackageFilename = "$($Data.id).$($Version.version).nupkg"

									[pscustomobject]@{
										Version = $Version.version
										Name = $Data.id
										Source = $Source
										Description = $Data.description
										PackageContent = $PackageContent
										PackageFilename = $PackageFilename
										Credential = $Credential
									}
								}
								else
								{
									[pscustomobject]@{
										Version = $Version.version
										Name = $Data.id
										Source = $Source
										Description = $Data.description
									}
								}
							}
						}
					}
					else
					{
						if ($AllVersions)
						{
							foreach ($Version in $Data.versions)
							{
								[pscustomobject]@{
									Version = $Version.version
									Name = $Data.id
									Source = $Source
									Description = $Data.description
								}
							}
						}
						else
						{
							[pscustomobject]@{
								Version = $Data.version
								Name = $Data.id
								Source = $Source
								Description = $Data.description
							}
						}
					}
				}
			}
		}
	}
}

function Find-NuGetPackage
{
	[CmdletBinding(PositionalBinding=$False)]

	Param(
		[Parameter(Mandatory=$True)][string]$Source,
		[string]$Name,
		[PSCredential]$Credential,
		[string]$Filter,
		[string]$RequiredVersion,
		[switch]$AllVersions
	)

	Process
	{
		$args = @{
			Source = $Source
		}

		foreach ($Nvp in ('Name',$Name),('Credential',$Credential),('RequiredVersion',$RequiredVersion),('Filter',$Filter))
		{
			if ($Nvp[1])
			{
				$args[$Nvp[0]] = $Nvp[1]
			}
		}

		if ($AllVersions)
		{
			$args['AllVersions'] = $AllVersions
		}

		$ErrorActionOriginal = $ErrorActionPreference

		try
		{
			$ErrorActionPreference = 'Stop'

			NuGetPackage @args
		}
		catch
		{
			$ErrorActionPreference = $ErrorActionOriginal

			Write-Error $PSItem
		}
	}
}

function Save-NuGetPackage
{
	[CmdletBinding(PositionalBinding=$False)]

	Param(
		[Parameter(Mandatory=$True)][string]$Source,
		[Parameter(Mandatory=$True)][string]$Name,
		[PSCredential]$Credential,
		[string]$Filter,
		[string]$RequiredVersion,
		[string]$Path,
		[string]$LiteralPath
	)

	Process
	{
		$args = @{
			Source = $Source
			Name = $Name
			SaveVerb = $True
		}

		foreach ($Nvp in ('Credential',$Credential),('RequiredVersion',$RequiredVersion),('Filter',$Filter))
		{
			if ($Nvp[1])
			{
				$args[$Nvp[0]] = $Nvp[1]
			}
		}

		$ErrorActionOriginal = $ErrorActionPreference

		try
		{
			$ErrorActionPreference = 'Stop'

			if ($Path -and $LiteralPath)
			{
				Write-Error "Can't provide both Path and LiteralPath"
			}

			if ($Path)
			{
				$ResolvedPath = Resolve-Path -Path $Path

				if ($ResolvedPath.Count -ne 1)
				{
					Write-Error "Path '$Path' was ambiguous"
				}

				$LiteralPath = $ResolvedPath
			}

			if ($LiteralPath -and -not ( Test-Path -LiteralPath $LiteralPath -PathType Container ))
			{
				Write-Error "Directory '$LiteralPath' not found"
			}

			$Results = New-Object -TypeName 'System.Collections.ArrayList'

			NuGetPackage @args | ForEach-Object {
				$Uri = $_.PackageContent
				$PackageFilename = $_.PackageFilename

				if ($LiteralPath)
				{
					$OutFile = Join-Path -Path $LiteralPath -ChildPath $PackageFilename
				}
				else
				{
					$OutFile = $PackageFilename
				}

				$args = @{
					OutFile = $OutFile
					Uri = $Uri
				}

				if ($_.Credential)
				{
					$args['Credential'] = $_.Credential
				}

				Write-Verbose "GET $Uri"

				Invoke-WebRequest @args

				$Results += $PackageFilename
			}

			if (-not $Results)
			{
				Write-Error 'No results'
			}
		}
		catch
		{
			$ErrorActionPreference = $ErrorActionOriginal

			Write-Error $PSItem
		}
	}
}

Export-ModuleMember -Function 'Find-NuGetPackage','Save-NuGetPackage'
