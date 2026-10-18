# ==============================================================================
# Smart Travel Planning - Supabase Database Disaster Recovery Backup Script
# Extracts the latest live database schema from Supabase into docs/supabase_schema.sql
# ==============================================================================

param(
    [string]$DbUrl = ""
)

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Supabase Database Schema Sync & Backup Tool" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$OutputFile = Join-Path $PSScriptRoot "..\docs\supabase_schema.sql"

if ([string]::IsNullOrWhiteSpace($DbUrl)) {
    Write-Host "Enter your Supabase PostgreSQL Connection String (from Project Settings -> Database):" -ForegroundColor Yellow
    Write-Host "Example: postgresql://postgres:[YOUR-PASSWORD]@db.[PROJECT-REF].supabase.co:5432/postgres" -ForegroundColor DarkGray
    $DbUrl = Read-Host "Connection URL"
}

if ([string]::IsNullOrWhiteSpace($DbUrl)) {
    Write-Host "No connection URL provided. Cancelled." -ForegroundColor Red
    exit 1
}

Write-Host "`nDumping live Supabase schema to: $OutputFile ..." -ForegroundColor Yellow

try {
    npx supabase db dump --db-url "$DbUrl" -f "$OutputFile"
    if ($LASTEXITCODE -eq 0) {
        Write-Host "`n[SUCCESS] Live database schema successfully synced to docs/supabase_schema.sql!" -ForegroundColor Green
        Write-Host "Commit this file to Git to preserve your disaster recovery backup." -ForegroundColor Cyan
    } else {
        Write-Host "`n[ERROR] Failed to dump schema. Please verify your connection URL and password." -ForegroundColor Red
    }
} catch {
    Write-Host "`n[ERROR] An exception occurred while running the backup: $_" -ForegroundColor Red
}
