Param(
	[string]$sourceTFS,
	[string]$destinationTFS,
	[string]$sourceFolder,
	[string]$destinationFolder,
	[string]$workingDir='C:\temp\TFSMigrator'
);

# START non-configurable variables at runtime
$global:gittfURL = 'http://download.microsoft.com/download/A/E/2/AE23B059-5727-445B-91CC-15B7A078A7F4/git-tf-2.0.3.20131219.zip';
$global:gitURL = 'https://msysgit.googlecode.com/files/Git-1.8.5.2-preview20131230.exe';
$global:gittfArchive = 'git-tf.zip';
$global:gitInstaller = 'git-installer.exe';
$global:gittfBasePath = 'C:\git-tf';
$global:tempPath = 'C:\temp';
$global:gittf = '';
$global:initialFolder = pwd;
# END non-configurable variables at runtime

function WriteHeader
{
	Write-Host ''
	Write-Host '   TFS Source Code Migration Tool - git-tf'
	Write-Host '   Mitchell Barry, 02/03/2014'
	Write-Host ''
}

function PrintHelp
{
	Write-Host ''
	Write-Host 'Expects 4 parameters, 1 optional'
	Write-Host "    -sourceTFS         'http://tfs.yourhost.net:8080/tfs/DefaultCollection'"
	Write-Host "    -destinationTFS    'http://tfs.yourhost.net:8080/tfs/SecondCollection'"
	Write-host "    -sourceFolder      '$/TeamProject/Path'"
	Write-host "    -destinationFolder '$/TeamProject/Path'"
	Write-host "    [-workingDir]      'C:\temp\TFSMigrator'"
	Write-Host ''
	Write-Host ''
	Write-Host ' * The script will automatically download and help you install Git and Git-TF'
	Write-Host ' * It is your responsibility to ensure a proper Team Project is specified in source and destination'
	Write-Host ' * This script will not create new Team Projects'
	Write-Host ' * User running script requires "Check-in other users changes" permission on destination TFS'
    Write-Host ' * Supports TFS 2010+'
	Write-Host ''
	Write-Host ''
    Write-Host 'Press any key to continue ...'
    $in = $host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
}

function ValidateInput
{
	if (([bool]$sourceTFS) -and ([bool]$destinationTFS) -and ([bool]$sourceFolder) -and ([bool]$destinationFolder) -and ([bool]$workingDir))
	{
		return $true;
	}
	else
	{
		return $false;
	}
}

function Download-Web-File ([string] $urlPath, [string] $filePath) 
{
	(New-Object Net.WebClient).DownloadFile($urlPath, $filePath);
}

function Extract-Zip ([string] $zipfilename, [string] $destination) 
{
    if(Test-Path($zipfilename)) 
    { 
        $shellApplication = new-object -com shell.application 
        $zipPackage = $shellApplication.NameSpace($zipfilename) 
        $destinationFolder = $shellApplication.NameSpace($destination) 
        $destinationFolder.CopyHere($zipPackage.Items()) 
    }
    else 
    {   
        Write-Host $zipfilename "not found"
    }
} 

function InstallGit
{
	Write-Host 'Downloading Git from msysgit.googlecode.com ...';
	Download-Web-File $gitURL (Join-Path $tempPath $gitInstaller);
	Write-Host 'Please complete local Git installation before continuing.'
	Start-Process -wait (Join-Path $tempPath $gitInstaller);
}

function PrepareGitTF
{
	if ((Test-Path $gittfBasePath) -eq 0)
	{
		mkdir $gittfBasePath 2>&1 | Out-Null;
		Write-Host 'Downloading Git-TF from microsoft.com ...';
		Download-Web-File $gittfURL (Join-Path $tempPath $gittfArchive);
		Write-Host 'Extracting...'
		Extract-Zip (Join-Path $tempPath $gittfArchive) $gittfBasePath;
		Write-Host ''
	}
	$gittfDir = (Get-ChildItem $gittfBasePath | Where {$_.PSisContainer}).FullName; #expects single folder
	$global:gittf = (Join-Path $gittfDir 'git-tf.cmd'); 
}

function CloneToRepository
{
	if ((Test-Path $workingDir) -eq 1)
	{
		Remove-Item -Recurse -Force $workingDir;
	}
	mkdir $workingDir 2>&1 | Out-Null;
	cd $workingDir;
	$args = 'clone', $sourceTFS, $sourceFolder, 'oldserver', '--deep';
	&$gittf $args;
}

function CheckInToDestination
{
	# intialize new git repository for destination
	$args = 'init', 'newserver';
	git $args;
	
	cd 'newserver';

	# pull all changes from source location
	$args = 'pull', '..\oldserver', '--depth', '100000000';
	git $args;

	# configure new repository for destination folder & TFS connection
	$args = 'configure', $destinationTFS, $destinationFolder;
	&$gittf $args;

	# commit your changes by performing checkin
	$args = 'checkin', '--deep', '--autosquash', '--keep-author';
	&$gittf $args; # user must be project administrator with "Check-in other users' changes" permission for --keep-author
}

function ResetWorkspace
{
	cd $initialFolder;
}

function Run
{
	Clear-Host;
	WriteHeader;
	if (ValidateInput)
	{
		# if user does not have Git installed, we will need it
		if (-not ($env:Path.ToLower().Contains('\git\'))) # funky, but eh ...
		{
			InstallGit;	
		}
		PrepareGitTF;
		CloneToRepository;
		CheckInToDestination;
	}
	else
	{
		PrintHelp;
	}
	ResetWorkspace;
}

Run;