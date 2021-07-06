
/*%%=============================================================================================
	0: GLD Harmonization Preamble
================================================================================================*/

/* -----------------------------------------------------------------------

<_Program name_>				IND_1987_NSS43-SCH10_V01_M_V01_A_GLD.do </_Program name_>
<_Application_>					STATA 15 <_Application_>
<_Author(s)_>					World Bank Jobs Group  </_Author(s)_>
<_Date created_>				2021-05-24 </_Date created_>
<_Date modified>				2021-05-24 </_Date modified_>

-------------------------------------------------------------------------

<_Country_>						India </_Country_>
<_Survey Title_>				National Sample survey 1987 Schedule 10 - Round 43 </_Survey Title_>
<_Survey Year_>					1987 </_Survey Year_>
<_ICLS Version_>				Unknown (does not seem to follow ICLS-13 </_ICLS Version_>
<_Study ID_>					DDI-IND-MOSPI-NSSO-43Rnd-Sch10-1987-88 </_Study ID_>
<_Data collection from (M/Y)_>	MM/1987 </_Data collection from (M/Y)_>
<_Data collection to (M/Y)_>	MM/1988 </_Data collection to (M/Y)_>
<_Source of dataset_> 			http://microdata.gov.in/nada43/index.php/catalog/55 </_Source of dataset_>
<_Sample size (HH)_> 			129,194 </_Sample size (HH)_>
<_Sample size (IND)_> 			667,848 </_Sample size (IND)_>
<_Sampling method_> 			The sample design adopted for this round of survey was similar to that followed in the past surveys in its general aspects. The ge neral scheme was a two stage stratified design with the first stage units being villages in the rural areas and urban frame survey blocks(UFS) in the urban areas. The second stage units were the households. 	</_Sampling method_>
<_Geographic coverage_> 		State Level </_Geographic coverage_>
<_Currency_> 					Indian Rupee </_Currency_> -----------------------------------------------------------------------

<_Version Control_>

* Date: [YYYY-MM-DD] File: [As in Program name above] - [Description of changes]
* Date: [YYYY-MM-DD] File: [As in Program name above] - [Description of changes]

</_Version Control_>

-------------------------------------------------------------------------*/


/*%%=============================================================================================
	1: Setting up of program environment, dataset
================================================================================================*/

*----------1.1: Initial commands------------------------------*

clear
set more off
set mem 800m

ssc install distinct

*----------1.2: Set directories------------------------------*

global path_in "C:\Users\Angelo Santos\OneDrive - George Mason University\Summer 2021\510859_AS\IND\IND_1987_NSS43-SCH10\IND_1987_NSS43-SCH10_v01_M\Data\Stata"
global path_output "C:\Users\Angelo Santos\OneDrive - George Mason University\Summer 2021\510859_AS\IND\IND_1987_NSS43-SCH10\IND_1987_NSS43-SCH10_v01_M_v01_A_GLD\Data\Harmonized"

*----------1.3: Database assembly------------------------------*
* Start process with individual block 4
tempfile block4 block4short

use "$path_in/Block-4-Persons-Demographic-current-weekly-activity- Records.dta", clear

* Identify the duplicates in person id
distinct Person_key //duplicates of 44 records
duplicates tag Person_key, gen(tag)

* Remove duplicates

	* Rule 1: If age is missing, drop that duplicate
	drop if B4_q5 == . & tag == 1 //drop

	* Rule 2: Keep the record with more information on labor market
	gen count = B4_q12 != "" // if has value of q12, also has value for q14-15
	bys Person_key: egen countmax = max(count)
	drop if tag == 1 & countmax != count

	* Rule 3: Keep the first recorded - get back to this later on

	duplicates drop Person_key, force
	distinct Person_key

* At this point, there are 667,804 persons (vs 667,844 in MOSPI - which included duplicates)
save `block4'

	* Save only Person key and current weekly activity (CWA)
	* CWA is important for us to reconcile with daily activity records in Block 5
	keep Person_key B4_q11

save `block4short'


* Proceed with Block 5
use "$path_in/Block-5-Persons-Daily- activity- time-disposion-Records.dta", clear

* Drop the invalid data to arrive with total consistent with that reported by MOSPI
drop if missing(B5_q13)
count // same total as reported by IND Ministry

* Generate person serial number from the unique person ID variable, Person_key
gen Prsn_slno = substr(Person_key, -3, 3)

********************************************************************************
********************************************************************************
* Sorting procedure

/*==============================================================================
Current weekly activity is selected based on this order:
	1. Equal to current weekly activity variable
	2. Activity status classification (see below)
	3. Number of days worked in a week
	4. If number of days are equal between two employment activities, the status
	code that is smaller in value is taken as the CWA (e.g., activites 11 and 51
	are worked for 3.5 days each; activity 11 will be the CWA because it is smaller
	in value than 51.

	Rule #1 is added because otherwise, CWA will not be entirely equal to activity status 1
===============================================================================*/


/* Need to classify activity status into the following:

	a. Working status
	b. Non-working status but seeking employment
	c. Neither working nor available for work

*/

destring B5_q3, gen(priority_tag)
gen num_status = priority_tag

* Classify the level of priority
recode priority_tag 11/72=1 81 82=2 91/98=3 99=.

* Decreasing order of number of days worked
gen neg_days = -(B5_q13)

/*==============================================================================
Caveat on using the number of days worked variable:

As per the instruction manual for the 1987 EUE, the total number of days for all
the activities shold be 7. However, in the data, the number of days for all activities
taken together do not all add up to 7. A total of 13,000 individuals have total
days more than or less than 7.

The harmonizer leaves it up to the data user to explore methods to address this
data issue. For the purposes of this exercise, only the ordering of the activity
duration is taken into consideration, regardless of the number of days sum up for
that individual or not.

==============================================================================*/
* Generate PID bec this is variable name used for the sorting procedure below
gen PID = Person_key

* Total number of days for each person's activity should be equal to 7
bys PID: egen tot = sum(B5_q13)
distinct PID if tot != 7 //nearly 13,000 people with unreliable data

distinct PID

* There are several duplicates in status code for the same person.
* Need to keep only one status code such that HH - Person - status code is unique
duplicates drop PID B5_q3, force

* Check if unique after trimming records
distinct PID B5_q3, joint
* End up with 750,293 unique observations

* Merge with block 4 short
merge m:1 Person_key using `block4short'
* There are 238 persons in Block 5 not found in Block 4
* There are 8 persons in Block 4 not in Block 5

gen first = 1 if B5_q3 == B4_q11
replace first = 2 if B5_q3 != B4_q11

sort PID first priority_tag neg_days num_status
bys PID: gen runner = _n

* At this point, we expect activity 1 to be equal to CWA, B4_q11
count if B5_q3! =  B4_q11 & runner==1 & !missing(B4_q11)

* However, there are 193 cases of mismatch. What do we do with this?
* In principle, CWA should be derived from daily activity records. I stick to this
* Also, since 50% of these cases have value = 99 under CWA, using daily activity records
* would also be more favorable. In terms of identifying primary and secondary 7-day
* occupation codes, which are mapped only to CWA, we leave them as missing
* for these 193 records.

* Keep only necessary variables for reshape
keep B5_q3 B5_q4 B5_q13 B5_q14 B5_q15 B5_q16  Hhold_key Prsn_slno Person_key runner

* Activity serial number is not unique, create serial id for each person

reshape wide B5_q3 B5_q4 B5_q13 B5_q14 B5_q15 B5_q16, i(Person_key) j(runner)

* Check whether activities correctly coded in order - there should not be a third activity if
* there is no second activity.
count if missing(B5_q31) & !missing(B5_q32)
count if missing(B5_q32) & !missing(B5_q33)
count if missing(B5_q33) & !missing(B5_q34)

* Next, we merge with full block 4
merge m:1 Person_key using `block4', nogen

tempfile weekly_act
save `weekly_act'


* Create temporary files for each block where we save the clean version
tempfile block3 block7 block6

* Proceed with block 1- 3

use "$path_in/Block-1-3-Household-Records", clear

duplicates tag Hhold_key, gen(tag)

	* Rule 1: Keep the duplicated record with more non-missing values
	foreach var of varlist B3_q7 - B3_q16{
		gen count_`var' = `var' ! = .
		}

	egen totl_nonmissing = rowtotal(count_B3_q7 - count_B3_q16)
	bys Hhold_key: egen max_nonmissing = max(totl_nonmissing)

	drop if tag ==1 & max_nonmissing != totl_nonmissing

	* Rule 2: At this point, all duplicates have same information. Drop duplicates
	duplicates drop Hhold_key, force

	save `block3'

* Proceed with block 7
use "$path_in/Block-7-Persons- usual-activity-statuscode-11to94-Records", clear

	* Since no pattern found, drop first record
	duplicates drop Person_key, force

	save `block7'

* Proceed with block 6
use "$path_in/Block-6--Persons-Usual-activity- migration-Records.dta", clear

* Identify the duplicates in person id
distinct Person_key //duplicates of 44 records
duplicates tag Person_key, gen(tag)

* Remove duplicates (keep the first instance)
duplicates drop Person_key, force


/*==============================================================================
Caveat:

At this point, we are not sure whether the dropped HHs/persons in Blocks 1-3, 6
and 7 are the exact match to those dropped in Block 4.

Unfortunately, there is no other common variable that would allow us to filter
the perfect match. We ignore the implications of the mismatch and leave it to the data analyzer
to explore other innovative options to match these observations.
==============================================================================*/


* Merge Individual 12 month info with 7 day info
merge 1:1 Person_key using `weekly_act', keep(match master) nogen

* Merge with HH info
merge m:1 Hhold_key using `block3', keep(match master) nogen

