<#
.NOTES
    *****************************************************************************
    ETML
    Script's name:	Get-EventLogs
    Author:	Ethan Schafstall, Thomas Nardou
    Date:	29.11.2023
 	*****************************************************************************
    Modifications
 	Date  : -
 	Author: -
 	Reasons: -
 	*****************************************************************************
.SYNOPSIS
	Va cherche l'event log de tous les pc d'un parc informatique avec une liste donnée
 	
.DESCRIPTION
    Va cherche l'event log de tous les pc d'un parc informatique avec une liste donnée
  	
.PARAMETER ComputerPath
    chemin d'accès vers la liste contenant les noms des pc

.OUTPUTS
	Va créer un fichier log dans un dossier log qui se trouve au même endroit que le script
	
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

<# The number of parameters must be the same as described in the header
   It's possible to have no parameter but arguments
   One parameter can be typed : [string]$ComputerPath
   One parameter can be required : [Parameter(Mandatory=$True][string]$ComputerPath
#>
# The parameters are defined right after the header and a comment must be added 

param (
    [Parameter(Mandatory=$true)]
    [string]$ComputerPath
)

###################################################################################################################
# Area for the variables and functions with examples
# Comments for variables
$fileContent = Get-Content -Path $ComputerPath

###################################################################################################################
# Area for the tests, for example admin rights, existing path or the presence of parameters

# Display help if at least on parameter is missing

if ($ComputerPath -eq "") {
    .\test_thomas.ps1 Get-Help 
}

###################################################################################################################
# Body's script

else {


    if (-not (Test-Path "./Logs")) {
        New-Item -ItemType Directory -Force -Name "Logs"
    }

    foreach ($computer in $fileContent) {

        $date = Get-Date -Format "yyyy-MM-dd-hh-mm"

        $password = ConvertTo-SecureString "ETML_2023" -AsPlainText -Force

        $cred = New-Object System.Management.Automation.PSCredential ("user", $password)
        try {
            $session = New-PSSession $computer -Credential $cred -ErrorAction Stop
        } 
    
        catch {
            Write-Error("Une erreur s'est produit lors de la connection au $($computer): $($_)")
        }

        if ($session) {

            $eventLog = Invoke-Command -Session $session -ScriptBlock {
    
                Get-EventLog security | Select-Object -Property TimeGenerated, MachineName, Source, Message | Format-Table -AutoSize

            }

            Write-Output $eventLog > "./Logs/$date`_$computer.txt"
        }

    
    }
}
