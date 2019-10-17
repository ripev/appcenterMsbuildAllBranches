# appcenter.ms builder

## Description

This powershell script can start build all branches of application in appcenter.ms via API.

## Usage

Note: before usage you should get access key from appcenter.ms - account settings - api tokens - new api token (with full access).

```.\DevOps.ps1 [-accessKey] <string> [-ownerName] <string> [-appName]```

where (all params is mandatory):
- accessKey - api key,
- ownerName - user from appcenter.ms
- appName   - application name