### Script Usage

1. In the `pbi_cfg.json` file, modify the following parameters:

    `"source_workspace"` - workspace where the base dataset is

    `"target_workspace"` - workspace where you want to deploy to per client

    `"use_subset"` - deploy a subset of coids or all of the `coids`

    `"db_name"` - name of the database

    `"db_type"` - type of the database server. The value is either 

    `SQL Server` or `Postgres`

    `"db_server"` - url of the database server

    `"report_name_prefix"` - Prefix for the report names. All reports will be prefixed with this name

    `"coid"` - Coid of the client

2. For the selected db, the script expects two environment variables present on the machine before running the script. To update Environment Variables, on your PC, click windows icon, Search for Environ, Choose "Edit the system environment variables" control panel, in "Advanced" tab, click "Environment Variables", "Edit" DBPASSWORD, DBUSER. 

    `DBUSER` - username of the database
    
    `DBPASSWORD` - password for the user


3. On windows machines, Run the command `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass` to make sure the script can be executed without certificate

4. Run the command `./pbi_deploy.ps1`

5. The script will prompt for the powerbi login. Login and the script will continue automatically
