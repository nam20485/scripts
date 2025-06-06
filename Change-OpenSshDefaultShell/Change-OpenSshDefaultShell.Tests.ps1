# Pester Test Script for OpenSshDefaultShellUtils.psm1 and Set-OpenSSH-Default-Shell.ps1

# Requires -Modules Pester

Describe "OpenSshDefaultShellUtils.psm1 Functionality" {
    $ModulePath = Join-Path $PSScriptRoot "OpenSshDefaultShellUtils.psm1"

    # Ensure the module is loaded for InModuleScope tests
    BeforeAll {
        Import-Module $ModulePath -Force
    }

    Context "Get-AvailableShellPaths" {
        It "should find shells from PATH and common directories" {
            Mock Get-Command -ModuleName OpenSshDefaultShellUtils {
                param($Name)
                switch ($Name) {
                    "powershell.exe" { return [pscustomobject]@{ Source = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" } }
                    "pwsh.exe"       { return [pscustomobject]@{ Source = "C:\Program Files\PowerShell\7\pwsh.exe" } }
                    default          { return $null }
                }
            }

            Mock Test-Path -ModuleName OpenSshDefaultShellUtils -MockWith {
                param($Path, $PathType)
                if ($Path -eq "$env:SystemRoot\System32\cmd.exe" -and $PathType -eq "Leaf") { return $true }
                if ($Path -eq "$env:ProgramFiles\Git\bin\bash.exe" -and $PathType -eq "Leaf") { return $true }
                return $false
            }

            InModuleScope OpenSshDefaultShellUtils {
                $found = Get-AvailableShellPaths
                $found | Should -HaveCount 4 # powershell.exe, pwsh.exe, cmd.exe, bash.exe
                $found | Should -Contain "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
                $found | Should -Contain "C:\Program Files\PowerShell\7\pwsh.exe"
                $found | Should -Contain "$env:SystemRoot\System32\cmd.exe"
                $found | Should -Contain "$env:ProgramFiles\Git\bin\bash.exe"
            }
        }
    }

    Context "Get-WindowsTerminalProfileShellPaths" {
        $mockSettingsJsonContent = @"
{
    "profiles": {
        "list": [
            { "name": "PowerShell", "commandline": "C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" },
            { "name": "PowerShell Core", "commandline": "\"C:\\Program Files\\PowerShell\\7\\pwsh.exe\" -NoLogo" },
            { "name": "WSL", "commandline": "wsl.exe -d Ubuntu" },
            { "name": "Invalid Path", "commandline": "C:\\NonExistent\\shell.exe" }
        ]
    }
}
"@
        BeforeEach {
            Mock Test-Path -ModuleName OpenSshDefaultShellUtils -MockWith {
                param($PathValue, $PathType)
                if ($PSBoundParameters.ContainsKey('PathType') -and $PathType -eq 'Leaf') {
                    # For executable Test-Path checks
                    if ($PathValue -eq "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe") { return $true }
                    if ($PathValue -eq "C:\Program Files\PowerShell\7\pwsh.exe") { return $true }
                    $wslFullPath = (Get-Command wsl.exe -ErrorAction SilentlyContinue)?.Source
                    if ($wslFullPath -and $PathValue -eq $wslFullPath) { return $true }
                    return $false
                } else {
                    # For settings.json Test-Path check
                    if ($PathValue -like "*Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json") { return $true }
                    return $false
                }
            }
            Mock Get-Content -ModuleName OpenSshDefaultShellUtils { return $using:mockSettingsJsonContent }
            Mock ConvertFrom-Json -ModuleName OpenSshDefaultShellUtils { return $using:mockSettingsJsonContent | ConvertFrom-Json }
            Mock Resolve-Path -ModuleName OpenSshDefaultShellUtils {
                param($PathValue)
                if ($PathValue -eq "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe") { return [pscustomobject]@{ Path = $PathValue } }
                if ($PathValue -eq "C:\Program Files\PowerShell\7\pwsh.exe") { return [pscustomobject]@{ Path = $PathValue } }
                $wslExePath = (Get-Command wsl.exe -ErrorAction SilentlyContinue)?.Source
                if ($wslExePath -and $PathValue -eq 'wsl.exe') { return [pscustomobject]@{ Path = $wslExePath } }
                if ($PathValue -eq "C:\NonExistent\shell.exe") { throw "Mock Resolve-Path: Path not found for $PathValue" } # Will be caught
                return [pscustomobject]@{ Path = $PathValue } # Default pass-through for others if any
            }
            Mock Write-Host -ModuleName OpenSshDefaultShellUtils {} # Suppress error messages from function
        }

        It "should extract valid shell paths from Windows Terminal settings" {
            InModuleScope OpenSshDefaultShellUtils {
                $wtShells = Get-WindowsTerminalProfileShellPaths
                $expectedCount = 2
                $wslFullPath = (Get-Command wsl.exe -ErrorAction SilentlyContinue)?.Source
                if ($wslFullPath) { $expectedCount++ }

                $wtShells | Should -HaveCount $expectedCount
                $wtShells | Should -Contain "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
                $wtShells | Should -Contain "C:\Program Files\PowerShell\7\pwsh.exe"
                if ($wslFullPath) { $wtShells | Should -Contain $wslFullPath }
                $wtShells | Should -NotContain "C:\NonExistent\shell.exe"
            }
        }
    }

    Context "Get-AllShellPaths" {
        It "should combine and deduplicate shells from both sources" {
            # Note: The original Get-AllShellPaths in OpenSshDefaultShellUtils.psm1 has its own
            # canonicalization logic. For this unit test, we are testing the combination and
            # deduplication aspect assuming the underlying functions return somewhat clean paths.
            # The canonicalization in Get-AllShellPaths itself might be redundant if
            # Get-AvailableShellPaths and Get-WindowsTerminalProfileShellPaths already do a good job.
            # The provided Get-AllShellPaths from context does its own loop.
            # Let's mock the inputs to Get-AllShellPaths to test its specific logic.

            Mock Get-AvailableShellPaths -ModuleName OpenSshDefaultShellUtils {
                return @(
                    "C:\path\shell1.exe",
                    "C:\path\shell2.exe",
                    "C:\PATH\SHELL2.EXE" # Deliberate case difference for Sort-Object -Unique test
                )
            }
            Mock Get-WindowsTerminalProfileShellPaths -ModuleName OpenSshDefaultShellUtils {
                return @(
                    "C:\path\shell2.exe",
                    "C:\path\shell3.exe",
                    "  C:\path\shell4.exe  " # Test trimming
                )
            }
            # Mock Resolve-Path as used by the Get-AllShellPaths in context
            Mock Resolve-Path -ModuleName OpenSshDefaultShellUtils {
                param($PathValue)
                # Simple mock: assume path is resolvable and return it as is for test purposes
                return [pscustomobject]@{ Path = $PathValue.Trim() }
            }


            InModuleScope OpenSshDefaultShellUtils {
                $allShells = Get-AllShellPaths
                # The provided Get-AllShellPaths does its own canonicalization loop.
                # It uses Resolve-Path and a regex match.
                # Given the mocks, we expect shell1, shell2 (deduplicated), shell3, shell4 (trimmed)
                $allShells | Should -HaveCount 4
                $allShells | Should -Contain "C:\path\shell1.exe"
                $allShells | Should -Contain "C:\path\shell2.exe" # Case might vary based on Sort-Object -Unique behavior
                $allShells | Should -Contain "C:\path\shell3.exe"
                $allShells | Should -Contain "C:\path\shell4.exe"

                # More specific check for deduplication of case-insensitive paths if Sort-Object -Unique is used
                # However, the provided Get-AllShellPaths uses its own loop with `-contains` which is case-insensitive by default.
                ($allShells | Where-Object { $_ -match "shell2.exe" }).Count | Should -Be 1
            }
        }
    }
}

Describe "Set-OpenSSH-Default-Shell.ps1 Functionality" {
    $ScriptPath = Join-Path $PSScriptRoot "Set-OpenSSH-Default-Shell.ps1"
    # $ModuleToImport = Join-Path $PSScriptRoot "OpenSshDefaultShellUtils.psm1" # Already imported in script

    BeforeEach {
        # Mock all external commands and script-terminating commands
        # Ensure mocks are fresh for each test in this Describe block
        Mock Get-ItemProperty { return $null } -Scope Describe
        Mock Set-ItemProperty { } -Scope Describe
        Mock Test-Path { return $true } -Scope Describe # Default to true
        Mock Out-File { } -Scope Describe
        Mock Write-Host { } -Scope Describe
        Mock Write-Error { } -Scope Describe # For the Import-Module catch block
        Mock Read-Host { } -Scope Describe
        Mock exit { param($exitCode) throw "SCRIPT_EXIT_$exitCode" } -Scope Describe

        # Mock the primary function imported from the module
        # This mock will be active for tests unless specifically removed or overridden
        Mock Get-AllShellPaths { return @("C:\shells\powershell.exe", "C:\shells\pwsh.exe", "C:\shells\bash.exe") } -Scope Describe
    }

    It "should import the OpenSshDefaultShellUtils module and make Get-AllShellPaths invokable" {
        # Temporarily remove the mock for Get-AllShellPaths to test the actual import
        Remove-Mock Get-AllShellPaths -ErrorAction SilentlyContinue

        # Dot-source the script to trigger its Import-Module
        # The try-catch in the script will handle if the module isn't found (but it should be)
        . $ScriptPath

        (Get-Command Get-AllShellPaths -ErrorAction SilentlyContinue) | Should -Not -BeNull
        (Get-Command Get-AllShellPaths).Module.Name | Should -Be "OpenSshDefaultShellUtils"

        # Restore mock for other tests if needed, or rely on Describe-level mock
        Mock Get-AllShellPaths { return @("C:\shells\powershell.exe", "C:\shells\pwsh.exe", "C:\shells\bash.exe") }
    }

    Context "Set-DefaultShell function (defined in Set-OpenSSH-Default-Shell.ps1)" {
        BeforeEach {
            # Dot-source the script to make its internally defined functions available for testing
            # This also re-runs the Import-Module, but mocks should prevent side effects
            . $ScriptPath
        }

        It "should set DefaultShell and backup existing value without actual registry/file changes" {
            $testShellPath = "C:\test\shell.exe"
            $existingShell = "C:\old\shell.exe"
            $registryPath = "HKLM:\SOFTWARE\OpenSSH"

            # Specific mock for Test-Path for this scenario
            Mock Test-Path -MockWith { param($Path) $Path -eq $registryPath } { return $true } -Scope It
            Mock Get-ItemProperty -MockWith {
                param($Path, $Name)
                if ($Path -eq $registryPath -and $Name -eq "DefaultShell") {
                    return [pscustomobject]@{ DefaultShell = $existingShell }
                }
                return $null
            } -Scope It

            Set-DefaultShell -ShellPath $testShellPath

            Get-MockCallHistory Set-ItemProperty | Should -HaveCount 2
            Get-MockCallHistory Set-ItemProperty | Where-Object { $_.Parameters.Name -eq "DefaultShellBackup" -and $_.Parameters.Value -eq $existingShell } | Should -HaveCount 1
            Get-MockCallHistory Set-ItemProperty | Where-Object { $_.Parameters.Name -eq "DefaultShell" -and $_.Parameters.Value -eq $testShellPath } | Should -HaveCount 1
            Get-MockCallHistory Out-File | Should -HaveCount 1
            Get-MockCallHistory Out-File | ForEach-Object { $_.Parameters.FilePath | Should -Be "DefaultShellBackup.reg" }
            (Get-MockCallHistory Out-File)[0].Parameters.Encoding.BodyName | Should -Be ([System.Text.Encoding]::ASCII).BodyName
        }

        It "should only set DefaultShell if no existing value, no backup performed" {
            $testShellPath = "C:\new\shell.exe"
            Mock Get-ItemProperty { return $null } -Scope It # Simulate no existing DefaultShell

            Set-DefaultShell -ShellPath $testShellPath

            Get-MockCallHistory Set-ItemProperty | Should -HaveCount 1
            Get-MockCallHistory Set-ItemProperty | Where-Object { $_.Parameters.Name -eq "DefaultShell" -and $_.Parameters.Value -eq $testShellPath } | Should -HaveCount 1
            Get-MockCallHistory Out-File | Should -BeEmpty
        }

        It "should attempt to set DefaultShell even if registry path does not exist (due to -Force in Set-ItemProperty)" {
             $testShellPath = "C:\another\shell.exe"
             Mock Test-Path { return $false } -Scope It # Simulate registry path not existing

             Set-DefaultShell -ShellPath $testShellPath

             Get-MockCallHistory Set-ItemProperty | Should -HaveCount 1 # Set-ItemProperty -Force will attempt to create
             Get-MockCallHistory Set-ItemProperty | Where-Object { $_.Parameters.Name -eq "DefaultShell" -and $_.Parameters.Value -eq $testShellPath } | Should -HaveCount 1
             # No backup should occur if the path doesn't exist for Get-ItemProperty
             Get-MockCallHistory Out-File | Should -BeEmpty
        }

        It "should call Write-Host with error if Set-ItemProperty fails" {
            $testShellPath = "C:\error\shell.exe"
            Mock Set-ItemProperty { throw "Registry access denied by mock" } -Scope It

            Set-DefaultShell -ShellPath $testShellPath

            Get-MockCallHistory Write-Host | Where-Object { $_.Parameters.Object -like "Failed to set default shell:*" -and $_.Parameters.ForegroundColor -eq "Red" } | Should -HaveCount 1
        }
    }

    Context "Main script execution flow (user interaction)" {
        # Mocks are mostly set in Describe's BeforeEach

        It "should display current shell, list available shells, and exit gracefully if user enters nothing" {
            Mock Read-Host { return "" } -Scope It # User presses Enter
            Mock Get-ItemProperty { return [pscustomobject]@{ DefaultShell = "C:\shells\powershell.exe" } } -Scope It

            { . $ScriptPath } | Should -Not -Throw "SCRIPT_EXIT_*" # Should not call our mocked exit

            Get-MockCallHistory Write-Host | Where-Object { $_.Parameters.Object -like "Current OpenSSH default shell: C:\shells\powershell.exe" } | Should -HaveCount 1
            Get-MockCallHistory Write-Host | Where-Object { $_.Parameters.Object -match "\[0\] C:\\shells\\powershell.exe" } | Should -HaveCount 1
            Get-MockCallHistory Write-Host | Where-Object { $_.Parameters.Object -eq "No changes made to the current default shell." } | Should -HaveCount 1
            # Ensure Set-DefaultShell (the function) is not called
            (Get-Command Set-DefaultShell -ErrorAction SilentlyContinue) | Should -Not -BeNull # function should exist
            Get-MockCallHistory Set-DefaultShell | Should -BeEmpty # But not called
        }

        It "should call Set-DefaultShell (the function) if user makes a valid selection" {
            Mock Read-Host { return "1" } -Scope It # User selects the second shell (index 1)
            $mockedShells = @("C:\shells\powershell.exe", "C:\shells\pwsh.exe", "C:\shells\bash.exe")
            Mock Get-AllShellPaths { return $mockedShells } -Scope It
            Mock Set-DefaultShell {} -Scope It # Mock the function defined in the script

            { . $ScriptPath } | Should -Not -Throw "SCRIPT_EXIT_*"

            Get-MockCallHistory Set-DefaultShell | Should -HaveCount 1
            (Get-MockCallHistory Set-DefaultShell)[0].Parameters.ShellPath | Should -Be $mockedShells[1]
        }

        It "should exit with code 1 if user makes an invalid numeric selection" {
            Mock Read-Host { return "99" } -Scope It # Invalid selection

            { . $ScriptPath } | Should -Throw "SCRIPT_EXIT_1"
            Get-MockCallHistory Write-Host | Where-Object { $_.Parameters.Object -eq "Invalid selection. Exiting." -and $_.Parameters.ForegroundColor -eq "Red" } | Should -HaveCount 1
        }

        It "should exit with code 1 if user makes a non-numeric selection" {
            Mock Read-Host { return "abc" } -Scope It # Invalid selection

            { . $ScriptPath } | Should -Throw "SCRIPT_EXIT_1"
            Get-MockCallHistory Write-Host | Where-Object { $_.Parameters.Object -eq "Invalid selection. Exiting." -and $_.Parameters.ForegroundColor -eq "Red" } | Should -HaveCount 1
        }

        It "should exit with code 1 if Get-AllShellPaths returns no shells" {
            Mock Get-AllShellPaths { return @() } -Scope It

            { . $ScriptPath } | Should -Throw "SCRIPT_EXIT_1"
            Get-MockCallHistory Write-Host | Where-Object { $_.Parameters.Object -eq "No available shells found on the system." -and $_.Parameters.ForegroundColor -eq "Red" } | Should -HaveCount 1
        }

        It "should display 'No available shells found' if Get-AllShellPaths returns null (and exit)" {
            Mock Get-AllShellPaths { return $null } -Scope It

            { . $ScriptPath } | Should -Throw "SCRIPT_EXIT_1"
            Get-MockCallHistory Write-Host | Where-Object { $_.Parameters.Object -eq "No available shells found on the system." -and $_.Parameters.ForegroundColor -eq "Red" } | Should -HaveCount 1
        }
    }
}
