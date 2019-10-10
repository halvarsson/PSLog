Import-Module D:\dev\PSLog\PSLog -Force
$moduleName = 'PSLog'

Describe "Public commands have Pester tests" -Tag 'Build' {
    $commands = Get-Command -Module $ModuleName

    foreach ($command in $commands.Name)
    {
        $file = Get-ChildItem -Path "$ModuleRoot" -Include "$command.Tests.ps1" -Recurse
        It "Should have a Pester test for [$command]" {
            $file.FullName | Should Not BeNullOrEmpty
        }
    }
}
