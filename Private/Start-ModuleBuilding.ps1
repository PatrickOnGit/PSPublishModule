﻿function Start-ModuleBuilding {
    [CmdletBinding()]
    param(
        [System.Collections.IDictionary] $Configuration
    )

    $DestinationPaths = @{ }
    if ($Configuration.Information.Manifest.CompatiblePSEditions) {
        if ($Configuration.Information.Manifest.CompatiblePSEditions -contains 'Desktop') {
            $DestinationPaths.Desktop = [IO.path]::Combine($Configuration.Information.DirectoryModules, $Configuration.Information.ModuleName)
        }
        if ($Configuration.Information.Manifest.CompatiblePSEditions -contains 'Core') {
            $DestinationPaths.Core = [IO.path]::Combine($Configuration.Information.DirectoryModulesCore, $Configuration.Information.ModuleName)
        }
    } else {
        # Means missing from config - send to both
        $DestinationPaths.Desktop = [IO.path]::Combine($Configuration.Information.DirectoryModules, $Configuration.Information.ModuleName)
        $DestinationPaths.Core = [IO.path]::Combine($Configuration.Information.DirectoryModulesCore, $Configuration.Information.ModuleName)
    }
    $Versioning = Step-Version -Module $Configuration.Information.ModuleName -ExpectedVersion $Configuration.Information.Manifest.ModuleVersion -Advanced

    $Configuration.Information.Manifest.ModuleVersion = $Versioning.Version

    [string] $Random = Get-Random 10000000000
    [string] $FullModuleTemporaryPath = [IO.path]::GetTempPath() + '' + $Configuration.Information.ModuleName
    [string] $FullTemporaryPath = [IO.path]::GetTempPath() + '' + $Configuration.Information.ModuleName + "_TEMP_$Random"
    [string] $FullProjectPath = [IO.Path]::Combine($Configuration.Information.DirectoryProjects, $Configuration.Information.ModuleName)
    [string] $ProjectName = $Configuration.Information.ModuleName

    Write-Text '----------------------------------------------------'
    Write-Text "[i] Project Name: $ProjectName" -Color Yellow
    Write-Text "[i] PSGallery Version: $($Versioning.PSGalleryVersion)" -Color Yellow
    Write-Text "[i] Expected Version: $($Configuration.Information.Manifest.ModuleVersion)" -Color Yellow
    Write-Text "[i] Full module temporary path: $FullModuleTemporaryPath" -Color Yellow
    Write-Text "[i] Full project path: $FullProjectPath" -Color Yellow
    Write-Text "[i] Full temporary path: $FullTemporaryPath" -Color Yellow
    Write-Text "[i] PSScriptRoot: $PSScriptRoot" -Color Yellow
    Write-Text "[i] Current PSEdition: $PSEdition" -Color Yellow
    Write-Text "[i] Destination Desktop: $($DestinationPaths.Desktop)" -Color Yellow
    Write-Text "[i] Destination Core: $($DestinationPaths.Core)" -Color Yellow
    Write-Text '----------------------------------------------------'

    if (-not $Configuration.Steps.BuildModule) {
        Write-Text '[-] Section BuildModule is missing. Terminating.' -Color Red
        return
    }

    # check if project exists
    if (-not (Test-Path -Path $FullProjectPath)) {
        Write-Text "[-] Project path doesn't exists $FullProjectPath. Terminating" -Color Red
        return
    }

    Start-LibraryBuilding -RootDirectory $FullProjectPath -Version $Configuration.Information.Manifest.ModuleVersion -ModuleName $ProjectName -LibraryConfiguration $Configuration.Steps.BuildLibraries


    if ($Configuration.Steps.BuildModule.Enable -eq $true) {

        if ($Configuration.Steps.BuildModule.DeleteBefore -eq $true) {
            Remove-Directory $($DestinationPaths.Desktop)
            Remove-Directory $($DestinationPaths.Core)
        }

        $CurrentLocation = (Get-Location).Path
        Set-Location -Path $FullProjectPath

        Remove-Directory $FullModuleTemporaryPath
        Remove-Directory $FullTemporaryPath
        Add-Directory $FullModuleTemporaryPath
        Add-Directory $FullTemporaryPath

        # $DirectoryTypes = 'Public', 'Private', 'Lib', 'Bin', 'Enums', 'Images', 'Templates', 'Resources'

        $LinkDirectories = @()
        $LinkPrivatePublicFiles = @()

        # Fix required fields:
        $Configuration.Information.Manifest.RootModule = "$($ProjectName).psm1"
        # Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
        $Configuration.Information.Manifest.CmdletsToExport = @()
        # Variables to export from this module
        #$Configuration.Information.Manifest.VariablesToExport = @()

        if ($Configuration.Information.Exclude) {
            $Exclude = $Configuration.Information.Exclude
        } else {
            $Exclude = '.*', 'Ignore', 'Examples', 'package.json', 'Publish', 'Docs'
        }
        if ($Configuration.Information.IncludeRoot) {
            $IncludeFilesRoot = $Configuration.Information.IncludeRoot
        } else {
            $IncludeFilesRoot = '*.psm1', '*.psd1', 'License*'
        }
        if ($Configuration.Information.IncludePS1) {
            $DirectoriesWithPS1 = $Configuration.Information.IncludePS1
        } else {
            $DirectoriesWithPS1 = 'Classes', 'Private', 'Public', 'Enums'
        }
        # This is basically converting given folder into array of variables
        # mostly done for internal project and testimo
        $DirectoriesWithArrays = $Configuration.Information.IncludeAsArray.Values

        if ($Configuration.Information.IncludeClasses) {
            $DirectoriesWithClasses = $Configuration.Information.IncludeClasses
        } else {
            $DirectoriesWithClasses = 'Classes'
        }
        if ($Configuration.Information.IncludeAll) {
            $DirectoriesWithAll = $Configuration.Information.IncludeAll
        } else {
            $DirectoriesWithAll = 'Images\', 'Resources\', 'Templates\', 'Bin\', 'Lib\', 'Data\'
        }
        if ($Configuration.Steps.BuildModule.Enable -eq $true) {
            $PreparingFilesTime = Write-Text "[+] Preparing files and folders" -Start

            if ($PSEdition -eq 'core') {
                $Directories = @(
                    $TempDirectories = Get-ChildItem -Path $FullProjectPath -Directory -Exclude $Exclude -FollowSymlink
                    @(
                        $TempDirectories
                        $TempDirectories | Get-ChildItem -Directory -Recurse -FollowSymlink
                    )
                )
                $Files = Get-ChildItem -Path $FullProjectPath -Exclude $Exclude -FollowSymlink | Get-ChildItem -File -Recurse -FollowSymlink
                $FilesRoot = Get-ChildItem -Path "$FullProjectPath\*" -Include $IncludeFilesRoot -File -FollowSymlink
            } else {
                $Directories = @(
                    $TempDirectories = Get-ChildItem -Path $FullProjectPath -Directory -Exclude $Exclude
                    @(
                        $TempDirectories
                        $TempDirectories | Get-ChildItem -Directory -Recurse
                    )
                )
                $Files = Get-ChildItem -Path $FullProjectPath -Exclude $Exclude | Get-ChildItem -File -Recurse
                $FilesRoot = Get-ChildItem -Path "$FullProjectPath\*" -Include $IncludeFilesRoot -File
            }
            $LinkDirectories = @(
                foreach ($directory in $Directories) {
                    $RelativeDirectoryPath = (Resolve-Path -LiteralPath $directory.FullName -Relative).Replace('.\', '')
                    $RelativeDirectoryPath = "$RelativeDirectoryPath\"
                    $RelativeDirectoryPath
                }
            )
            $AllFiles = foreach ($File in $Files) {
                $RelativeFilePath = (Resolve-Path -LiteralPath $File.FullName -Relative).Replace('.\', '')
                $RelativeFilePath
            }
            $RootFiles = foreach ($File in $FilesRoot) {
                $RelativeFilePath = (Resolve-Path -LiteralPath $File.FullName -Relative).Replace('.\', '')
                $RelativeFilePath
            }
            # Link only files in Root Directory
            $LinkFilesRoot = @(
                foreach ($File in $RootFiles | Sort-Object -Unique) {
                    switch -Wildcard ($file) {
                        '*.psd1' {
                            $File
                        }
                        '*.psm1' {
                            $File
                        }
                        'License*' {
                            $File
                        }
                    }
                }
            )
            # Link only files from subfolers
            $LinkPrivatePublicFiles = @(
                foreach ($file in $AllFiles | Sort-Object -Unique) {
                    switch -Wildcard ($file) {
                        '*.ps1' {
                            foreach ($dir in $DirectoriesWithPS1) {
                                if ($file -like "$dir*") {
                                    $file
                                }
                            }
                            foreach ($dir in $DirectoriesWithArrays) {
                                if ($file -like "$dir*") {
                                    $file
                                }
                            }
                            # Add-FilesWithFolders -file $file -FullProjectPath $FullProjectPath -directory $DirectoriesWithPS1
                            continue
                        }
                        '*.*' {
                            #Add-FilesWithFolders -file $file -FullProjectPath $FullProjectPath -directory $DirectoriesWithAll
                            foreach ($dir in $DirectoriesWithAll) {
                                if ($file -like "$dir*") {
                                    $file
                                }
                            }
                            continue
                        }
                    }
                }
            )
            $LinkPrivatePublicFiles = $LinkPrivatePublicFiles | Select-Object -Unique

            Write-Text -End -Time $PreparingFilesTime
            $AliasesAndFunctions = Write-TextWithTime -Text '[+] Preparing function and aliases names' {
                Get-FunctionAliasesFromFolder -FullProjectPath $FullProjectPath -Files $Files #-Folder $Configuration.Information.AliasesToExport
            }
            if ($AliasesAndFunctions -is [System.Collections.IDictionary]) {
                $Configuration.Information.Manifest.FunctionsToExport = $AliasesAndFunctions.Keys | Where-Object { $_ }
                if (-not $Configuration.Information.Manifest.FunctionsToExport) {
                    $Configuration.Information.Manifest.FunctionsToExport = @()
                }
                # Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
                $Configuration.Information.Manifest.AliasesToExport = $AliasesAndFunctions.Values | ForEach-Object { $_ } | Where-Object { $_ }
                if (-not $Configuration.Information.Manifest.AliasesToExport) {
                    $Configuration.Information.Manifest.AliasesToExport = @()
                }
            } else {
                # this is not used, as we're using Hashtable above, but maybe if we change mind we can go back
                $Configuration.Information.Manifest.FunctionsToExport = $AliasesAndFunctions.Name | Where-Object { $_ }
                if (-not $Configuration.Information.Manifest.FunctionsToExport) {
                    $Configuration.Information.Manifest.FunctionsToExport = @()
                }
                $Configuration.Information.Manifest.AliasesToExport = $AliasesAndFunctions.Alias | ForEach-Object { $_ } | Where-Object { $_ }
                if (-not $Configuration.Information.Manifest.AliasesToExport) {
                    $Configuration.Information.Manifest.AliasesToExport = @()
                }
            }
            Write-Text "[i] Checking for duplicates in funcions and aliases" -Color Yellow
            $FoundDuplicateAliases = $false
            if ($Configuration.Information.Manifest.AliasesToExport) {
                $UniqueAliases = $Configuration.Information.Manifest.AliasesToExport | Select-Object -Unique
                $DiffrenceAliases = Compare-Object -ReferenceObject $Configuration.Information.Manifest.AliasesToExport -DifferenceObject $UniqueAliases
                foreach ($Alias in $Configuration.Information.Manifest.AliasesToExport) {
                    if ($Alias -in $Configuration.Information.Manifest.FunctionsToExport) {
                        Write-Text "[-] Alias $Alias is also used as function name. Fix it!" -Color Red
                        $FoundDuplicateAliases = $true
                    }
                }
                foreach ($Alias in $DiffrenceAliases.InputObject) {
                    Write-Text "[-] Alias $Alias is used multiple times. Fix it!" -Color Red
                    $FoundDuplicateAliases = $true
                }
                if ($FoundDuplicateAliases) {
                    Exit
                }
            }
            if (-not [string]::IsNullOrWhiteSpace($Configuration.Information.ScriptsToProcess)) {
                $StartsWithEnums = "$($Configuration.Information.ScriptsToProcess)\"
                $FilesEnums = @(
                    $LinkPrivatePublicFiles | Where-Object { ($_).StartsWith($StartsWithEnums) }
                )

                if ($FilesEnums.Count -gt 0) {
                    Write-TextWithTime -Text "[+] ScriptsToProcess export $FilesEnums"
                    $Configuration.Information.Manifest.ScriptsToProcess = $FilesEnums
                }
                #}
            }

            $PSD1FilePath = "$FullProjectPath\$ProjectName.psd1"

            # Copy Configuration
            $SaveConfiguration = Copy-InternalDictionary -Dictionary $Configuration

            if ($Configuration.Steps.BuildModule.UseWildcardForFunctions) {
                New-PersonalManifest -Configuration $Configuration -ManifestPath $PSD1FilePath -AddScriptsToProcess -UseWildcardForFunctions:$Configuration.Steps.BuildModule.UseWildcardForFunctions
            } else {
                New-PersonalManifest -Configuration $Configuration -ManifestPath $PSD1FilePath -AddScriptsToProcess
            }
            # Restore configuration, as some PersonalManifest plays with those
            $Configuration = $SaveConfiguration

            Format-Code -FilePath $PSD1FilePath -FormatCode $Configuration.Options.Standard.FormatCodePSD1

            if ($Configuration.Steps.BuildModule.RefreshPSD1Only) {
                Exit
            }
        }
        if ($Configuration.Steps.BuildModule.Enable -and $Configuration.Steps.BuildModule.Merge) {
            foreach ($Directory in $LinkDirectories) {
                $Dir = "$FullTemporaryPath\$Directory"
                Add-Directory $Dir
            }
            # Workaround to link files that are not ps1/psd1
            [Array] $CompareWorkaround = foreach ($_ in $DirectoriesWithPS1) {
                -join ($_, '\')
            }

            $LinkDirectoriesWithSupportFiles = $LinkDirectories | Where-Object { $_ -notin $CompareWorkaround }
            #$LinkDirectoriesWithSupportFiles = $LinkDirectories | Where-Object { $_ -ne 'Public\' -and $_ -ne 'Private\' }
            foreach ($Directory in $LinkDirectoriesWithSupportFiles) {
                $Dir = "$FullModuleTemporaryPath\$Directory"
                Add-Directory $Dir
            }

            $LinkingFilesTime = Write-Text "[+] Linking files from root and sub directories" -Start
            Set-LinkedFiles -LinkFiles $LinkFilesRoot -FullModulePath $FullTemporaryPath -FullProjectPath $FullProjectPath
            Set-LinkedFiles -LinkFiles $LinkPrivatePublicFiles -FullModulePath $FullTemporaryPath -FullProjectPath $FullProjectPath
            Write-Text -End -Time $LinkingFilesTime

            # Workaround to link files that are not ps1/psd1
            $FilesToLink = $LinkPrivatePublicFiles | Where-Object { $_ -notlike '*.ps1' -and $_ -notlike '*.psd1' }
            Set-LinkedFiles -LinkFiles $FilesToLink -FullModulePath $FullModuleTemporaryPath -FullProjectPath $FullProjectPath

            if ($Configuration.Information.LibrariesStandard) {
                # User provided option, we don't care
            } elseif ($Configuration.Information.LibrariesCore -and $Configuration.Information.LibrariesDefault) {
                # User provided option for core and default we don't care
            } else {
                # user hasn't provided any option, we set it to default
                $Configuration.Information.LibrariesStandard = "Lib\Standard"
                $Configuration.Information.LibrariesCore = "Lib\Core"
                $Configuration.Information.LibrariesDefault = "Lib\Default"
            }


            if (-not [string]::IsNullOrWhiteSpace($Configuration.Information.LibrariesCore)) {
                $StartsWithCore = "$($Configuration.Information.LibrariesCore)\"
                $FilesLibrariesCore = $LinkPrivatePublicFiles | Where-Object { ($_).StartsWith($StartsWithCore) }
            }
            if (-not [string]::IsNullOrWhiteSpace($Configuration.Information.LibrariesDefault)) {
                $StartsWithDefault = "$($Configuration.Information.LibrariesDefault)\"
                $FilesLibrariesDefault = $LinkPrivatePublicFiles | Where-Object { ($_).StartsWith($StartsWithDefault) }
            }
            if (-not [string]::IsNullOrWhiteSpace($Configuration.Information.LibrariesStandard)) {
                $StartsWithStandard = "$($Configuration.Information.LibrariesStandard)\"
                $FilesLibrariesStandard = $LinkPrivatePublicFiles | Where-Object { ($_).StartsWith($StartsWithStandard) }
            }

            Merge-Module -ModuleName $ProjectName `
                -ModulePathSource $FullTemporaryPath `
                -ModulePathTarget $FullModuleTemporaryPath `
                -Sort $Configuration.Options.Merge.Sort `
                -FunctionsToExport $Configuration.Information.Manifest.FunctionsToExport `
                -AliasesToExport $Configuration.Information.Manifest.AliasesToExport `
                -AliasesAndFunctions $AliasesAndFunctions `
                -LibrariesStandard $FilesLibrariesStandard `
                -LibrariesCore $FilesLibrariesCore `
                -LibrariesDefault $FilesLibrariesDefault `
                -FormatCodePSM1 $Configuration.Options.Merge.FormatCodePSM1 `
                -FormatCodePSD1 $Configuration.Options.Merge.FormatCodePSD1 `
                -Configuration $Configuration -DirectoriesWithPS1 $DirectoriesWithPS1 `
                -ClassesPS1 $DirectoriesWithClasses -IncludeAsArray $Configuration.Information.IncludeAsArray

            if ($Configuration.Steps.BuildModule.CreateFileCatalog) {
                # Something is wrong here for folders other than root, need investigation
                $TimeToExecuteSign = [System.Diagnostics.Stopwatch]::StartNew()
                Write-Text "[+] Creating file catalog" -Color Blue
                $TimeToExecuteSign = [System.Diagnostics.Stopwatch]::StartNew()
                $CategoryPaths = @(
                    $FullModuleTemporaryPath
                    $NotEmptyPaths = (Get-ChildItem -Directory -Path $FullModuleTemporaryPath -Recurse).FullName
                    if ($NotEmptyPaths) {
                        $NotEmptyPaths
                    }
                )
                foreach ($CatPath in $CategoryPaths) {
                    $CatalogFile = [io.path]::Combine($CatPath, "$ProjectName.cat")
                    $FileCreated = New-FileCatalog -Path $CatPath -CatalogFilePath $CatalogFile -CatalogVersion 2.0
                    if ($FileCreated) {
                        Write-Text "   [>] Catalog file covering $CatPath was created $($FileCreated.Name)" -Color Yellow
                    }
                }
                $TimeToExecuteSign.Stop()
                Write-Text "[+] Creating file catalog [Time: $($($TimeToExecuteSign.Elapsed).Tostring())]" -Color Blue
            }
            if ($Configuration.Steps.BuildModule.SignMerged) {
                $TimeToExecuteSign = [System.Diagnostics.Stopwatch]::StartNew()
                #Write-Text "[+] 8th stage signing files" -Color Blue
                Write-TextWithTime -Text 'Applying signature to files' {
                    $SignedFiles = Register-Certificate -LocalStore CurrentUser -Path $FullModuleTemporaryPath -Include @('*.ps1', '*.psd1', '*.psm1', '*.dll', '*.cat') -TimeStampServer 'http://timestamp.digicert.com'
                    foreach ($File in $SignedFiles) {
                        Write-Text "   [>] File $($File.Path) with status: $($File.StatusMessage)" -Color Yellow
                    }
                    $TimeToExecuteSign.Stop()
                    #   Write-Text "[+] 8th stage signing files [Time: $($($TimeToExecuteSign.Elapsed).Tostring())]" -Color Blue
                } -PreAppend Plus
            }
        }
        if ($Configuration.Steps.BuildModule.Enable -and (-not $Configuration.Steps.BuildModule.Merge)) {
            foreach ($Directory in $LinkDirectories) {
                $Dir = "$FullModuleTemporaryPath\$Directory"
                Add-Directory $Dir
            }
            $LinkingFilesTime = Write-Text "[+] Linking files from root and sub directories" -Start
            Set-LinkedFiles -LinkFiles $LinkFilesRoot -FullModulePath $FullModuleTemporaryPath -FullProjectPath $FullProjectPath
            Set-LinkedFiles -LinkFiles $LinkPrivatePublicFiles -FullModulePath $FullModuleTemporaryPath -FullProjectPath $FullProjectPath
            Write-Text -End -Time $LinkingFilesTime
        }


        # Revers Path to current locatikon
        Set-Location -Path $CurrentLocation

        if ($Configuration.Steps.BuildModule.Enable) {
            if ($DestinationPaths.Desktop) {
                Write-TextWithTime -Text "[+] Copy module to PowerShell 5 destination: $($DestinationPaths.Desktop)" {
                    Remove-Directory -Directory $DestinationPaths.Desktop
                    Add-Directory -Directory $DestinationPaths.Desktop
                    Get-ChildItem -LiteralPath $FullModuleTemporaryPath | Copy-Item -Destination $DestinationPaths.Desktop -Recurse
                    # cleans up empty directories
                    Get-ChildItem $DestinationPaths.Desktop -Recurse -Force -Directory | Sort-Object -Property FullName -Descending | `
                        Where-Object { $($_ | Get-ChildItem -Force | Select-Object -First 1).Count -eq 0 } | `
                        Remove-Item #-Verbose
                }


            }
            if ($DestinationPaths.Core) {
                Write-TextWithTime -Text "[+] Copy module to PowerShell 6/7 destination: $($DestinationPaths.Core)" {
                    Remove-Directory -Directory $DestinationPaths.Core
                    Add-Directory -Directory $DestinationPaths.Core
                    Get-ChildItem -LiteralPath $FullModuleTemporaryPath | Copy-Item -Destination $DestinationPaths.Core -Recurse
                    # cleans up empty directories
                    Get-ChildItem $DestinationPaths.Core -Recurse -Force -Directory | Sort-Object -Property FullName -Descending | `
                        Where-Object { $($_ | Get-ChildItem -Force | Select-Object -First 1).Count -eq 0 } | `
                        Remove-Item #-Verbose
                }
            }
        }
        Start-ArtefactsBuilding -Configuration $Configuration -FullProjectPath $FullProjectPath -DestinationPaths $DestinationPaths

    }

    # Import Modules Section, useful to check before publishing
    if ($Configuration.Steps.ImportModules) {
        $TemporaryVerbosePreference = $VerbosePreference
        $VerbosePreference = $false

        if ($Configuration.Steps.ImportModules.RequiredModules) {
            Write-TextWithTime -Text '[+] Importing modules - REQUIRED' {
                foreach ($Module in $Configuration.Information.Manifest.RequiredModules) {
                    Import-Module -Name $Module -Force -ErrorAction Stop -Verbose:$false
                }
            }
        }
        if ($Configuration.Steps.ImportModules.Self) {
            Write-TextWithTime -Text '[+] Importing module - SELF' {
                Import-Module -Name $ProjectName -Force -ErrorAction Stop -Verbose:$false
            }
        }
        $VerbosePreference = $TemporaryVerbosePreference
    }

    if ($Configuration.Steps.PublishModule.Enabled) {
        Write-TextWithTime -Text "[+] Publishing Module to PowerShellGallery" {
            try {
                if ($Configuration.Options.PowerShellGallery.FromFile) {
                    $ApiKey = Get-Content -Path $Configuration.Options.PowerShellGallery.ApiKey -ErrorAction Stop
                    #New-PublishModule -ProjectName $Configuration.Information.ModuleName -ApiKey $ApiKey -RequireForce $Configuration.Steps.PublishModule.RequireForce
                    Publish-Module -Name $Configuration.Information.ModuleName -Repository PSGallery -NuGetApiKey $ApiKey -Force:$Configuration.Steps.PublishModule.RequireForce -Verbose -ErrorAction Stop
                } else {
                    #New-PublishModule -ProjectName $Configuration.Information.ModuleName -ApiKey $Configuration.Options.PowerShellGallery.ApiKey -RequireForce $Configuration.Steps.PublishModule.RequireForce
                    Publish-Module -Name $Configuration.Information.ModuleName -Repository PSGallery -NuGetApiKey $Configuration.Options.PowerShellGallery.ApiKey -Force:$Configuration.Steps.PublishModule.RequireForce -Verbose -ErrorAction Stop
                }
            } catch {
                $ErrorMessage = $_.Exception.Message
                Write-Host # This is to add new line, because the first line was opened up.
                Write-Text "[-] Publishing Module - failed. Error: $ErrorMessage" -Color Red
                Exit
            }
        }
    }

    if ($Configuration.Steps.PublishModule.GitHub) {
        Start-GitHubBuilding -Configuration $Configuration -FullProjectPath $FullProjectPath -TagName $TagName -ProjectName $ProjectName
    }
    if ($Configuration.Steps.BuildDocumentation) {
        # Support for old way of building documentation -> converts to new one
        if ($Configuration.Steps.BuildDocumentation -is [bool]) {
            $TemporaryBuildDocumentation = $Configuration.Steps.BuildDocumentation
            $Configuration.Steps.BuildDocumentation = @{
                Enable = $TemporaryBuildDocumentation
            }
        }
        # Real documentation process
        if ($Configuration.Steps.BuildDocumentation -is [System.Collections.IDictionary]) {
            if ($Configuration.Steps.BuildDocumentation.Enable -eq $true) {
                $WarningVariablesMarkdown = @()
                $DocumentationPath = "$FullProjectPath\$($Configuration.Options.Documentation.Path)"
                $ReadMePath = "$FullProjectPath\$($Configuration.Options.Documentation.PathReadme)"
                Write-Text "[+] Generating documentation to $DocumentationPath with $ReadMePath" -Color Yellow

                if (-not (Test-Path -Path $DocumentationPath)) {
                    $null = New-Item -Path "$FullProjectPath\Docs" -ItemType Directory -Force
                }
                [Array] $Files = Get-ChildItem -Path $DocumentationPath
                if ($Files.Count -gt 0) {
                    if ($Configuration.Steps.BuildDocumentation.StartClean -ne $true) {
                        try {
                            $null = Update-MarkdownHelpModule $DocumentationPath -RefreshModulePage -ModulePagePath $ReadMePath -ErrorAction Stop -WarningVariable +WarningVariablesMarkdown -WarningAction SilentlyContinue -ExcludeDontShow
                        } catch {
                            Write-Text "[-] Documentation warning: $($_.Exception.Message)" -Color Yellow
                        }
                    } else {
                        # remove everything / Refresh Count
                        #$null = Remove-Item -Path $DocumentationPath -Force -Recurse
                        <#
                        $ItemToDelete = Get-ChildItem -Path $DocumentationPath
                        foreach ($Item in $ItemToDelete) {
                            $Item.Delete()
                        }
                        $ItemToDelete = Get-Item -Path $DocumentationPath
                        $ItemToDelete.Delete($true)
                        #>
                        Remove-ItemAlternative -Path $DocumentationPath -SkipFolder
                        #$null = New-Item -Path "$FullProjectPath\Docs" -ItemType Directory -Force
                        [Array] $Files = Get-ChildItem -Path $DocumentationPath
                    }
                }
                if ($Files.Count -eq 0) {
                    try {
                        $null = New-MarkdownHelp -Module $ProjectName -WithModulePage -OutputFolder $DocumentationPath -ErrorAction Stop -WarningVariable +WarningVariablesMarkdown -WarningAction SilentlyContinue -ExcludeDontShow
                    } catch {
                        Write-Text "[-] Documentation warning: $($_.Exception.Message)" -Color Yellow
                    }
                    $null = Move-Item -Path "$DocumentationPath\$ProjectName.md" -Destination $ReadMePath -ErrorAction SilentlyContinue
                    #Start-Sleep -Seconds 1
                    # this is temporary workaround - due to diff output on update
                    if ($Configuration.Steps.BuildDocumentation.UpdateWhenNew) {
                        try {
                            $null = Update-MarkdownHelpModule $DocumentationPath -RefreshModulePage -ModulePagePath $ReadMePath -ErrorAction Stop -WarningVariable +WarningVariablesMarkdown -WarningAction SilentlyContinue -ExcludeDontShow
                        } catch {
                            Write-Text "[-] Documentation warning: $($_.Exception.Message)" -Color Yellow
                        }
                    }
                }
                foreach ($_ in $WarningVariablesMarkdown) {
                    Write-Text "[-] Documentation warning: $_" -Color Yellow
                }

            }
        }
    }

    # Cleanup temp directory
    Write-Text "[+] Cleaning up directories created in TEMP directory" -Color Yellow
    Remove-Directory $FullModuleTemporaryPath
    Remove-Directory $FullTemporaryPath
}