# PSLog
Logger written for Powershell

# Example XML configuration file
```
<PSLOG level="debug" console="true" >
    <logsettings    
        maxBackupFiles="5" 
        maxFileSize="10000" 
        name="logfile.log" 
        pattern="%d% %t% [%lvl%]: %log_data%" 
        datepattern="yyyy-MM-dd" 
        timepattern="HH:mm:ss:ffff" 
        logDestinationRegex="\\(config)\\(.*)\.xml"
        encoding="UTF-8"
    />
</PSLOG>
```

# Settings description

| Setting        | Description           | Default value  |
| ------------- |:-------------:| -----:|
| level | The level of logging that should be written to file. INFO/DEBUG/WARN/ERROR/FATAL     |  DEBUG   | 
| console | Whether or not logging should also be output to console     |  false   | 
| maxBackupFiles      | The amount of files to rotate before overwriting old logs | N/A |
| maxFileSize      | The max size of the log file before its rotated      | N/A   |
| name | The name of the logfile to be used. Will belogged to \logs\     |  N/A   | 
| pattern | The pattern of the log entries      |  %d% %t% [%lvl%]: %log_data%   |
| datepattern | Pattern for date (1)      |  yyyy-MM-dd   |
| timepattern | Pattern for timestamp (1)     | HH:mm:ss    |
| logDestinationRegex | Regular expression of where the .xml file is saved      |  \\(config)\\(.*)\.xml   |
| encoding | The encoding the content of the content in the logfile    | UTF-8

(1) https://docs.microsoft.com/en-us/dotnet/standard/base-types/custom-date-and-time-format-strings?view=netframework-4.8