* Merge with additional questions for employed (note this is a subset)
merge 1:1 Person_key using `block7', keep(match master) nogen



/*%%=============================================================================================
	2: Survey & ID
================================================================================================*/

{

*<_countrycode_>
	gen str4 countrycode="IND"
	label var countrycode "Country code"
*</_countrycode_>


*<_survname_>
	gen survname = "NSS43-SCH10"
	label var survname "Survey acronym"
*</_survname_>


*<_survey_>
	gen survey = "LFS"
	label var survey "Survey type"
*</_survey_>


*<_year_>
	gen int year = 1987
	label var year "Year of the start of the survey"
*</_year_>


*<_vermast_>
	gen vermast = "01"
	label var vermast "Version of master data"
*</_vermast_>


*<_veralt_>
	gen veralt = "01"
	label var veralt "Version of the alt/harmonized data"
*</_veralt_>


*<_harmonization_>
	gen harmonization = "GLD"
	label var harmonization "Type of harmonization"
*</_harmonization_>


*<_int_year_>
	gen int_year=.
	replace int_year = 1987 if inlist(SubRound,"1","2")
	replace int_year = 1988 if inlist(SubRound,"3","4")
	label var int_year "Year of the interview"
*</_int_year_>


*<_int_month_>
	gen  int_month = .
	label de lblint_month 1 "January" 2 "February" 3 "March" 4 "April" 5 "May" 6 "June" 7 "July" 8 "August" 9 "September" 10 "October" 11 "November" 12 "December"
	label value int_month lblint_month
	label var int_month "Month of the interview"
*</_int_month_>


*<_hhid_>
/* <_hhid_note>

	From different surveys a str9 should be created. In later surveys this is:
	FSU (str5) + Hamlet (str1) + 2nd Stage Sample (str1) + Sample HH Id (str2).

	Here Hhold_Key is str8 of FSU + Stage 2 Stratum + Sample HH Id. Add subround to make str9
	From preparing I notice there is one case where Stage2_Stratum is "0", when this makes no sense,
	HH Key has code 2, so first amend that
</_hhid_note> */
	gen hamlet = substr(Vill_Blk_No, -1, 1)
	replace FSU_No = "11723" if Person_key == "11723203001"
	egen hhid = concat(FSU_No hamlet Sub_stratum Hhold_No)
	label var hhid "Household ID"
*</_hhid_>


*<_pid_>
	egen  str11 pid = concat(hhid Prsn_Slno)
	label var pid "Individual ID"
	isid pid
*</_pid_>


*<_weight_>
	gen weight = Wgt4_pooled
	label var weight "Household sampling weight"
*</_weight_>


*<_psu_>
	gen psu = FSU_No
	label var psu "Primary sampling units"
*</_psu_>


*<_strata_>
	gen strata = Stratum
	label var strata "Strata"
*</_strata_>


}

/*%%=============================================================================================
	3: Geography
================================================================================================*/

{

*<_urban_>
	destring Sector, gen(urban)
	recode urban (1 = 0) (2 = 1)
	label var urban "Location is urban"
	la de lblurban 1 "Urban" 0 "Rural"
	label values urban lblurban

*</_urban_>


*<_subnatid1_>

	destring State, gen(subnatid1)
	label de lblsubnatid1 2 "2 - Andhra Pradesh" 3 "3 - Arunachal Pradesh" 4 "4 - Assam" ///
			5 "5 - Bihar" 6 "6 - Goa" 7 "7 - Gujarat" 8 "8 - Haryana" 9 "9 - Himachal Pradesh" ///
			10 "10 - Jammu & Kashmir" 11 "11 - Karnataka" 12 "12 - Kerala" 13 "13 - Madhya Pradesh" ///
			14 "14 - Maharashtra" 15 "15 - Manipur" 16 "16 - Meghalaya" 17 "17 - Mizoram" ///
			18 "18 - Nagaland" 19 "19 - Orissa" 20 "20 - Punjab" 21 "21 - Rajasthan" ///
			22 "22 - Sikkim" 23 "23 - Tamil Nadu" 24 "24 - Tripura" 25 "25 - Uttar Pradesh" ///
			26 "26 - West Bengal" 27 "27 - A & N Islands" 28 "28 - Chandigarh" ///
			29 "29 - Dadra & Nagar Haveli" 30 "30 - Daman & Diu" 31 "31 - Delhi" ///
			32 "32 - Lakshdweep" 33 "33 - Pondicherry"
	label values subnatid1 lblsubnatid1
	label var subnatid1 "Subnational ID at First Administrative Level"
*</_subnatid1_>


*<_subnatid2_>
	destring Region, gen(subnatid2)
	label var subnatid2 "Subnational ID at Second Administrative Level"
*</_subnatid2_>


*<_subnatid3_>
	gen byte subnatid3 = .
	label de lblsubnatid3 1 "1 - Name"
	label values subnatid3 lblsubnatid3
	label var subnatid3 "Subnational ID at Third Administrative Level"
*</_subnatid3_>


*<_subnatidsurvey_>
	gen subnatidsurvey = "subnatid1"
	label var subnatidsurvey "Administrative level at which survey is representative"
*</_subnatidsurvey_>


*<_subnatid1_prev_>
/* <_subnatid1_prev>

	subnatid1_prev is coded as missing unless the classification used for subnatid1 has changed since the previous survey.

</_subnatid1_prev> */
	gen subnatid1_prev = .
	label var subnatid1_prev "Classification used for subnatid1 from previous survey"
*</_subnatid1_prev_>


*<_subnatid2_prev_>
	gen subnatid2_prev = .
	label var subnatid2_prev "Classification used for subnatid2 from previous survey"
*</_subnatid2_prev_>


*<_subnatid3_prev_>
	gen subnatid3_prev = .
	label var subnatid3_prev "Classification used for subnatid3 from previous survey"
*</_subnatid3_prev_>


*<_gaul_adm1_code_>
	gen gaul_adm1_code = .
	label var gaul_adm1_code "Global Administrative Unit Layers (GAUL) Admin 1 code"
*</_gaul_adm1_code_>


*<_gaul_adm2_code_>
	gen gaul_adm2_code = .
	label var gaul_adm2_code "Global Administrative Unit Layers (GAUL) Admin 2 code"
*</_gaul_adm2_code_>


*<_gaul_adm3_code_>
	gen gaul_adm3_code = .
	label var gaul_adm3_code "Global Administrative Unit Layers (GAUL) Admin 3 code"
*</_gaul_adm3_code_>

}

/*%%=============================================================================================
	4: Demography
================================================================================================*/

{

*<_hsize_>
	* Need to recount hh size after dropping individuals in data assembly
	bys hhid: gen hsize = _N
	label var hsize "Household size"
*</_hsize_>


*<_age_>
	gen age = B4_q5
	label var age "Individual age"
*</_age_>


*<_male_>
	destring B4_q4, gen(male)
	recode male (2 = 0)
	label var male "Sex - Ind is male"
	la de lblmale 1 "Male" 0 "Female"
	label values male lblmale
*</_male_>


*<_relationharm_>
/* <_relationharm_note>

	1578 observations (335 HHs) have either no head or more than one.
	Elect HH head following this order:
	 a) eldest male head, if not
	 b) eldest female if no male the head. Use
	 c) lowest running ID to break ties
	Other heads sent to value 5, coded as "Other relatives"
</_relationharm_note> */


	destring B4_q3, replace

	bys Hhold_key: gen one=1 if B4_q3==1
	bys Hhold_key: egen temp=count(one)
	tab temp

	destring Prsn_Slno, gen(pno)
	destring B4_q4, gen(sex)
	gen relation = B4_q3
	bys Hhold_key relation: egen istheremale = total(sex==1)
	bys Hhold_key relation: egen maxagemale = max(cond(sex==1,age,.))
	bys Hhold_key relation: egen maxagefemale = max(cond(sex==2,age,.))
	bys Hhold_key relation: egen minid = min(pno)
	bys Hhold_key relation: egen howmany = total(age==maxagefemale)

	replace relation = 1 if temp==0 & istheremale>=1 & age==maxagemale & minid==pno
	replace relation = 1 if temp==0 & istheremale==0 & age==maxagefemale & minid==pno

	drop istheremale maxage* minid howmany one temp
	bys Hhold_key: gen one=1 if relation==1
	bys Hhold_key: egen temp=count(one)
	tab temp

	bys Hhold_key relation: egen istheremale = total(sex==1)
	bys Hhold_key relation: egen maxagemale = max(cond(sex==1,age,.))
	bys Hhold_key relation: egen maxagefemale = max(cond(sex==2,age,.))
	bys Hhold_key relation: egen minid = min(pno)
	bys Hhold_key relation: egen howmany = total(age==maxagefemale)

	replace relation = cond(temp>1 & relation ==1 & istheremale>=1 & (age!=maxagemale|sex==2),5,cond(age!=maxagefemale & howmany == 1 & temp>1 & relation ==1 &istheremale==0,5,cond(minid!=pno & howmany >1 & temp>1 & relation ==1 & istheremale==0,5,relation)))

	drop one temp
	bys Hhold_key: gen one=1 if relation==1
	bys Hhold_key: egen temp=count(one)
	tab temp
	* 33 cases left, 5 HHs, change manually.

	replace relation = 5 if Hhold_key == "10230202" & pno == 2
	replace relation = 5 if Hhold_key == "11249202" & pno == 11
	replace relation = 5 if Hhold_key == "14591101" & pno == 2
	replace relation = 5 if Hhold_key == "73988201" & pno == 2
	replace relation = 5 if Hhold_key == "74623207" & pno == 100

	drop one temp
	bys Hhold_key: gen one=1 if relation==1
	bys Hhold_key: egen temp=count(one)
	tab temp

	drop one temp
	* At this point, we have single HH head per HH

	gen relationharm = relation
	recode relationharm (3 5 = 3) (7=4) (4 6 8 = 5) (9=6) (0=.)
	label var relationharm "Relationship to the head of household - Harmonized"
	la de lblrelationharm  1 "Head of household" 2 "Spouse" 3 "Children" 4 "Parents" 5 "Other relatives" 6 "Other and non-relatives"
	label values relationharm  lblrelationharm
*</_relationharm_>


*<_relationcs_>
	gen relationcs = relation
	label var relationcs "Relationship to the head of household - Country original"
*</_relationcs_>
*/

*<_marital_>
	destring B4_q6, gen(marital)
	recode marital (1 = 2) (2 = 1) (3 = 5)
	label var marital "Marital status"
	la de lblmarital 1 "Married" 2 "Never Married" 3 "Living together" 4 "Divorced/Separated" 5 "Widowed"
	label values marital lblmarital

	*All spouses should not have "never been married" response
	replace marital = 1 if relationharm == 2

*</_marital_>


*<_eye_dsablty_>
	gen eye_dsablty = .
	label var eye_dsablty "Disability related to eyesight"
*</_eye_dsablty_>


*<_hear_dsablty_>
	gen hear_dsablty = .
	label var eye_dsablty "Disability related to hearing"
*</_hear_dsablty_>


*<_walk_dsablty_>
	gen walk_dsablty = .
	label var eye_dsablty "Disability related to walking or climbing stairs"
*</_walk_dsablty_>


*<_conc_dsord_>
	gen conc_dsord = .
	label var eye_dsablty "Disability related to concentration or remembering"
*</_conc_dsord_>


*<_slfcre_dsablty_>
	gen slfcre_dsablty  = .
	label var eye_dsablty "Disability related to selfcare"
*</_slfcre_dsablty_>


*<_comm_dsablty_>
	gen comm_dsablty = .
	label var eye_dsablty "Disability related to communicating"
*</_comm_dsablty_>

}


/*%%=============================================================================================
	5: Migration
================================================================================================*/


{

*<_migrated_mod_age_>
	gen migrated_mod_age = 0
	label var migrated_mod_age "Migration module application age"
*</_migrated_mod_age_>


*<_migrated_ref_time_>
	gen migrated_ref_time = 0.5 // 6 months ref period
	label var migrated_ref_time "Reference time applied to migration questions"
*</_migrated_ref_time_>


*<_migrated_binary_>
	destring B6_q14, gen(migrated_binary)
	recode migrated_binary (2 = 0)
	label de lblmigrated_binary 0 "No" 1 "Yes"
	label values migrated_binary lblmigrated_binary
	label var migrated_binary "Individual has migrated"
*</_migrated_binary_>


*<_migrated_years_>
	gen migrated_years = .
	replace migrated_years = B6_q15 if migrated_binary == 1
	label var migrated_years "Years since latest migration"
*</_migrated_years_>


*<_migrated_from_urban_>
	gen migrated_from_urban = .
	replace migrated_from_urban = 1 if inlist(B6_q16, "2", "4", "6") & migrated_binary == 1
	replace migrated_from_urban = 0 if inlist(B6_q16, "1", "3", "5") & migrated_binary == 1
	label de lblmigrated_from_urban 0 "Rural" 1 "Urban"
	label values migrated_from_urban lblmigrated_from_urban
	label var migrated_from_urban "Migrated from area"
*</_migrated_from_urban_>


*<_migrated_from_cat_>
	gen migrated_from_cat = .
	replace migrated_from_cat = 2 if inlist(B6_q16, "1", "2") & migrated_binary == 1
	replace migrated_from_cat = 3 if inlist(B6_q16, "3", "4") & migrated_binary == 1
	replace migrated_from_cat = 4 if inlist(B6_q16, "5", "6") & migrated_binary == 1
	replace migrated_from_cat = 5 if inlist(B6_q16, "7") & migrated_binary == 1
	label de lblmigrated_from_cat 1 "From same admin3 area" 2 "From same admin2 area" 3 "From same admin1 area" 4 "From other admin1 area" 5 "From other country"
	label values migrated_from_cat lblmigrated_from_cat
	label var migrated_from_cat "Category of migration area"
*</_migrated_from_cat_>


*<_migrated_from_code_>
	destring B6_q18, gen(helper_var)
	gen migrated_from_code = .
	replace migrated_from_code = subnatid1 if inrange(migrated_from_cat,1,3)
	replace migrated_from_code = helper_var if migrated_from_cat == 4 & (helper_var != subnatid1)
	/* In the above code, if the respondent declared migrating from a diff state but the
	state of residence 6 months ago is same as the current state of residence, then
	this data should be missing.
	*/
	label var migrated_from_code "Code of migration area as subnatid level of migrated_from_cat"
	drop helper_var
*</_migrated_from_code_>


*<_migrated_from_country_>
	* Codes of origin do not clearly identify the specific countries
	gen migrated_from_country = ""
	label var migrated_from_country "Code of migration country (ISO 3 Letter Code)"
*</_migrated_from_country_>


*<_migrated_reason_>
	gen migrated_reason = .
	replace migrated_reason =  3 if inlist(B6_q21,"1", "2", "3") & !missing(migrated_binary)
	replace migrated_reason =  2 if inlist(B6_q21,"4") & !missing(migrated_binary)
	replace migrated_reason =  1 if inlist(B6_q21,"5", "6") & !missing(migrated_binary)
	replace migrated_reason =  4 if inlist(B6_q21,"7", "8") & !missing(migrated_binary)
	replace migrated_reason =  5 if inlist(B6_q21,"9") & !missing(migrated_binary)
	label de lblmigrated_reason 1 "Family reasons" 2 "Educational reasons" 3 "Employment" 4 "Forced (political reasons, natural disaster, …)" 5 "Other reasons"
	label values migrated_reason lblmigrated_reason
	label var migrated_reason "Reason for migrating"
*</_migrated_reason_>

}


/*%%=============================================================================================
	6: Education
================================================================================================*/


{

*<_ed_mod_age_>

/* <_ed_mod_age_note>

Education module is only asked to those XX and older.

</_ed_mod_age_note> */

gen byte ed_mod_age = 0
label var ed_mod_age "Education module application age"

*</_ed_mod_age_>

*<_school_>
	gen byte school = .
	replace school=0 if B4_q9 == "01"
	replace school=1 if B4_q9 != "01" & !missing(B4_q9)
	replace school=. if B4_q9 == "99"
	label var school "Attending school"
	la de lblschool 0 "No" 1 "Yes"
	label values school  lblschool
*</_school_>


*<_literacy_>
	gen byte literacy = .
	replace literacy = 0 if B4_q7 == "00"
	replace literacy = 1 if B4_q7 != "00" & !missing(B4_q7)
	*Allow for missing values if literacy cannot be determined
	replace literacy = . if B4_q7 == "99"
	label var literacy "Individual can read & write"
	la de lblliteracy 0 "No" 1 "Yes"
	label values literacy lblliteracy
*</_literacy_>


*<_educy_>
	gen educy=.
	/* no education */
	replace educy=0 if B4_q7=="01" | B4_q7=="00"
	/* below primary */
	replace educy=1 if B4_q7=="02"
	/* primary */
	replace educy=5 if B4_q7=="03"
	/* middle */
	replace educy=8 if B4_q7=="04"
	/* secondary */
	replace educy=10 if B4_q7=="05"
	/* higher secondary */
	* None
	/* graduate and above in agriculture, engineering/technology, medicine */
	replace educy=16 if B4_q7=="06" | B4_q7=="07" | B4_q7=="08"
	/* graduate and above in other subjects */
	replace educy=15 if B4_q7=="09"

	* Use age to get in between categories using the ISCED mapping
	* (http://uis.unesco.org/en/isced-mappings)
	* Entry into primary is 6, entry into middle is at 11,
	* entry into secondar7 is 14, entry into higher sec is at 16
	* Use age to adapt profile. For example a 17 year old with higher secondary
	* has 11 years of education, not 12

	* Primary kids, allow entry from 5
	replace educy = educy - (5 - (age - 5)) if B4_q7 == "03" & inrange(age,5,11)
	* Middle kids
	replace educy = educy - (3 - (age - 11)) if B4_q7 == "04" & inrange(age,11,14)
	* Secondary
	replace educy = educy - (2 - (age - 14)) if B4_q7 == "05" & inrange(age,14,16)
	* Higher secondary
	*replace educy = educy - (2 - (age - 16)) if B4_q7 == "09" & inrange(age,16,18)

	* Correct if B4_q7 incorrect (e.g., a five year old high schooler)
	replace educy = educy - 4 if (educy > age) & (educy > 0) & !missing(educy)
	replace educy = 0 if (educy > age) & (age < 4) & (educy > 0) & !missing(educy)
	replace educy = educy - (8 - age) if (educy > age) & (age >= 4 & age <=8) & (educy > 0) & !missing(educy)
	replace educy = 0 if educy < 0
	label var educy "Years of education"
*</_educy_>


*<_educat7_>
	destring B4_q7, gen(genedulev)
	gen byte educat7 = .
	replace educat7= 1 if genedulev== 0 | genedulev==1 // No educ
	replace educat7 = 2 if genedulev == 2 & educy < 5 // Primary incomplete
	replace educat7 = 3 if genedulev == 3 & educy >= 5  // Primary complete
	replace educat7 = 4 if genedulev == 4 & educy < 12  // Secondary incomplete
	replace educat7 = 5 if genedulev == 5 & educy >= 12  // Secondary complete
	replace educat7= 7 if genedulev==6 | genedulev==7 | genedulev==8 | genedulev==9
	replace educat7=. if  genedulev==99
	label var educat7 "Level of education 1"
	la de lbleducat7 1 "No education" 2 "Primary incomplete" 3 "Primary complete" 4 "Secondary incomplete" 5 "Secondary complete" 6 "Higher than secondary but not university" 7 "University incomplete or complete"
	label values educat7 lbleducat7
	drop genedulev
*</_educat7_>


*<_educat5_>
	gen byte educat5 = educat7
	recode educat5 4=3 5=4 6 7=5
	label var educat5 "Level of education 2"
	la de lbleducat5 1 "No education" 2 "Primary incomplete"  3 "Primary complete but secondary incomplete" 4 "Secondary complete" 5 "Some tertiary/post-secondary"
	label values educat5 lbleducat5
*</_educat5_>


*<_educat4_>
	gen byte educat4 = educat7
	recode educat4 2 3=2 4 5=3 6 7=4
	label var educat4 "Level of education 3"
	la de lbleducat4 1 "No education" 2 "Primary" 3 "Secondary" 4 "Post-secondary"
	label values educat4 lbleducat4
*</_educat4_>


*<_educat_isced_>
	destring B4_q7, gen(genedulev)
	gen educat_isced = .
	replace educat_isced = 0 if genedulev < 3 //early childhood education
	replace educat_isced = 1 if genedulev == 3 //Primary education
	replace educat_isced = 2 if genedulev == 4 // Lower secondary
	replace educat_isced = 3 if genedulev == 5 //Upper secondary
	replace educat_isced = 6 if inrange(genedulev, 6, 9) //Bachelor
	label var educat_isced "ISCED standardised level of education"
	drop genedulev
*</_educat_isced_>

*----------6.1: Education cleanup------------------------------*

*<_% Correction min age_>

** Drop info for cases under the age for which questions to be asked (do not need a variable for this)
local ed_var "school literacy educy educat7 educat5 educat4 educat_isced"
foreach v of local ed_var {
	replace `v'=. if ( age < ed_mod_age & !missing(age) )
}

