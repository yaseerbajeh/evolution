# Script to connect WhatsApp to Evolution API
# Instance: MkanTv
# Phone: 966542668201

$apiUrl = "http://localhost:8080"
$apiKey = "BQYHJGJHJ"
$instanceName = "MkanTv"
$phoneNumber = "966542668201"

Write-Host "Checking if Evolution API server is running..." -ForegroundColor Yellow

# Function to check if server is running
function Test-Server {
    try {
        $response = Invoke-WebRequest -Uri "$apiUrl/" -Method Get -TimeoutSec 5 -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

# Wait for server to be available (max 30 seconds)
$maxAttempts = 6
$attempt = 0
$serverRunning = $false

while ($attempt -lt $maxAttempts -and -not $serverRunning) {
    $serverRunning = Test-Server
    if (-not $serverRunning) {
        $attempt++
        Write-Host "Server not running. Waiting 5 seconds... (Attempt $attempt/$maxAttempts)" -ForegroundColor Yellow
        if ($attempt -lt $maxAttempts) {
            Start-Sleep -Seconds 5
        }
    }
}

if (-not $serverRunning) {
    Write-Host "`nERROR: Evolution API server is not running on $apiUrl" -ForegroundColor Red
    Write-Host "`nPlease start the server first using one of these commands:" -ForegroundColor Yellow
    Write-Host "  npm run dev:server    (Development mode with hot reload)" -ForegroundColor Cyan
    Write-Host "  npm start             (Direct execution)" -ForegroundColor Cyan
    Write-Host "  npm run build && npm run start:prod  (Production mode)" -ForegroundColor Cyan
    Write-Host "`nAfter starting the server, run this script again." -ForegroundColor Yellow
    exit 1
}

Write-Host "Server is running! Creating WhatsApp instance..." -ForegroundColor Green

# Create the instance
$headers = @{
    "apikey" = $apiKey
    "Content-Type" = "application/json"
}

$body = @{
    instanceName = $instanceName
    integration = "WHATSAPP-BAILEYS"
    qrcode = $true
    number = $phoneNumber
} | ConvertTo-Json

try {
    Write-Host "`nSending request to create instance '$instanceName'..." -ForegroundColor Cyan
    $response = Invoke-RestMethod -Uri "$apiUrl/instance/create" -Method Post -Headers $headers -Body $body
    
    Write-Host "`n=== Instance Created Successfully ===" -ForegroundColor Green
    Write-Host "Instance Name: $($response.instance.instanceName)" -ForegroundColor White
    Write-Host "Instance ID: $($response.instance.instanceId)" -ForegroundColor White
    Write-Host "Status: $($response.instance.status)" -ForegroundColor White
    Write-Host "Hash Token: $($response.hash)" -ForegroundColor Gray
    
    # Display QR Code
    if ($response.qrcode -and $response.qrcode.base64) {
        Write-Host "`n=== QR CODE FOR WHATSAPP CONNECTION ===" -ForegroundColor Green
        
        # Save QR code to file
        $qrCodePath = "$PSScriptRoot\qrcode-$instanceName.png"
        $base64Data = $response.qrcode.base64 -replace '^data:image/[^;]+;base64,', ''
        [System.Convert]::FromBase64String($base64Data) | Set-Content -Path $qrCodePath -Encoding Byte
        
        Write-Host "QR Code saved to: $qrCodePath" -ForegroundColor Cyan
        Write-Host "`nTo scan the QR code:" -ForegroundColor Yellow
        Write-Host "1. Open WhatsApp on your phone" -ForegroundColor White
        Write-Host "2. Go to Settings > Linked Devices > Link a Device" -ForegroundColor White
        Write-Host "3. Scan the QR code image saved at: $qrCodePath" -ForegroundColor White
        
        if ($response.qrcode.pairingCode) {
            Write-Host "`nPairing Code: $($response.qrcode.pairingCode)" -ForegroundColor Cyan
            Write-Host "You can also use this pairing code instead of scanning the QR code." -ForegroundColor Gray
        }
        
        # Try to open the QR code image
        if (Test-Path $qrCodePath) {
            Write-Host "`nOpening QR code image..." -ForegroundColor Cyan
            Start-Process $qrCodePath
        }
    } else {
        Write-Host "`nWARNING: QR code not found in response" -ForegroundColor Yellow
        Write-Host "Response: $($response | ConvertTo-Json -Depth 10)" -ForegroundColor Gray
    }
    
    Write-Host "`n=== Connection Instructions ===" -ForegroundColor Green
    Write-Host "After scanning the QR code, check connection status with:" -ForegroundColor Yellow
    Write-Host "  GET $apiUrl/instance/connectionState/$instanceName" -ForegroundColor Cyan
    Write-Host "  Header: apikey: $apiKey" -ForegroundColor Cyan
    
} catch {
    Write-Host "`nERROR: Failed to create instance" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.ErrorDetails.Message) {
        Write-Host "Details: $($_.ErrorDetails.Message)" -ForegroundColor Red
    }
    exit 1
}

Write-Host "`nDone! Your WhatsApp instance '$instanceName' is ready for connection." -ForegroundColor Green

