enum logLevels
{
    UNKNOWN = 0;
    DEBUG = 1; 
    INFO = 2; 
    WARN = 3; 
    ERROR = 4; 
    FATAL = 5
}

enum logLevelConsoleHostColors
{
    Gray = 0;
    Magenta = 1;
    Cyan = 2;
    Yellow = 3;
    Red = 4;
    DarkRed = 5
}

Class Logger
{
    [string]$configFilePath
    [int]$setLogLevel = 0

    [boolean]$consoleLoggingEnabled = $false

    hidden [string]$logPattern
    hidden [string]$dateFormat
    hidden [string]$timeFormat
    [string]$logName
    [string]$logPath
    [string]$rootDirectory
    hidden [int]$maxBackupFiles
    hidden [int]$maxLogFileSize
    hidden [int]$currentLogFileSize = 0
    hidden [int]$currentBackupFilesCount = 1
    hidden [System.Text.Encoding]$streamWriterEncoding = [System.Text.Encoding]::UTF8

    # Method used to set the encoding used for writing to the logfile
    hidden setEncoding($encoding)
    {
        $this.streamWriterEncoding = [System.Text.Encoding]::GetEncoding($encoding)
    }

    # Load the configuration file and configure the Logger class
    [void]Initialize($configFilePath)
    {
        # test path of logfile
        if (!(Test-Path -Path $configFilePath))
        {
            Write-Error "Unable to find config file."
        }
        # try to load logfile
        $configFile = [xml](Get-Content -Path $configFilePath -Raw)

        # check that it has right FORMAT?
        if (!($configFile.PSLOG))
        {
            Write-Error "Unable to find valid PSLOG entry in XML file"
        }

        # set logfilepath
        [int]$this.setLogLevel = [logLevels]::"$($configFile.PSLOG.level)".value__

        # get logging pattern expression
        $this.logPattern = $configFile.PSLOG.logsettings.pattern
        if ($this.logPattern -match "%d%")
        {
            $this.dateFormat = $configFile.PSLOG.logsettings.datepattern
        }
        if ($this.logPattern -match "%t%")
        {
            $this.timeFormat = $configFile.PSLOG.logsettings.timepattern
        }

        # set encoding
        if ($configFile.PSLOG.logsettings.encoding)
        {
            $this.setEncoding($configFile.PSLOG.logsettings.encoding)
        }

        # check if console logging is enabled
        if ($configFile.PSLOG.console -eq 'true')
        {
            $this.consoleLoggingEnabled = $true
        }

        $this.logName = $configFile.PSLOG.logsettings.name
        $this.maxBackupFiles = [int]$configFile.PSLOG.logsettings.maxBackupFiles
        $this.maxLogFileSize = [int]$configFile.PSLOG.logsettings.maxFileSize * 1024
        $this.configFilePath = $configFilePath
        $this.rootDirectory = $configFilePath -replace $configFile.PSLOG.logsettings.logDestinationRegex, ""
        $this.logPath = "$($this.rootDirectory)\logs\$($this.logName)"

        # stage the folders 
        $this.stageFolders()
        $backupFiles = Get-ChildItem -Path "$($this.rootDirectory)\logs\backup\" -Directory

        if ($backupFiles)
        {
            $this.currentBackupFilesCount = ($backupFiles).Count
        }
        if (Test-Path -Path $this.logPath)
        {
            $this.currentLogFileSize = [System.IO.FileInfo]::new($this.logPath).Length
        }
    }

    [void]load($configFilePath)
    {
        $this.Initialize($configFilePath)
    }

    # return pattern with %d% replaced with date, and %t% replaced with time
    hidden [string]getPatternWithDate()
    {
        $pattern = $this.logPattern
        # pattern="%d %t [%lvl]: %log_data" datepattern="yyyy-MM-dd" timepattern="HH:mm:ss:ffff" />
        if ($this.dateFormat -and $this.timeFormat)
        {
            $datePattern = "$($this.dateFormat)|$($this.timeFormat)"
            $dateTimeResult = [Datetime]::Now.ToString($datePattern).Split("|")
            $dateString = $dateTimeResult[0]
            $timeString = $dateTimeResult[1]
            $pattern = $pattern -replace "%d%", $dateString
            $pattern = $pattern -replace "%t%", $timeString
        }
        elseif ($this.dateFormat)
        {
            $datePattern = $this.dateFormat
            $dateResult = [Datetime]::Now().ToString($datePattern)
            $pattern = $pattern -replace "%d%", $dateResult
        }
        elseif ($this.timeFormat)
        {
            $timePattern = $this.timeFormat
            $timeResult = [Datetime]::Now().ToString($timePattern)
            $pattern = $pattern -replace "%t%", $timeResult
        }
        return $pattern        
    }

    # method that creates the logs/backup folders
    hidden [void]stageFolders()
    {
        if (!(Test-Path -Path "$($this.rootDirectory)\logs"))
        {
            New-Item -Path $this.rootDirectory -ItemType Directory -Name "logs"
        }
        if (!(Test-Path -Path "$($this.rootDirectory)\logs\backup"))
        {
            New-Item -Path "$($this.rootDirectory)\logs" -ItemType Directory -Name "backup"
        }
    }

    # method for returning the backup logfile path based on number of backed up logs
    hidden [string]getBackupLogFilePath($number)
    {
        $ext = ".$($number)" + ".log";
        $dest = $this.rootDirectory + "\logs\backup\" + $this.logName.replace(".log", $ext);
        return $dest
    }
    # method for shifting the backup files by 1, renaming .1 to .2 etc
    hidden [void]rotateBackupFiles()
    {
        for ($i = ($this.maxBackupFiles - 1); $i -ge 0; $i--)
        {
            $source = $this.getBackupLogFilePath("$i")
            if (Test-Path $source)
            {
                $dest = $this.getBackupLogFilePath("$($i + 1)")
                Move-Item $source $dest -Force;
            }
        }
    }
    # method for moving the latest logfile to backup folder as .1, and rotate logs if needed
    hidden [void]rollLogFiles()
    {
        if ($this.currentBackupFilesCount -ge $this.maxBackupFiles)
        {      
            # remove oldest
            $removeDestination = $this.getBackupLogFilePath("$($this.maxBackupFiles)")
            if (Test-Path -Path $removeDestination)
            {
                Remove-Item -Path $removeDestination -Force
            }
        }
        # roll backup files
        $this.rotateBackupFiles()
        $this.currentBackupFilesCount = ($this.currentBackupFilesCount + 1);

        if (Test-Path -Path $this.logPath)
        {
            $ext = "." + "1" + ".log";
            $dest = $this.rootDirectory + "\logs\backup\" + $this.logName.replace(".log", $ext);
            Move-Item $this.logPath $dest -Force;
            $this.currentBackupFilesCount++;
        }
        New-Item -Path $this.logPath -Force 

        $this.currentLogFileSize = 0;
        
    }
    # method for returning the log message to be used
    hidden [string]getLogMessage($level, $message)
    {
        $logMessagePattern = $this.getPatternWithDate()
        $logMessagePattern = $logMessagePattern -replace "%lvl%", $level
        $logMessagePattern = $logMessagePattern -replace "%log_data%", $message
        return $logMessagePattern
    }

    # method used for logging
    hidden [void]LOG($level, $message)
    {
        if ($this.setLogLevel -le $level.value__)
        {
            # generate log message
            $logMessage = $this.getLogMessage($level, $message) 
            if ($this.consoleLoggingEnabled -eq $true)
            {
                Write-Host $logMessage -ForegroundColor $([logLevelConsoleHostColors]$($level.value__)).ToString()
            }
            # log to file
            $this.logToFile($logMessage)
            $this.currentLogFileSize = $this.currentLogFileSize + ($logMessage.Length)
            if ($this.currentLogFileSize -ge $this.maxLogFileSize)
            {
                $this.rollLogFiles()
                $this.currentLogFileSize = 0
            }
        }
    }

    # the method used for actually writing to the file
    hidden [void]logToFile($lineToLog)
    {
        $writer = [System.IO.StreamWriter]::new($this.logPath, $true, $this.streamWriterEncoding)
        $writer.WriteLine($lineToLog)
        $writer.close()
    }
    
    [void]DEBUG($message)
    {
        $this.LOG([logLevels]::DEBUG, $message)
    }

    [void]INFO($message)
    {
        $this.LOG([logLevels]::INFO, $message)
    }

    [void]WARN($message)
    {
        $this.LOG([logLevels]::WARN, $message)
    }

    [void]ERROR($message)
    {
        $this.LOG([logLevels]::ERROR, $message)
    }

    [void]FATAL($message)
    {
        $this.LOG([logLevels]::FATAL, $message)
    }

}