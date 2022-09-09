function Get-WinEventTail{
  <#
    .DESCRIPTION
    This function tails the specified event log based on log name or filter for specified server(s)
    .PARAMETER LogName
    Specifies which Windows event log to tail:  System, Application, etc.
    .PARAMETER LogFilter
    Specifies a more complex Windows event log filter
    See: https://docs.microsoft.com/en-us/powershell/scripting/samples/Creating-Get-WinEvent-queries-with-FilterHashtable?view=powershell-7.2
    .PARAMETER Servers
    Single server or array of servers you would like to target for event log tailing
    .EXAMPLE
      Get-WinEventTail -Servers "server1","server2" -LogName System
      Get-WinEventTail -Servers "server1","server2" -LogFilter @{ LogName='System'; ID=4; ProviderName ='l2nd2' }
  #>
  [CmdletBinding()]
  Param (
      [Parameter(Mandatory=$true,ParameterSetName='LogName')]
      [string]$LogName,
      [Parameter(Mandatory=$true,ParameterSetName='LogFilter')]
      [hashtable]$LogFilter,
      [Parameter(Mandatory=$true)]
      [string[]]$Servers
  )
  begin {
    $eventtrack = @()
  }
  process{
    while ($true)
    {
      foreach($Server in $Servers){
        $eventobject = $eventtrack | Where-Object SystemName -eq $Server
        if($eventobject){
          Write-Verbose ("Pulling events for server {0}" -f  $server)
          Start-Sleep -Seconds 1
          $CurrRecordId = if ($PSBoundParameters.ContainsKey('LogName')) {
            (Get-WinEvent -ComputerName $Server -LogName $LogName -MaxEvents 1 -ErrorAction SilentlyContinue).RecordId
          }else{
            (Get-WinEvent -ComputerName $Server -FilterHashtable $LogFilter -MaxEvents 1 -ErrorAction SilentlyContinue).RecordId
          }
          if($CurrRecordId){
            Write-Verbose ("  Current record ID {0}.  Last record ID {0}" -f  $CurrRecordId, $eventobject.LastRecordId)
            If ($CurrRecordId -gt $eventobject.LastRecordId){
              if ($PSBoundParameters.ContainsKey('LogName')) {
                Get-WinEvent -ComputerName $Server -LogName $LogName -MaxEvents ($CurrRecordId - $eventobject.LastRecordId) | Sort-Object -Property RecordId
              }else{
                Get-WinEvent -ComputerName $Server -FilterHashtable $LogFilter -MaxEvents ($CurrRecordId - $eventobject.LastRecordId) | Sort-Object -Property RecordId
              }
            }else{
              Write-Verbose ("  No new records to pull for server {0}" -f $server)
            }
            Write-Verbose ("Setting last record ID for server {0} to {1}" -f  $server, $CurrRecordId)
            $eventobject.LastRecordId = $CurrRecordId
          }else{
            Write-Verbose ("No current events found for server {0} to track.  Will continue to monitor..." -f  $server)
          }
        }else{
          $lastid = if ($PSBoundParameters.ContainsKey('LogName')) {
            (Get-WinEvent -ComputerName $Server -LogName $LogName -MaxEvents 1 -ErrorAction SilentlyContinue).RecordId
          }else{
            (Get-WinEvent -ComputerName $Server -FilterHashtable $LogFilter -MaxEvents 1 -ErrorAction SilentlyContinue).RecordId
          }          
          $eventtrack += [PSCustomObject]@{
            SystemName = $Server
            LastRecordId  = if($lastid){ $lastid } else { 0 }
          }
          if (!$lastid){
            Write-Warning ("No current events found for server {0} to track.  Will continue to monitor..." -f  $server)
          }else{
            Write-Verbose ("Configuring event tracker object for server {0} with last record id {1}" -f  $server, $lastid)
          }
        }
      }
    }
  }
  end {}
}