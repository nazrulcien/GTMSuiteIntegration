# FOR EVERY ENTITY, ITERATE OVER MONTHS AND TRY TO DOWNLOAD THE DATA
# IF num_docs > 50k (sf limit), then break down the month into weeks and try again
# if num_docs > 50k for a week, break the week in to 7 days and try again.
# assuming the data limit won't be reached for day.

$current_location = Get-Location
$current_location = $current_location.Path

$dt = Get-Date
$dt = $dt.ToString("yyyy_MM_dd_HH_mm_ss")
$logpath = "output/script_2_$dt.log"
$savefile = "output/savefile.json"
$SF_LIMIT = 50000

function New-LogFile {
    if (-not (Test-Path -Path $logpath -PathType Leaf)) {
        if (-not (Test-Path "output")){
            Write-Output "Creating output/ Directory"
            New-Item "output/" -ItemType Directory | Out-Null
        }
        New-Item $logpath -ItemType File
    }
}


function New-SaveFile {
    if (-not (Test-Path -Path $savefile -PathType Leaf)) {
        Write-Log "savefile.json not found" Yellow
        $config = Get-Content "config.json" | Out-String | ConvertFrom-Json
        $dict = New-Object hashtable
        foreach ($entity in $config.entities) {
            if ($entity -eq 'Account'){
                $dict.Add("Account_1", "")
                $dict.Add("Account_2", "")
            } else {
                $dict.Add($entity, "")
            }
        }
        $dict | ConvertTo-Json -Depth 10 | Set-Content $savefile
    }
}

function Write-Log {
    param (
        $message,
        $colour="White"
    )

    $now = Get-Date
    $now = $now.ToString("yyyy-MM-ddTHH:mm:ss")
    $text = [string]::Format("[{0}] {1}", $now, $message)
    $text | Tee-Object -FilePath $logpath -Append | Write-Host -ForegroundColor $colour
}

function Get-DSConfig {
    $config = Get-Content "config.json" | Out-String | ConvertFrom-Json
    $config
}

function Get-SFUsername {
    $config = Get-DSConfig
    $config = $config[-1]
    $username = $config.username
    return $username
}

function Invoke-SFLogin {
    param ([Int32]$login)
    # web auth with salesforce
    if ($login -ne 0){
        Write-Log "Opening Web Browser for Login"
        $username = Get-SFUsername
        $username = $username[-1]
        Start-Job -Name WebReq -ScriptBlock {
            sfdx force:auth:web:login -d -a DevHub
        }
        Wait-Job -Name WebReq
        $login = 0
    }
}

function Export-For-Query ($query, $username, $outfile) {
    $res = sfdx data:query -q "$query" --target-org $username -r json
    $res = $res | ConvertFrom-Json
    # print the error and exit if status != 0
    if ($res.status -ne 0){
        Write-Log "ERROR has occurred while running the program." "Red"
        Write-Log "status code: $($res.status)" "Red"
        Write-Log "================ FULL ERROR MESSAGE ===========================" "Red"
        Write-Log $($res.ToString()) "Red"
        Write-Log "===============================================================" "Red"
        Write-Log "exiting the program...." "Red"
        exit 1
    }

    $count = 0
    # only proceed if there are > 0 records
    if ($res.result.totalSize -ne 0) {
        $records = $res.result.records

        # hash the PII information for relevant fields
        foreach ($record in $records){
            $count += 1
            foreach ($field_name in $config.pii_fields.$entity) {
                $field_value = $record.$field_name
                if ($null -eq $field_value) {
                    $field_value = ""
                } else {
                    $obfuscated_string = Get-StringObfuscated $field_value
                    $record.$field_name = $obfuscated_string
                }
            }
        }

        if ($res.result.totalSize -eq 1) {
            ConvertTo-Json @($records) -Depth 10 | Set-Content $outfile
        }
        else {
            $records | ConvertTo-Json -Depth 10 | Set-Content $outfile
        }
    }
    $count
}


