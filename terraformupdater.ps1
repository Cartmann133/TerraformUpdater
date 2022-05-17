# Terraform Repository
$repo = "hashicorp/terraform"
# Terraform releases API, to get the latest full releases on the main branch
$releases = "https://api.github.com/repos/$repo/releases"
# Root terraform folder
$root = "C:\Program Files\terraform\"

# get current version. Version full output is 'Terraform <version> on <os>'
# checks if an executable exists first!
Set-Location -Path $root
if((Get-ChildItem -Attributes a -Filter *.exe -Name) -contains "terraform.exe")
{
    $currentversion = (.\terraform.exe version).Split(" ")[1]
    Write-Host Current version: $currentversion
}
else { Write-Host No existing Terraform executable in root folder }

Write-Host Determining latest release
for ($i = 0; $i -lt 10; $i++) # Get 10 latest releases, limited due to API request hourly limit of 60
{
    # Gets a powershell object, we can use this to get any key data
    $release = (Invoke-WebRequest $releases | ConvertFrom-Json)[$i]

    # Get version
    $latestrelease = $release.tag_name

    # Outputs index and version
    Write-Host i = $i tag = $latestrelease

    # Check if:
    # draft is false, prerelease is false, and branch is main
    # the first 2 seem to be the main identifiers of full releases
    # 3rd is just an extra sense check
    if($release.draft -eq $false -and $release.prerelease -eq $false -and $release.target_commitish -eq "main") 
    {
        Write-Host i = $i tag = $latestrelease is the latest full release
        break
    }
}

# Output version once again, this is the version that will be downloaded
Write-Host $latestrelease is the latest full release

if($latestrelease -eq $currentversion)
{ 
    Write-Host The latest full release matches the current version already installed. Exiting.
    Exit 
}

else {
    # check if a terraform exectuable is already in folder
    if((Get-ChildItem -Attributes a -Filter *.exe -Name) -contains "terraform.exe")
    {
        # Check if backup folder exists and creates it if not
        Write-Host Checking if backup folder exists
        if(!(Test-Path $root\Backup\terraform-$currentversion))
        {
            Write-Host Creating backup folder for version $currentversion
            New-Item -Path $root\Backup\terraform-$currentversion -ItemType Directory -Force | Out-Null
        }
        # create backup folder and move exe there, if an executable exists
        Write-Host Moving old exe into backup folder
        Move-Item "terraform.exe" -Destination $root\Backup\terraform-$currentversion -Force
    }


    # This will be the download link for the source
    # alternatives would be:
    # append .zip to the version we've found
    # $file = $tag + ".zip"
    # $download = "https://github.com/$repo/archive/refs/tags/$file"
    # or $release.tarball_url
    $download = $release.zipball_url # download link
    $name = "terraform" # First part of downloaded zip
    $zip = "$name-$latestrelease.zip" # Full zip name to be
    $dir = "$root\Backup\$name-$latestrelease" # used in tidyup

    Write-Host Dowloading latest release
    Invoke-WebRequest $download -Out $zip # downloads zipball and saves with friendly name

    Write-Host Extracting release files # extracts 
    Expand-Archive $zip -DestinationPath $dir -Force

    Write-Host Moving zip # moves downloaded .zip into its own folder
    Move-Item $zip -Destination "$root\Backup\$name-$latestrelease\$name-$latestrelease.zip" -Force

    # changes directory to extracted folder, so we can compile
    Set-Location -Path "$root\Backup\$name-$latestrelease"
    $extractedfolder = "$root\Backup\$name-$latestrelease\" + (Get-ChildItem -Attributes D -Name)
    Set-Location -Path $extractedfolder

    # build the executable
    Write-Host Building executable, may take some time...
    go build
    Write-Host Executable compiled
    # get the file for moving
    $executablefile = Get-ChildItem -Attributes a -Filter *.exe -Name
    # copy the exe to its folder
    Write-Host Copying executable to root folder
    Copy-Item $executablefile -Destination "$root\$executablefile" -Force

    # back to root folder
    Set-Location -Path $root
    Write-Host Terraform $latestrelease installed:
    .\terraform.exe validate # check the exe is valid
    .\terraform.exe version # check the version
}