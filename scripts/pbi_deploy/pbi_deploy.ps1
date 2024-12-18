function Write-Log {
    # logger function
    param (
        $message,
        $colour="White"
    )

    $now = Get-Date
    $now = $now.ToString("yyyy-MM-ddTHH:mm:ss")
    $text = [string]::Format("[{0}] {1}", $now, $message)
    Write-Host $text -ForegroundColor $colour
}


function Remove-EverythingRelatedToDataset {
    param (
        $dataset_name,
        $workspace,
        $no_ds=$false
    )

    if ( $no_ds ){
        $datasets = Get-PowerBIDataset -Workspace $workspace
        foreach ($ds in $datasets) {
            if ($ds.Name -eq $dataset_name){
                Write-Log "Deleting dataset: $($ds.Name), Id: $($ds.Id)" -colour "Red"
                $res = Invoke-PowerBIRestMethod -Method Delete -Url "https://api.powerbi.com/v1.0/myorg/datasets/$($ds.Id)"
            }
        }
    }

    $dashboards = Get-PowerBIDashboard -Workspace $workspace
    foreach ($ds in $dashboards) {
        if ($ds.Name -eq $dataset_name){
            Write-Log "Deleting dashboard: $($ds.Name), Id: $($ds.Id)" -colour "Red"
            $res = Invoke-PowerBIRestMethod -Method Delete -Url "https://api.powerbi.com/v1.0/myorg/dashboards/$($ds.Id)"
        }
    }

    $reports = Get-PowerBIReport -Workspace $workspace
    foreach ($ds in $reports) {
        if ($ds.Name -eq $dataset_name){
            Write-Log "Deleting report: $($ds.Name), Id: $($ds.Id)" -colour "Red"
            $res = Invoke-PowerBIRestMethod -Method Delete -Url "https://api.powerbi.com/v1.0/myorg/reports/$($ds.Id)"
        }
    }
}


function Remove-RemoteReport {
    param (
        $report_name,
        $workspace
    )
    $reports = Get-PowerBIReport -Workspace $workspace
    foreach ($ds in $reports) {
        if ($ds.Name -eq $report_name){
            Write-Log "Deleting report: $($ds.Name), Id: $($ds.Id)" -colour "Red"
            $res = Invoke-PowerBIRestMethod -Method Delete -Url "https://api.powerbi.com/v1.0/myorg/reports/$($ds.Id)"
        }
    }
}


function Check-Env {
    if ( -not [System.Environment]::GetEnvironmentVariable('DBUSER') ){
        Write-Log "Environment variable DBUSER not set. please set the value to the db user" -colour "Red"
        exit 1
    }
    if ( -not [System.Environment]::GetEnvironmentVariable('DBPASSWORD') ){
        Write-Log "Environment variable DBPASSWORD not set. please set the value to the db password" -colour "Red"
        exit 1
    }
}