function Export-For-Query-By-Id ($final_fields, $entity, $fd, $ld, $username) {
    $fom = [datetime]::Parse($fd)
    $id_loop_count = 0
    $total_count = 0
    $should_exit = $false
    $QUERY = [string]::Format("SELECT $final_fields FROM $entity WHERE CreatedDate >= $fd AND CreatedDate < $ld ORDER BY Id ASC LIMIT 50000")
    $outfile = [string]::Format("output/{0}/{1}_daily_id_{2}_{3}_{4}_{5:d3}.json", $entity, $entity, $fom.year, $fom.ToString("MM"), $fom.ToString("dd"), $id_loop_count)

    while ( -not $should_exit) {
        $count = 0
        $id_loop_count += 1

        $res = sfdx data:query -q "$QUERY" --target-org $username -r json
        $res = $res | ConvertFrom-Json

        Write-Log "Batch $id_loop_count : cursor count: $($res.result.records.expr0)"
        # print the error and exit if status != 0
        if ($res.status -ne 0){
            Write-Log "ERROR has occurred while running the program." "Red"
            Write-Log "status code: $($res.status)" "Red"
            Write-Log "================ FULL ERROR MESSAGE ===========================" "Red"
            Write-Log $($res.ToString()) "Red"
            Write-Log "===============================================================" "Red"
            Write-Log "exiting the program...." "Red"
            exit 1
        }

        # only proceed if there are > 0 records
        if ($res.result.totalSize -ne 0) {
            $records = $res.result.records

            # hash the PII information for relevant fields
            foreach ($record in $records){
                $count += 1
                $last_id = $record.Id
                foreach ($field_name in $config.pii_fields.$entity) {
                    $field_value = $record.$field_name
                    if ($null -eq $field_value) {
                        $field_value = ""
                    } else {
                        $obfuscated_string = Get-StringObfuscated $field_value
                        $record.$field_name = $obfuscated_string
                    }
                }
            }

            if ($res.result.totalSize -eq 1) {
                ConvertTo-Json @($records) -Depth 10 | Set-Content $outfile
            }
            else {
                $records | ConvertTo-Json -Depth 10 | Set-Content $outfile
            }

            $total_count += $count
            $QUERY = [string]::Format("SELECT $final_fields FROM $entity WHERE Id > '$last_id' AND CreatedDate >= $fd AND CreatedDate < $ld ORDER BY Id ASC LIMIT 50000")
            $outfile = [string]::Format("output/{0}/{1}_daily_id_{2}_{3}_{4}_{5:d3}.json", $entity, $entity, $fom.year, $fom.ToString("MM"), $fom.ToString("dd"), $id_loop_count)
        } else {
            $should_exit = $true
        }
    }
    $total_count
}


function Export-Daily($week, $week_count, $entity, $username, $final_fields){
    $fom = $week[0]
    $eom = $week[1]
    $days = New-Object System.Collections.ArrayList
    while ($fom -lt $eom) {
        if ($($fom.AddDays(1)) -gt $eom){
            [void]$days.Add([System.Tuple]::Create($fom, $eom))
        } else {
            [void]$days.Add([System.Tuple]::Create($fom, $fom.AddDays(1)))
        }
        $fom = $fom.AddDays(1)
    }

    $total_docs
    $loop_count = 0
    foreach ($day in $days) {
        $loop_count += 1

        $fd = $day[0].ToString("yyyy-MM-ddTHH:mm:ss.000+0000")
        $ld = $day[1].ToString("yyyy-MM-ddTHH:mm:ss.000+0000")
        $COUNT_QUERY = [string]::Format("SELECT Count(Id) FROM $entity WHERE CreatedDate >= $fd AND CreatedDate < $ld AND CreatedDate != NULL")
        $res = sfdx data:query -q "$COUNT_QUERY" --target-org $USERNAME -r json
        $res = $res | ConvertFrom-Json

        Write-Log "Day of: $($day[0].ToString("yyyy-MM-dd")) cursor count: $($res.result.records.expr0)"
        # print the error and exit if status != 0
        if ($res.status -ne 0){
            Write-Log "ERROR has occurred while running the program." "Red"
            Write-Log "status code: $($res.status)" "Red"
            Write-Log "================ FULL ERROR MESSAGE ===========================" "Red"
            Write-Log $($res.ToString()) "Red"
            Write-Log "===============================================================" "Red"
            Write-Log "exiting the program...." "Red"
            exit 1
        }

        # if there are more than 50k docs, do it daily
        if ($res.result.records.expr0 -lt $SF_LIMIT){
            $QUERY = [string]::Format("SELECT $final_fields FROM $entity WHERE CreatedDate >= $fd AND CreatedDate < $ld")
            $outfile = [string]::Format("output/{0}/{1}_daily_{2}_{3}_{4:d2}.json", $entity, $entity, $day[0].year, $day[0].ToString("MM"), $day[0].ToString("dd"))
            $count = Export-For-Query $QUERY $USERNAME $outfile
            $total_docs += $count
        }
        else {
            Write-Log "Data too big. splitting into id batches" "Yellow"
            $count = Export-For-Query-By-Id $final_fields $entity $fd $ld $username
            $total_docs += $count
        }
    }
    return $total_docs
}