*</_% Correction min age_>


}


/*%%=============================================================================================
	7: Training
================================================================================================*/

{

*<_vocational_>
	gen vocational = .
	label values vocational lblvocational
	label var vocational "Ever received vocational training"
*</_vocational_>

*<_vocational_type_>
	gen vocational_type = .
	label de lblvocational_type 1 "Inside Enterprise" 2 "External"
	label values vocational_type lblvocational_type
	label var vocational_type "Type of vocational training"
*</_vocational_type_>

*<_vocational_length_l_>
	gen vocational_length_l = .
	label var vocational_length_l "Length of training, lower limit"
*</_vocational_length_l_>

*<_vocational_length_u_>
	gen vocational_length_u = .
	label var vocational_length_u "Length of training, upper limit"
*</_vocational_length_u_>

*<_vocational_field_>
	gen vocational_field = .
	label var vocational_field "Field of training"
*</_vocational_field_>

*<_vocational_financed_>
	gen vocational_financed = .
	label de lblvocational_financed 1 "Employer" 2 "Government" 3 "Mixed Employer/Government" 4 "Own funds" 5 "Other"
	label var vocational_financed "How training was financed"
*</_vocational_financed_>

}

/*%%=============================================================================================
	8: Labour
================================================================================================*/


*<_minlaborage_>
	gen byte minlaborage = 5
	label var minlaborage "Labor module application age"
