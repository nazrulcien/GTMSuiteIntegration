# Cien.ai's Salesforce.com File  Download script for Windows & Mac/Linux

# WINDOWS - PowerShell script for downloading Salesforce.com data

### Prerequisites:
 1. **Microsoft PowerShell version 7**
    Follow this link to install PowerShell: *https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows?view=powershell-7.3*
 2. **Salesforce.com Developer Experience (sfdx) Command Line Interface (CLI)**
    Download the windows executable from here: *https://developer.salesforce.com/tools/sfdxcli*, run the .exe and follow the instructions in the installer window. If you already have sfdx-cli installed then run the command `sfdx update` to update the tool to the latest version.

### Steps to run the script:
1. In file explorer, navigate to the folder named `salesforce_file_sync_scripts`, and open the config.json file in a text editor.

      i) Change the YOUR_USERNAME value to a valid Salesforce.com username in your organization. eg: john_doe@acme.com

      ii) PII: The script is masking Personally Identifiable Information (PII) by default. However, any additional fields can be included to be masked in the config file. To do so, Add/Delete/Modify those fields in the `pii_fields` section.

      iii) Custom Fields: if you are including custom fields, these can be added in the appropriate entity under 'schema'. Add the fields at the end of the fields list one field per line, ending with a comma,  (also make sure all the fields except the last one ends with the comma). If unsure, go to https://jsonlint.com/ and paste the whole file contents and validate it. if it's invalid, make necessary corrections.

      iv) Save and Close the file.

2. Open PowerShell 7 as an Administrator (right click to get menu option).
3. Navigate to the folder containing the scripts using the cd command: eg. `cd C:\Users\JohnDoe\Downloads\salesforce_file_sync_scripts\`
4. Run the following command to enable running the scripts: `gci | Unblock-File`.
5. Now run the script using `.\salesforce_file_sync_scripts.ps1` command.
6. The script will open the web browser in order for you to log in to your Salesforce.com instance - and the script will be authorized to query your Salesforce.com instance (i.e., you are authorizing yourself to download the files). After log-in, you can go back to the PowerShell window.
7. The script will present the following options: `1` for Download Salesforce schema,  `2` for Download Salesforce Data , (or `3` to exit the script). Make your choice and press `[ENTER]`.
8. With choice `2`, you will be given another set of options to export specific entities or all of them. We recommend choosing â€™1â€™ for All. Press your chosen key and press `ENTER`.
9. Now wait for the data download to finish. The script will exit with a message after completion. The schema data should download in a few minutes. The full data download can take several hours for larger Salesforce.com instances. Please make sure you have a stable internet connection and can leave the script running in the background until it is done.
10. Due to the salesforce API rate limitations, the script may show error messages while exporting. In that case, simply run the script again, and it will continue from the point of failure.
11. Upon a successfully script execution, the exported data will be zipped into `sf_data_export.zip` file in the same folder. This file can now be reviewed and then shared with Cien.ai (support@cien.ai) using your preferred file sharing client (eg. Dropbox.com). If the choice made in step 8 is to export individual entities, then the user will need to zip the output folder manually.

-----------------------------------------------------------------------------------------------------------------------------------------------------------

# macOS/Linux - PowerShell script for downloading Salesforce.com data

### Prerequisites:
 1. **Microsoft PowerShell version 7**
	a) Follow the instructions to download and install Homebrew: *https://brew.sh/*.
	b) Follow the instructions to download and install PowerShell: *https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-macos?view=powershell-7.3*
 2. **Salesforce.com Developer Experience (sfdx) Command Line Interface (CLI)**
	1) Follow the instructions to download and install sfdx: *https://developer.Salesforce.com.com/docs/atlas.en-us.sfdx_setup.meta/sfdx_setup/sfdx_setup_install_cli.htm*. If you already have sfdx-cli installed then run the command `sfdx update` to update the tool to the latest version.

### Steps to run the script:
1. In Finder, navigate to the folder named `salesforce_file_sync_scripts`, and open the config.json file in a text editor.

      i) Change the YOUR_USERNAME value to a valid Salesforce.com username in your organization. eg: john_doe@acme.com

      ii) PII: The script is masking Personally Identifiable Information (PII) by default. However, any additional fields can be included to be masked in the config file. To do so, Add/Delete/Modify those fields in the `pii_fields` section.

      iii) Custom Fields: if you are including custom fields, these can be added in the appropriate entity under 'schema'. Add the fields at the end of the fields list one field per line, ending with a comma,  (also make sure all the fields except the last one ends with the comma). If unsure, go to *https://jsonlint.com/* and paste the whole file contents and validate it. if it's invalid, make necessary corrections.

      iv) Save and Close the file.

2. Open a terminal and run PowerShell using `pwsh` command.
3. Navigate to the folder containing the scripts using the cd command:  eg `cd /Users/johndoe/Downloads/salesforce_file_sync_scripts/`
4. Now run the script using `./salesforce_file_sync_scripts.ps1`.
5. The script will open the web browser in order for you to log in to your Salesforce.com instance - and the script will be authorized to query your Salesforce.com instance. After logging in, you can go back to the PowerShell window.
6. The script will present the following options: `1` for Download Salesforce.com schema,  `2` for Download Salesforce.com Data , (or `3` to exit the script). Make your choice and press `[ENTER]`.
7. With choice `2`, you'll be given another set of options to export specific entities or all of them. We recommend choosing â€™1â€™ for All. Press your chosen key and press `ENTER`.
8. Now wait for the data download to finish. The script will exit with a message after completion. The schema data should download in a few minutes. The full data download can take several hours for larger Salesforce.com instances. Please make sure you have a stable internet connection and can leave the script running in the background until it is done.
9. Due to the salesforce API rate limitations, the script may show error messages while exporting. In that case, simply run the script again, and it will continue from the point of failure.
10. Upon a successfully script execution, the exported data will be zipped into `sf_data_export.zip` file in the same folder. This file can now be reviewed and then shared with Cien (support@cien.ai) using your preferred file sharing client (e.g. Dropbox.com). If the choice made in step 7 is to export individual entities, then the user will need to zip the output folder manually.