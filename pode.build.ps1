param (
    [string]
    $Version = ''
)

<#
# Dependency Versions
#>

$Versions = @{
    Pester = '4.8.0'
    MkDocs = '1.1.2'
    PSCoveralls = '1.0.0'
    SevenZip = '18.5.0.20180730'
    DotNetCore = '3.1.5'
    Checksum = '0.2.0'
    MkDocsTheme = '6.2.8'
    PlatyPS = '0.14.0'
}

<#
# Helper Functions
#>

function Test-PodeBuildIsWindows
{
    $v = $PSVersionTable
    return ($v.Platform -ilike '*win*' -or ($null -eq $v.Platform -and $v.PSEdition -ieq 'desktop'))
}

function Test-PodeBuildIsGitHub
{
    return (![string]::IsNullOrWhiteSpace($env:GITHUB_REF))
}

function Test-PodeBuildCanCodeCoverage
{
    return (@('1', 'true') -icontains $env:PODE_RUN_CODE_COVERAGE)
}

function Get-PodeBuildService
{
    return 'github-actions'
}

function Test-PodeBuildCommand($cmd)
{
    $path = $null

    if (Test-PodeBuildIsWindows) {
        $path = (Get-Command $cmd -ErrorAction Ignore)
    }
    else {
        $path = (which $cmd)
    }

    return (![string]::IsNullOrWhiteSpace($path))
}

function Get-PodeBuildBranch
{
    return ($env:GITHUB_REF -ireplace 'refs\/heads\/', '')
}

function Invoke-PodeBuildInstall($name, $version)
{
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    if (Test-PodeBuildIsWindows) {
        if (Test-PodeBuildCommand 'choco') {
            choco install $name --version $version -y
        }
    }
    else {
        if (Test-PodeBuildCommand 'brew') {
            brew install $name
        }
        elseif (Test-PodeBuildCommand 'apt-get') {
            sudo apt-get install $name -y
        }
        elseif (Test-PodeBuildCommand 'yum') {
            sudo yum install $name -y
        }
    }
}

function Install-PodeBuildModule($name)
{
    if ($null -ne ((Get-Module -ListAvailable $name) | Where-Object { $_.Version -ieq $Versions[$name] })) {
        return
    }

    Write-Host "Installing $($name) v$($Versions[$name])"
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Install-Module -Name "$($name)" -Scope CurrentUser -RequiredVersion "$($Versions[$name])" -Force -SkipPublisherCheck
}


<#
# Helper Tasks
#>

# Synopsis: Stamps the version onto the Module
task StampVersion {
    (Get-Content ./pkg/Pode.psd1) | ForEach-Object { $_ -replace '\$version\$', $Version } | Set-Content ./pkg/Pode.psd1
    (Get-Content ./packers/choco/pode.nuspec) | ForEach-Object { $_ -replace '\$version\$', $Version } | Set-Content ./packers/choco/pode.nuspec
    (Get-Content ./packers/choco/tools/ChocolateyInstall.ps1) | ForEach-Object { $_ -replace '\$version\$', $Version } | Set-Content ./packers/choco/tools/ChocolateyInstall.ps1
}

# Synopsis: Generating a Checksum of the Zip
task PrintChecksum {
    if (Test-PodeBuildIsWindows) {
        $Script:Checksum = (checksum -t sha256 $Version-Binaries.zip)
    }
    else {
        $Script:Checksum = (shasum -a 256 ./$Version-Binaries.zip | awk '{ print $1 }').ToUpper()
    }

    Write-Host "Checksum: $($Checksum)"
}


<#
# Dependencies
#>

# Synopsis: Installs Chocolatey
task ChocoDeps -If (Test-PodeBuildIsWindows) {
    if (!(Test-PodeBuildCommand 'choco')) {
        Set-ExecutionPolicy Bypass -Scope Process -Force
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
    }
}

# Synopsis: Install dependencies for packaging
task PackDeps -If (Test-PodeBuildIsWindows) ChocoDeps, {
    if (!(Test-PodeBuildCommand 'checksum')) {
        Invoke-PodeBuildInstall 'checksum' $Versions.Checksum
    }

    if (!(Test-PodeBuildCommand '7z')) {
        Invoke-PodeBuildInstall '7zip' $Versions.SevenZip
    }
}

# Synopsis: Install dependencies for compiling/building
task BuildDeps {
    # install dotnet
    if (!(Test-PodeBuildCommand 'dotnet')) {
        Invoke-PodeBuildInstall 'dotnetcore' $Versions.DotNetCore
    }
}

# Synopsis: Install dependencies for running tests
task TestDeps {
    # install pester
    Install-PodeBuildModule Pester

    # install PSCoveralls
    if (Test-PodeBuildCanCodeCoverage) {
        Install-PodeBuildModule PSCoveralls
    }
}

# Synopsis: Install dependencies for documentation
task DocsDeps ChocoDeps, {
    # install mkdocs
    if (!(Test-PodeBuildCommand 'mkdocs')) {
        Invoke-PodeBuildInstall 'mkdocs' $Versions.MkDocs
    }

    $_installed = (pip list --format json --disable-pip-version-check | ConvertFrom-Json)
    if (($_installed | Where-Object { $_.name -ieq 'mkdocs-material' -and $_.version -ieq $Versions.MkDocsTheme } | Measure-Object).Count -eq 0) {
        pip install "mkdocs-material==$($Versions.MkDocsTheme)" --force-reinstall --disable-pip-version-check
    }

    # install platyps
    Install-PodeBuildModule PlatyPS
}


<#
# Building
#>

