param (
    [Parameter(Mandatory=$true)][string]$ConfigFile,
    [Parameter(Mandatory=$true)][string]$ScratchDirectory,
    [Parameter(Mandatory=$true)][string]$LogDirectory
 )

# #################################################
# PREREQUISITES FOR THIS SCRIPT!!!!
# #################################################

# This script requires Amazon S3 powershell. How to install:
#  See: https://docs.aws.amazon.com/powershell/latest/userguide/pstools-getting-set-up-windows.html#ps-installing-awstools
#  Install-Module -Name AWS.Tools.Installer -Force -AllowClobber -SkipPublisherCheck -Scope AllUsers
#  Install-AWSToolsModule AWS.Tools.S3 -CleanUp -Force -SkipPublisherCheck -Scope allUsers
#  NOTE: The "-Scope AllUsers" does not seem to work - you may need to log in as the service account that you use for this script and install it manually.

$JobName = "IE-EDUFORMS"

$RetrySeconds = 60

# #################################################
# File names for FTP transactions
# #################################################

$CSVGetFiles = @(
    @{
        VendorName = "Schools.csv"
        SQLQueryBase64 = "U0VMRUNUIA0KICAgIFNLTF9TQ0hPT0xfTkFNRSBhcyBOYW1lLA0KICAgIFNLTF9TQ0hPT0xfSUQgYXMgRXh0SWQsDQogICAgUkVQTEFDRShSRVBMQUNFKFNLTF9TVEFSVF9HUkFERSwtMSwnUEsnKSwwLCdLJykgYXMgTG93R3JhZGUsDQogICAgKFNLTF9TVEFSVF9HUkFERSArIFNLTF9OVU1CRVJfT0ZfR1JBREVTIC0gMSkgYXMgSGlnaEdyYWRlLA0KICAgIFNLTF9TQ0hPT0xfSUQgYXMgU2Nob29sTnVtYmVyDQpGUk9NIA0KICAgIE1TU19TQ0hPT0wNCldIRVJFIFNLTF9JTkFDVElWRV9JTkQgPSAw"
        size = -1
        hash = "NONE"
        RetrieveSuccess = $false
        RetrieveError = ""
        Uploaded = $false
        UploadError = ""
    },
    @{
        VendorName = "Contacts.csv"
        SQLQueryBase64 = "U0VMRUNUIA0KCU1TU19QRVJTT04uUFNOX0VNQUlMXzAxIGFzIEVtYWlsLA0KCU1TU19DT05UQUNULkNOVF9PSUQgYXMgRXh0SWQsDQoJTVNTX1BFUlNPTi5QU05fUEhPTkVfMDEgYXMgUGhvbmUsDQoJQ09OQ0FUKE1TU19QRVJTT04uUFNOX05BTUVfRklSU1QsICcgJywgTVNTX1BFUlNPTi5QU05fTkFNRV9MQVNUKSBhcyBGdWxsTmFtZSwNCgknUHJpbWFyeScgYXMgUGhvbmVUeXBlLA0KCU1TU19TVFVERU5UX0NPTlRBQ1QuQ1RKX1JFTEFUSU9OU0hJUF9DT0RFIGFzIFJlbGF0aW9uc2hpcCwNCglNU1NfU1RVREVOVC5TVERfSURfTE9DQUwgYXMgU3R1ZGVudE51bWJlcg0KRlJPTQ0KCU1TU19TVFVERU5UX0NPTlRBQ1QNCglMRUZUIE9VVEVSIEpPSU4gTVNTX0NPTlRBQ1QgT04gTVNTX1NUVURFTlRfQ09OVEFDVC5DVEpfQ05UX09JRD1NU1NfQ09OVEFDVC5DTlRfT0lEDQoJTEVGVCBPVVRFUiBKT0lOIE1TU19QRVJTT04gT04gTVNTX0NPTlRBQ1QuQ05UX1BTTl9PSUQ9TVNTX1BFUlNPTi5QU05fT0lEDQoJTEVGVCBPVVRFUiBKT0lOIE1TU19TVFVERU5UIE9OIE1TU19TVFVERU5UX0NPTlRBQ1QuQ1RKX1NURF9PSUQ9TVNTX1NUVURFTlQuU1REX09JRA0KV0hFUkUNCglNU1NfU1RVREVOVC5TVERfRU5ST0xMTUVOVF9TVEFUVVMgSU4gKCdBY3RpdmUnLCAnQWN0aXZlIE5vIFByaW1hcnknKQ=="
        size = -1
        hash = "NONE"
        RetrieveSuccess = $false
        RetrieveError = ""
        Uploaded = $false
        UploadError = ""
    },
    @{
        VendorName = "Sections.csv"
        SQLQueryBase64 = "U0VMRUNUDQoJTVNTX1NDSEVEVUxFX1RFUk1fREFURS5UTURfRU5EX0RBVEUgYXMgVGVybUVuZCwNCglNU1NfU0NIT09MLlNLTF9TQ0hPT0xfSUQgYXMgU2Nob29sSWQsDQoJTVNTX1NUQUZGLlNURl9JRF9MT0NBTCBhcyBUZWFjaGVyMSwNCgknJyBhcyBUZWFjaGVyMiwNCgknJyBhcyBUZWFjaGVyMywNCglNU1NfU0NIRURVTEVfVEVSTS5UUk1fVEVSTV9OQU1FIGFzIFRlcm1OYW1lLA0KCU1TU19TQ0hFRFVMRV9NQVNURVIuTVNUX09JRCBhcyBTZWN0aW9uSWQsDQoJTVNTX1NDSEVEVUxFX1RFUk1fREFURS5UTURfU1RBUlRfREFURSBhcyBUZXJtU3RhcnQsDQoJTVNTX1NDSEVEVUxFX01BU1RFUi5NU1RfREVTQ1JJUFRJT04gYXMgQ291cnNlTmFtZSwNCglNU1NfQ09VUlNFX1NDSE9PTC5DU0tfQ09VUlNFX05VTUJFUiBhcyBDb3Vyc2VOdW1iZXIsIA0KCU1TU19TQ0hFRFVMRV9NQVNURVIuTVNUX1NFQ1RJT05fTlVNQkVSIGFzIFNlY3Rpb25OdW1iZXIsDQoJTVNTX1NDSEVEVUxFX01BU1RFUi5NU1RfREVTQ1JJUFRJT04gYXMgQ291cnNlRGVzY3JpcHRpb24NCkZST00NCglNU1NfU0NIRURVTEVfTUFTVEVSDQoJTEVGVCBPVVRFUiBKT0lOIE1TU19TQ0hFRFVMRSBPTiBNU1NfU0NIRURVTEVfTUFTVEVSLk1TVF9TQ0hfT0lEPU1TU19TQ0hFRFVMRS5TQ0hfT0lEDQoJTEVGVCBPVVRFUiBKT0lOIE1TU19TQ0hPT0wgT04gTVNTX1NDSEVEVUxFLlNDSF9TS0xfT0lEPU1TU19TQ0hPT0wuU0tMX09JRAkNCglMRUZUIE9VVEVSIEpPSU4gTVNTX1NDSEVEVUxFX1RFUk0gT04gTVNTX1NDSEVEVUxFX01BU1RFUi5NU1RfVFJNX09JRD1NU1NfU0NIRURVTEVfVEVSTS5UUk1fT0lEDQoJTEVGVCBPVVRFUiBKT0lOIE1TU19TQ0hFRFVMRV9URVJNX0RBVEUgT04gTVNTX1NDSEVEVUxFX1RFUk0uVFJNX09JRD1NU1NfU0NIRURVTEVfVEVSTV9EQVRFLlRNRF9UUk1fT0lECQ0KCUxFRlQgT1VURVIgSk9JTiBNU1NfU1RBRkYgT04gTVNTX1NDSEVEVUxFX01BU1RFUi5NU1RfU1RGX09JRF9QUklNQVJZPU1TU19TVEFGRi5TVEZfT0lEDQoJTEVGVCBPVVRFUiBKT0lOIE1TU19DT1VSU0VfU0NIT09MIE9OIE1TU19TQ0hFRFVMRV9NQVNURVIuTVNUX0NTS19PSUQ9TVNTX0NPVVJTRV9TQ0hPT0wuQ1NLX09JRA0KCUxFRlQgT1VURVIgSk9JTiBNU1NfRElTVFJJQ1RfU0NIT09MX1lFQVJfQ09OVEVYVCBPTiBNU1NfU0NIRURVTEUuU0NIX0NUWF9PSUQ9TVNTX0RJU1RSSUNUX1NDSE9PTF9ZRUFSX0NPTlRFWFQuQ1RYX09JRA0KV0hFUkUNCglNU1NfRElTVFJJQ1RfU0NIT09MX1lFQVJfQ09OVEVYVC5DVFhfRklFTERBXzAwMSA9ICdDdXJyZW50Jw0KCUFORCBNU1NfQ09VUlNFX1NDSE9PTC5DU0tfQ09VUlNFX05VTUJFUiBOT1QgSU4gKCdGQVNBJywgJ05BQycsICdBVFQtUE0nLCAnQVRULUFNJykNCglBTkQgTVNTX1NDSEVEVUxFX1RFUk1fREFURS5UTURfRU5EX0RBVEUgSVMgTk9UIE5VTEwNCg0KT1JERVIgQlkgVGVybUVuZCBERVNDOw=="
        size = -1
        hash = "NONE"
        RetrieveSuccess = $false
        RetrieveError = ""
        Uploaded = $false
        UploadError = ""
    },
    @{
        VendorName = "Staff.csv"
        SQLQueryBase64 = "U0VMRUNUDQoJTVNTX1BFUlNPTi5QU05fRU1BSUxfMDEgYXMgJ0VtYWlsJywNCglTVEZfSURfTE9DQUwgYXMgJ0V4dElkJywNCglNU1NfUEVSU09OLlBTTl9OQU1FX0xBU1QgYXMgJ0xhc3ROYW1lJywNCglNU1NfUEVSU09OLlBTTl9OQU1FX0ZJUlNUIGFzICdGaXJzdE5hbWUnLA0KICAgIE1TU19TQ0hPT0wuU0tMX1NDSE9PTF9JRCBhcyAnU2Nob29sSURzJw0KRlJPTQ0KCU1TU19TVEFGRg0KCUxFRlQgT1VURVIgSk9JTiBNU1NfU0NIT09MIE9OIFNURl9TS0xfT0lEPU1TU19TQ0hPT0wuU0tMX09JRA0KCUxFRlQgT1VURVIgSk9JTiBNU1NfUEVSU09OIE9OIFNURl9QU05fT0lEPU1TU19QRVJTT04uUFNOX09JRA0KV0hFUkUNCglTVEZfU1RBVFVTID0gJ0FjdGl2ZScNCglBTkQgTVNTX1NDSE9PTC5TS0xfT0lEIElTIE5PVCBOVUxMDQoJQU5EIFNURl9JRF9TVEFURSBJUyBOVUxMDQpPUkRFUiBCWSANCglTVEZfTkFNRV9WSUVXIEFTQw=="
        size = -1
        hash = "NONE"
        RetrieveSuccess = $false
        RetrieveError = ""
        Uploaded = $false
        UploadError = ""
    },
    @{
        VendorName = "Students.csv"
        SQLQueryBase64 = "U0VMRUNUDQoJTVNTX1BFUlNPTl9BRERSRVNTLkFEUl9PSUQsDQoJTVNTX1BFUlNPTl9BRERSRVNTLkFEUl9DSVRZLA0KCU1TU19QRVJTT05fQUREUkVTUy5BRFJfU1RBVEUsDQoJTVNTX1BFUlNPTl9BRERSRVNTLkFEUl9BRERSRVNTX0xJTkVfMDENCklOVE8gI0xTS1lTRDIwMl9URU1QX01TU19BRERSRVNTDQpGUk9NDQoJTVNTX1BFUlNPTl9BRERSRVNTDQpXSEVSRQ0KCU5PVCAoDQoJCU1TU19QRVJTT05fQUREUkVTUy5BRFJfQ0lUWSBJUyBOVUxMDQoJCUFORCBNU1NfUEVSU09OX0FERFJFU1MuQURSX1NUQVRFIElTIE5VTEwNCgkJQU5EIE1TU19QRVJTT05fQUREUkVTUy5BRFJfQUREUkVTU19MSU5FXzAxIElTIE5VTEwNCgkJKTsNCg0KU0VMRUNUDQoJTVNTX1BFUlNPTi5QU05fT0lELA0KCVRFTVBfQUREUkVTU0VTLkFEUl9DSVRZIGFzICdDaXR5JywgLS0gQ2l0eSBpbiB3aGljaCB0aGUgc3R1ZGVudCByZXNpZGVzDQoJTVNTX1BFUlNPTi5QU05fRU1BSUxfMDEgYXMgJ0VtYWlsJywNCglNU1NfUEVSU09OLlBTTl9QSE9ORV8wMSBhcyAnUGhvbmUnLA0KCVRFTVBfQUREUkVTU0VTLkFEUl9TVEFURSBhcyAnU3RhdGUnLA0KCVRFTVBfQUREUkVTU0VTLkFEUl9BRERSRVNTX0xJTkVfMDEgYXMgJ1N0cmVldCcsDQoJTVNTX1BFUlNPTi5QU05fRklFTERDXzAwMyBhcyAnTGFzdE5hbWUnLA0KCU1TU19QRVJTT04uUFNOX0ZJRUxEQ18wMDEgYXMgJ0ZpcnN0TmFtZScsDQoJTVNTX1BFUlNPTi5QU05fRE9CIGFzICdEYXRlT2ZCaXJ0aCcNCklOVE8gI0xTS1lTRDIwMl9UZW1wX01TU19QRVJTT04NCkZST00NCglNU1NfUEVSU09ODQoJTEVGVCBPVVRFUiBKT0lOICNMU0tZU0QyMDJfVEVNUF9NU1NfQUREUkVTUyBhcyBURU1QX0FERFJFU1NFUyBPTiBNU1NfUEVSU09OLlBTTl9BRFJfT0lEX1BIWVNJQ0FMPVRFTVBfQUREUkVTU0VTLkFEUl9PSUQ7DQoNClNFTEVDVAkNCglURU1QX1BFUlNPTi5DaXR5IGFzICdDaXR5JywgLS0gQ2l0eSBpbiB3aGljaCB0aGUgc3R1ZGVudCByZXNpZGVzDQoJVEVNUF9QRVJTT04uRW1haWwgYXMgJ0VtYWlsJywNCglSRVBMQUNFKFJFUExBQ0UoUkVQTEFDRShSRVBMQUNFKFJFUExBQ0UoUkVQTEFDRShSRVBMQUNFKFJFUExBQ0UoUkVQTEFDRShSRVBMQUNFKFNURF9HUkFERV9MRVZFTCwnMEsnLCdLJyksJzAxJywnMScpLCcwMicsJzInKSwnMDMnLCczJyksJzA0JywnNCcpLCcwNScsJzUnKSwnMDYnLCc2JyksJzA3JywnNycpLCcwOCcsJzgnKSwnMDknLCc5JykgYXMgJ0dyYWRlJywNCglURU1QX1BFUlNPTi5QaG9uZSBhcyAnUGhvbmUnLA0KCVRFTVBfUEVSU09OLlN0YXRlIGFzICdTdGF0ZScsDQoJVEVNUF9QRVJTT04uU3RyZWV0IGFzICdTdHJlZXQnLA0KCVRFTVBfUEVSU09OLkxhc3ROYW1lIGFzICdMYXN0TmFtZScsDQoJTVNTX1NDSE9PTC5TS0xfU0NIT09MX0lEIGFzICdTY2hvb2xJZCcsDQoJVEVNUF9QRVJTT04uRmlyc3ROYW1lIGFzICdGaXJzdE5hbWUnLA0KCSdQcmltYXJ5JyBhcyAnUGhvbmVUeXBlJywNCglURU1QX1BFUlNPTi5EYXRlT2ZCaXJ0aCBhcyAnRGF0ZU9mQmlydGgnLA0KCVNURF9JRF9MT0NBTCBhcyAnU3R1ZGVudE51bWJlcicsIC0tIEludGVybmFsIGRpdmlzaW9uIHN0dWRlbnQgbnVtYmVyDQoJU1REX0lEX0xPQ0FMIGFzICdTdHVkZW50UmVnaW9uSWQnIC0tIFByb3ZpbmNpYWwgc3R1ZGVudCBudW1iZXINCkZST00NCglNU1NfU1RVREVOVA0KCUxFRlQgT1VURVIgSk9JTiBNU1NfU0NIT09MIE9OIE1TU19TVFVERU5ULlNURF9TS0xfT0lEPU1TU19TQ0hPT0wuU0tMX09JRA0KCUxFRlQgT1VURVIgSk9JTiAjTFNLWVNEMjAyX1RlbXBfTVNTX1BFUlNPTiBhcyBURU1QX1BFUlNPTiBPTiBNU1NfU1RVREVOVC5TVERfUFNOX09JRD1URU1QX1BFUlNPTi5QU05fT0lEDQpXSEVSRQ0KCVNURF9FTlJPTExNRU5UX1NUQVRVUyBJTiAoJ0FjdGl2ZScsICdBY3RpdmUgTm8gUHJpbWFyeScpDQoJQU5EIE1TU19TQ0hPT0wuU0tMX09JRCBJUyBOT1QgTlVMTDsNCgkNCkRST1AgVEFCTEUgSUYgRVhJU1RTICNMU0tZU0QyMDJfVGVtcF9NU1NfUEVSU09OOw0KRFJPUCBUQUJMRSBJRiBFWElTVFMgI0xTS1lTRDIwMl9URU1QX01TU19BRERSRVNTOw0KDQo="
        size = -1
        hash = "NONE"
        RetrieveSuccess = $false
        RetrieveError = ""
        Uploaded = $false
        UploadError = ""
    },
    @{
        VendorName = "Teachers.csv"
        SQLQueryBase64 = "U0VMRUNUDQoJTVNTX1BFUlNPTi5QU05fRU1BSUxfMDEgYXMgJ0VtYWlsJywNCglTVEZfSURfTE9DQUwgYXMgJ0V4dElkJywNCglNU1NfUEVSU09OLlBTTl9OQU1FX0xBU1QgYXMgJ0xhc3ROYW1lJywNCglNU1NfUEVSU09OLlBTTl9OQU1FX0ZJUlNUIGFzICdGaXJzdE5hbWUnLA0KICAgIE1TU19TQ0hPT0wuU0tMX1NDSE9PTF9JRCBhcyAnU2Nob29sSURzJw0KRlJPTQ0KCU1TU19TVEFGRg0KCUxFRlQgT1VURVIgSk9JTiBNU1NfU0NIT09MIE9OIFNURl9TS0xfT0lEPU1TU19TQ0hPT0wuU0tMX09JRA0KCUxFRlQgT1VURVIgSk9JTiBNU1NfUEVSU09OIE9OIFNURl9QU05fT0lEPU1TU19QRVJTT04uUFNOX09JRA0KV0hFUkUNCglTVEZfU1RBVFVTID0gJ0FjdGl2ZScNCglBTkQgTVNTX1NDSE9PTC5TS0xfT0lEIElTIE5PVCBOVUxMDQoJQU5EIFNURl9JRF9TVEFURSBJUyBOT1QgTlVMTA0KT1JERVIgQlkgDQoJU1RGX05BTUVfVklFVyBBU0M="
        size = -1
        hash = "NONE"
        RetrieveSuccess = $false
        RetrieveError = ""
        Uploaded = $false
        UploadError = ""
    },
    @{
        VendorName = "Enrolments.csv"
        SQLQueryBase64 = "U0VMRUNUDQoJTVNTX1NDSE9PTC5TS0xfU0NIT09MX0lEIGFzIFNjaG9vbElkLA0KCU1TU19TQ0hFRFVMRV9NQVNURVIuTVNUX09JRCBhcyBTZWN0aW9uSWQsCQ0KCU1TU19TVFVERU5ULlNURF9JRF9MT0NBTCBhcyBTdHVkZW50TnVtYmVyDQpGUk9NDQoJTVNTX1NUVURFTlRfU0NIRURVTEUNCglMRUZUIE9VVEVSIEpPSU4gTVNTX1NUVURFTlQgT04gTVNTX1NUVURFTlRfU0NIRURVTEUuU1NDX1NURF9PSUQ9TVNTX1NUVURFTlQuU1REX09JRA0KCUxFRlQgT1VURVIgSk9JTiBNU1NfU0NIRURVTEVfTUFTVEVSIE9OIE1TU19TVFVERU5UX1NDSEVEVUxFLlNTQ19NU1RfT0lEPU1TU19TQ0hFRFVMRV9NQVNURVIuTVNUX09JRA0KCUxFRlQgT1VURVIgSk9JTiBNU1NfU0NIRURVTEUgT04gTVNTX1NDSEVEVUxFX01BU1RFUi5NU1RfU0NIX09JRD1NU1NfU0NIRURVTEUuU0NIX09JRA0KCUxFRlQgT1VURVIgSk9JTiBNU1NfU0NIT09MIE9OIE1TU19TQ0hFRFVMRS5TQ0hfU0tMX09JRD1NU1NfU0NIT09MLlNLTF9PSUQNCglMRUZUIE9VVEVSIEpPSU4gTVNTX0RJU1RSSUNUX1NDSE9PTF9ZRUFSX0NPTlRFWFQgT04gTVNTX1NDSEVEVUxFLlNDSF9DVFhfT0lEPU1TU19ESVNUUklDVF9TQ0hPT0xfWUVBUl9DT05URVhULkNUWF9PSUQNCldIRVJFDQoJTVNTX1NUVURFTlQuU1REX0VOUk9MTE1FTlRfU1RBVFVTIElOICgnQWN0aXZlJywgJ0FjdGl2ZSBObyBQcmltYXJ5JykNCglBTkQgTVNTX0RJU1RSSUNUX1NDSE9PTF9ZRUFSX0NPTlRFWFQuQ1RYX0ZJRUxEQV8wMDEgPSAnQ3VycmVudCc="
        size = -1
        hash = "NONE"
        RetrieveSuccess = $false
        RetrieveError = ""
        Uploaded = $false
        UploadError = ""
    },
    @{
        VendorName = "StuGuardianCustody.csv"
        SQLQueryBase64 = "U0VMRUNUDQoJTVNTX1NUVURFTlQuU1REX0lEX0xPQ0FMIGFzIFN0dWRlbnRSZWdpb25JZCwNCglDVEpfQ05UX09JRCBhcyBDb250YWN0RXh0SWQsDQoJKENBU0UNCgkJV0hFTiBDVEpfRklFTERBXzAwMSBJUyBOVUxMIFRIRU4gMA0KCQlFTFNFIENUSl9GSUVMREFfMDAxDQogICAgRU5EKSBhcyBJc0N1c3RvZGlhbAkNCkZST00NCglNU1NfU1RVREVOVF9DT05UQUNUDQoJTEVGVCBPVVRFUiBKT0lOIE1TU19TVFVERU5UIE9OIE1TU19TVFVERU5UX0NPTlRBQ1QuQ1RKX1NURF9PSUQ9TVNTX1NUVURFTlQuU1REX09JRA=="
        size = -1
        hash = "NONE"
        RetrieveSuccess = $false
        RetrieveError = ""
        Uploaded = $false
        UploadError = ""
    }
)