function Export-Weekly ($month, $entity, $username, $final_fields) {
    $fom = $month[0]
    $eom = $month[1]
    $weeks = New-Object System.Collections.ArrayList
    while ($fom -lt $eom) {
        if ($($fom.AddDays(7)) -gt $eom){
            [void]$weeks.Add([System.Tuple]::Create($fom, $eom))
        } else {
            [void]$weeks.Add([System.Tuple]::Create($fom, $fom.AddDays(7)))
        }
        $fom = $fom.AddDays(7)
    }

    $total_docs = 0
    $loop_count = 0
    foreach ($week in $weeks) {
        $loop_count += 1
        $fd = $week[0].ToString("yyyy-MM-ddTHH:mm:ss.000+0000")
        $ld = $week[1].ToString("yyyy-MM-ddTHH:mm:ss.000+0000")
        $COUNT_QUERY = [string]::Format("SELECT Count(Id) FROM $entity WHERE CreatedDate >= $fd AND CreatedDate < $ld AND CreatedDate != NULL")
        $res = sfdx data:query -q "$COUNT_QUERY" --target-org $USERNAME -r json
        $res = $res | ConvertFrom-Json

        # print the error and exit if status != 0
        if ($res.status -ne 0){
            Write-Log "ERROR has occurred while running the program." "Red"
            Write-Log "status code: $($res.status)" "Red"
            Write-Log "================ FULL ERROR MESSAGE ===========================" "Red"
            Write-Log $($res.ToString()) "Red"
            Write-Log "===============================================================" "Red"
            Write-Log "exiting the program...." "Red"
            exit 1
        }

        Write-Log "Week of: $($week[0].ToString("yyyy-MM-dd")) cursor count: $($res.result.records.expr0)"
        # if there are more than 50k docs, do it daily
        if ($res.result.records.expr0 -lt $SF_LIMIT){
            $QUERY = [string]::Format("SELECT $final_fields FROM $entity WHERE CreatedDate >= $fd AND CreatedDate < $ld")
            $outfile = [string]::Format("output/{0}/{1}_weekly_{2}_{3}_{4:d2}_{5:d2}.json", $entity, $entity, $week[0].year, $week[0].ToString("MM"), $week[0].ToString("dd"), $loop_count)
            $count = Export-For-Query $QUERY $USERNAME $outfile
            $total_docs += $count
        }
        else {
            Write-Log "Data too big. breaking into Daily"
            $count = Export-Daily $week $loop_count $entity $USERNAME $final_fields
            $total_docs += $count[1]
        }
    }
    $total_docs
}


