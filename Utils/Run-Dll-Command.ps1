
Function Run-Dll-Command {
    <#
    .SYNOPSIS
    This function runs a command from a specified DLL file.

    .DESCRIPTION
    The function uses rundll32.exe to execute a command from a DLL file. 
    It requires the DLL name, command name, file name, and verb as parameters.

    .PARAMETER Dll
    The name of the DLL file containing the command to be executed.

    .PARAMETER Command
    The name of the command to be executed from the DLL.

    .PARAMETER File
    The file name to be passed to the command.

    .PARAMETER Verb
    The verb to be passed to the command.

    .EXAMPLE
    Run-Dll-Command -Dll "example.dll" -Command "ExampleCommand" -File "example.txt" -Verb "open"
    #>
Parameter(
    [string]$Dll(Mandatory=$true),
    [string]$Command(Mandatory=$true),
    [string]$File(Mandatory=$true),
    [string]$Verb(Mandatory=$true)
)    
    # rundll32.exe shell32.dll,$File $Verb 
    
    rundll32.exe $Dll,$Command $File $Verb
    # Example usage:    
}
    