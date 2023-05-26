﻿function Remove-GPOZaurr {
    [cmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Position = 1)][scriptblock] $ExcludeGroupPolicies,
        [parameter(Position = 0, Mandatory)][validateset('Empty', 'Unlinked', 'Disabled', 'NoApplyPermission')][string[]] $Type,
        [int] $LimitProcessing,
        [alias('ForestName')][string] $Forest,
        [string[]] $ExcludeDomains,
        [alias('Domain', 'Domains')][string[]] $IncludeDomains,
        [System.Collections.IDictionary] $ExtendedForestInformation,
        [string[]] $GPOPath,
        [string] $BackupPath,
        [switch] $BackupDated,
        [int] $RequireDays
    )
    Begin {
        if ($BackupPath) {
            $BackupRequired = $true
            if ($BackupDated) {
                $BackupFinalPath = "$BackupPath\$((Get-Date).ToString('yyyy-MM-dd_HH_mm_ss'))"
            } else {
                $BackupFinalPath = $BackupPath
            }
            Write-Verbose "Remove-GPOZaurr - Backing up to $BackupFinalPath"
            $null = New-Item -ItemType Directory -Path $BackupFinalPath -Force -WhatIf:$false
        } else {
            $BackupRequired = $false
        }
        $CountProcessedGPO = 0
    }
    Process {
        $getGPOZaurrSplat = @{
            Forest                    = $Forest
            IncludeDomains            = $IncludeDomains
            ExcludeDomains            = $ExcludeDomains
            ExtendedForestInformation = $ExtendedForestInformation
            GPOPath                   = $GPOPath
            ExcludeGroupPolicies      = $ExcludeGroupPolicies
        }

        Get-GPOZaurr @getGPOZaurrSplat | ForEach-Object {
            if ($LimitProcessing -ne 0 -and $CountProcessedGPO -ge $LimitProcessing) {
                Write-Warning -Message "Remove-GPOZaurr - LimitProcessing ($CountProcessedGPO / $LimitProcessing) reached. Stopping processing"
                break
            }

            $DeleteRequired = $false

            if ($Type -contains 'Empty') {
                if ($_.Empty -eq $true) {
                    $DeleteRequired = $true
                }
            }
            if ($Type -contains 'Unlinked') {
                if ($_.Linked -eq $false) {
                    $DeleteRequired = $true
                }
            }
            if ($Type -contains 'Disabled') {
                if ($_.Enabled -eq $false) {
                    $DeleteRequired = $true
                }
            }
            if ($Type -contains 'NoApplyPermission') {
                if ($_.ApplyPermission -eq $false) {
                    $DeleteRequired = $true
                }
            }
            if ($RequireDays) {
                if ($RequireDays -ge $_.Days) {
                    # GPO was modified recently and we don't want to touch it yet, maybe edit is in progress
                    $DeleteRequired = $false
                }
            }
            if ($_.Exclude -eq $true) {
                Write-Verbose "Remove-GPOZaurr - Excluded GPO $($_.DisplayName) from $($_.DomainName). Skipping!"
            } elseif ($DeleteRequired) {
                if ($BackupRequired) {
                    try {
                        Write-Verbose "Remove-GPOZaurr - Backing up GPO $($_.DisplayName) from $($_.DomainName)"
                        $BackupInfo = Backup-GPO -Guid $_.Guid -Domain $_.DomainName -Path $BackupFinalPath -ErrorAction Stop
                        $BackupInfo
                        $BackupOK = $true
                    } catch {
                        Write-Warning "Remove-GPOZaurr - Backing up GPO $($_.DisplayName) from $($_.DomainName) failed: $($_.Exception.Message)"
                        $BackupOK = $false
                    }
                }
                if (($BackupRequired -and $BackupOK) -or (-not $BackupRequired)) {
                    try {
                        Write-Verbose "Remove-GPOZaurr - Removing GPO $($_.DisplayName) from $($_.DomainName)"
                        Remove-GPO -Domain $_.DomainName -Guid $_.Guid -ErrorAction Stop
                    } catch {
                        Write-Warning "Remove-GPOZaurr - Removing GPO $($_.DisplayName) from $($_.DomainName) failed: $($_.Exception.Message)"
                    }
                }
                $CountProcessedGPO++
            }
        }
    }
    End {

    }
}