*</_minlaborage_>


*----------8.1: 7 day reference overall------------------------------*

{
*<_lstatus_>
	destring B5_q31, gen(lstatus)
	recode lstatus  11/72=1 81 82=2 91/98=3 99=.
	replace lstatus = . if age < minlaborage
	label var lstatus "Labor status"
	la de lbllstatus 1 "Employed" 2 "Unemployed" 3 "Non-LF"
	label values lstatus lbllstatus
*</_lstatus_>


*<_potential_lf_>
	gen byte potential_lf = .
	replace potential_lf = . if age < minlaborage & age != .
	replace potential_lf = . if lstatus != 3
	label var potential_lf "Potential labour force status"
	la de lblpotential_lf 0 "No" 1 "Yes"
	label values potential_lf lblpotential_lf
*</_potential_lf_>


*<_underemployment_>
	gen byte underemployment = .
	replace underemployment = . if age < minlaborage & age != .
	replace underemployment = . if lstatus == 1
	label var underemployment "Underemployment status"
	la de lblunderemployment 0 "No" 1 "Yes"
	label values underemployment lblunderemployment
*</_underemployment_>


*<_nlfreason_>
	destring B5_q31, gen(nlfreason)
	recode nlfreason 11/82=. 91=1 92 93=2 94=3 95=4 96/98=5
	replace nlfreason = . if lstatus != 3 | (age < minlaborage & age != .)
	label var nlfreason "Reason not in the labor force"
	la de lblnlfreason 1 "Student" 2 "Housekeeper" 3 "Retired" 4 "Disabled" 5 "Other"
	label values nlfreason lblnlfreason
*</_nlfreason_>


* Recode the unemployment spell duration vble
	gen unemp_months = B7_q6/4

*<_unempldur_l_>
	gen unempldur_l= floor(unemp_months)
	replace unempldur_l = . if missing(B7_q6) | lstatus!=2
	label var unempldur_l "Unemployment duration (months) lower bracket"
*</_unempldur_l_>


*<_unempldur_u_>
	gen unempldur_u= ceil(unemp_months)
	replace unempldur_u = . if missing(B7_q6) | lstatus!=2
	label var unempldur_u "Unemployment duration (months) upper bracket"
*</_unempldur_u_>

}


*----------8.2: 7 day reference main job------------------------------*


{
*<_empstat_>

	* Note: In the 1987 survey, there is no B5_19 variable
	* Use activity with the most time worked = B5_q31
	destring B5_q31, gen(empstat)
	recode empstat 11=4 12=3 21=2 31 41 51 61 62 71 72=1 81/99=.
	replace empstat=. if lstatus != 1 | (age < minlaborage & age != .)
	label var empstat "Employment status during past week primary job 7 day recall"
	la de lblempstat 1 "Paid employee" 2 "Non-paid employee" 3 "Employer" 4 "Self-employed" 5 "Other, workers not classifiable by status"
	label values empstat lblempstat
*</_empstat_>


*<_ocusec_>
	gen byte ocusec = .
	label var ocusec "Sector of activity primary job 7 day recall"
	la de lblocusec 1 "Public Sector, Central Government, Army" 2 "Private, NGO" 3 "State owned" 4 "Public or State-owned, but cannot distinguish"
	label values ocusec lblocusec
*</_ocusec_>


*<_industry_orig_>
	gen industry_orig = B5_q41
	label var industry_orig "Original survey industry code, main job 7 day recall"
	* Note: A total of 94,670 are paid employees but 90 records have no industry code
	* Industry not asked if worked as casual wage labour or not work due to sickness
*</_industry_orig_>


*<_industrycat_isic_>
	gen industrycat_isic = .
	label var industrycat_isic "ISIC code of primary job 7 day recall"
*</_industrycat_isic_>


*<_industrycat10_>

	*Note: There are 2 categories for manufacturing

	gen industrycat10 = .

	replace industrycat10=1 if B5_q41 == "0"
	replace industrycat10=2 if B5_q41 == "1"
	replace industrycat10=3 if B5_q41 == "2" | B5_q41 == "3"
	replace industrycat10=4 if B5_q41 == "4"
	replace industrycat10=5 if B5_q41 == "5"
	replace industrycat10=6 if B5_q41 == "6"
	replace industrycat10=7 if B5_q41 == "7"
	replace industrycat10=8 if B5_q41 == "8"
	replace industrycat10=10 if B5_q41 == "9"

	replace industrycat10=. if lstatus != 1 | (age < minlaborage & age != .)
	label var industrycat10 "1 digit industry classification, primary job 7 day recall"
	la de lblindustrycat10 1 "Agriculture" 2 "Mining" 3 "Manufacturing" 4 "Public utilities" 5 "Construction"  6 "Commerce" 7 "Transport and Comnunications" 8 "Financial and Business Services" 9 "Public Administration" 10 "Other Services, Unspecified"
	label values industrycat10 lblindustrycat10
*</_industrycat10_>


*<_industrycat4_>
	gen byte industrycat4 = industrycat10
	recode industrycat4 (1=1)(2 3 4 5 =2)(6 7 8 9=3)(10=4)
	label var industrycat4 "1 digit industry classification (Broad Economic Activities), primary job 7 day recall"
	la de lblindustrycat4 1 "Agriculture" 2 "Industry" 3 "Services" 4 "Other"
	label values industrycat4 lblindustrycat4
*</_industrycat4_>


*<_occup_orig_>
	* Correspondence holds only if CWA = activity 1
	gen occup_orig = B4_q15 if B4_q11 == B5_q31
	label var occup_orig "Original occupation record primary job 7 day recall"
*</_occup_orig_>


*<_occup_isco_>
	gen occup_isco = .
	label var occup_isco "ISCO code of primary job 7 day recall"
*</_occup_isco_>


*<_occup_skill_>
	gen occup_skill = .
	label var occup_skill "Skill based on ISCO standard primary job 7 day recall"
*</_occup_skill_>


*<_occup_>
	gen code_68 = B4_q15 if B4_q11 == B5_q31
	gen x_indic = regexm(code_68, "x|X|y|y")
	replace code_68 = "99" if x_indic == 1
	replace code_68 = "0" + code_68 if length(code_68) == 2
	replace code_68 = "00" + code_68 if length(code_68) == 1
	replace code_68 = substr(code_68,1,2)

	merge m:1 code_68 using "$path_in/IND_1987_NSS43-SCH10_NCO_68_to_2004_conversion.dta"
	destring code_04, replace

	gen occup = .
	replace occup = code_04 if lstatus == 1 & (age >= minlaborage & age != .)
	replace occup = 99 if x_indic == 1 & lstatus == 1 & (age >= minlaborage & age != .)
	label var occup "1 digit occupational classification, primary job 7 day recall"
	la de lbloccup 1 "Managers" 2 "Professionals" 3 "Technicians" 4 "Clerks" 5 "Service and market sales workers" 6 "Skilled agricultural" 7 "Craft workers" 8 "Machine operators" 9 "Elementary occupations" 10 "Armed forces"  99 "Others"
	label values occup lbloccup
	drop x_indic code_68 code_04
*</_occup_>


*<_wage_no_compen_>
	gen double wage_no_compen = B5_q141
	replace wage_no_compen=. if lstatus != 1 | (age < minlaborage & age != .)
	label var wage_no_compen "Last wage payment primary job 7 day recall"
*</_wage_no_compen_>


*<_unitwage_>
	gen byte unitwage = 2
	replace unitwage=. if lstatus != 1 | (age < minlaborage & age != .)
	label var unitwage "Last wages' time unit primary job 7 day recall"
	la de lblunitwage 1 "Daily" 2 "Weekly" 3 "Every two weeks" 4 "Bimonthly"  5 "Monthly" 6 "Trimester" 7 "Biannual" 8 "Annually" 9 "Hourly" 10 "Other"
	label values unitwage lblunitwage
*</_unitwage_>


*<_whours_>
/* <_whours_note>

	Data is recorded for the day as full day or half day, then summed up over the 7 days. Assume a full day has 8 hours

</_whours_note> */
	gen whours = 8*B5_q131
	replace whours=. if lstatus != 1 | (age < minlaborage & age != .)
	label var whours "Hours of work in last week primary job 7 day recall"
*</_whours_>


*<_wmonths_>
	gen wmonths = .
	label var wmonths "Months of work in past 12 months primary job 7 day recall"
*</_wmonths_>


*<_wage_total_>
/* <_wage_total_note>

	Since this is annualized but no information is given on how many months of work cannot fill it out

</_wage_total_note> */
	gen wage_total = .
	replace wage_total=. if lstatus != 1 | (age < minlaborage & age != .)
	label var wage_total "Annualized total wage primary job 7 day recall"
*</_wage_total_>


*<_contract_>
	gen byte contract = .
	label var contract "Employment has contract primary job 7 day recall"
	la de lblcontract 0 "Without contract" 1 "With contract"
	label values contract lblcontract
*</_contract_>


*<_healthins_>
	gen byte healthins = .
	label var healthins "Employment has health insurance primary job 7 day recall"
	la de lblhealthins 0 "Without health insurance" 1 "With health insurance"
	label values healthins lblhealthins
*</_healthins_>


*<_socialsec_>
	gen byte socialsec = .
	label var socialsec "Employment has social security insurance primary job 7 day recall"
	la de lblsocialsec 1 "With social security" 0 "Without social secturity"
	label values socialsec lblsocialsec
*</_socialsec_>


*<_union_>
	gen byte union = .
	label var union "Union membership at primary job 7 day recall"
	la de lblunion 0 "Not union member" 1 "Union member"
	label values union lblunion
*</_union_>


*<_firmsize_l_>
	gen byte firmsize_l = .
	label var firmsize_l "Firm size (lower bracket) primary job 7 day recall"
*</_firmsize_l_>


*<_firmsize_u_>
	gen byte firmsize_u=.
	label var firmsize_u "Firm size (upper bracket) primary job 7 day recall"
*</_firmsize_u_>

}


