Git-TF Source Code Migration Script
===========================

#### As always, run this script at your own risk.

PowerShell script to migrate source code across TFS collections. This can serve as an alternative to the [TFS Integration Tool](http://tfsintegration.codeplex.com) which relies on SQL Server database and some complex configuration.

Open PowerShell and navigate to the directory where you've downloaded the PS1 file to execute. Try running the script without any parameters to get some information on the script.


You'll notice that you need to supply at least 4 parameters:

- sourceTFS
  - FQDN of the TFS Server and collection hosting the source code you're looking to migrate
  - ex. http://tfs.yourhost.net:8080/tfs/DefaultCollection
- destinationTFS
  - FQDN of the TFS Server and collection which will host the source code
  - ex. http://tfs.anotherhost.net:8080/tfs/SecondCollection
- sourceFolder
  - TFS path to source code you're looking to migrate
  - ex. $/Old Team Project/Main
- destinationFolder
  - TFS path which your source code will soon live in
  - ex. $/Team Project/Main

Optionally, you can specify where the script will work in (does not automatically delete this folder):

- workingDir
  - Where two copies of your source code will be pulled
  - default value: "C:\temp\TFSMigrator"

## Tools Used

Running the migration requires the use of two tools: [Git](http://git-scm.org) and [Git-TF](http://gittf.codeplex.com). Git is another source code management system, which Team Foundation Server now supports (2012+) as an alternate version control system to TFVC (Team Foundation Version Control). Git-TF is a product released by Microsoft which is cross-platform and meant to facilitate changes between Team Foundation Server, Visual Studio Online, and Git.

## Running the script

You may need to properly set [ExecutionPolicy in PowerShell](http://technet.microsoft.com/en-us/library/ee176961.aspx) with ```Set-ExecutionPolicy RemoteSigned``` while running PowerShell as an Administrator.

The script will first download Git installation if "\git\" is not found within system environment variable ```%PATH%```.

Then, the script will download a Git-TF release and extract it into ```C:\git-tf\<version>\```. If this folder doesn't already exist from a previous run, it will create it. If there are multiple folders in this location, the script will fail. This is something that can be improved someday.

From this point on, the application should run as intended without user interaction.

Sample execution:

    PS C:\temp>.\GitTFMigrator.ps1 -sourceTFS 'http://server1:8080/tfs/Development' -destinationTFS 'http://server2:8080/tfs/Development' -sourceFolder '$/FabrikamFiber/Main' -destinationFolder '$/FabrikamFiber/Main'


## Troubleshooting

The script, when committing to Git, uses the ```--keep-author``` flag. This works fantastic if the executing user has "Check-in other users' changes" permission on destination TFS location. However, if a Windows account that was used for a check-in no longer is valid in destination system, the script will exit asking you to check the user map file ```C:\temp\TFSMigrator\newserver\USERMAP``` and repeat. Open this file and you'll see output like:


```
# The file provides mapping between Git users and known TFS user
# unique names. The Git user has to be represented as it appears
# in Git commits, including the user name and e-mail address.
# The TFS user has to be represented either as DOMAIN\account
# (for on-premises TFS) or as Windows Live ID (for hosted TFS).

# The section contains mapping between Git users and TFS users.
# Add new mappings to this section as needed. Only this section
# is parsed when the file is used in a check-in command.

[mapping]
    Barry, Mitch <DOMAIN\MITCH> = DOMAIN\MITCH
    Schmoe, Joe <DOMAIN\JOE> = DOMAIN\JOE

# The section contains Git user names found in commits that cannot
# be mapped to TFS users automatically. You should provide mapping
# for these names or remove the --keep-author option from the
# check-in command. This section is not parsed when the file is
# used in a check-in command, you have to move resolved mapping
# to the [mapping] section

[unknown]
    CARL <DOMAIN\CARL> =
```

You'll notice at the bottom, there is an ```[unknown]``` section. Copy the userID line up to where the rest of the ```[mapping]``` elements are and delete the ```[unknown]``` tag. On the right hand side of the =, you'll need to add a valid user in the destination TFS instance. You will want to save the USERMAP file when it looks like below:
```
[mapping]
    Barry, Mitch <DOMAIN\MITCH> = DOMAIN\MITCH
    Schmoe, Joe <DOMAIN\JOE> = DOMAIN\JOE
    CARL <DOMAIN\CARL> = DOMAIN\TFSService
```
You'll notice I chose a service account for the checkin of the user which no longer exists. I figure this was a better representation of the check-in than assing a different human to it.

Now, instead of re-running the script (it would reset the USERMAP file ... then we're back to square-one), manually run this command in PowerShell window:

    PS C:\temp\TFSMigrator\newserver>C:\git-tf\git-tf-2.0.3.2013.1219\git-tf.cmd checkin --deep --autosquash --keep-author

If that doesn't work for you, modify the PS1 script and remove the ```--keep-author``` flag. However, if all goes well, you should have a successful migration! Congrats!

## Caveats

- Unfortunately, you will need to create the Team Projects before attempting to migrate with this script. No new Team Projects can be created through this tool.
- Branch relationships will be lost, and only baseless merges will be possible. The code and each branch will still exist, but the relationship back to your Main will be lost.
