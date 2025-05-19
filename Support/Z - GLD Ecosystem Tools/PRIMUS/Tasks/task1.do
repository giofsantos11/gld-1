/* TASK SET 1
1. Identify the surveys needed to upload/update
2. Upload the surveys
3. Confirm the upload										*/

* Folder names: Pls use backward slash because forward slashes creates issue with Windows commands
global primusfolder "C:\Users\wb510859\OneDrive - WBG\PRIMUS"
global gldfolder "C:\Users\wb510859\WBG\GLD - GLD"
global logfolder "C:\Users\wb510859\OneDrive - WBG\PRIMUS\log files"

* File size limit
scalar filelimit = 1.0

* Sample restriction
global includepanels = "No"

global datestamp = subinstr("`=c(current_date)'", " ", "_", .)  
global timestamp = subinstr("`=c(current_time)'", ":", "-", .)  

* Create a log file
log using "${logfolder}/task1_${datestamp}_${timestamp}.log"
* Identify surveys need to upload/update
do "${primusfolder}/Do files/get metadata.do"

* Load the create xml function
do "${primusfolder}/Do files/create xml file.do"

* Upload the surveys
do "${primusfolder}/Do files/upload sequence.do"

* Confirm the uploads
do "${primusfolder}/Do files/confirm upload.do"

log close