*----------8.3: 7 day reference secondary job------------------------------*
* Since labels are the same as main job, values are labelled using main job labels


{
*<_empstat_2_>
	gen has_job_primary = inlist(B5_q31,"11", "12", "21", "31", "41", "51") | inlist(B5_q31, "61", "62", "71", "72")
	destring B5_q32, gen(empstat_2)
	recode empstat_2 11=4 12=3 21=2 31 41 51 61 62 71 72=1 81/99=.
	replace empstat_2=. if lstatus != 1 | (age < minlaborage & age != .)
	replace empstat_2 = . if has_job_primary == 0 & !missing(empstat_2)
	label var empstat_2 "Employment status during past week primary job 7 day recall"
	la de lblempstat_2 1 "Paid employee" 2 "Non-paid employee" 3 "Employer" 4 "Self-employed" 5 "Other, workers not classifiable by status"
	label values empstat_2 lblempstat_2

*</_empstat_2_>


*<_ocusec_2_>
	gen byte ocusec_2 = .
	label var ocusec_2 "Sector of activity secondary job 7 day recall"
	label values ocusec_2 lblocusec
*</_ocusec_2_>


*<_industry_orig_2_>
	gen industry_orig_2 = B5_q42
	label var industry_orig_2 "Original survey industry code, secondary job 7 day recall"
*</_industry_orig_2_>


*<_industrycat_isic_2_>
	gen industrycat_isic_2 = .
	label var industrycat_isic_2 "ISIC code of secondary job 7 day recall"
*</_industrycat_isic_2_>


*<_industrycat10_2_>
	gen industrycat10_2 = .

	replace industrycat10_2=1 if B5_q42 == "0"
	replace industrycat10_2=2 if B5_q42 == "1"
	replace industrycat10_2=3 if B5_q42 == "2" | B5_q42 == "3"
	replace industrycat10_2=4 if B5_q42 == "4"
	replace industrycat10_2=5 if B5_q42 == "5"
	replace industrycat10_2=6 if B5_q42 == "6"
	replace industrycat10_2=7 if B5_q42 == "7"
	replace industrycat10_2=8 if B5_q42 == "8"
	replace industrycat10_2=10 if B5_q42 == "9"


	replace industrycat10_2=. if lstatus != 1 | (age < minlaborage & age != .)
	label var industrycat10_2 "1 digit industry classification, primary job 7 day recall"
	la de lblindustrycat10_2 1 "Agriculture" 2 "Mining" 3 "Manufacturing" 4 "Public utilities" 5 "Construction"  6 "Commerce" 7 "Transport and Comnunications" 8 "Financial and Business Services" 9 "Public Administration" 10 "Other Services, Unspecified"
	label values industrycat10_2 lblindustrycat10_2
*</_industrycat10_2_>


*<_industrycat4_2_>
	gen byte industrycat4_2 = industrycat10_2
	recode industrycat4_2 (1=1)(2 3 4 5 =2)(6 7 8 9=3)(10=4)
	label var industrycat4_2 "1 digit industry classification (Broad Economic Activities), secondary job 7 day recall"
	label values industrycat4_2 lblindustrycat4
*</_industrycat4_2_>


*<_occup_orig_2_>
	gen occup_orig_2 = .
	label var occup_orig_2 "Original occupation record secondary job 7 day recall"
*</_occup_orig_2_>


*<_occup_isco_2_>
	gen occup_isco_2 = .
	label var occup_isco_2 "ISCO code of secondary job 7 day recall"
*</_occup_isco_2_>


*<_occup_skill_2_>
	gen occup_skill_2 = .
	label var occup_skill_2 "Skill based on ISCO standard secondary job 7 day recall"
*</_occup_skill_2_>


*<_occup_2_>
	gen byte occup_2 = .
	label var occup_2 "1 digit occupational classification secondary job 7 day recall"
	label values occup_2 lbloccup
*</_occup_2_>


*<_wage_no_compen_2_>
	gen double wage_no_compen_2 = B5_q142
	replace wage_no_compen_2=. if lstatus != 1 | (age < minlaborage & age != .)
	label var wage_no_compen_2 "Last wage payment secondary job 7 day recall"
*</_wage_no_compen_2_>


*<_unitwage_2_>
	gen byte unitwage_2 = 2
	replace unitwage_2=. if lstatus != 1 | (age < minlaborage & age != .)
	label var unitwage_2 "Last wages' time unit secondary job 7 day recall"
	la de lblunitwage_2 1 "Daily" 2 "Weekly" 3 "Every two weeks" 4 "Bimonthly"  5 "Monthly" 6 "Trimester" 7 "Biannual" 8 "Annually" 9 "Hourly" 10 "Other"
	label values unitwage_2 lblunitwage_2
*</_unitwage_2_>


*<_whours_2_>
	gen whours_2 = 8*B5_q132
	replace whours_2=. if lstatus != 1 | (age < minlaborage & age != .)
	label var whours_2 "Hours of work in last week secondary job 7 day recall"
*</_whours_2_>


*<_wmonths_2_>
	gen wmonths_2 = .
	label var wmonths_2 "Months of work in past 12 months secondary job 7 day recall"
*</_wmonths_2_>


*<_wage_total_2_>
	gen wage_total_2 = .
	label var wage_total_2 "Annualized total wage secondary job 7 day recall"
*</_wage_total_2_>


*<_firmsize_l_2_>
	gen byte firmsize_l_2 = .
	label var firmsize_l_2 "Firm size (lower bracket) secondary job 7 day recall"
*</_firmsize_l_2_>


*<_firmsize_u_2_>
	gen byte firmsize_u_2 = .
	label var firmsize_u_2 "Firm size (upper bracket) secondary job 7 day recall"
*</_firmsize_u_2_>

}

*----------8.4: 7 day reference additional jobs------------------------------*

*<_t_hours_others_>
	gen t_hours_others = .
	label var t_hours_others "Annualized hours worked in all but primary and secondary jobs 7 day recall"
*</_t_hours_others_>


*<_t_wage_nocompen_others_>
	gen t_wage_nocompen_others = .
	label var t_wage_nocompen_others "Annualized wage in all but primary & secondary jobs excl. bonuses, etc. 7 day recall"
*</_t_wage_nocompen_others_>


*<_t_wage_others_>
	gen t_wage_others = .
	label var t_wage_others "Annualized wage in all but primary and secondary jobs (12-mon ref period)"
*</_t_wage_others_total_>


*----------8.5: 7 day reference total summary------------------------------*


*<_t_hours_total_>
	egen t_hours_total = rowtotal(whours whours_2 t_hours_others), missing
	label var t_hours_total "Annualized hours worked in all jobs 7 day recall"
