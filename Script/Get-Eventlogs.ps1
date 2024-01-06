<#
.NOTES
    *****************************************************************************
    ETML
    Script's name:	Get-EventLogs.ps1
    Author:	Ethan Schafstall, Thomas Nardou
    Date:	29.11.2023
 	*****************************************************************************
    Modifications
 	Date  : -
 	Author: -
 	Reasons: -
 	*****************************************************************************
.SYNOPSIS
	Va chercher les journaux d'�venement d'un type choisi de tout les PC d'un parc informatique et va �crire les �venments dans un fichier log
 	
.DESCRIPTION
    Va cherche l'event log du type choisi de tous les pc d'un parc informatique avec une liste donn�e contenant : le nom de chaque PC, les noms des utilisateur et leur mot de passe.
    un fichier .log sera cr�er pour chaque PC et leur contenu sera les �venement des PC 
  	
.PARAMETER ComputerPath
    chemin d'acc�s vers la liste contenant les noms des pc, les users de chaque ordinateur correspondant et leurs mot de passe

.OUTPUTS
	Va cr�er un fichier log dans un dossier logs qui se trouve au m�me endroit que le script
	
.EXAMPLE
	.\Get-Eventlogs.ps1 -ComputerPath "C:\Users\User\Documents\list.txt" 
	Result : 

        imeGenerated        MachineName Source                              Message                                                                                                                                         
        -------------       ----------- ------                              -------                                                                                                                                         
        13.12.2023 14:11:50 PC3         Microsoft-Windows-Security-Auditing Fermeture de session d�un compte....  
        
	
.EXAMPLE
	.\Get-Eventlogs.ps1
	Result : Affiche l'aide du script
	
.LINK
    -
#>


param(
    [string]$ComputerPath
)

###################################################################################################################

$logPathStart = "./Logs"
$dirErrorName = "$($dirErrorName)"
$dirLogName = "Logs"

function TestAdmin {
    $identity  = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object System.Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}

###################################################################################################################
# Area for the tests, for example admin rights, existing path or the presence of parameters

cls

# Display help if at least on parameter is missing
if([String]::IsNullOrEmpty($ComputerPath))
{
    Get-Help $MyInvocation.Mycommand.Path
}

###################################################################################################################
# Body's script
else
{
    # check if the user is admin
    if (!(TestAdmin)) {
        throw [System.UnauthorizedAccessException]::new("User is not an Admin");
    }

    else {
        # Checks if the path the user passed as parameter is valid
        if(!(Test-Path -Path $ComputerPath))
        {
            throw [System.ArgumentException]::new("The path was invalid");
        }

        [string[]]$eventList = (Get-EventLog -List).Log;

        $continue = $false;

        # Waits for user input, checks if it's a valid option
        do
        {
            Write-Host("`nChoose your desired eventlog: `n");
    
            for($i = 0; $i -lt $eventList.Length; $i++)
            {
                Write-Host "Press $i for" $eventList[$i];
            }

            $chosenEvent = Read-Host;

            if($chosenEvent -isnot [int] -and $chosenEvent -gt $eventList.Length-1)
            {
              Write "Not a valid choice"
            }
            else
            {
                $continue = $true;
            }
        }
        while(-not $continue)


        # Displays which option the user chose
        write-host "`nYou choose the" $eventList[$chosenEvent] "eventlog`n"


        #---------------------------------------------------------- Get-Event log part ----------------------------------------------------------#

        # check if log directory exists
        if (-not (Test-Path $logPathStart)) {
            # Create direactory 
            New-Item -ItemType Directory -Force -Name $dirLogName
        }

        # check if error direactory exist
        if (!(Test-Path "$($logPathStart)/$($dirErrorName)")) {
            # Create direactory 
            New-Item -ItemType Directory -Force -Name $dirErrorName -Path $logPathStart
        }

        # Take the content of the list
        $fileContent = Import-CSV -Path $ComputerPath -Delimiter ";"

        foreach ($computer in $fileContent) {
        
            $date = Get-Date -Format "yyyy-MM-dd-hh-mm"
            $errorPath = "$($logPathStart)/$($dirErrorName)/$($date)_$($computer.MachineName)`_error.txt"
            $logPath = "$($logPathStart)/$($date)_$($computer.MachineName)_logs.txt"

            # Converts plain text or encrypted strings to secure strings.
            $password = ConvertTo-SecureString $computer.Password -AsPlainText -Force
            # Information to connect on the remote machine
            $cred = New-Object System.Management.Automation.PSCredential ($computer.User, $password)


            # Try to connect to the machine
            try {
                
                # Open the connection 
                $session = New-PSSession $computer.MachineName -Credential $cred -ErrorAction Stop

                if ($session) {

                    # Execute the event log command into the remote machine 
                    $eventLog = Invoke-Command -Session $session -ScriptBlock {
                        param($Events)

                        # if the event log doean't exist 
                        if ([System.Diagnostics.EventLog]::SourceExists($Event) -eq $false) {
                            return $false
                        }
                        else {
                            Get-EventLog $Event | Select-Object -Property TimeGenerated, MachineName, Source, Message | Format-Table -AutoSize
                        }

                    } -ArgumentList $eventList[$chosenEvent]

                    # write error into a log file 
                    if($eventLog -eq $false) {
                        Write-Output "Le Pc avec le nom $($computer.MachineName) ne possède pas de journaux windows poss�dant le nom $($eventList[$chosenEvent])" >> $errorPath
                    }
                    # write event log into a log file 
                    else {
                        Write-Output $eventLog >> $logPath
                    }
                }
            } 
            # if the connection could not be made
            catch {
                # write error into a log file 
                Write-Output "Une erreur s'est produit lors de la connection au $($computer.MachineName)" >> $errorPath
            }
        }
    }

}