# #################################################
# Ensure that necesary folders exist
# #################################################

if ((test-path -Path $ScratchDirectory) -eq $false) {
    New-Item -Path $ScratchDirectory -ItemType Directory
}

if ((test-path -Path $LogDirectory) -eq $false) {
    New-Item -Path $LogDirectory -ItemType Directory
}

$ActualScratchPath = $(Resolve-Path $ScratchDirectory)
$ActualLogPath = $(Resolve-Path $LogDirectory)
$ActualConfigFilePath = $(Resolve-Path $ConfigFile)

$ActualLogFilePath =  "$ActualScratchPath\\log.txt"

# #################################################
# Functions
# #################################################

function LogThis
{
   Param ([string]$logmessage)
   $Stamp = (Get-Date).toString("yyyy/MM/dd HH:mm:ss")
   $Line = "$Stamp $logmessage"
   Add-content $ActualLogFilePath -value $Line
}

function Get-FullTimeStamp {
    $now=get-Date
    $yr=("{0:0000}" -f $now.Year).ToString()
    $mo=("{0:00}" -f $now.Month).ToString()
    $dy=("{0:00}" -f $now.Day).ToString()
    $hr=("{0:00}" -f $now.Hour).ToString()
    $mi=("{0:00}" -f $now.Minute).ToString()
    $timestamp=$yr + "-" + $mo + "-" + $dy + "-" + $hr + $mi
    return $timestamp
}

