* TASK 2: Approve the data

* Folder names: Pls use backward slash because forward slashes creates issue with Windows commands
global primusfolder "C:\Users\wb510859\OneDrive - WBG\PRIMUS"
global gldfolder "C:\Users\wb510859\WBG\GLD - GLD"
global logfolder "C:\Users\wb510859\OneDrive - WBG\PRIMUS\log files"

global datestamp = subinstr("`=c(current_date)'", " ", "_", .)  
global timestamp = subinstr("`=c(current_time)'", ":", "-", .)  

* Create a log file
log using "${logfolder}/task2_${datestamp}_${timestamp}.log"

* Load the Excel file
import delimited using "${logfolder}/latest.csv", varnames(1) clear

capture confirm string variable tranxid_harmonized
if !_rc {
    drop if tranxid_harmonized == "NA" | missing(tranxid_harmonized)
}

* Loop over all rows
forvalues i = 1/`=_N' {
    *local case = case_type[`i']
    local surveyid = surveyid[`i']
    local tranx_h = tranxid_harmonized[`i']
    local tranx_r = tranxid_raw[`i']

    * Harmonized action (process 14)
    primus action, tranxid(`tranx_h') decision(APPROVE) proc(14) comments("Approved")

    * Raw action (process 15)
    if "`tranx_r'" != "NA" | missing("`tranx_r'") {
		primus action, tranxid(`tranx_r') decision(APPROVE) proc(15) comments("Approved")
    }	
}

* Delete latest because we dont want the next run to pick this up!
erase "${logfolder}/latest.csv"

log close

