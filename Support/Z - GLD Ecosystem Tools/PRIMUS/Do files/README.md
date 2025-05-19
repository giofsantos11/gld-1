# Task 1 do files

This folder contains the do files used in Task 1

## `get metadata.do`: Reconciling GLD and Datalibweb survey versions

The do file `get metadata.do` performs the following processes

### A. Extract Metadata from GLD Folder Structure

This block recursively scans the folder structure of the GLD directory to construct survey identifiers and extract version information:
- It parses the folder names into components: country code, survey year, survey short name, and master/alternative version codes.
- Raw folders are excluded because their counterparts in the Datalibweb cannot be identified. Thus, we assume that if a harmonized folder is missing, the raw is also not uploaded. This is consistent with the pre-PRIMUS workflow of GLD where both harmonized and raw are uploaded at the same time (i.e., even if a raw is available earlier, this is not uploaded until the harmonized data is not finalized). 
- When multiple versions are present, only the latest is kept for each unique survey. This will be matched later with the latest version in Datalibweb. All intermediate versions that require upload will be identified later in the do file, `upload sequence.do`

### B. Extract Metadata from Datalibweb

This block retrieves survey metadata from Datalibweb using the `datalibweb` Stata API and merges it with the GLD metadata:
- The merge identifies surveys that are in GLD but not in Datalibweb, and vice versa.
- Based on duplicate patterns and merge results, each survey is flagged for a potential action:
  - New upload
  - Version update
  - Error (present in Datalibweb but missing in GLD)

If no mismatches are detected, the script exits early, indicating Datalibweb is already up to date.


### C. Case Classification and Path Construction

After reconciliation, each unmatched or inconsistent survey is classified into one of four case types. These classifications determine the upload procedure required in PRIMUS.

#### Case Classification Table

| Case Type | Description |
|-----------|-------------|
| **Case 1 – New upload** | The survey is present in GLD but not yet in Datalibweb. Both raw and harmonized data need to be uploaded. |
| **Case 2 – Update harmonized data only** | The survey exists in both sources with the same master version (raw data), but the harmonized (alternative) version is newer in GLD. Only the harmonized file needs to be updated. |
| **Case 3 – Update raw and harmonized data** | The survey exists in both sources, but both the raw (master) and harmonized (alternative) versions differ. A full re-upload of both components is required. |
| **Case 4 – New upload with multiple harmonized versions** | A variation of Case 1, where the harmonized file version number suggests multiple versions exist (e.g., `_A01`, `_A02`). This may indicate prior unofficial uploads or internal testing versions. Extra caution is advised to prevent accidental overwrite. |

### File Path Construction

For each case, the script constructs:
- `rawdir`: the directory path to the raw `.dta` files (used during XML generation and PRIMUS upload).
- `harmdir`: the path to the harmonized files (used for upload and metadata reference).

Both paths follow GLD's internal folder naming conventions and are stored as variables in the output Excel for reference during automation.

### D. Excel Output

The final output is an Excel file containing three separate tabs that guide the PRIMUS upload process. The table below describes the purpose of each tab:

| Sheet Name | Description |
|------------|-------------|
| **Guide**  | Contains definitions and descriptions for all variables in the output file, serving as metadata for users. |
| **Main**   | The primary sheet listing all upload cases (new uploads and version updates), along with the constructed paths for raw and harmonized folders. |
| **Flags**  | A troubleshooting sheet listing unusual cases where a survey appears in Datalibweb but not in GLD, which may require manual review. |

The file is saved in the parent directory with the naming convention:  
`gld_dlw_reconcile_YYYY_MM_DD.xlsx`. Everytime the `get metadata.do` is run, the previous Excel output is deleted to ensure that only one version exists in the parent folder. 