function Export-BetweenDates([string]$first_date, [string]$last_date, [string]$entity, [int]$pass){
    # Query SF and export data between the given dates
    Write-Log "==============================================================================================================" Blue
    Write-Log "Exporting $entity Between: $first_date - $last_date" Blue
    Write-Log "==============================================================================================================" Blue

    $config = Get-DSConfig

    # create the output/ENTITY directory if doesn't exist
    if (-not (Test-Path "output/$entity")) {
        Write-Log "Creating output/$entity Directory" "Yellow"
        New-Item "output/$entity" -ItemType Directory | Out-Null
    }

    $json = $config.schema
    $our_fields=$json.$entity

    # check if all the fields in our schema is actually present in user's SF,
    # remove the fields not in the client's SF
    $USERNAME = Get-SFUsername
    $schema = sfdx force:schema:sobject:describe --target-org $USERNAME -s $entity --json
    $schema_json = $schema | ConvertFrom-Json

    if ($schema_json.status -ne 0){
        Write-Log "--------------------- ERROR getting schema for $entity. message: -------------------------" "Red"
        Write-Log $schema_json "Red"

        if ($schema_json.name -eq "NOT_FOUND") {
            Write-Log "`n--------------------- The Entity $entity not found on salesforce. skipping ----------------------" "yellow"
            return
        }
        Write-Log "------------------------- exiting --------------------------------------------------------" "Red"
        exit
    }
    $sf_fields = New-Object System.Collections.ArrayList

    foreach ($field_ in $schema_json.result.fields) {
        # Write-Output $field_
        [void]$sf_fields.Add($field_.name)  # add returns an index. use [void] to avoid the printing
    }

    $final_fields = New-Object System.Collections.ArrayList
    $omitted_fields = New-Object System.Collections.ArrayList

    $exception_fields = @("What.Name", "Who.Type", "What.Type", "Who.Title")

    foreach ($item in $our_fields){
        # Write-Output $item
        if ($exception_fields -contains $item){
            [void]$final_fields.Add($item)
            continue
        }
        if ($sf_fields -contains $item){
            [void]$final_fields.Add($item)
        } else {
            [void]$omitted_fields.Add($item)
        }
    }

    $final_fields = $final_fields -join ','

    if ($omitted_fields.Count -ne 0 ){
        Write-Log "The following fields are not in SF schema: $($omitted_fields -join ', '). ignoring them for export" Yellow
    }
    Write-Log "Requested fields: $final_fields" 'Yellow'

    # ------------- prepare monthly dates ---------------------------------------
    $starting_date = [datetime]::Parse($first_date)
    $ending_date = [datetime]::Parse($last_date)

    $dates = New-Object System.Collections.ArrayList
    while ($starting_date -le $ending_date) {
        [void]$dates.Add([Tuple]::Create($starting_date, $starting_date.AddMonths(1)))
        $starting_date = $starting_date.AddMonths(1)
    }

    # ==========================================================================================================
    # ------- query data for each month ----------------------
    $total_docs = 0
    foreach ($current_month in $dates) {
        $save_date_filename = $current_month[0].ToString("yyyy-MM-dd")
        $save_details = Get-Content $savefile | ConvertFrom-Json
        # skip the current month if it's already processed as per the savefile.json log we keep

        $val = $save_details.$entity
        if ($entity -eq "Account"){
            $key = [string]::Format("{0}_{1}", $entity, $pass)
            $val = $save_details.$key
        }

        if ($val -ne ""){
            $date_to_compare = [datetime]::Parse($val)
            if ($date_to_compare -ge $current_month[0]){
                Write-Log "Date $save_date_filename processed. skipping" Green
                continue
            }
        }

        $fd = $current_month[0].ToString("yyyy-MM-ddTHH:mm:ss.000+0000")
        $ld = $current_month[1].ToString("yyyy-MM-ddTHH:mm:ss.000+0000")
        $COUNT_QUERY = [string]::Format("SELECT Count(Id) FROM $entity WHERE CreatedDate >= $fd AND CreatedDate < $ld AND CreatedDate != NULL")
        $res = sfdx data:query -q "$COUNT_QUERY" --target-org $USERNAME -r json
        $res = $res | ConvertFrom-Json

        Write-Log "Month of: $($current_month[0].ToString("yyyy-MM-dd")) cursor count: $($res.result.records.expr0)"
        # print the error and exit if status != 0
        if ($res.status -ne 0){
            Write-Log "ERROR has occurred while running the program." "Red"
            Write-Log "status code: $($res.status)" "Red"
            Write-Log "================ FULL ERROR MESSAGE ===========================" "Red"
            Write-Log $($res.ToString()) "Red"
            Write-Log "===============================================================" "Red"
            Write-Log "exiting the program...." "Red"
            exit 1
        }

        if ($res.result.records.expr0 -lt $SF_LIMIT){
            $QUERY = [string]::Format("SELECT $final_fields FROM $entity WHERE CreatedDate >= $fd AND CreatedDate < $ld")
            $outfile = [string]::Format("output/{0}/{1}_monthly_{2}_{3}.json", $entity, $entity, $current_month[0].year, $current_month[0].ToString("MM"))
            $count = Export-For-Query $QUERY $USERNAME $outfile
            $total_docs += $count
        }
        else {
            Write-Log "Data too big. breaking into weekly" Yellow
            $count = Export-Weekly $current_month $entity $USERNAME $final_fields
            $total_docs += $count
        }

        $message = [string]::Format("[{0:d2}/{1}] {2}, month: {3}, records exported={4}", $dates.IndexOf($current_month) + 1, $dates.Count, $entity,
        $current_month[0].ToString('yyyy-MM'), $count)

        if ($dates.Count -ge 100) {
            $message = [string]::Format("[{0:d3}/{1}] {2}, month: {3}, records exported={4}", $dates.IndexOf($current_month) + 1, $dates.Count, $entity,
            $current_month[0].ToString('yyyy-MM'), $count)
        }

        Write-Log $message Green
        if ($entity -eq "Account") {
            $key = [string]::Format("{0}_{1}", $entity, $pass)
            $save_details.$key = $save_date_filename
        } else {
            $save_details.$entity = $save_date_filename
        }
        $save_details | ConvertTo-Json -Depth 10 | Set-Content $savefile
        Write-Log '-------------------------------------------------------------------------------------------------'
        # ==========================================================================================================
    }
    Write-Log "Total $entity records exported: $total_docs`n" Green
}

