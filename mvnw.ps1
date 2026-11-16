param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ArgsList
)

$currentDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$env:JAVA_HOME = "$currentDir\.tools\jdk"
$env:PATH = "$currentDir\.tools\jdk\bin;$currentDir\.tools\apache-maven-3.9.9\bin;$env:PATH"

$mvnCmd = "$currentDir\.tools\apache-maven-3.9.9\bin\mvn.cmd"
$localRepo = "$currentDir\.tools\.m2\repository"

& $mvnCmd -Dmaven.repo.local="$localRepo" @ArgsList
exit $LASTEXITCODE
