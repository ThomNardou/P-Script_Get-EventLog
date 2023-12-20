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
	Va chercher les journaux d'évenement de tout les PC d'un parc informatique et va écrire les évenments dans un fichier log
 	
.DESCRIPTION
    Va cherche l'event log de tous les pc d'un parc informatique avec une liste donnée
  	
.PARAMETER ComputerPath
    chemin d'accès vers la liste contenant les noms des pc, les users de chaque ordinateur correspondant et leurs mot de passe

.OUTPUTS
	Va créer un fichier log dans un dossier logs qui se trouve au même endroit que le script
	
.EXAMPLE
	.\Get-Eventlogs.ps1 -ComputerPath "C:\Users\User\Documents\list.txt" 
	Result : 

        imeGenerated        MachineName Source                              Message                                                                                                                                         
        -------------       ----------- ------                              -------                                                                                                                                         
        13.12.2023 14:11:50 PC3         Microsoft-Windows-Security-Auditing Fermeture de session d’un compte....  
        
	
.EXAMPLE
	.\Get-Eventlogs.ps1 -ComputerPath 
	Result : Affiche l'aide du script
	
.LINK
    -
#>


param(
    [string]$ComputerPath
)

###################################################################################################################

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



        if (-not (Test-Path "./Logs")) {
            New-Item -ItemType Directory -Force -Name "Logs"
        }

        if (!(Test-Path "./Logs/Error")) {
            Write-Host "test"
            New-Item -ItemType Directory -Force -Name "Error" -Path "./Logs"
        }

        $fileContent = Import-CSV -Path $ComputerPath -Delimiter ";"

        foreach ($computer in $fileContent) {

            $date = Get-Date -Format "yyyy-MM-dd-hh-mm"
            $errorPath = "./Logs/Error/$($date)_$($computer.MachineName)`_error.log"
            $logPath = "./Logs/$($date)_$($computer.MachineName)_logs.log"

            $password = ConvertTo-SecureString $computer.Password -AsPlainText -Force

            $cred = New-Object System.Management.Automation.PSCredential ($computer.User, $password)

            try {

                $session = New-PSSession $computer.MachineName -Credential $cred -ErrorAction Stop

                if ($session) {


                    $eventLog = Invoke-Command -Session $session -ScriptBlock {
                        param($events)

                        if ([System.Diagnostics.EventLog]::SourceExists($events) -eq $false) {
                            return $false
                        }
                        else {
                            Get-EventLog $events | Select-Object -Property TimeGenerated, MachineName, Source, Message | Format-Table -AutoSize
                        }

                    } -ArgumentList $eventList[$chosenEvent]


                    if($eventLog -eq $false) {
                        Write-Output "Le Pc avec le nom $($computer.MachineName) ne possède pas de journaux windows possèdant le nom $($eventList[$chosenEvent])" >> $errorPath
                    }
                    else {
                        Write-Output $eventLog >> $logPath
                    }
                }
            } 
    
            catch {
                Write-Output "Une erreur s'est produit lors de la connection au $($computer.MachineName)" >> $errorPath
            }
        }
    }

}