function Get-Hashofstring([string]$str_to_hash){
    $cleaned_str = $str_to_hash -creplace '\P{IsBasicLatin}', ''
    $mystream = [IO.MemoryStream]::new([byte[]][char[]]$cleaned_str)
    $hashed_valued = Get-FileHash -InputStream $mystream -Algorithm SHA256
    $hashed_valued = $hashed_valued.Hash
    return $hashed_valued
}

function Get-StringObfuscated([string]$field_value) {
    # obfuscate a given string. if it's an email, hash the parts around @ separately
    $parts = $field_value.Split("@")
    if ($parts.Length -eq 1) {
        $output = Get-Hashofstring $parts
        return $output
    } else {
        $res = ''
        foreach ($part in $parts) {
            $output = Get-Hashofstring $part
            $res = $res + $output + '@'
        }
        $res = $res.Substring(0, $res.Length-1)
        return $res
    }
}


#Creates a function called Show-Menu
function Show-Menu {
    param (
        [string]$Title = 'Cien SF Utility'
    )
    # Clear-Host
    Write-Host "========== Choose your option ============="
    Write-Host "1. Press '1' to Download Salesforce Schema"
    Write-Host "2. Press '2' to Download Salesforce Data"
    Write-Host "q. Press 'q' to exit the script"
    Write-Host "==========================================="
}

function Show-EntitiesMenu {
    param (
        $sf_entities
    )

    $count = 1
    Write-Host ""
    Write-Host "=================================== Select an entity to export ================================================"
    foreach ($entity in $sf_entities) {
        # Get the connection string
        Write-Host "$count. $entity"
        $count += 1
    }
    Write-Host "=============================================================================================================="
    Write-Host ""
}

function Export-Schema {
    param (
        $config
    )

    Write-Log $config
    $USERNAME=$config.username

    # create empty json object
    $jsonBase = @{}
    foreach ($entity in $config.entities) {

        Write-Log "Processing: $entity"
        $schema = sfdx force:schema:sobject:describe --target-org $USERNAME -s $entity --json

        $schema_json = $schema | ConvertFrom-Json
        $fields = New-Object System.Collections.ArrayList

        foreach ($field_ in $schema_json.result.fields) {
            [void]$fields.Add($field_.name)  # add returns an index. use [void] to avoid the printing
        }

        $jsonBase.Add($entity, $fields)
    }

    if (-not (Test-Path "output")) {
        Write-Log "Creating Output Directory"
        New-Item "output" -ItemType Directory | Out-Null
    }

    Write-Log "Writing output/schema.json"
    $jsonBase | ConvertTo-Json -Depth 10 |  Out-File output/schema.json

}

function Export-User {
    param (
        $config
    )

    $USERNAME=$config.username

    Write-Log "==============================================================================================================" "Blue"
    Write-Log "Exporting User" "Blue"
    Write-Log "==============================================================================================================" "Blue"`

    $json = $config.schema

    $FIELDS = $json.User -join ','
    $QUERY = [string]::Format("SELECT $FIELDS FROM User WHERE UserType='Standard'")

    $res = sfdx data:query -q "$QUERY" --target-org $USERNAME -r json
    $res = $res | ConvertFrom-Json

    $msg = [string]::Format("Total records exported: {0}`n", $res.result.totalSize)

    $records = $res.result.records

    if (-not (Test-Path "output/User")) {
        Write-Log "Creating output/User Directory"
        New-Item "output/User" -ItemType Directory | Out-Null
    }
    $records | ConvertTo-Json -Depth 10 |  Out-File output/User/User.json

    Write-Log $msg Green
}

