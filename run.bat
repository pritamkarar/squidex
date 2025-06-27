@echo off
setlocal
title Squidex Setup Terminal
color 0A
cls

echo  ________  ________  ___  ___  ___  ________  _______      ___    ___ 
echo ^|\   ____\^|\   __  \^|\  \^|\  \^|\  \^|\   ___ \^|\  ___ \    ^|\  \  /  /^|
echo \ \  \___^|\ \  \^|\  \ \  \\\  \ \  \ \  \_^|\ \ \   __/^|   \ \  \/  / /
echo  \ \_____  \ \  \\\  \ \  \\\  \ \  \ \  \ \\ \ \  \_^|/__  \ \    / / 
echo   \^|____^|\  \ \  \\\  \ \  \\\  \ \  \ \  \_\\ \ \  \_^|\ \  /     \/  
echo     ____\_\  \ \_____  \ \_______\ \__\ \_______\ \_______\/  /\   \  
echo    ^|\_________\^|___^| \__\^|_______^|\^|__^|\^|_______^|\^|_______/__/ /\ __\ 
echo    \^|_________^|     \^|__^|                                 ^|__^|/ \^|__^| 
echo(
echo ------------------------------------------------------------------------------

echo * Creating launchSettings.json file
set launchSettingsFile=backend\src\Squidex\Properties\launchSettings.json

if exist "%launchSettingsFile%" (
    echo launchSettings.json already configured
) else (
	(
		echo {
		echo   "profiles": {
		echo     "Squidex": {
		echo       "commandName": "Project",
		echo       "launchBrowser": true,
		echo       "environmentVariables": {
		echo         "ASPNETCORE_ENVIRONMENT": "Development"
		echo       },
		echo       "applicationUrl": "https://localhost:5001;http://localhost:5000"
		echo     }
		echo   }
		echo }
	) > %launchSettingsFile%
	
	echo CREATED: %launchSettingsFile%
)

echo * Setting up Database and Storage...

set appsettingsFile=backend\src\Squidex\appsettings.Development.json
if exist "%appsettingsFile%" (
    echo appsettings.Development.json already exists
	goto appSetup
)

set BASE_URL=https://localhost:5001
set AZURE_CONTAINER=squidex-assets
set AZURE_CONNECTION=DefaultEndpointsProtocol=https;AccountName=your_account_name;AccountKey=your_account_key;EndpointSuffix=core.windows.net
set MONGODB_URI=mongodb://localhost

set /p MONGODB_URI=Enter MongoDb Connection String (press Enter for default localhost): 
set /p AZURE_CONNECTION=Enter Azure Blob Connection String: 
(
	echo {
	echo   "urls": {
	echo     "baseUrl": "%BASE_URL%"
	echo   },
	echo   "assetStore": {
	echo     "type": "AzureBlob",
	echo     "azureBlob": {
	echo       "containerName": "%AZURE_CONTAINER%",
	echo       "connectionString": "%AZURE_CONNECTION%"
	echo     }
	echo   },
	echo   "eventStore": {
	echo     "type": "MongoDb",
	echo     "mongoDb": {
	echo       "configuration": "%MONGODB_URI%"
	echo     }
	echo   },
	echo   "store": {
	echo     "type": "MongoDb",
	echo     "mongoDb": {
	echo       "configuration": "%MONGODB_URI%"
	echo     }
	echo   }
	echo }
) > %appsettingsFile%

echo CREATED: %appsettingsFile%

:appSetup

set squidexBackendPath=backend\src\Squidex
set squidexFrontendPath=Frontend

echo * Squidex Backend - Builing/Restoring dependencies...
pushd "%squidexBackendPath%"
dotnet restore
popd

echo * Squidex Frontend - Installing dependencies...
pushd "%squidexFrontendPath%"
powershell -Command "npm i --no-fund --no-audit"
popd

echo * Squidex Frontend - Installing Certificate for SSL...
set certificatePath=dev\squidex-dev.cer
set certStore=Cert:\CurrentUser\Root

powershell -NoProfile -ExecutionPolicy Bypass -Command "$cert = Get-ChildItem -Path %certStore% | Where-Object { $_.Subject -eq 'CN=localhost' }; if ($cert) { Write-Host 'Certificate already exists.' } else { Write-Host 'Importing certificate...'; $result = Import-Certificate -FilePath '%certificatePath%' -CertStoreLocation %certStore%; if ($result.Certificate) { Write-Host 'Certificate imported. You may have to restart your PC for certificate working correctly' } else { Write-Host 'Import failed.' } }"

timeout /t 3 >nul
echo Continuing to the next steps
for /L %%i in (3,-1,1) do (
    echo %%i...
    timeout /t 1 >nul
)

echo * Squidex Backend - Starting Server...
pushd "%squidexBackendPath%"
start dotnet run --launch-profile Squidex
popd

echo * Squidex Frontend - Starting Server...
pushd "%squidexFrontendPath%"
start "" cmd /c "npm start"
popd

set "URL=https://localhost:5001"
set "elapsed=0"
set "TIMEOUT=60"

:waitloop
powershell -Command "try { (Invoke-WebRequest -Uri '%URL%' -UseBasicParsing -TimeoutSec 1) | Out-Null; exit 0 } catch { exit 1 }"
if %errorlevel%==0 (
    echo Squidex services started successfully
    start %URL%
    goto end
)
timeout /t 2 >nul
set /a elapsed+=2
if %elapsed% GEQ %TIMEOUT% (
    echo Open %URL% in browser
    goto end
)
goto waitloop
:end

exit /b 0