function Main {
    Check-Env
    $config = Get-Content "pbi_cfg.json" | Out-String | ConvertFrom-Json -AsHashtable
    $config["rep_ds_id_mapping"] = @{}
    Write-Log "--------------------- starting ---------------------" -colour "Green"

    # if not logged in to powerbi online, prompt to do so
    $res = Get-PowerBIAccessToken
    if ( $null -eq $res ) {
        <# Action to perform if the condition is true #>
        Write-Log "Not loged in, logging in..." -colour "Red"
        $res = Connect-PowerBIServiceAccount
        Write-Log "login: $res " -colour "Green"

    } else {
            Write-Log "Authenticated" -colour "Green"
    }

    # get the workspace with the name given in the config
    $source_workspace_name = $config.source_workspace
    $source_workspace = Get-PowerBIWorkspace -Name $source_workspace_name

    # # <====NOTE: workspace is actually the group so group id = workspace id =====>
    $source_workspace_id = $source_workspace | Select-Object -ExpandProperty Id
    Write-Log "Using source Workspace: $($source_workspace | Select-Object -ExpandProperty Name), Id: $source_workspace_id" -colour "Green"

    $target_workspace_name = $config.target_workspace
    $target_workspace = Get-PowerBIWorkspace -Name $target_workspace_name

    # # <====NOTE: workspace is actually the group so group id = workspace id =====>
    $target_workspace_id = $target_workspace | Select-Object -ExpandProperty Id
    Write-Log "Using target Workspace: $($target_workspace | Select-Object -ExpandProperty Name), Id: $target_workspace_id" -colour "Green"

    # for each coid in the config file,
    $coids_to_parse = $config.coids
    if ( $config.use_subset ) {
        Write-Log "===== WARNING: Using subset of coids =====" yellow
        $coids_to_parse = $config.subset_coids
    }

    # for each coid
    foreach ($company in $coids_to_parse) {
        Write-Log "===== Processing: coid: $($company.coid) =====" -colour "yellow"
        # $current_dir = (Get-Location).Path
        $coid = $company.coid.ToLower()
        $db_name = $company.db_name
        $db_server_postgres = $company.db_server_postgres
        $db_server_sql = $company.db_server_sql
        $db_type = $company.db_type

        $dataset_report_mapping = $config.dataset_report_mapping
        # for each pbix file in the coid directory, upload to target workspace
        foreach ($dsfile in $dataset_report_mapping.Keys){
            $dataset_name = "$($company.report_name_prefix) " + $dsfile.Replace(".pbix", "")
            Write-Log "processing dataset: $dataset_name" -colour "yellow"

            # We first have to delete the 'report, dataset and dashboard' that are related to the dataset
            Remove-EverythingRelatedToDataset -dataset_name $dataset_name -workspace $target_workspace -no_ds $true
            $report_file_path = Join-Path $PSScriptRoot $dsfile

            Write-Log "Uploading dataset: $dataset_name"
            $dataset = New-PowerBIReport -Path $report_file_path -Name $dataset_name -WorkspaceId $target_workspace_id

            # after uploading the dataset, the extra report and dashboard files can be deleted
            Remove-EverythingRelatedToDataset -dataset_name $dataset_name -workspace $target_workspace -no_ds $false

            $dsets = Get-PowerBIDataset -Workspace $target_workspace
            foreach ($tmp_dset in $dsets) {
                if ($tmp_dset.Name -eq $dataset_name){
                    $dataset = $tmp_dset
                }
            }

            $dataset_id = $dataset.Id
            Write-Log "dataset: $dataset_id"

            $reports = $dataset_report_mapping[$dsfile]
            foreach ($rep  in $reports){
                $report_base_name = $rep.Replace(".pbix", "")
                $report_name = "$($company.report_name_prefix) " + $report_base_name
                $report_name = $report_name
                Write-Log "processing report: $report_name"

                # delete the report that's already there otherwise it just makes copies
                Remove-RemoteReport -report_name $report_name -workspace $target_workspace

                Write-Log $report_base_name
                $report = Get-PowerBIReport -Workspace $source_workspace -Name $report_base_name
                if ( $null -eq $report ){
                    Write-Log "=== ERROR: $report_name not found in sourcce workspace ====" -colour "Red"
                    exit
                } else {
                    Write-Log "copying report: $report_name"
                    $report = Copy-PowerBIReport -Name $report_name -Report $report -Workspace $source_workspace -TargetWorkspaceId $target_workspace_id
                }

                Write-Log "copied report: $($report.Id)"
                
                $report_id = $report.Id
                $json_body = @{}
                $json_body["datasetId"] = $dataset_id
                $json_body = $json_body | ConvertTo-Json
                
                Write-Log "Binding report $report_id to $dataset_id" Yellow
                # 2. BINDING THE REPORT TO THE DATASET
                $binding = Invoke-PowerBIRestMethod -Url https://api.powerbi.com/v1.0/myorg/groups/$target_workspace_id/reports/$report_id/Rebind -Method Post -Body $json_body

            }
            # 3. Update dataset params
            $json_body = @{}
            $details = (
                @{
                    name = 'db_name'
                    newValue = $db_name
                },
                @{
                    name = 'db_server_postgres'
                    newValue = $db_server_postgres
                },
                @{
                    name = 'db_server_sql'
                    newValue = $db_server_sql
                },
                @{
                    name = 'db_type'
                    newValue = $db_type
                }
            )
            $json_body['updateDetails'] = @($details)
            $json_body = $json_body | ConvertTo-Json
            $dataset_id = $dataset_id

            Write-Log "Updating dataset params" Yellow
            $updating_params = Invoke-PowerBIRestMethod -Url https://api.powerbi.com/v1.0/myorg/groups/$target_workspace_id/datasets/$dataset_id/Default.UpdateParameters -Method Post -Body $json_body

            if ( $company.is_scheduled_refresh -eq $true ){
                $refresh_body = @{
                    "value" = @{
                        "enabled" = $true
                        "days" = $company.refresh_schedule.days
                        "times" = $company.refresh_schedule.times
                        "localTimeZoneId" = $company.refresh_schedule.localTimeZoneId
                    }
                }
                $refresh_body = $refresh_body | ConvertTo-Json
                Write-Log "Updating refresh schedule" Yellow
                $refresh_upd = Invoke-PowerBIRestMethod -Url https://api.powerbi.com/v1.0/myorg/groups/$target_workspace_id/datasets/$dataset_id/refreshSchedule -Method Patch -Body $refresh_body
            }

            $db_username = [System.Environment]::GetEnvironmentVariable('DBUSER')
            $db_password = [System.Environment]::GetEnvironmentVariable('DBPASSWORD')
            # 4. Get datasources, select the right one and then update the datasource (postgres)credentials
            $dsources = Invoke-PowerBIRestMethod -Method Get -Url https://api.powerbi.com/v1.0/myorg/datasets/$dataset_id/datasources
            $dsources = $dsources | ConvertFrom-Json
            foreach ($ds in $dsources.value) {
                $ds_id = $ds.datasourceId
                $gateway_id = $ds.gatewayId
                if ( $ds.datasourceType -eq "PostgreSql" ) {
                    # 5. UPDATE DATASOURCE CREDENTIALS
                    # TODO: credentials are hardcoded. need to change it at some point
                    $json_body = @{
                        credentialDetails = @{
                            credentialType = 'Basic'
                            credentials = "{`"credentialData`":[{`"name`":`"username`",`"value`":`"$db_username`"},{`"name`":`"password`", `"value`":`"$db_password`"}]}"
                            encryptedConnection = 'Encrypted'
                            encryptionAlgorithm = 'None'
                            privacyLevel = 'None'
                            useEndUserOAuth2Credentials = 'False'
                        }
                    }
                    $json_body = $json_body | ConvertTo-Json -Depth 10
                    $res = Invoke-PowerBIRestMethod -Method Patch -Url https://api.powerbi.com/v1.0/myorg/gateways/$gateway_id/datasources/$ds_id -Body $json_body
                } elseif ( $ds.datasourceType -eq "Sql" ) {
                    # 5. UPDATE DATASOURCE CREDENTIALS
                    $json_body = @{
                        credentialDetails = @{
                            credentialType = 'Basic'
                            credentials = "{`"credentialData`":[{`"name`":`"username`", `"value`":`"$db_username`"},{`"name`":`"password`", `"value`":`"$db_password`"}]}"
                            encryptedConnection = 'Encrypted'
                            encryptionAlgorithm = 'None'
                            privacyLevel = 'None'
                            useEndUserOAuth2Credentials = 'False'
                        }
                    }
                    $json_body = $json_body | ConvertTo-Json -Depth 10
                    $res = Invoke-PowerBIRestMethod -Method Patch -Url https://api.powerbi.com/v1.0/myorg/gateways/$gateway_id/datasources/$ds_id -Body $json_body
                } else {
                    Write-Log "Deleting datasource $ds" Yellow
                    $res = Invoke-PowerBIRestMethod -Method Delete -Url https://api.powerbi.com/v1.0/myorg/gateways/$gateway_id/datasources/$ds_id
                }
            }
            Write-Log "Submitting Refresh request for the dataset" -colour "Yellow"
            # 6. REFRESH THE DATASET
            $ds_refresh = Invoke-PowerBIRestMethod -Method Post -Url https://api.powerbi.com/v1.0/myorg/datasets/$dataset_id/refreshes -Body '{"notifyOption": ""}'
        }
    
    Write-Log "==============================================================================================================="
    }
}

Main
Write-Log '----------------------- finished ---------------------------' -colour "green"