function Export-Lead {
    param (
        $config
    )

    $filter_date = $config.date_others
    $start_date = Get-Date -Year $filter_date -Month 1 -Day 1 -Hour 0 -Minute 0 -Second 0
    $end_date = Get-Date

    $start_date = $start_date.ToString('s')
    $end_date = $end_date.ToString('s')
    Export-BetweenDates $start_date $end_date "Lead" 1
}


function Export-Account {
    param (
        $config
    )

    $filter_date = $config.date_others

    # for accounts from filter_date to today
    $start_date = Get-Date -Year $filter_date -Month 1 -Day 1 -Hour 0 -Minute 0 -Second 0
    $end_date = Get-Date

    $start_date = $start_date.ToString('s')
    $end_date = $end_date.ToString('s')
    Export-BetweenDates $start_date $end_date "Account" 1

    # for accounts from an old date to filter_date
    $start_date = Get-Date -Year 2000 -Month 1 -Day 1 -Hour 0 -Minute 0 -Second 0
    $end_date = Get-Date -Year $filter_date -Month 1 -Day 1 -Hour 0 -Minute 0 -Second 0

    $start_date = $start_date.ToString('s')
    $end_date = $end_date.ToString('s')
    Export-BetweenDates $start_date $end_date "Account" 2
}


function Export-Contact {
    param (
        $config
    )

    $filter_date = $config.date_others
    $start_date = Get-Date -Year $filter_date -Month 1 -Day 1 -Hour 0 -Minute 0 -Second 0
    $end_date = Get-Date

    $start_date = $start_date.ToString('s')
    $end_date = $end_date.ToString('s')
    Export-BetweenDates $start_date $end_date "Contact" 1
}


function Export-Opportunity {
    param (
        $config
    )

    $filter_date = $config.date_others

    $start_date = Get-Date -Year $filter_date -Month 1 -Day 1 -Hour 0 -Minute 0 -Second 0
    $end_date = Get-Date

    $start_date = $start_date.ToString('s')
    $end_date = $end_date.ToString('s')
    Export-BetweenDates $start_date $end_date "Opportunity"
}


function Export-OpportunityStage {
    param (
        $config
    )

    $USERNAME=$Config.username
    Write-Log "==============================================================================================================" "Blue"
    Write-Log "Exporting OpportunityStage" "Blue"
    Write-Log "==============================================================================================================" "Blue"


    $json = $config.schema

    $FIELDS=$json.OpportunityStage -join ','
    $QUERY="SELECT $FIELDS FROM OpportunityStage"

    $res = sfdx data:query -q "$QUERY" --target-org $USERNAME -r json
    $res = $res | ConvertFrom-Json
    $msg = [string]::Format("Total records exported: {0}`n", $res.result.totalSize)

    $records = $res.result.records

    if (-not (Test-Path "output/OpportunityStage")) {
        Write-Log "Creating output/OpportunityStage Directory"
        New-Item "output/OpportunityStage" -ItemType Directory | Out-Null
    }
    $records | ConvertTo-Json -Depth 10 |  Out-File output/OpportunityStage/OpportunityStage.json
    Write-Log $msg Green
}


function Export-OpportunityHistory {
    param (
        $config
    )

    $filter_date = $config.date_others
    $start_date = Get-Date -Year $filter_date -Month 1 -Day 1 -Hour 0 -Minute 0 -Second 0
    $end_date = Get-Date

    $start_date = $start_date.ToString('s')
    $end_date = $end_date.ToString('s')
    Export-BetweenDates $start_date $end_date "OpportunityHistory" 1
}


function Export-OpportunityLineItem{
    param($config)

    $filter_date = $config.date_others
    $start_date = Get-Date -Year $filter_date -Month 1 -Day 1 -Hour 0 -Minute 0 -Second 0
    $end_date = Get-Date

    $start_date = $start_date.ToString('s')
    $end_date = $end_date.ToString('s')
    Export-BetweenDates $start_date $end_date "OpportunityLineItem" 1
}


function Export-Product2{
    param($config)

    $filter_date = $config.date_others
    $start_date = Get-Date -Year $filter_date -Month 1 -Day 1 -Hour 0 -Minute 0 -Second 0
    $end_date = Get-Date

    $start_date = $start_date.ToString('s')
    $end_date = $end_date.ToString('s')
    Export-BetweenDates $start_date $end_date "Product2" 1
}


function Export-Billing{
    param($config)

    $filter_date = $config.date_others
    $start_date = Get-Date -Year $filter_date -Month 1 -Day 1 -Hour 0 -Minute 0 -Second 0
    $end_date = Get-Date

    $start_date = $start_date.ToString('s')
    $end_date = $end_date.ToString('s')
    Export-BetweenDates $start_date $end_date "Billing" 1
}