*</_t_hours_total_>


*<_t_wage_nocompen_total_>
	egen t_wage_nocompen_total = rowtotal(wage_no_compen wage_no_compen_2 t_wage_nocompen_others), missing
	label var t_wage_nocompen_total "Annualized wage in all jobs excl. bonuses, etc. 7 day recall"
*</_t_wage_nocompen_total_>


*<_t_wage_total_>
	gen t_wage_total = .
	label var t_wage_total "Annualized total wage for all jobs 7 day recall"
*</_t_wage_total_>


*----------8.6: 12 month reference overall------------------------------*

{

*<_lstatus_year_>
/* <_lstatus_year_note>

	For a person to be employed use the concept of usual economic activity, that is principal
	activity and add secondary if the principal is not in employment byt secondary is.
	So a full time student working on the side is still in the labor force in this 12 month sense

	Note: there are two variables for principal activity status: B6_q2 and B7_q2
	The first is part of the migration module while the second is part of the laor module
	We use the second one.

</_lstatus_year_note> */

	destring B7_q2, gen(lstatus_year)
	recode lstatus_year  11/51=1 81 82=2 91/94=3
	destring B7_q3, gen(secondary_help)
	recode secondary_help  11/51=1
	replace lstatus_year = 1 if secondary_help == 1 & lstatus_year != 1
	replace lstatus = . if age < minlaborage
	label var lstatus_year "Labor status during last year"
	la de lbllstatus_year 1 "Employed" 2 "Unemployed" 3 "Non-LF"
	label values lstatus_year lbllstatus_year
	drop secondary_help
*</_lstatus_year_>

*<_potential_lf_year_>
	gen byte potential_lf_year = .
	replace potential_lf_year=. if age < minlaborage & age != .
	replace potential_lf_year = . if lstatus_year != 3
	label var potential_lf_year "Potential labour force status"
	la de lblpotential_lf_year 0 "No" 1 "Yes"
	label values potential_lf_year lblpotential_lf_year
*</_potential_lf_year_>


*<_underemployment_year_>
	gen byte underemployment_year = 0
	replace underemployment_year = 1 if B7_q8 != "4" & !missing(B7_q8)
	replace underemployment_year = . if age < minlaborage & age != .
	replace underemployment_year = . if lstatus_year != 1
	label var underemployment_year "Underemployment status"
	la de lblunderemployment_year 0 "No" 1 "Yes"
	label values underemployment_year lblunderemployment_year
*</_underemployment_year_>


*<_nlfreason_year_>
	destring B7_q2, gen(nlfreason_year)
	recode nlfreason_year 11/82=. 91=1 92 93=2 94=3
	replace nlfreason_year = . if lstatus != 3 | (age < minlaborage & age != .)
	label var nlfreason_year "Reason not in the labor force - 12 month recall"
	la de lblnlfreason_year 1 "Student" 2 "Housekeeper" 3 "Retired" 4 "Disable" 5 "Other"
	label values nlfreason_year lblnlfreason_year
*</_nlfreason_year_>


*<_unempldur_l_year_>
	gen byte unempldur_l_year= floor(unemp_months)
	label var unempldur_l_year "Unemployment duration (months) lower bracket"
*</_unempldur_l_year_>


*<_unempldur_u_year_>
	gen byte unempldur_u_year= ceil(unemp_months)
	label var unempldur_u_year "Unemployment duration (months) upper bracket"
*</_unempldur_u_year_>

}

*----------8.7: 12 month reference main job------------------------------*

{

*<_empstat_year_>
	*Use B7_q2
	destring B7_q2, gen(empstat_year)
	recode empstat_year 11=4 21=2 31 41 51 = 1 81/99=.
	destring B7_q3, gen(secondary_help)
	recode secondary_help  11=4 21=2 31 41 51 = 1
	replace empstat_year = secondary_help if missing(empstat_year) & lstatus_year == 1
	label var empstat_year "Employment status during past week primary job 12 month recall"
	la de lblempstat_year 1 "Paid employee" 2 "Non-paid employee" 3 "Employer" 4 "Self-employed" 5 "Other, workers not classifiable by status"
	label values empstat_year lblempstat_year
	drop secondary_help
*</_empstat_year_>

*<_ocusec_year_>
/* <_ocusec_year_note>

	Ocusec question is only to those with code 31. For those with code 11, 12, 21 assume Private as
	this is self employed which is assumed not to be a public.

	Note that there are 50K employees that B7_q20 has no answer for so there seems to be a gap here.
</_ocusec_year_note> */
	gen byte ocusec_year = .
	label var ocusec_year "Sector of activity primary job 12 day recall"
	la de lblocusec_year 1 "Public Sector, Central Government, Army" 2 "Private, NGO" 3 "State owned" 4 "Public or State-owned, but cannot distinguish"
	label values ocusec_year lblocusec_year
*</_ocusec_year_>

*<_industry_orig_year_>
	gen industry_orig_year = B7_q2a
	replace industry_orig_year = B7_q3a if missing(B7_q2a)
	label var industry_orig_year "Original industry record main job 12 month recall"
*</_industry_orig_year_>


*<_industrycat_isic_year_>
	gen industrycat_isic_year = .
	label var industrycat_isic_year "ISIC code of primary job 12 month recall"
*</_industrycat_isic_year_>


*<_industrycat10_year_>
	gen red_indus = B7_q2a
	gen red_indus_s = B7_q3a

	replace red_indus = red_indus_s if missing(red_indus) & lstatus_year == 1

	gen byte industrycat10_year = .

	replace industrycat10_year=1 if red_indus == "0"
	replace industrycat10_year=2 if red_indus == "1"
	replace industrycat10_year=3 if red_indus == "2" | red_indus == "3"
	replace industrycat10_year=4 if red_indus == "4"
	replace industrycat10_year=5 if red_indus == "5"
	replace industrycat10_year=6 if red_indus == "6"
	replace industrycat10_year=7 if red_indus == "7"
	replace industrycat10_year=8 if red_indus == "8"
	replace industrycat10_year=10 if red_indus == "9"

	replace industrycat10_year= . if lstatus_year != 1 | (age < minlaborage & age != .)
	label var industrycat10_year "1 digit industry classification, primary job 12 month recall"
	la de lblindustrycat10_year 1 "Agriculture" 2 "Mining" 3 "Manufacturing" 4 "Public utilities" 5 "Construction"  6 "Commerce" 7 "Transport and Comnunications" 8 "Financial and Business Services" 9 "Public Administration" 10 "Other Services, Unspecified"
	label values industrycat10_year lblindustrycat10_year

*</_industrycat10_year_>


*<_industrycat4_year_>
	gen byte industrycat4_year=industrycat10_year
	recode industrycat4_year (1=1)(2 3 4 5 =2)(6 7 8 9=3)(10=4)
	label var industrycat4_year "1 digit industry classification (Broad Economic Activities), primary job 12 month recall"
	la de lblindustrycat4_year 1 "Agriculture" 2 "Industry" 3 "Services" 4 "Other"
	label values industrycat4_year lblindustrycat4_year
*</_industrycat4_year_>


*<_occup_orig_year_>
	gen occup_orig_year = B6_q6
	replace occup_orig_year = B6_q12 if missing(B6_q6)
	label var occup_orig_year "Original occupation record primary job 12 month recall"
*</_occup_orig_year_>


*<_occup_isco_year_>
	gen occup_isco_year = .
	label var occup_isco_year "ISCO code of primary job 12 month recall"
*</_occup_isco_year_>


*<_occup_skill_year_>
	gen occup_skill_year = .
	label var occup_skill_year "Skill based on ISCO standard primary job 12 month recall"
*</_occup_skill_year_>


*<_occup_year_>
	gen code_68 = B6_q6
	gen x_indic = regexm(code_68, "x|X|y|Y")
	replace code_68 = "99" if x_indic == 1
	replace code_68 = "0" + code_68 if length(code_68) == 2
	replace code_68 = "00" + code_68 if length(code_68) == 1
	replace code_68 = substr(code_68,1,2)
	drop x_indic

	gen code_68_s = B6_q12
	gen x_indic = regexm(code_68_s, "x|X|y|y")
	replace code_68_s = "99" if x_indic == 1
	replace code_68_s = "0" + code_68_s if length(code_68_s) == 2
	replace code_68_s = "00" + code_68_s if length(code_68_s) == 1
	replace code_68_s = substr(code_68_s,1,2)
	replace code_68 = code_68_s if missing(code_68) & lstatus_year == 1
	drop x_indic code_68_s

	merge m:1 code_68 using "$path_in\IND_1987_NSS43-SCH10_NCO_68_to_2004_conversion.dta", nogen
	destring code_04, replace

	gen occup_year = .
	replace occup_year = code_04 if lstatus_year == 1 & (age >= minlaborage & age != .)
	label var occup_year "1 digit occupational classification, primary job 12 month recall"
	la de lbloccup_year 1 "Managers" 2 "Professionals" 3 "Technicians" 4 "Clerks" 5 "Service and market sales workers" 6 "Skilled agricultural" 7 "Craft workers" 8 "Machine operators" 9 "Elementary occupations" 10 "Armed forces"  99 "Others"
	label values occup_year lbloccup_year
	drop code_68 code_04
*</_occup_year_>


*<_wage_no_compen_year_>
	gen double wage_no_compen_year = .
	label var wage_no_compen_year "Last wage payment primary job 12 month recall"
*</_wage_no_compen_year_>


*<_unitwage_year_>
	gen byte unitwage_year = .
	label var unitwage_year "Last wages' time unit primary job 12 month recall"
	la de lblunitwage_year 1 "Daily" 2 "Weekly" 3 "Every two weeks" 4 "Bimonthly"  5 "Monthly" 6 "Trimester" 7 "Biannual" 8 "Annually" 9 "Hourly" 10 "Other"
	label values unitwage_year lblunitwage_year
*</_unitwage_year_>


*<_whours_year_>
	gen whours_year = .
	label var whours_year "Hours of work in last week primary job 12 month recall"
*</_whours_year_>


*<_wmonths_year_>
/* <_wmonths_year_note>

	Survey asks individuals whether they worked regularly. If not, how many months out of work.
	Hence assume if worked regularly 12 months of work, if not 12 minus the number mentioned.
</_wmonths_year_note> */
	gen wmonths_year = .
	replace wmonths_year = 12 if B7_q4 == "1"
	replace wmonths_year = 12 - unemp_months if B7_q4 == "2"
	replace wmonths_year = . if missing(empstat_year) | B7_q4 == "9"
	label var wmonths_year "Months of work in past 12 months primary job 12 month recall"
*</_wmonths_year_>


*<_wage_total_year_>
	gen wage_total_year = .
	label var wage_total_year "Annualized total wage primary job 12 month recall"
*</_wage_total_year_>


*<_contract_year_>
	gen byte contract_year = .
	label var contract_year "Employment has contract primary job 12 month recall"
	la de lblcontract_year 0 "Without contract" 1 "With contract"
	label values contract_year lblcontract_year
*</_contract_year_>


*<_healthins_year_>
	gen byte healthins_year = .
	label var healthins_year "Employment has health insurance primary job 12 month recall"
	la de lblhealthins_year 0 "Without health insurance" 1 "With health insurance"
	label values healthins_year lblhealthins_year
*</_healthins_year_>


*<_socialsec_year_>
	gen byte socialsec_year = .
	label var socialsec_year "Employment has social security insurance primary job 7 day recall"
	la de lblsocialsec_year 1 "With social security" 0 "Without social secturity"
	label values socialsec_year lblsocialsec_year
*</_socialsec_year_>


*<_union_year_>
/* <_wmonths_year_note>

	Survey asks whether there is a union available, if not no further questions - if yes,
	then whether they are member. Treat no union available also as a no.
</_wmonths_year_note> */
	gen byte union_year = .

	label var union_year "Union membership at primary job 12 month recall"
	la de lblunion_year 0 "Not union member" 1 "Union member"
	label values union_year lblunion_year
*</_union_year_>


*<_firmsize_l_year_>
	gen byte firmsize_l_year = .
	label var firmsize_l_year "Firm size (lower bracket) primary job 12 month recall"
*</_firmsize_l_year_>


*<_firmsize_u_year_>
	gen byte firmsize_u_year = .
	label var firmsize_u_year "Firm size (upper bracket) primary job 12 month recall"
*</_firmsize_u_year_>

}


