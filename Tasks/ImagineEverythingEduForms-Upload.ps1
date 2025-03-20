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
        SQLQueryBase64 = "U0VMRUNUIA0KCU1TU19QRVJTT04uUFNOX0VNQUlMXzAxIGFzIEVtYWlsLA0KCU1TU19DT05UQUNULkNOVF9PSUQgYXMgRXh0SWQsDQoJTVNTX1BFUlNPTi5QU05fUEhPTkVfMDEgYXMgUGhvbmUsDQoJQ09OQ0FUKE1TU19QRVJTT04uUFNOX05BTUVfRklSU1QsICcgJywgTVNTX1BFUlNPTi5QU05fTkFNRV9MQVNUKSBhcyBGdWxsTmFtZSwNCgknUHJpbWFyeScgYXMgUGhvbmVUeXBlLA0KCU1TU19TVFVERU5UX0NPTlRBQ1QuQ1RKX1JFTEFUSU9OU0hJUF9DT0RFIGFzIFJlbGF0aW9uc2hpcCwNCglNU1NfU1RVREVOVC5TVERfSURfTE9DQUwgYXMgU3R1ZGVudE51bWJlcg0KRlJPTQ0KCU1TU19TVFVERU5UX0NPTlRBQ1QNCglMRUZUIE9VVEVSIEpPSU4gTVNTX0NPTlRBQ1QgT04gTVNTX1NUVURFTlRfQ09OVEFDVC5DVEpfQ05UX09JRD1NU1NfQ09OVEFDVC5DTlRfT0lEDQoJTEVGVCBPVVRFUiBKT0lOIE1TU19QRVJTT04gT04gTVNTX0NPTlRBQ1QuQ05UX1BTTl9PSUQ9TVNTX1BFUlNPTi5QU05fT0lEDQoJTEVGVCBPVVRFUiBKT0lOIE1TU19TVFVERU5UIE9OIE1TU19TVFVERU5UX0NPTlRBQ1QuQ1RKX1NURF9PSUQ9TVNTX1NUVURFTlQuU1REX09JRA0KCUxFRlQgT1VURVIgSk9JTiBNU1NfU0NIT09MIE9OIE1TU19TVFVERU5ULlNURF9TS0xfT0lEPU1TU19TQ0hPT0wuU0tMX09JRA0KV0hFUkUNCglNU1NfU1RVREVOVC5TVERfRU5ST0xMTUVOVF9TVEFUVVMgSU4gKCdBY3RpdmUnLCAnQWN0aXZlIE5vIFByaW1hcnknKQ=="
        size = -1
        hash = "NONE"
        RetrieveSuccess = $false
        RetrieveError = ""
        Uploaded = $false
        UploadError = ""
    },
    @{
        VendorName = "Sections.csv"
        SQLQueryBase64 = "V0lUSCBSYW5rZWRUZWFjaGVycyBBUyAoCglTRUxFQ1QKCQlNVENfTVNUX09JRCwKCQlNU1NfU1RBRkYuU1RGX0lEX0xPQ0FMLAoJCVJPV19OVU1CRVIoKSBPVkVSIChQQVJUSVRJT04gQlkgTVRDX01TVF9PSUQgT1JERVIgQlkgTVRDX1BSSU1BUllfVEVBQ0hFUl9JTkQgREVTQywgTVRDX09JRCkgYXMgdGVhY2hlcl9yYW5rCglGUk9NIAoJCU1TU19TQ0hFRFVMRV9NQVNURVJfVEVBQ0hFUgoJCUxFRlQgT1VURVIgSk9JTiBNU1NfU1RBRkYgT04gTVNTX1NDSEVEVUxFX01BU1RFUl9URUFDSEVSLk1UQ19TVEZfT0lEPU1TU19TVEFGRi5TVEZfT0lECikKU0VMRUNUCglNU1NfU0NIRURVTEVfTUFTVEVSLk1TVF9PSUQsCglNU1NfU0NIRURVTEVfVEVSTV9EQVRFLlRNRF9FTkRfREFURSBhcyBUZXJtRW5kLAoJTVNTX1NDSE9PTC5TS0xfU0NIT09MX0lEIGFzIFNjaG9vbElkLAoJdDEuU1RGX0lEX0xPQ0FMIGFzIFRlYWNoZXIxLAoJdDIuU1RGX0lEX0xPQ0FMIGFzIFRlYWNoZXIyLAoJdDMuU1RGX0lEX0xPQ0FMIGFzIFRlYWNoZXIzLAoJTVNTX1NDSEVEVUxFX1RFUk0uVFJNX1RFUk1fTkFNRSBhcyBUZXJtTmFtZSwKCU1TU19TQ0hFRFVMRV9NQVNURVIuTVNUX09JRCBhcyBTZWN0aW9uSWQsCglNU1NfU0NIRURVTEVfVEVSTV9EQVRFLlRNRF9TVEFSVF9EQVRFIGFzIFRlcm1TdGFydCwKCU1TU19TQ0hFRFVMRV9NQVNURVIuTVNUX0RFU0NSSVBUSU9OIGFzIENvdXJzZU5hbWUsCglNU1NfQ09VUlNFX1NDSE9PTC5DU0tfQ09VUlNFX05VTUJFUiBhcyBDb3Vyc2VOdW1iZXIsIAoJTVNTX1NDSEVEVUxFX01BU1RFUi5NU1RfU0VDVElPTl9OVU1CRVIgYXMgU2VjdGlvbk51bWJlciwKCU1TU19TQ0hFRFVMRV9NQVNURVIuTVNUX0RFU0NSSVBUSU9OIGFzIENvdXJzZURlc2NyaXB0aW9uCkZST00KCU1TU19TQ0hFRFVMRV9NQVNURVIKCUxFRlQgT1VURVIgSk9JTiBNU1NfU0NIRURVTEUgT04gTVNTX1NDSEVEVUxFX01BU1RFUi5NU1RfU0NIX09JRD1NU1NfU0NIRURVTEUuU0NIX09JRAoJTEVGVCBPVVRFUiBKT0lOIE1TU19TQ0hPT0wgT04gTVNTX1NDSEVEVUxFLlNDSF9TS0xfT0lEPU1TU19TQ0hPT0wuU0tMX09JRAkKCUxFRlQgT1VURVIgSk9JTiBNU1NfU0NIRURVTEVfVEVSTSBPTiBNU1NfU0NIRURVTEVfTUFTVEVSLk1TVF9UUk1fT0lEPU1TU19TQ0hFRFVMRV9URVJNLlRSTV9PSUQKCUxFRlQgT1VURVIgSk9JTiBNU1NfU0NIRURVTEVfVEVSTV9EQVRFIE9OIE1TU19TQ0hFRFVMRV9URVJNLlRSTV9PSUQ9TVNTX1NDSEVEVUxFX1RFUk1fREFURS5UTURfVFJNX09JRAkJCglMRUZUIE9VVEVSIEpPSU4gTVNTX0NPVVJTRV9TQ0hPT0wgT04gTVNTX1NDSEVEVUxFX01BU1RFUi5NU1RfQ1NLX09JRD1NU1NfQ09VUlNFX1NDSE9PTC5DU0tfT0lECglMRUZUIE9VVEVSIEpPSU4gTVNTX0RJU1RSSUNUX1NDSE9PTF9ZRUFSX0NPTlRFWFQgT04gTVNTX1NDSEVEVUxFLlNDSF9DVFhfT0lEPU1TU19ESVNUUklDVF9TQ0hPT0xfWUVBUl9DT05URVhULkNUWF9PSUQKCUxFRlQgT1VURVIgSk9JTiBSYW5rZWRUZWFjaGVycyB0MSBPTiBNU1NfU0NIRURVTEVfTUFTVEVSLk1TVF9PSUQ9dDEuTVRDX01TVF9PSUQgQU5EIHQxLnRlYWNoZXJfcmFuaz0xCglMRUZUIE9VVEVSIEpPSU4gUmFua2VkVGVhY2hlcnMgdDIgT04gTVNTX1NDSEVEVUxFX01BU1RFUi5NU1RfT0lEPXQyLk1UQ19NU1RfT0lEIEFORCB0Mi50ZWFjaGVyX3Jhbms9MgoJTEVGVCBPVVRFUiBKT0lOIFJhbmtlZFRlYWNoZXJzIHQzIE9OIE1TU19TQ0hFRFVMRV9NQVNURVIuTVNUX09JRD10My5NVENfTVNUX09JRCBBTkQgdDMudGVhY2hlcl9yYW5rPTMKV0hFUkUKCU1TU19ESVNUUklDVF9TQ0hPT0xfWUVBUl9DT05URVhULkNUWF9GSUVMREFfMDAxID0gJ0N1cnJlbnQnCglBTkQgTVNTX0NPVVJTRV9TQ0hPT0wuQ1NLX0NPVVJTRV9OVU1CRVIgTk9UIElOICgnRkFTQScsICdOQUMnKQoJQU5EIE1TU19TQ0hFRFVMRV9URVJNX0RBVEUuVE1EX0VORF9EQVRFIElTIE5PVCBOVUxMCk9SREVSIEJZIFRlcm1FbmQgREVTQzs="
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
        SQLQueryBase64 = "U0VMRUNUCglNU1NfUEVSU09OX0FERFJFU1MuQURSX09JRCwKCU1TU19QRVJTT05fQUREUkVTUy5BRFJfQ0lUWSwKCU1TU19QRVJTT05fQUREUkVTUy5BRFJfU1RBVEUsCglNU1NfUEVSU09OX0FERFJFU1MuQURSX0FERFJFU1NfTElORV8wMQpJTlRPICNMU0tZU0QyMDJfVEVNUF9NU1NfQUREUkVTUwpGUk9NCglNU1NfUEVSU09OX0FERFJFU1MKV0hFUkUKCU5PVCAoCgkJTVNTX1BFUlNPTl9BRERSRVNTLkFEUl9DSVRZIElTIE5VTEwKCQlBTkQgTVNTX1BFUlNPTl9BRERSRVNTLkFEUl9TVEFURSBJUyBOVUxMCgkJQU5EIE1TU19QRVJTT05fQUREUkVTUy5BRFJfQUREUkVTU19MSU5FXzAxIElTIE5VTEwKCQkpOwoKU0VMRUNUCglNU1NfUEVSU09OLlBTTl9PSUQsCglURU1QX0FERFJFU1NFUy5BRFJfQ0lUWSBhcyAnQ2l0eScsIC0tIENpdHkgaW4gd2hpY2ggdGhlIHN0dWRlbnQgcmVzaWRlcwoJTVNTX1BFUlNPTi5QU05fRU1BSUxfMDEgYXMgJ0VtYWlsJywKCU1TU19QRVJTT04uUFNOX1BIT05FXzAxIGFzICdQaG9uZScsCglURU1QX0FERFJFU1NFUy5BRFJfU1RBVEUgYXMgJ1N0YXRlJywKCVRFTVBfQUREUkVTU0VTLkFEUl9BRERSRVNTX0xJTkVfMDEgYXMgJ1N0cmVldCcsCglNU1NfUEVSU09OLlBTTl9GSUVMRENfMDAzIGFzICdMYXN0TmFtZScsCglNU1NfUEVSU09OLlBTTl9GSUVMRENfMDAxIGFzICdGaXJzdE5hbWUnLAoJTVNTX1BFUlNPTi5QU05fRE9CIGFzICdEYXRlT2ZCaXJ0aCcKSU5UTyAjTFNLWVNEMjAyX1RlbXBfTVNTX1BFUlNPTgpGUk9NCglNU1NfUEVSU09OCglMRUZUIE9VVEVSIEpPSU4gI0xTS1lTRDIwMl9URU1QX01TU19BRERSRVNTIGFzIFRFTVBfQUREUkVTU0VTIE9OIE1TU19QRVJTT04uUFNOX0FEUl9PSURfUEhZU0lDQUw9VEVNUF9BRERSRVNTRVMuQURSX09JRDsKClNFTEVDVAkKCVRFTVBfUEVSU09OLkNpdHkgYXMgJ0NpdHknLCAtLSBDaXR5IGluIHdoaWNoIHRoZSBzdHVkZW50IHJlc2lkZXMKCVRFTVBfUEVSU09OLkVtYWlsIGFzICdFbWFpbCcsCglSRVBMQUNFKFJFUExBQ0UoUkVQTEFDRShSRVBMQUNFKFJFUExBQ0UoUkVQTEFDRShSRVBMQUNFKFJFUExBQ0UoUkVQTEFDRShSRVBMQUNFKFNURF9HUkFERV9MRVZFTCwnMEsnLCdLJyksJzAxJywnMScpLCcwMicsJzInKSwnMDMnLCczJyksJzA0JywnNCcpLCcwNScsJzUnKSwnMDYnLCc2JyksJzA3JywnNycpLCcwOCcsJzgnKSwnMDknLCc5JykgYXMgJ0dyYWRlJywKCVRFTVBfUEVSU09OLlBob25lIGFzICdQaG9uZScsCglURU1QX1BFUlNPTi5TdGF0ZSBhcyAnU3RhdGUnLAoJVEVNUF9QRVJTT04uU3RyZWV0IGFzICdTdHJlZXQnLAoJVEVNUF9QRVJTT04uTGFzdE5hbWUgYXMgJ0xhc3ROYW1lJywKCU1TU19TQ0hPT0wuU0tMX1NDSE9PTF9JRCBhcyAnU2Nob29sSWQnLAoJVEVNUF9QRVJTT04uRmlyc3ROYW1lIGFzICdGaXJzdE5hbWUnLAoJJ1ByaW1hcnknIGFzICdQaG9uZVR5cGUnLAoJVEVNUF9QRVJTT04uRGF0ZU9mQmlydGggYXMgJ0RhdGVPZkJpcnRoJywKCVNURF9JRF9MT0NBTCBhcyAnU3R1ZGVudE51bWJlcicsIC0tIEludGVybmFsIGRpdmlzaW9uIHN0dWRlbnQgbnVtYmVyCglTVERfSURfU1RBVEUgYXMgJ1N0dWRlbnRSZWdpb25JZCcgLS0gUHJvdmluY2lhbCBzdHVkZW50IG51bWJlcgpGUk9NCglNU1NfU1RVREVOVAoJTEVGVCBPVVRFUiBKT0lOIE1TU19TQ0hPT0wgT04gTVNTX1NUVURFTlQuU1REX1NLTF9PSUQ9TVNTX1NDSE9PTC5TS0xfT0lECglMRUZUIE9VVEVSIEpPSU4gI0xTS1lTRDIwMl9UZW1wX01TU19QRVJTT04gYXMgVEVNUF9QRVJTT04gT04gTVNTX1NUVURFTlQuU1REX1BTTl9PSUQ9VEVNUF9QRVJTT04uUFNOX09JRApXSEVSRQoJU1REX0VOUk9MTE1FTlRfU1RBVFVTIElOICgnQWN0aXZlJywgJ0FjdGl2ZSBObyBQcmltYXJ5JykKCUFORCBNU1NfU0NIT09MLlNLTF9PSUQgSVMgTk9UIE5VTEwKCQpEUk9QIFRBQkxFIElGIEVYSVNUUyAjTFNLWVNEMjAyX1RlbXBfTVNTX1BFUlNPTjsKRFJPUCBUQUJMRSBJRiBFWElTVFMgI0xTS1lTRDIwMl9URU1QX01TU19BRERSRVNTOw=="
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
        SQLQueryBase64 = "U0VMRUNUDQoJTVNTX1NDSE9PTC5TS0xfU0NIT09MX0lEIGFzIFNjaG9vbElkLA0KCU1TU19TQ0hFRFVMRV9NQVNURVIuTVNUX09JRCBhcyBTZWN0aW9uSWQsCQ0KCU1TU19TVFVERU5ULlNURF9JRF9MT0NBTCBhcyBTdHVkZW50TnVtYmVyDQpGUk9NDQoJTVNTX1NUVURFTlQNCglMRUZUIE9VVEVSIEpPSU4gTVNTX1NUVURFTlRfU0NIRURVTEUgT04gTVNTX1NUVURFTlQuU1REX09JRD1NU1NfU1RVREVOVF9TQ0hFRFVMRS5TU0NfU1REX09JRAkNCglMRUZUIE9VVEVSIEpPSU4gTVNTX1NDSEVEVUxFX01BU1RFUiBPTiBNU1NfU1RVREVOVF9TQ0hFRFVMRS5TU0NfTVNUX09JRD1NU1NfU0NIRURVTEVfTUFTVEVSLk1TVF9PSUQNCglMRUZUIE9VVEVSIEpPSU4gTVNTX1NDSEVEVUxFIE9OIE1TU19TQ0hFRFVMRV9NQVNURVIuTVNUX1NDSF9PSUQ9TVNTX1NDSEVEVUxFLlNDSF9PSUQNCglMRUZUIE9VVEVSIEpPSU4gTVNTX0RJU1RSSUNUX1NDSE9PTF9ZRUFSX0NPTlRFWFQgT04gTVNTX1NDSEVEVUxFLlNDSF9DVFhfT0lEPU1TU19ESVNUUklDVF9TQ0hPT0xfWUVBUl9DT05URVhULkNUWF9PSUQNCglMRUZUIE9VVEVSIEpPSU4gTVNTX1NDSE9PTCBPTiBNU1NfU0NIRURVTEUuU0NIX1NLTF9PSUQ9TVNTX1NDSE9PTC5TS0xfT0lEDQpXSEVSRQ0KCU1TU19TVFVERU5ULlNURF9FTlJPTExNRU5UX1NUQVRVUyBJTiAoJ0FjdGl2ZScsICdBY3RpdmUgTm8gUHJpbWFyeScpDQoJQU5EIE1TU19ESVNUUklDVF9TQ0hPT0xfWUVBUl9DT05URVhULkNUWF9GSUVMREFfMDAxID0gJ0N1cnJlbnQn"
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