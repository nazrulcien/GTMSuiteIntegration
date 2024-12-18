param (
    [Parameter(Mandatory=$true)]
    [ValidateSet('csv', 'json', 'jsonlines')]
    [string]$FileType,

    [Parameter(Mandatory=$true)]
    [string]$InputFile,

    [Parameter(Mandatory=$true)]
    [string[]]$FieldNames
)

function Hash-Field([string]$value) {
    $parts = $value -split '(?<=@)|(?=@)|(?<=\s)' | Where-Object { $_ -ne '' }

    $hashedParts = foreach ($part in $parts) {
        if ($part -eq '@' -or $part -eq ' ') {
            $hashedPart = $part
        }
        else {
            $sha256 = [System.Security.Cryptography.SHA256]::Create()
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($part)
            $hash = $sha256.ComputeHash($bytes)
            $sha256.Dispose()
            $hashedPart = [System.BitConverter]::ToString($hash) -replace "-"
        }
        $hashedPart
    }

    $combinedHash = $hashedParts -join ''
    return $combinedHash
}

# Read the input file based on the file type
if ($FileType -eq "csv") {
    $data = Import-Csv -Path $InputFile
} elseif ($FileType -eq "json") {
    $data = Get-Content -Raw -Path $InputFile | ConvertFrom-Json
} elseif ($FileType -eq "jsonlines") {
    $data = Get-Content -Path $InputFile | ForEach-Object {
        $_ | ConvertFrom-Json
    }
} else {
    Write-Host "Invalid file type specified."
    exit 1
}

# Hash the specified fields
foreach ($item in $data) {
    foreach ($fieldName in $FieldNames) {
        if ($item.$fieldName) {
            $item.$fieldName = Hash-Field -value $item.$fieldName
        }
    }
}

# Extract the file name from the input file path
$FileName = [System.IO.Path]::GetFileName($InputFile)
# Create a new output file with the hashed fields
$OutputFile = "hashed_$FileName"
if ($FileType -eq "csv") {
    $data | Export-Csv -Path $OutputFile -NoTypeInformation
} elseif ($FileType -eq "json") {
    $data | ConvertTo-Json | Out-File -FilePath $OutputFile
} elseif ($FileType -eq "jsonlines") {
    $data | ForEach-Object { $_ | ConvertTo-Json -Compress } | Out-File -FilePath $OutputFile
}

Write-Host "File with hashed fields created: $OutputFile"