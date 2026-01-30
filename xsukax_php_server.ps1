# ============================================================================
# xsukax PHP Server - Standalone PHP Server for Windows
# Version: 1.0.0
# Author: xsukax
# License: GPL v3.0
# 
# A single-file PHP server with automatic PHP download and configuration
# No external dependencies required - downloads PHP automatically
# ============================================================================

# Configuration
$port = 8080
$phpFolder = "php"
$wwwFolder = "www"
$serverName = "xsukax PHP Server v1.0"

# Get script directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if ([string]::IsNullOrEmpty($scriptDir)) { $scriptDir = Get-Location }
$phpPath = Join-Path $scriptDir $phpFolder
$wwwPath = Join-Path $scriptDir $wwwFolder

# Display banner
Clear-Host
Write-Host ""
Write-Host "========================================================================" -ForegroundColor Cyan
Write-Host " xsukax PHP Server v1.0" -ForegroundColor Cyan
Write-Host " Standalone PHP Server for Windows" -ForegroundColor Cyan
Write-Host "========================================================================" -ForegroundColor Cyan
Write-Host ""

# Function to download file with progress
function Download-File {
    param (
        [string]$url,
        [string]$output
    )
    
    try {
        Write-Host "[*] Downloading from: $url" -ForegroundColor Yellow
        Write-Host "[*] Saving to: $output" -ForegroundColor Yellow
        Write-Host "[*] Please wait, this may take a few minutes..." -ForegroundColor Yellow
        
        # Use Invoke-WebRequest for more reliable downloads
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $url -OutFile $output -UseBasicParsing
        $ProgressPreference = 'Continue'
        
        # Verify file was downloaded and has content
        if (Test-Path $output) {
            $fileSize = (Get-Item $output).Length
            if ($fileSize -gt 1MB) {
                Write-Host "[+] Download completed! File size: $([math]::Round($fileSize/1MB, 2)) MB" -ForegroundColor Green
                return $true
            }
            else {
                Write-Host "[ERROR] Downloaded file is too small ($fileSize bytes). Download may have failed." -ForegroundColor Red
                return $false
            }
        }
        else {
            Write-Host "[ERROR] File was not created." -ForegroundColor Red
            return $false
        }
    }
    catch {
        Write-Host "[ERROR] Download failed: $_" -ForegroundColor Red
        return $false
    }
}

# Function to extract ZIP file
function Extract-ZipFile {
    param (
        [string]$zipFile,
        [string]$destination
    )
    
    try {
        Write-Host "[*] Extracting PHP to: $destination" -ForegroundColor Yellow
        
        # Ensure destination exists
        if (-not (Test-Path $destination)) {
            New-Item -ItemType Directory -Path $destination -Force | Out-Null
        }
        
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($zipFile, $destination)
        
        # Verify extraction
        if (Test-Path (Join-Path $destination "php.exe")) {
            Write-Host "[+] Extraction completed successfully!" -ForegroundColor Green
            return $true
        }
        else {
            Write-Host "[ERROR] Extraction completed but php.exe not found." -ForegroundColor Red
            return $false
        }
    }
    catch {
        Write-Host "[ERROR] Extraction failed: $_" -ForegroundColor Red
        Write-Host "[TIP] Try deleting the 'php' folder and running the script again." -ForegroundColor Yellow
        return $false
    }
}