# Synopsis: Build the .NET Core Listener
task Build BuildDeps, {
    if (Test-Path ./src/Libs) {
        Remove-Item -Path ./src/Libs -Recurse -Force | Out-Null
    }

    Push-Location ./src/Listener

    try {
        dotnet build --configuration Release
        dotnet publish --configuration Release --self-contained --output ../Libs
    }
    finally {
        Pop-Location
    }
}


<#
# Packaging
#>

# Synopsis: Creates a Zip of the Module
task 7Zip -If (Test-PodeBuildIsWindows) PackDeps, StampVersion, {
    exec { & 7z -tzip a $Version-Binaries.zip ./pkg/* }
}, PrintChecksum

# Synopsis: Creates a Chocolately package of the Module
task ChocoPack -If (Test-PodeBuildIsWindows) PackDeps, StampVersion, {
    exec { choco pack ./packers/choco/pode.nuspec }
}

# Synopsis: Package up the Module
task Pack -If (Test-PodeBuildIsWindows) Build, {
    $path = './pkg'
    if (Test-Path $path) {
        Remove-Item -Path $path -Recurse -Force | Out-Null
    }

    # create the pkg dir
    New-Item -Path $path -ItemType Directory -Force | Out-Null

    # which folders do we need?
    $folders = @('Private', 'Public', 'Misc', 'Libs')

    # create the directories, then copy the source
    $folders | ForEach-Object {
        New-Item -ItemType Directory -Path (Join-Path $path $_) -Force | Out-Null
        Copy-Item -Path "./src/$($_)/*" -Destination (Join-Path $path $_) -Force | Out-Null
    }

    # copy general files
    Copy-Item -Path ./src/Pode.psm1 -Destination $path -Force | Out-Null
    Copy-Item -Path ./src/Pode.psd1 -Destination $path -Force | Out-Null
    Copy-Item -Path ./LICENSE.txt -Destination $path -Force | Out-Null
}, 7Zip, ChocoPack


<#
# Testing
#>

# Synopsis: Run the tests
task Test Build, TestDeps, {
    $p = (Get-Command Invoke-Pester)
    if ($null -eq $p -or $p.Version -ine $Versions.Pester) {
        Import-Module Pester -Force -RequiredVersion $Versions.Pester
    }

    $Script:TestResultFile = "$($pwd)/TestResults.xml"

    # if run code coverage if enabled
    if (Test-PodeBuildCanCodeCoverage) {
        $srcFiles = (Get-ChildItem "$($pwd)/src/*.ps1" -Recurse -Force).FullName
        $Script:TestStatus = Invoke-Pester './tests/unit', './tests/integration' -OutputFormat NUnitXml -OutputFile $TestResultFile -CodeCoverage $srcFiles -PassThru
    }
    else {
        $Script:TestStatus = Invoke-Pester './tests/unit', './tests/integration' -OutputFormat NUnitXml -OutputFile $TestResultFile -Show Failed -PassThru
    }
}, PushCodeCoverage, CheckFailedTests

# Synopsis: Check if any of the tests failed
task CheckFailedTests {
    if ($TestStatus.FailedCount -gt 0) {
        throw "$($TestStatus.FailedCount) tests failed"
    }
}

# Synopsis: If AppyVeyor or GitHub, push code coverage stats
task PushCodeCoverage -If (Test-PodeBuildCanCodeCoverage) {
    try {
        $service = Get-PodeBuildService
        $branch = Get-PodeBuildBranch

        Write-Host "Pushing coverage for $($branch) from $($service)"
        $coverage = New-CoverallsReport -Coverage $Script:TestStatus.CodeCoverage -ServiceName $service -BranchName $branch
        Publish-CoverallsReport -Report $coverage -ApiToken $env:PODE_COVERALLS_TOKEN
    }
    catch {
        $_.Exception | Out-Default
    }
}


<#
# Docs
#>

# Synopsis: Run the documentation locally
task Docs DocsDeps, DocsHelpBuild, {
    mkdocs serve
}

# Synopsis: Build the function help documentation
task DocsHelpBuild DocsDeps, {
    # import the local module
    Remove-Module Pode -Force -ErrorAction Ignore | Out-Null
    Import-Module ./src/Pode.psm1 -Force | Out-Null

    # build the function docs
    $path = './docs/Functions'
    $map =@{}

    (Get-Module Pode).ExportedFunctions.Keys | ForEach-Object {
        $type = [System.IO.Path]::GetFileNameWithoutExtension((Split-Path -Leaf -Path (Get-Command $_ -Module Pode).ScriptBlock.File))
        New-MarkdownHelp -Command $_ -OutputFolder (Join-Path $path $type) -Force -Metadata @{ PodeType = $type } -AlphabeticParamsOrder | Out-Null
        $map[$_] = $type
    }

    # update docs to bind links to unlinked functions
    $path = Join-Path $pwd 'docs'
    Get-ChildItem -Path $path -Recurse -Filter '*.md' | ForEach-Object {
        $depth = ($_.FullName.Replace($path, [string]::Empty).trim('\/') -split '[\\/]').Length
        $updated = $false

        $content = (Get-Content -Path $_.FullName | ForEach-Object {
            $line = $_

            while ($line -imatch '\[`(?<name>[a-z]+\-pode[a-z]+)`\](?<char>[^(])') {
                $updated = $true
                $name = $Matches['name']
                $char = $Matches['char']
                $line = ($line -ireplace "\[``$($name)``\][^(]", "[``$($name)``]($('../' * $depth)Functions/$($map[$name])/$($name))$($char)")
            }

            $line
        })

        if ($updated) {
            $content | Out-File -FilePath $_.FullName -Force -Encoding ascii
        }
    }

    # remove the module
    Remove-Module Pode -Force -ErrorAction Ignore | Out-Null
}

# Synopsis: Build the documentation
task DocsBuild DocsDeps, DocsHelpBuild, {
    mkdocs build
}