*----------8.8: 12 month reference secondary job------------------------------*

{

*<_empstat_2_year_>
	gen has_job_primary = inlist(B7_q2,"11", "21", "31", "41", "51")
	destring B7_q3, gen(empstat_2_year)
	recode empstat_2_year  11=4 21=2 31 41 51 =1 81/99=.
	replace empstat_2_year = . if lstatus_year != 1
	replace empstat_2_year = . if has_job_primary == 0 & !missing(empstat_2_year)
	label var empstat_2_year "Employment status during past week secondary job 12 month recall"
	la de lblempstat_2_year 1 "Paid employee" 2 "Non-paid employee" 3 "Employer" 4 "Self-employed" 5 "Other, workers not classifiable by status"
	label values empstat_2_year lblempstat_2_year
	drop has_job_primary
*</_empstat_2_year_>


*<_ocusec_2_year_>
	gen byte ocusec_2_year = .
	label var ocusec_2_year "Sector of activity secondary job 12 day recall"
	la de lblocusec_2_year 1 "Public Sector, Central Government, Army" 2 "Private, NGO" 3 "State owned" 4 "Public or State-owned, but cannot distinguish"
	label values ocusec_2_year lblocusec_2_year
*</_ocusec_2_year_>


*<_industry_orig_2_year_>
	gen industry_orig_2_year = B7_q3a
	replace industry_orig_2_year = "" if missing(empstat_2_year)
	label var industry_orig_2_year "Original survey industry code, secondary job 12 month recall"
*</_industry_orig_2_year_>


*<_industrycat_isic_2_year_>
	gen industrycat_isic_2_year = .
	label var industrycat_isic_2_year "ISIC code of secondary job 12 month recall"
*</_industrycat_isic_2_year_>


*<_industrycat10_2_year_>

	gen byte industrycat10_2_year = .

	replace industrycat10_2_year=1 if B7_q3a == "0"
	replace industrycat10_2_year=2 if B7_q3a == "1"
	replace industrycat10_2_year=3 if B7_q3a == "2" | B7_q3a == "3"
	replace industrycat10_2_year=4 if B7_q3a == "4"
	replace industrycat10_2_year=5 if B7_q3a == "5"
	replace industrycat10_2_year=6 if B7_q3a == "6"
	replace industrycat10_2_year=7 if B7_q3a == "7"
	replace industrycat10_2_year=8 if B7_q3a == "8"
	replace industrycat10_2_year=10 if B7_q3a == "9"


	replace industrycat10_2_year= . if lstatus_year != 1 | (age < minlaborage & age != .)
	replace industrycat10_2_year= . if missing(empstat_2_year)
	label var industrycat10_2_year "1 digit industry classification, secondary job 12 month recall"
	la de lblindustrycat10_2_year 1 "Agriculture" 2 "Mining" 3 "Manufacturing" 4 "Public utilities" 5 "Construction"  6 "Commerce" 7 "Transport and Comnunications" 8 "Financial and Business Services" 9 "Public Administration" 10 "Other Services, Unspecified"
	label values industrycat10_2_year lblindustrycat10_2_year
*</_industrycat10_2_year_>


*<_industrycat4_2_year_>
	gen byte industrycat4_2_year=industrycat10_2_year
	recode industrycat4_2_year (1=1)(2 3 4 5 =2)(6 7 8 9=3)(10=4)
	label var industrycat4_2_year "1 digit industry classification (Broad Economic Activities), secondary job 12 month recall"
	label values industrycat4_2_year lblindustrycat4_year
*</_industrycat4_2_year_>


*<_occup_orig_2_year_>
	gen occup_orig_2_year = B6_q12
	replace occup_orig_2_year = "" if missing(empstat_2_year)
	label var occup_orig_2_year "Original occupation record secondary job 12 month recall"
*</_occup_orig_2_year_>


*<_occup_isco_2_year_>
	gen occup_isco_2_year = .
	label var occup_isco_2_year "ISCO code of secondary job 12 month recall"
*</_occup_isco_2_year_>


*<_occup_skill_2_year_>
	gen occup_skill_2_year = .
	label var occup_skill_2_year "Skill based on ISCO standard secondary job 12 month recall"
*</_occup_skill_2_year_>


*<_occup_2_year_>

	gen code_68 = B6_q12
	gen x_indic = regexm(code_68, "x|X|y|Y")
	replace code_68 = "99" if x_indic == 1
	replace code_68 = "0" + code_68 if length(code_68) == 2
	replace code_68 = "00" + code_68 if length(code_68) == 1
	replace code_68 = substr(code_68,1,2)
	drop x_indic

	merge m:1 code_68 using "$path_in\IND_1987_NSS43-SCH10_NCO_68_to_2004_conversion.dta", nogen
	destring code_04, replace

	gen occup_2_year = .
	replace occup_2_year = code_04 if lstatus_year == 1 & !missing(empstat_2_year)
	label var occup_2_year "1 digit occupational classification, secondary job 12 month recall"
	la de lbloccup_2_year 1 "Managers" 2 "Professionals" 3 "Technicians" 4 "Clerks" 5 "Service and market sales workers" 6 "Skilled agricultural" 7 "Craft workers" 8 "Machine operators" 9 "Elementary occupations" 10 "Armed forces"  99 "Others"
	label values occup_2_year lbloccup_2_year
	drop code_68 code_04
*</_occup_2_year_>


*<_wage_no_compen_2_year_>
	gen double wage_no_compen_2_year = .
	label var wage_no_compen_2_year "Last wage payment secondary job 12 month recall"
*</_wage_no_compen_2_year_>


*<_unitwage_2_year_>
	gen byte unitwage_2_year = .
	label var unitwage_2_year "Last wages' time unit secondary job 12 month recall"
	label values unitwage_2_year lblunitwage_year
*</_unitwage_2_year_>


*<_whours_2_year_>
	gen whours_2_year = .
	label var whours_2_year "Hours of work in last week secondary job 12 month recall"
*</_whours_2_year_>


*<_wmonths_2_year_>
	gen wmonths_2_year = .
	label var wmonths_2_year "Months of work in past 12 months secondary job 12 month recall"
*</_wmonths_2_year_>


*<_wage_total_2_year_>
	gen wage_total_2_year = .
	label var wage_total_2_year "Annualized total wage secondary job 12 month recall"
*</_wage_total_2_year_>

*<_firmsize_l_2_year_>
	gen byte firmsize_l_2_year = .
	label var firmsize_l_2_year "Firm size (lower bracket) secondary job 12 month recall"
*</_firmsize_l_2_year_>


*<_firmsize_u_2_year_>
	gen byte firmsize_u_2_year = .
	label var firmsize_u_2_year "Firm size (upper bracket) secondary job 12 month recall"
*</_firmsize_u_2_year_>

}


*----------8.9: 12 month reference additional jobs------------------------------*


*<_t_hours_others_year_>
	gen t_hours_others_year = .
	label var t_hours_others_year "Annualized hours worked in all but primary and secondary jobs 12 month recall"
*</_t_hours_others_year_>

*<_t_wage_nocompen_others_year_>
	gen t_wage_nocompen_others_year = .
	label var t_wage_nocompen_others_year "Annualized wage in all but primary & secondary jobs excl. bonuses, etc. 12 month recall)"