# #################################################
# Logging
# #################################################

LogThis "Starting $JobName"
LogThis "Scratch path is $ActualScratchPath"
LogThis "Log path is $ActualLogPath"
LogThis "Log file is $ActualLogFilePath"

# #################################################
# Load config file
# #################################################
if ((test-path -Path $ActualConfigFilePath) -eq $false) {
    LogThis "Config file \"$ActualConfigFilePath\" not found."
    Throw "Config file not found. Specify using -ConfigFile."
}

$configXML = [xml](Get-Content $ActualConfigFilePath)
$SevenZipPath = $configXml.Settings.Utilities.SevenZipPath
$LogFilePassword = $configXml.Settings.LogFilePassword
$IES3BucketAccessKey = $configXml.Settings.ImagineEverythingEduForms.S3BucketAccessKey
$IES3BucketSecretKey = $configXml.Settings.ImagineEverythingEduForms.S3BucketSecret
$IES3BucketName = $configXml.Settings.ImagineEverythingEduForms.S3BucketName
$IES3Region = $configXml.Settings.ImagineEverythingEduForms.S3Region
$UtilitiesScriptsRoot = $configXml.Settings.UtilitiesScriptsRoot
$WebHookURL = $configXml.Settings.WebHookURL

$OrigLocation = Get-Location
set-location $ActualScratchPath

