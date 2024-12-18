# **GTM Suite - Getting GTM Suite Reports & Datasets on to, and running on, your PBI Staging Workspace.**

#   

# **Step-by-step instructions:** 

**Step 1: GitHub Integration Hub**

Download files from Cien.ai’s Integration Hub [(https://github.com/cienai/IntegrationHub/tree/main)](https://github.com/cienai/IntegrationHub/tree/main))
to a Windows computer: 

**/powerbi**

- GTM Suite - Automatic Data Enhancement Report.pbix
- GTM Suite - Dataset - Automatic Enhancement .pbix
- GTM Suite - Dataset - Sales Performance.pbix
- GTM Suite - Management Report.pbix
- GTM Suite - Strategy Report.pbix
- GTM Suite - Tactical Report.pbix
- GTM Suite - Utility Box Report.pbix

**/scripts**
/pbi_deploy
- README.md
- cfg.json
- deploy.ps1

**Step 2: Sign in to the Power BI Service**

Open your web browser and go to the Power BI Service website (https://app.powerbi.com).
Sign in with your Power BI account credentials.


**Step 3: Create or Select a “GTM Suite Staging” Workspace**

In Power BI Service (online), Workspaces are used to organize datasets, reports, and dashboards. You can create a new workspace or select an existing one.
*Note: You will need a Premium-per-User Power BI license to do this, and the workspace access level should be “Admin”.*
 
a/ To create a new “GTM Suite Staging” workspace, click on "Workspaces" in the left sidebar, then click "Create a workspace."
or
b/ To select an existing workspace, click on "Workspaces" and choose the workspace you want to use.

*Note: The workspace settings need to be set as “Premium-Per-User” and “Large Data Set Storage Format”.* 

  
**Step 3: Datasets - settings and publishing to workspace**

In Power BI Desktop (local):

1.  Open dataset:  - GTM Suite - Dataset - Automatic Enhancement, go to “Transform Data” -> “Edit  parameters”, and put in the correct params to the db server/db name/db type. We recommend that you connect to the _cien\_dghyzcwxdptrmpqqt\_db_  db that is a simulated reference implementation dataset, with no data security implications.
2.  At this point you will be asked for your username and password for that server. Enter and Save.
3.  Refresh the dataset (this can take up to 20 minutes)
4.  Publish the dataset to your online “Staging” Workspace
5.  Repeat the process above for the second dataset - GTM Suite - Dataset - Sales Performance.pbix

**Step 4: Reports - Connecting to Datasets and publishing to workspace**

In Power BI Desktop

1.  Open each of the visualization reports (GTM Suite - Management Report.pbix, GTM Suite - Strategy Report.pbix, GTM Suite - Tactical Report.pbix, Utility Box Report.pbix)
2.  In Menu - click “Transform Data” -> “Data Source Settings”
3.  For GTM Suite - Automatic Data Enhancement Report.pbix, connect it to **GTM Suite - Dataset - Automatic Enhancement.pbix**
4.  For the **other reports**, connect them to **GTM Suite - Dataset - Sales Performance.pbix**

Now you should have a working report set in your “GTM Suite Staging” workspace. 

**Future releases:** 

Cien is frequently improving its platform and reports. When a new build is available, it will be reflected in our Github Release Notes. For your staging workspace (and subsequently all your workspaces) to reflect the latest release, you will have to repeat steps 1 - 4 above. 

**Deploying Across your PBI organization:** 

To publish your staging workspace reports across your different customer workspaces, you will use the scripts in the GitHub integration hub /pbi\_deploy folder. Find instructions for configuring and running deployment script in the associated README.md file. The script will copy the current staging workspace report set to an unlimited number of workspaces and automatically refresh with the appropriate datasource.