*</_t_wage_nocompen_others_year_>

*<_t_wage_others_year_>
	gen t_wage_others_year = .
	label var t_wage_others_year "Annualized wage in all but primary and secondary jobs 12 month recall"
*</_t_wage_others_year_>


*----------8.10: 12 month total summary------------------------------*


*<_t_hours_total_year_>
	gen t_hours_total_year = .
	label var t_hours_total_year "Annualized hours worked in all jobs 12 month month recall"
*</_t_hours_total_year_>


*<_t_wage_nocompen_total_year_>
	gen t_wage_nocompen_total_year = .
	label var t_wage_nocompen_total_year "Annualized wage in all jobs excl. bonuses, etc. 12 month recall"
*</_t_wage_nocompen_total_year_>


*<_t_wage_total_year_>
	gen t_wage_total_year = .
	label var t_wage_total_year "Annualized total wage for all jobs 12 month recall"
*</_t_wage_total_year_>


*----------8.11: Overall across reference periods------------------------------*


*<_njobs_>
	gen njobs = .
	replace njobs = 1 if !missing(empstat_year)
	replace njobs = 2 if !missing(empstat_2_year)
	label var njobs "Total number of jobs"
*</_njobs_>


*<_t_hours_annual_>
	gen t_hours_annual = .
	label var t_hours_annual "Total hours worked in all jobs in the previous 12 months"
*</_t_hours_annual_>


*<_linc_nc_>
	gen linc_nc = .
	label var linc_nc "Total annual wage income in all jobs, excl. bonuses, etc."
*</_linc_nc_>


*<_laborincome_>
	gen laborincome = .
	label var laborincome "Total annual individual labor income in all jobs, incl. bonuses, etc."
*</_laborincome_>


*----------8.13: Labour cleanup------------------------------*

{
*<_% Correction min age_>

** Drop info for cases under the age for which questions to be asked (do not need a variable for this)
local lab_var "lstatus potential_lf underemployment nlfreason unempldur_l unempldur_u empstat ocusec industry_orig industrycat_isic industrycat10 industrycat4 occup_orig occup_isco occup_skill occup wage_no_compen unitwage whours wmonths wage_total contract healthins socialsec union firmsize_l firmsize_u empstat_2 ocusec_2 industry_orig_2 industrycat_isic_2 industrycat10_2 industrycat4_2 occup_orig_2 occup_isco_2 occup_skill_2 occup_2 wage_no_compen_2 unitwage_2 whours_2 wmonths_2 wage_total_2 firmsize_l_2 firmsize_u_2 t_hours_others t_wage_nocompen_others t_wage_others  t_hours_total t_wage_nocompen_total t_wage_total lstatus_year potential_lf_year underemployment_year nlfreason_year unempldur_l_year unempldur_u_year empstat_year ocusec_year industry_orig_year industrycat_isic_year industrycat10_year industrycat4_year occup_orig_year occup_isco_year occup_skill_year occup_year wage_no_compen_year unitwage_year whours_year wmonths_year wage_total_year contract_year healthins_year socialsec_year union_year firmsize_l_year firmsize_u_year empstat_2_year ocusec_2_year industry_orig_2_year industrycat_isic_2_year industrycat10_2_year industrycat4_2_year occup_orig_2_year occup_isco_2_year occup_skill_2_year occup_2_year wage_no_compen_2_year unitwage_2_year whours_2_year wmonths_2_year wage_total_2_year firmsize_l_2_year firmsize_u_2_year t_hours_others_year t_wage_nocompen_others_year t_wage_others_year t_hours_total_year t_wage_nocompen_total_year t_wage_total_year njobs t_hours_annual linc_nc laborincome"

foreach v of local lab_var {
	capture confirm numeric variable `v'
	if _rc != 0 {
		replace `v'="" if ( age < minlaborage & !missing(age) )
	}
	else {
		replace `v'=. if ( age < minlaborage & !missing(age) )
	}

}

*</_% Correction min age_>
}


/*%%=============================================================================================
	9: Final steps
================================================================================================*/

{

*<_% KEEP VARIABLES - ALL_>

keep countrycode survname survey year vermast veralt harmonization int_year int_month hhid pid weight psu strata urban subnatid1 subnatid2 subnatid3 subnatidsurvey subnatid1_prev subnatid2_prev subnatid3_prev gaul_adm1_code gaul_adm2_code gaul_adm3_code hsize age male relationharm relationcs marital eye_dsablty hear_dsablty walk_dsablty conc_dsord slfcre_dsablty comm_dsablty migrated_mod_age migrated_ref_time migrated_binary migrated_years migrated_from_urban migrated_from_cat migrated_from_code migrated_from_country migrated_reason ed_mod_age school literacy educy educat7 educat5 educat4 educat_isced vocational vocational_type vocational_length_l vocational_length_u vocational_field vocational_financed minlaborage lstatus potential_lf underemployment nlfreason unempldur_l unempldur_u empstat ocusec industry_orig industrycat_isic industrycat10 industrycat4 occup_orig occup_isco occup_skill occup wage_no_compen unitwage whours wmonths wage_total contract healthins socialsec union firmsize_l firmsize_u empstat_2 ocusec_2 industry_orig_2 industrycat_isic_2 industrycat10_2 industrycat4_2 occup_orig_2 occup_isco_2 occup_skill_2 occup_2 wage_no_compen_2 unitwage_2 whours_2 wmonths_2 wage_total_2 firmsize_l_2 firmsize_u_2 t_hours_others t_wage_nocompen_others t_wage_others t_hours_total t_wage_nocompen_total t_wage_total lstatus_year potential_lf_year underemployment_year nlfreason_year unempldur_l_year unempldur_u_year empstat_year ocusec_year industry_orig_year industrycat_isic_year industrycat10_year industrycat4_year occup_orig_year occup_isco_year occup_skill_year occup_year wage_no_compen_year unitwage_year whours_year wmonths_year wage_total_year contract_year healthins_year socialsec_year union_year firmsize_l_year firmsize_u_year empstat_2_year ocusec_2_year industry_orig_2_year industrycat_isic_2_year industrycat10_2_year industrycat4_2_year occup_orig_2_year occup_isco_2_year occup_skill_2_year occup_2_year wage_no_compen_2_year unitwage_2_year whours_2_year wmonths_2_year wage_total_2_year firmsize_l_2_year firmsize_u_2_year t_hours_others_year t_wage_nocompen_others_year t_wage_others_year t_hours_total_year t_wage_nocompen_total_year t_wage_total_year njobs t_hours_annual linc_nc laborincome

*</_% KEEP VARIABLES - ALL_>

*<_% ORDER VARIABLES_>

order countrycode survname survey year vermast veralt harmonization int_year int_month hhid pid weight psu strata urban subnatid1 subnatid2 subnatid3 subnatidsurvey subnatid1_prev subnatid2_prev subnatid3_prev gaul_adm1_code gaul_adm2_code gaul_adm3_code hsize age male relationharm relationcs marital eye_dsablty hear_dsablty walk_dsablty conc_dsord slfcre_dsablty comm_dsablty migrated_mod_age migrated_ref_time migrated_binary migrated_years migrated_from_urban migrated_from_cat migrated_from_code migrated_from_country migrated_reason ed_mod_age school literacy educy educat7 educat5 educat4 educat_isced vocational vocational_type vocational_length_l vocational_length_u vocational_field vocational_financed minlaborage lstatus potential_lf underemployment nlfreason unempldur_l unempldur_u empstat ocusec industry_orig industrycat_isic industrycat10 industrycat4 occup_orig occup_isco occup_skill occup wage_no_compen unitwage whours wmonths wage_total contract healthins socialsec union firmsize_l firmsize_u empstat_2 ocusec_2 industry_orig_2 industrycat_isic_2 industrycat10_2 industrycat4_2 occup_orig_2 occup_isco_2 occup_skill_2 occup_2 wage_no_compen_2 unitwage_2 whours_2 wmonths_2 wage_total_2 firmsize_l_2 firmsize_u_2 t_hours_others t_wage_nocompen_others t_wage_others t_hours_total t_wage_nocompen_total t_wage_total lstatus_year potential_lf_year underemployment_year nlfreason_year unempldur_l_year unempldur_u_year empstat_year ocusec_year industry_orig_year industrycat_isic_year industrycat10_year industrycat4_year occup_orig_year occup_isco_year occup_skill_year occup_year wage_no_compen_year unitwage_year whours_year wmonths_year wage_total_year contract_year healthins_year socialsec_year union_year firmsize_l_year firmsize_u_year empstat_2_year ocusec_2_year industry_orig_2_year industrycat_isic_2_year industrycat10_2_year industrycat4_2_year occup_orig_2_year occup_isco_2_year occup_skill_2_year occup_2_year wage_no_compen_2_year unitwage_2_year whours_2_year wmonths_2_year wage_total_2_year firmsize_l_2_year firmsize_u_2_year t_hours_others_year t_wage_nocompen_others_year t_wage_others_year t_hours_total_year t_wage_nocompen_total_year t_wage_total_year njobs t_hours_annual linc_nc laborincome

*</_% ORDER VARIABLES_>

}


*<_% COMPRESS_>

compress

*</_% COMPRESS_>


*<_% DELETE MISSING VARIABLES_>

quietly: describe, varlist
local kept_vars `r(varlist)'

foreach var of local kept_vars {
   capture assert missing(`var')
   if _rc == 0 {
	drop `var'
	dis as error "Drop variable: `var' since all missing"
   }
}

*</_% DELETE MISSING VARIABLES_>


*<_% SAVE_>

save "$path_output\IND_1987_NSS43-SCH10_V01_M_V01_A_GLD.dta", replace

*</_% SAVE_>