# #################################################
# Get CSV files from SQL
# #################################################

LogThis "Starting to get files from SQL..."

foreach($file in $CSVGetFiles) {
    write-host $file.VendorName
    LogThis "Getting file $($file.VendorName) from SQL..."

    $OutFilePath = Join-Path $(Resolve-Path $ScratchDirectory) $file.VendorName
    $QueryLogfilePath = "$($OutFilePath).log"

    LogThis "A log for this query can be found here: $QueryLogfilePath"

    $CombinedParams = @(
        '-Configfile', $ConfigFile,
        '-SQLQueryBase64', $file.SQLQueryBase64,
        '-OutputFile', $OutFilePath
    );

    $attemptSuccess = $false
    $attempts = 0

    while ($attemptSuccess -eq $false) {
        $attempts++
        if ($attempts -gt 5) {
            LogThis "Failed to get file after 5 attempts."
            exit
        }
        try {
            . powershell.exe -Command $UtilitiesScriptsRoot/Get-CSVFromSQL.ps1 $CombinedParams -LogFile $QueryLogfilePath
            $attemptSuccess = $true
        } catch {
            LogThis "Error getting file: $_"
            $file.RetrieveError = $_
            LogThis "Sleeping for $RetrySeconds seconds before trying again..."
            Start-Sleep -Seconds $RetrySeconds
        }
    }

    # Gather some file metadata for logging purposes...

    $ThisFileExists = Test-Path $OutFilePath
    if ($ThisFileExists -eq $true) {

        $file.RetrieveSuccess = $true
        $file.hash = $(Get-FileHash $OutFilePath -Algorithm SHA256).Hash
        $file.size = (Get-Item $OutFilePath).Length

        LogThis "File $OutFilePath obtained. SHA256: $($file.hash), Size: $($file.size) bytes"
    } else {
        $file.RetrieveSuccess = $false

        LogThis "FILE $OutFilePath FAILED TO EXPORT!"
    }

    # Delay so we don't anger the SQL server
    Start-Sleep -Seconds 10
}