# Check if PHP is already installed
$phpExe = Join-Path $phpPath "php.exe"
if (-not (Test-Path $phpExe)) {
    Write-Host "[!] PHP not found. Let's download it!" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Available PHP Versions (NTS x64 - Recommended):" -ForegroundColor Cyan
    Write-Host "  1. PHP 8.5.1 (Latest - VS17)"
    Write-Host "  2. PHP 8.4.16 (Stable - VS17)"
    Write-Host "  3. PHP 8.3.29 (Stable - VS16 - Recommended)"
    Write-Host "  4. PHP 8.2.30 (Stable - VS16)"
    Write-Host "  5. PHP 8.1.34 (Legacy - VS16)"
    Write-Host ""
    
    $choice = Read-Host "Select PHP version (1-5, default: 3)"
    
    if ([string]::IsNullOrWhiteSpace($choice)) {
        $choice = "3"
    }
    
    # Real download URLs from windows.php.net
    $phpVersions = @{
        "1" = @{ 
            Version = "8.5.1"
            URL = "https://windows.php.net/downloads/releases/php-8.5.1-nts-Win32-vs17-x64.zip"
        }
        "2" = @{ 
            Version = "8.4.16"
            URL = "https://windows.php.net/downloads/releases/php-8.4.16-nts-Win32-vs17-x64.zip"
        }
        "3" = @{ 
            Version = "8.3.29"
            URL = "https://windows.php.net/downloads/releases/php-8.3.29-nts-Win32-vs16-x64.zip"
        }
        "4" = @{ 
            Version = "8.2.30"
            URL = "https://windows.php.net/downloads/releases/php-8.2.30-nts-Win32-vs16-x64.zip"
        }
        "5" = @{ 
            Version = "8.1.34"
            URL = "https://windows.php.net/downloads/releases/php-8.1.34-nts-Win32-vs16-x64.zip"
        }
    }
    
    if (-not $phpVersions.ContainsKey($choice)) {
        Write-Host "[!] Invalid choice. Using PHP 8.3.29 by default." -ForegroundColor Yellow
        $choice = "3"
    }
    
    $selectedPHP = $phpVersions[$choice]
    Write-Host ""
    Write-Host "[*] Selected: PHP $($selectedPHP.Version)" -ForegroundColor Green
    Write-Host "[*] Preparing to download..." -ForegroundColor Yellow
    Write-Host ""
    
    # Create PHP folder
    if (-not (Test-Path $phpPath)) {
        New-Item -ItemType Directory -Path $phpPath -Force | Out-Null
    }
    
    # Download PHP
    $zipFile = Join-Path $scriptDir "php-temp.zip"
    
    # Clean up any existing temp file
    if (Test-Path $zipFile) {
        Write-Host "[*] Removing old temporary file..." -ForegroundColor Yellow
        Remove-Item $zipFile -Force
    }
    
    $downloadSuccess = Download-File -url $selectedPHP.URL -output $zipFile
    
    if (-not $downloadSuccess) {
        Write-Host "[ERROR] Failed to download PHP. Please check your internet connection." -ForegroundColor Red
        Write-Host "[TIP] You can manually download PHP from: $($selectedPHP.URL)" -ForegroundColor Yellow
        Write-Host "[TIP] Then extract it to: $phpPath" -ForegroundColor Yellow
        Read-Host "Press Enter to exit"
        exit 1
    }
    
    # Verify ZIP file integrity before extraction
    Write-Host "[*] Verifying download integrity..." -ForegroundColor Yellow
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $zip = [System.IO.Compression.ZipFile]::OpenRead($zipFile)
        $entryCount = $zip.Entries.Count
        $zip.Dispose()
        Write-Host "[+] ZIP file verified: $entryCount files found" -ForegroundColor Green
    }
    catch {
        Write-Host "[ERROR] Downloaded file appears to be corrupted." -ForegroundColor Red
        Write-Host "[ERROR] $_" -ForegroundColor Red
        if (Test-Path $zipFile) { Remove-Item $zipFile -Force }
        Write-Host "[TIP] Please try running the script again." -ForegroundColor Yellow
        Write-Host "[TIP] Or manually download from: $($selectedPHP.URL)" -ForegroundColor Yellow
        Read-Host "Press Enter to exit"
        exit 1
    }
    
    # Extract PHP
    $extractSuccess = Extract-ZipFile -zipFile $zipFile -destination $phpPath
    
    # Cleanup
    if (Test-Path $zipFile) {
        Write-Host "[*] Cleaning up temporary files..." -ForegroundColor Yellow
        Remove-Item $zipFile -Force
    }
    
    if (-not $extractSuccess) {
        Write-Host "[ERROR] Failed to extract PHP." -ForegroundColor Red
        Read-Host "Press Enter to exit"
        exit 1
    }
    
    Write-Host ""
    Write-Host "[+] PHP $($selectedPHP.Version) installed successfully!" -ForegroundColor Green
    Write-Host ""
}
else {
    # Get PHP version
    $phpVersion = & $phpExe -v 2>$null | Select-Object -First 1
    Write-Host "[+] PHP already installed: $phpVersion" -ForegroundColor Green
    Write-Host ""
}

# Create www folder if it doesn't exist
if (-not (Test-Path $wwwPath)) {
    Write-Host "[*] Creating www folder..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $wwwPath -Force | Out-Null
    Write-Host "[+] WWW folder created: $wwwPath" -ForegroundColor Green
}
else {
    Write-Host "[+] WWW folder found: $wwwPath" -ForegroundColor Green
}