function Export-Task {
    param (
        $config
    )

    $filter_date = $config.date_activities
    $start_date = Get-Date -Year $filter_date -Month 1 -Day 1 -Hour 0 -Minute 0 -Second 0
    $end_date = Get-Date

    $start_date = $start_date.ToString('s')
    $end_date = $end_date.ToString('s')
    Export-BetweenDates $start_date $end_date "Task" 1
}

function Export-Event {
    param (
        $config
    )

    $filter_date = $config.date_activities
    $start_date = Get-Date -Year $filter_date -Month 1 -Day 1 -Hour 0 -Minute 0 -Second 0
    $end_date = Get-Date

    $start_date = $start_date.ToString('s')
    $end_date = $end_date.ToString('s')
    Export-BetweenDates $start_date $end_date "Event" 1
}


function Main {

    New-LogFile | Out-Null;
    New-SaveFile | Out-Null;

    Write-Output "`n------------------- starting export script ------------------------"
    if ($PSVersionTable.PSVersion.Major -ne 7){
        Write-Output "ERROR: Powershell version 7 is required. found $($PSVersionTable.PSVersion.ToString()). exiting"
        Write-Output "---------------------------------------------------------------`n"
        exit
    }

    $config = Get-Content "config.json" | Out-String | ConvertFrom-Json

    $username = $config.username
    $sf_entities = New-Object System.Collections.ArrayList
    [void]$sf_entities.Add('All')

    foreach ($item in $config.entities) {
        [void]$sf_entities.Add($item)
    }

    Write-Log "configured username: $username" "blue"
    if ($username -eq "YOUR_USERNAME") {
        Write-Log "ERROR: Please enter a valid username in the config.json`n" -ForegroundColor Red
        Write-Log "---------------------- script error ------------------------------"
        Write-Log ""
        Exit
    }

    # check if logged in
    $sf = sfdx force:limits:api:display --target-org $username --json | ConvertFrom-Json
    $login = $sf.status
    if ($login -ne 0 ){
        Write-Log "User not logged in"
        $login = Invoke-SFLogin($login)[-1]
    }

    Show-Menu
    $options = Read-Host "Enter your choice"
    switch ($options) {
        '1' {
                Export-Schema($config)
            }
        '2' {
            Show-EntitiesMenu($sf_entities)
            $options = Read-Host "Enter your choice"
            $options = [int]$options - 1

            Write-Host "`n"
            switch ($sf_entities[$options]) {
                'User' {
                    Export-User($config)
                 }
                 'Lead' {
                    Export-Lead($config)
                 }
                 'Account' {
                    Export-Account($config)
                 }
                 'Contact' {
                    Export-Contact($config)
                 }
                 'Opportunity' {
                    Export-Opportunity($config)
                 }
                 'OpportunityStage' {
                    Export-OpportunityStage($config)
                 }
                 'OpportunityHistory' {
                    Export-OpportunityHistory($config)
                 }
                 'OpportunityLineItem' {
                    Export-OpportunityLineItem($config)
                 }
                 'Product2' {
                    Export-Product2($config)
                 }
                 'Billing' {
                    Export-Billing($config)
                 }
                 'Task' {
                    Export-Task($config)
                 }
                 'Event' {
                    Export-Event($config)
                 }
                 'Products'{
                    Export-Products($config)
                 }
                 'All' {
                    Export-User($config)
                    Export-Opportunity($config)
                    Export-OpportunityStage($config)
                    Export-OpportunityHistory($config)
                    Export-OpportunityLineItem($config)
                    Export-Product2($config)
                    Export-Billing($config)
                    Export-Lead($config)
                    Export-Contact($config)
                    Export-Account($config)
                    Export-Task($config)
                    Export-Event($config)
                    Write-Log "Finished exporting all entities"
                    Compress-Archive 'output/' -Force sf_data_export.zip
                    Write-Log "sf_data_export.zip created"
                    # Remove-Item 'output' -Recurse
                 }
                Default {}
            }
        }
        'q' {
            Write-Host "exiting"
        }
    }
}

[Console]::OutputEncoding = New-Object -TypeName System.Text.UTF8Encoding
Main
Write-Host "`n-------------------------- script finished ---------------------------------- `n" -ForegroundColor Green