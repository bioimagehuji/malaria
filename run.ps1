Add-Type -AssemblyName System.Windows.Forms
$OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
#$OpenFileDialog.InitialDirectory = “C:\”
$OpenFileDialog.Title = "Please select image file"

$OpenFileDialog.ShowDialog()
$ImageFile = $OpenFileDialog.FileName

$env:MALARIA_IMAGE = $ImageFile
Write-Host "MALARIA_IMAGE: '$env:MALARIA_IMAGE'"
$env:MAX_CROPS = 1  # Limit number of crops per series in crop.ijm. 0 is unlimited.
Write-Host "MAX_CROPS: '$env:MAX_CROPS'"
$env:MALARIA_SHELL_SCRIPT = 1  # Tell the ImageJ macros that they are called from a shell script
Write-Host "MALARIA_SHELL_SCRIPT: '$env:MALARIA_SHELL_SCRIPT'" 

# Crop
# Check if crops directory already exists
$crops_dir = "$((Get-Item $ImageFile ).DirectoryName)\$((Get-Item $ImageFile ).Basename)_crops"
Write-Host "crops_dir = $crops_dir"
if (Test-Path $crops_dir ) {
  Write-Warning "Skipping crop.ijm. Crops directory already exists: $crops_dir "
} else {
  Start-Process -FilePath ..\Fiji.app\ImageJ-win64.exe -ArgumentList "--console -macro ./crop.ijm " -NoNewWindow -Wait
}


# Analyze
# Check if shpreadsheets directory already exists
$spreadsheets_dir = "$((Get-Item $ImageFile ).DirectoryName)\$((Get-Item $ImageFile ).Basename)_spreadsheets"
Write-Host "spreadsheets_dir = $spreadsheets_dir"
if (Test-Path $spreadsheets_dir ) {
  Write-Warning "Skipping analyze_crop.ijm. Spreadsheet directory already exists: $spreadsheets_dir "
} else {
  Start-Process -FilePath ..\Fiji.app\ImageJ-win64.exe -ArgumentList "--console -macro ./analyze_crop.ijm " -NoNewWindow -Wait
}

# Finished
Write-Host "Finished ps1 script"