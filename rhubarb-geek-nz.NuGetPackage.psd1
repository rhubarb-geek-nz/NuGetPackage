@{
	RootModule = 'NuGetPackage.psm1'
	ModuleVersion = '1.0.2'
	GUID = '008e368c-1047-4f30-a7b9-aff2b2f2fd1d'
	Author = 'Roger Brown'
	CompanyName = 'rhubarb-geek-nz'
	Copyright = 'Copyright © 2024 Roger Brown'
	Description = 'NuGet tools'
	FunctionsToExport = @('Find-NuGetPackage','Save-NuGetPackage')
	CmdletsToExport = @()
	VariablesToExport = '*'
	AliasesToExport = @()
	RequiredModules = @()
	PrivateData = @{
		PSData = @{
			ProjectUri = 'https://github.com/rhubarb-geek-nz/NuGetPackage'
		}
	}
}