# #################################################
# Send files to vendor
# #################################################

write-host "Uploading files to vendor..."
LogThis "Uploading files to vendor..."

try {
    foreach($file in $CSVGetFiles) {
        LogThis "Uploading file $($file.VendorName) to S3..."
        try {
            Write-S3Object -AccessKey $IES3BucketAccessKey -SecretKey $IES3BucketSecretKey -Region $IES3Region -BucketName $IES3BucketName -Key $file.VendorName -File $file.VendorName
            $file.Uploaded = $true
        }
        catch {
            $file.Uploaded = $false
            $file.UploadError = $_
            LogThis "Error uploading file $($file.VendorName) to S3: $_"
        }
    }
}
catch {
    LogThis "Error uploading files to S3: $_"
}


# #################################################
# Clean up scratch directory
# #################################################
LogThis "Compressing and clearing scratch directory, then sending webhook notification. This log file will be included in the compressed file, so you will not see further logs here for this run."

$todayLogFileName = Join-Path $ActualLogPath "$(Get-FullTimeStamp)-$($JobName).7z"
. $SevenZipPath/7za.exe a -t7z $todayLogFileName -mx9 "-p$LogFilePassword" "$ActualScratchPath/*.*" -xr!".placeholder"


# Clear the rest of the scratch folder
Get-ChildItem $ActualScratchPath |
Foreach-Object {
    if ($_.Name -ne ".placeholder") {
        Remove-Item $_.FullName
    }
}

