# Tasks

### Description of Tasks

The integration process is organized into three separate Stata `.do` files, each corresponding to a scheduled task. These will be executed automatically using a task scheduler on different dates or triggers, depending on the workflow.

- **Task 1 – Upload and Confirm**: This task identifies GLD surveys that have not yet been uploaded or updated in Datalibweb. It uploads the relevant survey files and confirms the transactions in PRIMUS. This initiates the data transfer and registers the upload into the PRIMUS system.
  
- **Task 2 – Approve for Datalibweb**: This follow-up task is run after Task 1. It reviews the uploaded transactions and automatically approves them in PRIMUS. Once approved, the data becomes visible and accessible in Datalibweb for authorized users.
  
- **Task 3 – Cleanup**: This task removes log files and temporary working files generated during Task 1. It helps maintain a clean working environment and ensures that unnecessary files do not accumulate over time.

Each task plays a distinct role in automating and maintaining the end-to-end data upload workflow from the GLD server to Datalibweb via PRIMUS.
