## Best Practices for Uploading GLD Data to PRIMUS

In addition to strict PRIMUS rules, several workflow design choices implemented in the automation script serve as best practices. These are not enforced by the PRIMUS system itself, but are essential for avoiding upload issues, reducing reviewer confusion, and maintaining a robust, auditable process.

### 1. Classification of Upload Cases

The upload workflow categorizes each survey into one of four `case_type`s based on the differences between GLD and Datalibweb versions. These classifications guide whether to upload raw data, harmonized data, or both. While not required by PRIMUS, this classification ensures that:

- Version sequencing is respected,
- Raw data is uploaded only when needed, and
- The right upload logic is applied per survey.

This logic prevents accidental overwriting or skipped uploads due to incomplete prerequisites.

### 2. Creation of `.doc` Files for Oversized Datasets

When a survey folder exceeds the 1.5 GB size limit imposed by PRIMUS, the harmonized or raw data cannot be uploaded. Instead of skipping the upload entirely, the script creates a `.doc` file in the `Doc/Technical/` folder with the message:

> "The full data cannot be uploaded to Datalibweb because it is too big. To access the data, write an email..."

This allows the folder to still be uploaded and registered in PRIMUS, preventing it from being misclassified as missing. Reviewers will see the explanatory `.doc` file and know that no action is required.

### 3. Zipping the Entire Folder

The script compresses the entire cleaned survey folder into a single `.zip` file (using `tar.exe`) before uploading. This is not required by PRIMUS but is considered best practice for several reasons:

- Uploading a single ZIP avoids managing individual file uploads.
- Ensures folder structure is preserved (`Data`, `Doc`, `Programs`).
- Simplifies automation and troubleshooting.

**Caveat:** Each file within the ZIP must still comply with PRIMUS rules (e.g., file naming, size limits, accepted formats).

### 4. Transaction Logging and Issue Tracking

The script maintains a central CSV log file named like `tranxids_YYYYMMDD_HHMMSS.csv`, which stores:

- `surveyid`
- `tranxid_harmonized`
- `tranxid_raw`
- `notes` or error messages (e.g., “File too large”, “Dataset not found”, “Upload successful”)

This log allows for:

- Tracking all transactions in a single, structured place.
- Reuse in the confirmation and approval phases.
- Debugging of issues in automated runs without needing to reprocess all surveys.

Additionally, Stata log files (`.log`) are generated per process if desired, ensuring full traceability.

### 5. Checks Performed Before Upload

Before uploading, the script performs a number of defensive checks to ensure data availability and structural integrity:

| Check Description           | Condition                                                 | Consequence                                                    |
|----------------------------|-----------------------------------------------------------|----------------------------------------------------------------|
| **Check for `.dta` file**  | `confirm file` is used to verify the harmonized file exists (`*_ALL.dta`) | If missing, the survey is skipped and logged as a missing dataset |
| **Check for valid `tranxid`** | Ensures `tranxid_harmonized` is not `"NA"` or missing      | Without it, confirmation and approval cannot proceed           |
| **Folder size check**      | Uses PowerShell to check if the ZIP will exceed 1.5 GB    | If exceeded, skips upload and creates `.doc` explanation       |
| **Case logic check**       | Uploads raw only for cases 1, 3, and 4                    | Avoids uploading unnecessary files                             |

These checks reduce error rates in batch uploads and avoid triggering PRIMUS validation failures or inconsistent system states.
