@echo off
set "CURRENT_DIR=%~dp0"
set "JAVA_HOME=%CURRENT_DIR%.tools\jdk"
set "PATH=%CURRENT_DIR%.tools\jdk\bin;%CURRENT_DIR%.tools\apache-maven-3.9.9\bin;%PATH%"
"%CURRENT_DIR%.tools\apache-maven-3.9.9\bin\mvn.cmd" -Dmaven.repo.local="%CURRENT_DIR%.tools\.m2\repository" %*
