# Uploading GLD data into PRIMUS

## Motivation for Integrating the Global Labor Database (GLD) into PRIMUS

The **Global Labor Database (GLD)** is the World Bank’s flagship initiative for harmonizing labor force and household surveys with labor modules. GLD ensures transparency and reproducibility by documenting each step of the harmonization process—from raw data acquisition to the coding of harmonized variables—and by sharing codes and metadata openly through GitHub. It is both a research asset and a public good that empowers users to rely on harmonized “as-is” files or to customize the process to suit deeper analytical needs. 

Currently, **Datalibweb** acts as the front-end interface through which World Bank users download harmonized labor data from GLD using the Stata API. **PRIMUS**, on the other hand, is the institutional platform designed to ensure that data uploaded to Datalibweb meets Bank-wide clearance protocols, with roles for uploaders, approvers, and finalizers. It provides the infrastructure for version control, metadata validation, and auditability of microdata workflows.

Unlike other databases that rely on PRIMUS for multi-stage validation, all datasets in the GLD server have already undergone extensive quality checks. These include validation against external indicators (e.g., ILO, WDI), over-time consistency tests, and consultation with national statistical offices and World Bank regional staff. As such, the integration of GLD into PRIMUS is not to conduct additional validation but to use PRIMUS as a structured conduit to upload datasets to Datalibweb in accordance with institutional protocols.

<img src="Utilities/primus-gld.png" alt="Integration of GLD into PRIMUS" width="600"/>

Integrating GLD into PRIMUS requires careful attention to a number of technical and procedural requirements unique to the PRIMUS platform. For instance, PRIMUS mandates that each upload be accompanied by an XML file containing summary indicators derived from the microdata. The upload process also differs depending on whether the dataset represents a new entry in GLD or an update to an existing dataset, with each scenario requiring distinct steps. In addition, there are important platform-specific constraints to consider: survey folders must not exceed 1.5 GB in total size, only certain file types are accepted, and strict version sequencing is enforced (e.g., version 2 cannot be uploaded unless version 1 already exists).

The goal of this project is two-fold. First, it seeks to ensure that all these complications and requirements can be addressed through a streamlined workflow, eliminating the need for manual uploads. Second, it aims to automate the upload process itself—ideally through integration with Stata—so that PRIMUS uploads can occur seamlessly in the background without requiring significant analyst effort.

This integration aligns with PRIMUS’s role as the central gateway for uploading licensed, validated data into secured cloud storage, while preserving the GLD’s core principles of openness, transparency, and user empowerment. Moreover, formalizing GLD uploads via PRIMUS increases institutional visibility, ensures traceability, and positions the GLD to scale sustainably as part of the Bank’s unified data architecture.
