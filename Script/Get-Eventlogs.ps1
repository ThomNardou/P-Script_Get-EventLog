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
	Light information about the script, could be the title
 	
.DESCRIPTION
    Explanations about the script with details, what it does, what kind of tests and some possible results
  	
.PARAMETER ComputerPath
    A path string to the .txt file containing each machine to be contacted.

.OUTPUTS
	What the script do, like output files or system modifications
	
.EXAMPLE
	.\Get-Eventlogs.ps1 -Param1 "C:\Users\user\Documents\machineList.txt" -Param2 Titi -Param3 Tutu
	What you write to run the script with the parameters
	Result : for example a file, a modification, a error message
	
.EXAMPLE
	.\CanevasV3.ps1
	Result : Display help when no parameter are present
	
.LINK
    When other scripts are used in this script
#>


param(
[Parameter(Mandatory=$true)]
    [string]$ComputerPath
)

###################################################################################################################

function TestAdmin {
    $identity  = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object System.Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}

$fileContent = Get-Content -Path $ComputerPath

Set-Variable ERROR_MESSAGE -Option Constant -Value "Une erreur s'est produit lors de la connection au"


###################################################################################################################
# Area for the tests, for example admin rights, existing path or the presence of parameters

# Display help if at least on parameter is missing
if(!$ComputerPath)
{
    throw [System.ArgumentException]::new("The path was invalid");
}

###################################################################################################################
# Body's script
else
{
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

    # Tests if the user is an admin, saves into variable
    $isadmin = TestAdmin;

    if(!$isadmin)
    {
        throw [System.UnauthorizedAccessException]::new("User is not an Admin");
    }

    if (-not (Test-Path "./Logs")) {
        New-Item -ItemType Directory -Force -Name "Logs"
    }




    foreach ($computer in $fileContent) {
        $date = Get-Date -Format "yyyy-MM-dd-hh-mm"

        $password = ConvertTo-SecureString "ETML_2023" -AsPlainText -Force

        $cred = New-Object System.Management.Automation.PSCredential ("user", $password)

        try {
            $session = New-PSSession $computer -Credential $cred -ErrorAction Stop

            if ($session) {


                $eventLog = Invoke-Command -Session $session -ScriptBlock {
                    param($events)

                    if (!$events) {
                        Write-Output "Le Pc avec le nom $($computer) ne possède pas de journaux windows possèdant ce nom " >> "./Logs/$date`_error.log"
                    }
                    else {
                        Get-EventLog $events | Select-Object -Property TimeGenerated, MachineName, Source, Message | Format-Table -AutoSize
                    }

                } -ArgumentList $eventList[$chosenEvent]


                if($eventLog.length -eq 0) {
                    Write-Output "Le Pc avec le nom $($computer) ne possède pas de journaux windows possèdant le nom $($eventList[$chosenEvent])" > "./Logs/$date`_$computer`_error.log"
                }
                else {
                    Write-Output $eventLog > "./Logs/$date`_$computer`_logs.log"
                }


                
            }
        } 
    
        catch {
            Write-Output "$($ERROR_MESSAGE) $($computer)" >> "./Logs/$date`_error.log"
        }
    }

}# endif

