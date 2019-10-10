# Class tests
#Remove-Module -Name PSLog -Force
#using module "D:\dev\PSLog\PSLog\PSLog.psm1"
Import-Module "D:\dev\PSLog\PSLog" -Force
Describe "PSLog Tests" -Tags 'Build' {
    Context "Testing class" {

        It 'Should not throw when creating new logger instance' {
            { Get-Logger } | Should not throw
        }
        $logger = Get-Logger
        $logger.Initialize("D:\dev\PSLog\config\testfile.xml")
        It "should have returned a logger instance with expected logpath set" {
            $logger.logPath | Should Be "D:\dev\PSLog\logs\testfile.log"
        }
        It 'Should have console logging enabled prior to it being disabled' {
            $logger.consoleLoggingEnabled | Should Be $true
        }
        $logger.consoleLoggingEnabled = $false

        # log 10000 entries and check runtime
        $measureComm = Measure-Command { 
            1..10000 | Foreach-Object { $logger.debug('unit testing') }
        }

        It 'should be able to log 100000 entries in less than 5 seconds' {
            $measureComm.Seconds | Should -BeLessOrEqual 5
        }

    }
}