# Only create index.php if www folder is empty or doesn't have index.php
$indexPhpPath = Join-Path $wwwPath "index.php"
if (-not (Test-Path $indexPhpPath)) {
    Write-Host "[*] Creating default index.php..." -ForegroundColor Yellow
    
    # Create default index.php (will show server info after server starts)
    $indexPhp = @"
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>xsukax PHP Server</title>
    <style>
        body { font-family: 'Segoe UI', Arial, sans-serif; margin: 0; padding: 0; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); min-height: 100vh; display: flex; align-items: center; justify-content: center; }
        .container { background: white; border-radius: 10px; padding: 40px; max-width: 700px; box-shadow: 0 10px 40px rgba(0,0,0,0.2); }
        h1 { color: #667eea; margin: 0 0 10px 0; }
        .version { color: #999; font-size: 0.9em; margin-bottom: 20px; }
        .status { background: #4CAF50; color: white; padding: 10px 20px; border-radius: 5px; display: inline-block; margin: 20px 0; }
        .info { background: #f5f5f5; padding: 15px; border-left: 4px solid #667eea; margin: 20px 0; }
        .php-info { background: #e8f4f8; padding: 15px; border-left: 4px solid #2196F3; margin: 20px 0; }
        code { background: #f0f0f0; padding: 2px 6px; border-radius: 3px; font-family: 'Courier New', monospace; }
        .footer { margin-top: 30px; padding-top: 20px; border-top: 1px solid #eee; color: #999; font-size: 0.9em; text-align: center; }
        table { width: 100%; border-collapse: collapse; margin: 10px 0; }
        td { padding: 8px; border-bottom: 1px solid #eee; }
        td:first-child { font-weight: bold; color: #667eea; width: 40%; }
    </style>
</head>
<body>
    <div class="container">
        <h1>xsukax PHP Server</h1>
        <div class="version">Version 1.0.0</div>
        <div class="status">&#10003; Server is Running</div>
        
        <div class="php-info">
            <strong>PHP Information:</strong>
            <table>
                <tr><td>PHP Version</td><td><?php echo phpversion(); ?></td></tr>
                <tr><td>Server Software</td><td><?php echo `$_SERVER['SERVER_SOFTWARE']; ?></td></tr>
                <tr><td>Document Root</td><td><?php echo `$_SERVER['DOCUMENT_ROOT']; ?></td></tr>
                <tr><td>Server Time</td><td><?php echo date('Y-m-d H:i:s'); ?></td></tr>
                <tr><td>Current Script</td><td><?php echo `$_SERVER['SCRIPT_NAME']; ?></td></tr>
            </table>
        </div>
        
        <div class="info">
            <strong>Welcome!</strong> Your PHP server is successfully running.<br><br>
            Place your PHP files in the <code>www</code> folder to serve them.
        </div>
        
        <div class="info">
            <strong>Features:</strong>
            <ul>
                <li>Automatic PHP installation and configuration</li>
                <li>PHP <?php echo PHP_MAJOR_VERSION . '.' . PHP_MINOR_VERSION; ?> support</li>
                <li>Directory browsing support</li>
                <li>Single-file deployment</li>
            </ul>
        </div>
        
        <div class="info">
            <strong>Test PHP:</strong><br>
            <?php
                echo "<code>Server current time: " . date('H:i:s') . "</code><br>";
                echo "<code>PHP is working correctly!</code>";
            ?>
        </div>
        
        <div class="footer">
            Created by xsukax | GPL v3.0 License
        </div>
    </div>
</body>
</html>
"@
    $indexPhp | Out-File -FilePath $indexPhpPath -Encoding UTF8
    Write-Host "[+] Created default index.php" -ForegroundColor Green
}

Write-Host ""
Write-Host "[*] Initializing HTTP Listener with PHP support..." -ForegroundColor Yellow
Write-Host "[*] Port: $port"
Write-Host "[*] Document Root: $wwwPath"
Write-Host "[*] PHP Executable: $phpExe"
Write-Host ""

# MIME types
$mimeTypes = @{
    '.html' = 'text/html'; '.htm' = 'text/html'; '.css' = 'text/css'
    '.js' = 'application/javascript'; '.json' = 'application/json'
    '.xml' = 'application/xml'; '.txt' = 'text/plain'
    '.jpg' = 'image/jpeg'; '.jpeg' = 'image/jpeg'; '.png' = 'image/png'
    '.gif' = 'image/gif'; '.bmp' = 'image/bmp'; '.ico' = 'image/x-icon'
    '.svg' = 'image/svg+xml'; '.webp' = 'image/webp'
    '.pdf' = 'application/pdf'; '.zip' = 'application/zip'
    '.mp3' = 'audio/mpeg'; '.mp4' = 'video/mp4'; '.webm' = 'video/webm'
    '.woff' = 'font/woff'; '.woff2' = 'font/woff2'; '.ttf' = 'font/ttf'
    '.eot' = 'application/vnd.ms-fontobject'; '.otf' = 'font/otf'
    '.php' = 'text/html'
}

try {
    $listener = New-Object System.Net.HttpListener
    $listener.Prefixes.Add("http://+:$port/")
    $listener.Start()
    
    Write-Host "========================================================================" -ForegroundColor Green
    Write-Host "[+] SERVER STARTED SUCCESSFULLY" -ForegroundColor Green
    Write-Host "========================================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Access the server at:"
    Write-Host "  > http://localhost:$port/" -ForegroundColor Cyan
    Write-Host "  > http://127.0.0.1:$port/" -ForegroundColor Cyan
    
    # Get local IP addresses
    try {
        $ips = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -ne '127.0.0.1' -and $_.PrefixOrigin -ne 'WellKnown' }
        foreach ($ip in $ips) {
            Write-Host "  > http://$($ip.IPAddress):$port/" -ForegroundColor Cyan
        }
    }
    catch {
        # Fallback if Get-NetIPAddress fails
        Write-Host "  > Check your local network IP manually" -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Host "Press Ctrl+C to stop the server" -ForegroundColor Yellow
    Write-Host "========================================================================" -ForegroundColor Green
    Write-Host ""
    
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response
        
        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $urlPath = $request.Url.LocalPath
        
        # Default to index.php
        if ($urlPath -eq '/') { $urlPath = '/index.php' }
        
        $filePath = Join-Path $wwwPath $urlPath.TrimStart('/')
        
        Write-Host "[$timestamp]" -ForegroundColor Yellow -NoNewline
        Write-Host " $($request.HttpMethod)" -ForegroundColor Cyan -NoNewline
        Write-Host " $urlPath" -NoNewline
        Write-Host " from $($request.RemoteEndPoint.Address)" -ForegroundColor Gray
        
        # Handle directories
        if (Test-Path $filePath -PathType Container) {
            $indexPhpPath = Join-Path $filePath 'index.php'
            $indexHtmlPath = Join-Path $filePath 'index.html'
            
            if (Test-Path $indexPhpPath) {
                $filePath = $indexPhpPath
            }
            elseif (Test-Path $indexHtmlPath) {
                $filePath = $indexHtmlPath
            }
            else {
                # Generate directory listing
                $items = Get-ChildItem -Path $filePath
                $html = @"
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Directory Listing</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }
        h1 { color: #667eea; border-bottom: 2px solid #667eea; padding-bottom: 10px; }
        ul { list-style: none; padding: 0; }
        li { background: white; margin: 5px 0; padding: 10px; border-radius: 5px; }
        a { text-decoration: none; color: #333; }
        a:hover { color: #667eea; }
        .size { color: #999; float: right; }
    </style>
</head>
<body>
    <h1>Directory: $urlPath</h1>
    <ul>
"@
                if ($urlPath -ne '/') {
                    $parentPath = Split-Path $urlPath -Parent
                    if ([string]::IsNullOrEmpty($parentPath)) { $parentPath = '/' }
                    $html += "<li><a href=`"$parentPath`">.. (Parent Directory)</a></li>`n"
                }
                
                foreach ($item in $items) {
                    $itemPath = $urlPath.TrimEnd('/') + '/' + $item.Name
                    if ($item.PSIsContainer) {
                        $html += "<li><a href=`"$itemPath/`">$($item.Name)/</a></li>`n"
                    }
                    else {
                        $size = if ($item.Length -lt 1KB) { 
                            "$($item.Length) B" 
                        } 
                        elseif ($item.Length -lt 1MB) { 
                            "{0:N2} KB" -f ($item.Length / 1KB) 
                        } 
                        else { 
                            "{0:N2} MB" -f ($item.Length / 1MB) 
                        }
                        $html += "<li><a href=`"$itemPath`">$($item.Name)</a> <span class=`"size`">$size</span></li>`n"
                    }
                }
                
                $html += @"
    </ul>
    <hr>
    <p style="color:#999">$serverName</p>
</body>
</html>
"@
                $buffer = [System.Text.Encoding]::UTF8.GetBytes($html)
                $response.ContentType = 'text/html; charset=utf-8'
                $response.ContentLength64 = $buffer.Length
                $response.StatusCode = 200
                $response.OutputStream.Write($buffer, 0, $buffer.Length)
                $response.OutputStream.Close()
                continue
            }
        }
        
        # Serve file
        if (Test-Path $filePath -PathType Leaf) {
            $ext = [System.IO.Path]::GetExtension($filePath).ToLower()
            
            # Execute PHP files
            if ($ext -eq '.php') {
                try {
                    # Set environment variables for PHP
                    $env:SCRIPT_FILENAME = $filePath
                    $env:REDIRECT_STATUS = "200"
                    $env:SERVER_SOFTWARE = $serverName
                    $env:SERVER_NAME = "localhost"
                    $env:SERVER_PORT = $port
                    $env:REQUEST_METHOD = $request.HttpMethod
                    $env:DOCUMENT_ROOT = $wwwPath
                    $env:SCRIPT_NAME = $urlPath
                    $env:REQUEST_URI = $request.Url.PathAndQuery
                    $env:QUERY_STRING = $request.Url.Query.TrimStart('?')
                    
                    # Execute PHP
                    $phpOutput = & $phpExe -f $filePath 2>&1
                    $buffer = [System.Text.Encoding]::UTF8.GetBytes($phpOutput)
                    
                    $response.ContentType = 'text/html; charset=utf-8'
                    $response.ContentLength64 = $buffer.Length
                    $response.StatusCode = 200
                    $response.OutputStream.Write($buffer, 0, $buffer.Length)
                }
                catch {
                    $errorHtml = "<h1>PHP Error</h1><pre>$_</pre>"
                    $buffer = [System.Text.Encoding]::UTF8.GetBytes($errorHtml)
                    $response.ContentType = 'text/html; charset=utf-8'
                    $response.ContentLength64 = $buffer.Length
                    $response.StatusCode = 500
                    $response.OutputStream.Write($buffer, 0, $buffer.Length)
                }
            }
            else {
                # Serve static files
                $contentType = if ($mimeTypes.ContainsKey($ext)) { 
                    $mimeTypes[$ext] 
                } 
                else { 
                    'application/octet-stream' 
                }
                
                $response.ContentType = $contentType
                $buffer = [System.IO.File]::ReadAllBytes($filePath)
                $response.ContentLength64 = $buffer.Length
                $response.StatusCode = 200
                $response.OutputStream.Write($buffer, 0, $buffer.Length)
            }
        }
        else {
            # 404 Not Found
            $html = @"
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>404 Not Found</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 0; padding: 0; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); min-height: 100vh; display: flex; align-items: center; justify-content: center; }
        .container { background: white; border-radius: 10px; padding: 40px; max-width: 500px; text-align: center; }
        h1 { color: #e74c3c; font-size: 72px; margin: 0; }
        h2 { color: #333; margin: 10px 0; }
        p { color: #666; }
        .footer { margin-top: 30px; color: #999; font-size: 0.9em; }
    </style>
</head>
<body>
    <div class="container">
        <h1>404</h1>
        <h2>Page Not Found</h2>
        <p>The requested file <strong>$urlPath</strong> was not found.</p>
        <div class="footer">$serverName</div>
    </div>
</body>
</html>
"@
            $buffer = [System.Text.Encoding]::UTF8.GetBytes($html)
            $response.ContentType = 'text/html; charset=utf-8'
            $response.ContentLength64 = $buffer.Length
            $response.StatusCode = 404
            $response.OutputStream.Write($buffer, 0, $buffer.Length)
        }
        
        $response.OutputStream.Close()
    }
}
catch {
    Write-Host ""
    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
    if ($_.Exception.Message -match 'access is denied') {
        Write-Host "[ERROR] Port $port is already in use or requires administrator privileges." -ForegroundColor Red
        Write-Host "[TIP] Try running as Administrator or change the port variable in the script." -ForegroundColor Yellow
    }
    Read-Host "Press Enter to exit"
    exit 1
}
finally {
    if ($listener -ne $null -and $listener.IsListening) {
        $listener.Stop()
        $listener.Close()
        Write-Host ""
        Write-Host "========================================================================" -ForegroundColor Yellow
        Write-Host "[!] Server has been stopped" -ForegroundColor Yellow
        Write-Host "========================================================================" -ForegroundColor Yellow
        Write-Host ""
    }
}