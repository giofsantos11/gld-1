# Uploading GLD data into PRIMUS

## Motivation for Integrating the Global Labor Database (GLD) into PRIMUS

The **Global Labor Database (GLD)** is the World Bank’s flagship initiative for harmonizing labor force and household surveys with labor modules. GLD ensures transparency and reproducibility by documenting each step of the harmonization process—from raw data acquisition to the coding of harmonized variables—and by sharing codes and metadata openly through GitHub. It is both a research asset and a public good that empowers users to rely on harmonized “as-is” files or to customize the process to suit deeper analytical needs. 

Currently, **Datalibweb** acts as the front-end interface through which World Bank users download harmonized labor data from GLD using the Stata API. [PRIMUS](https://github.com/worldbank/primus), on the other hand, is the institutional platform designed to ensure that data uploaded to Datalibweb meets Bank-wide clearance protocols, with roles for uploaders, approvers, and finalizers. It provides the infrastructure for version control, metadata validation, and auditability of microdata workflows. PRIMUS also includes built-in Stata commands and functions that enable the entire upload process to be scripted. 

Unlike other databases that rely on PRIMUS for multi-stage validation, all datasets in the GLD server have already undergone extensive quality checks. These include validation against external indicators (e.g., ILO, WDI), over-time consistency tests, and consultation with national statistical offices and World Bank regional staff. As such, the integration of GLD into PRIMUS is not to conduct additional validation but to use PRIMUS as a structured conduit to upload datasets to Datalibweb in accordance with institutional protocols.

<img src="Utilities/primus-gld.png" alt="Integration of GLD into PRIMUS" width="600"/>

Integrating GLD into PRIMUS requires careful attention to a number of technical and procedural requirements unique to the PRIMUS platform. For instance, PRIMUS mandates that each upload be accompanied by an XML file containing summary indicators derived from the microdata. The upload process also differs depending on whether the dataset represents a new entry in GLD or an update to an existing dataset, with each scenario requiring distinct steps. In addition, there are important platform-specific constraints to consider: survey folders must not exceed 1.5 GB in total size, only certain file types are accepted, and strict version sequencing is enforced (e.g., version 2 cannot be uploaded unless version 1 already exists).

The goal of this project is two-fold. First, it seeks to ensure that all these complications and requirements can be addressed through a streamlined workflow, eliminating the need for manual uploads. Second, it aims to automate the upload process itself, through integration with Stata, so that PRIMUS uploads can occur seamlessly in the background without requiring significant analyst effort.

This GitHub page serves as a public resource for documenting the integration of the Global Labor Database (GLD) into PRIMUS. It provides:

- The full codebase required for automating uploads,
- Detailed explanations of the logic behind each step,
- Documentation of PRIMUS protocols and constraints,
- Reflections on best practices for addressing PRIMUS-specific requirements.

### [Tasks folder](./Tasks/)

The `Tasks` folder contains the `.do` files that execute the main stages of the upload pipeline. Each task corresponds to a discrete set of operations, executed in sequence as part of the end-to-end workflow:

- **Task 1 – Upload and Confirm:** Identifies which GLD surveys need to be uploaded or updated in Datalibweb. It prepares the files, creates the required XML metadata, compresses folders into ZIPs, and uploads the harmonized and raw files to PRIMUS. It also confirms the transactions to move them out of draft status.
- **Task 2 – Approve:** Automatically reviews the uploaded and confirmed transactions in PRIMUS and submits them for final approval, making the datasets visible and accessible in Datalibweb.
- **Task 3 – Reconciliation Report:** Generates diagnostic reports comparing GLD and Datalibweb holdings, flags inconsistencies, and informs the Task 1 logic about which surveys require uploads, version updates, or no action.

### [Do files folder](./Do%20files/)

The `Do files` folder contains reusable subroutines and helper scripts used by the main tasks. These include:

- Functions for constructing dynamic folder paths
- XML generation code for PRIMUS compliance
- Logging utilities for tracking file size, errors, and transaction IDs
- Zip and upload handlers that interface with `robocopy`, `tar`, and the `primus` API

These modular scripts ensure flexibility, traceability, and maintainability of the PRIMUS automation process.

### [PRIMUS Rules and Constraints](./Documentation/PRIMUS-Rules-Constraints.md)

This document outlines the institutional rules enforced by PRIMUS. It categorizes constraints into areas such as upload cycle requirements, transaction ID handling, version sequencing, and folder size or structure rules. Understanding these rules is essential for ensuring that uploads are successful and compliant with Bank protocols.

### [Best Practices](./Documentation/Best-Practices.md)

This document captures the lessons learned and best practices developed while integrating GLD into PRIMUS. It offers strategies to overcome size restrictions, streamline version control, and maintain data traceability. These recommendations are meant to improve efficiency, minimize human error, and ensure smooth operations in future integrations.