# #################################################
# Send notifications
# #################################################

$AllSuccess = $true
foreach($file in $CSVGetFiles)
{
    if ($file.RetrieveSuccess -eq $false)
    {
        $AllSuccess = $false
    }

    if ($file.Uploaded -eq $false)
    {
        $AllSuccess = $false
    }
}

if (-not [string]::IsNullOrEmpty($WebHookURL))
{
    $WebHookBody = ""
    $WebHookBody += '{
        "@type": "MessageCard",
        "@context": "http://schema.org/extensions",
        "themeColor": "0076D7",
        "summary": "Data sync job results - ' + $JobName + '",
        "sections": [{
            "activityTitle": "Data sync job results - ' + $JobName + '",
            "facts": ['

    if ($AllSuccess -eq $true) {
        $WebHookBody += '{ "name": "Status", "value": "&#x1F603; No errors, probably success" },'
    } else {
        $WebHookBody += '{ "name": "Status", "value": "&#x1F640; Some failures!" },'
    }


    foreach($file in $CSVGetFiles)
    {
        if ($file.RetrieveSuccess -eq $false)
        {
            $WebHookBody += '{ "name": "' + $($file.VendorName) + '", "value": "&#x1F6A8; **Failed to retrieve file from MSS**.\n' + $($file.RetrieveError) + '" },'
        } elseif ($file.Uploaded -eq $false)
        {
            $WebHookBody += '{ "name": "' + $($file.VendorName) + '", "value": "&#x1F6A9; **Failed to upload to vendor**.\n' + $($file.UploadError) + '" },'
        } else {
            $WebHookBody += '{ "name": "' + $($file.VendorName) + '", "value": "'
            $WebHookBody += "**Size:** $($file.size), **SHA256:** $($file.hash)"
            $WebHookBody += '"},'
        }
    }

    $WebHookBody += '
                ],
            "markdown": true
        }]
    }'

    Invoke-RestMethod -Uri $WebHookURL -Method Post -Body $WebHookBody -ContentType "application/json"
}


# #################################################
# Finished
# #################################################

write-host "Done"
set-location $OrigLocation