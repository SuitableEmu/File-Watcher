#Folder to monitor
$Folder = 'C:\whatever\whatever'
$Path = $Folder

#File Filter *.txt, *.pdf, *.docx etc..
$FileFilter = '*.whatever'  

#ture if you want to include subfolders.
$IncludeSubfolders = $false

# specify the file or folder properties you want to monitor:
$AttributeFilter = [IO.NotifyFilters]::FileName, [IO.NotifyFilters]::LastWrite 

try
{
  $watcher = New-Object -TypeName System.IO.FileSystemWatcher -Property @{
    Path = $Path
    Filter = $FileFilter
    IncludeSubdirectories = $IncludeSubfolders
    NotifyFilter = $AttributeFilter
  }

  # define the code that should execute when a change occurs:
  $action = {
    # the code is receiving this to work with:
    
    # change type information:
    $details = $event.SourceEventArgs
    $Name = $details.Name
    $FullPath = $details.FullPath
    $OldFullPath = $details.OldFullPath
    $OldName = $details.OldName
    
    # type of change:
    $ChangeType = $details.ChangeType
    
    # when the change occured:
    $Timestamp = $event.TimeGenerated
    
    # save information to a global variable for testing purposes
    # so you can examine it later
    # MAKE SURE YOU REMOVE THIS IN PRODUCTION!
    $global:all = $details
    
    # now you can define some action to take based on the
    # details about the change event:
    # this is also where you can add the pdf file search script.
    
    # let's compose a message:
    $text = "{0} was {1} at {2}" -f $FullPath, $ChangeType, $Timestamp
    Write-Host ""
    Write-Host $text -ForegroundColor DarkYellow
    
    # you can also execute code based on change type here:
    switch ($ChangeType)
    {
      'Changed'  { "CHANGE" 
      Write-Host "Monitoring..." -NoNewline -ForegroundColor Yellow
      }
      'Created'  { "CREATED"
        Write-Host "File Created" -ForegroundColor Yellow
        # Update with the location of where the files are created.
        $location = "C:\whatever\*.txt"
        $content = Get-ChildItem $location | sort LastWriteTime | select -last 1 | Copy-Item -Destination C:\temp\
        $tmpfile = "C:\Temp"
        $file = Get-ChildItem $tmpfile | sort LastWriteTime | select -last 1 | Get-Content
        # if you want it to take items and export to a text file for some reason update this
        $outfile = "C:\Temp\whatever.txt"

        # If you need to remove or replace anything from the string of text edit this if not comment it out with "#"
        $file -replace ';',"`r`n" | Out-file $outfile -Force

        #this is for e-mail notifications, where it takes the lines "[0] - [999]" and places them in a e-mail and sends it to you.
        $usr = (Get-Content C:\Temp\whatever.txt)[5]
        $time = (Get-Content C:\Temp\whatever.txt)[6]
        $Project = (Get-Content C:\Temp\whatever.txt)[0]
        
        # bsm is body of the message
        $bsm = ''
        
        # sms is subject of the message
        $sms = ''

       
        Get-ChildItem $tmpfile | sort LastWriteTime | select -First 1 | Remove-Item
        

        Send-MailMessage -From 'example <example@example.com' -To 'example <example@example.com>' -Subject $sms -BodyAsHtml $bsm -Priority High -SmtpServer 'smtp.example.com'
        # cleanup
        Remove-Item C:\Temp\whatever.txt
        Write-Host "Monitoring..." -NoNewline -ForegroundColor Yellow
      }
      'Deleted'  { "DELETED"
        # to illustrate that ALL changes are picked up even if
        # handling an event takes a lot of time, we artifically
        # extend the time the handler needs whenever a file is deleted
        Write-Host "Deletion Handler Start" -ForegroundColor Gray
        Start-Sleep -Seconds 4    
        Write-Host "Deletion Handler End" -ForegroundColor Gray
        Write-Host "Monitoring..." -NoNewline -ForegroundColor Yellow
      }
      'Renamed'  { 
        # this executes only when a file was renamed
        $text = "File {0} was renamed to {1}" -f $OldName, $Name
        Write-Host $text -ForegroundColor Yellow
        Write-Host "Monitoring..." -NoNewline -ForegroundColor Yellow
      }
        
      # any unhandled change types surface here:
      default   { Write-Host $_ -ForegroundColor Red -BackgroundColor White }
    }
  }

  # subscribe your event handler to all event types that are
  # important to you. Do this as a scriptblock so all returned
  # event handlers can be easily stored in $handlers:
  $handlers = . {
    Register-ObjectEvent -InputObject $watcher -EventName Changed  -Action $action 
    Register-ObjectEvent -InputObject $watcher -EventName Created  -Action $action 
    Register-ObjectEvent -InputObject $watcher -EventName Deleted  -Action $action 
    Register-ObjectEvent -InputObject $watcher -EventName Renamed  -Action $action 
  }

  # monitoring starts now:
  $watcher.EnableRaisingEvents = $true

  Write-Host "Watching for changes to $Path"

  # since the FileSystemWatcher is no longer blocking PowerShell
  # we need a way to pause PowerShell while being responsive to
  # incoming events. Use an endless loop to keep PowerShell busy:

  Write-Host "Monitoring..." -NoNewline -ForegroundColor Yellow

  do
  {
    # Wait-Event waits for a second and stays responsive to events
    # Start-Sleep in contrast would NOT work and ignore incoming events
    Wait-Event -Timeout 1

        
  } while ($true)
}
finally
{
  # this gets executed when user presses CTRL+C:
  
  # stop monitoring
  $watcher.EnableRaisingEvents = $false
  
  # remove the event handlers
  $handlers | ForEach-Object {
    Unregister-Event -SourceIdentifier $_.Name
  }
  
  # event handlers are technically implemented as a special kind
  # of background job, so remove the jobs now:
  $handlers | Remove-Job
  
  # properly dispose the FileSystemWatcher:
  $watcher.Dispose()
  
  Write-Warning "Event Handler disabled, monitoring ends."
}