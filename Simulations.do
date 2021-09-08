*******************************************************************************************
*******************************************************************************************
*****							COI ESTIMATES										  *****
*****				date: 09/06/2021   author: Claudia Vazquez 						  *****
*******************************************************************************************
*******************************************************************************************
version 15
set more off
clear all
global dir="C:\Users\Usuario\Dropbox\My PC (L-CVASQUEZ)\Documents\2020\COI\Next 1000 days\COI_SDG4.2"  /*Modify route*/

*******************************************************************************************
********** 						DATA CLEANING
*******************************************************************************************
insheet using "$dir\Database1.csv", clear comma names /* Country and regions codes. Source: United Nations Statistical Division */

keep isoalpha3code m49code countryorarea intermediateregionname intermediateregioncode subregionname subregioncode regionname regioncode developeddevelopingcountries 

rename m49code country_code
rename isoalpha3code country_code_iso
rename countryorarea country_name

save "$dir\codes.dta", replace 

insheet using "$dir\Database2_m.csv", clear comma names /* Total population by age. Source: United Nations Population Division. Males */

nrow 12
destring v8, replace
keep if v8==2018
drop Index Variant Notes Type v7 v8 
rename v3 country
rename v5 country_code
destring country_code-_100, replace ignore(". ")
egen pop=rowtotal(_0-_100)
keep country country_code _0 _1 _2 _3 _4 _5 pop

forvalues i=0(1)5 {
	rename _`i' _`i'm
	lab var _`i' "males `i' years (thousands)
}

egen pop_35m=rowtotal(_3m _4m _5m)
save "$dir\pop_m.dta", replace 

insheet using "$dir\Database2_f.csv", clear comma names /* Total population by age. Source: United Nations Population Division. Females */
nrow 12
destring v8, replace
keep if v8==2018
drop Index Variant Notes Type v7 v8 
rename v3 country
rename v5 country_code
destring country_code-_100, replace ignore(". ")
egen pop=rowtotal(_0-_100)
keep country country_code _0 _1 _2 _3 _4 _5 pop

forvalues i=0(1)5 {
	rename _`i' _`i'f
	lab var _`i' "females `i' years (thousands)
}

egen pop_35f=rowtotal(_3f _4f _5f)
save "$dir\pop_f.dta", replace 

insheet using "$dir\Database3.csv", clear comma names /* Current GDP (current US$). Source: World Bank national accounts data. */
nrow 2

forvalues j=2017(-1)2011 {
	replace _2018=_`j' if _2018==. 
}

keep datasource worlddevelopmentindicators _2018
rename datasource country
rename worlddevelopmentindicators country_code_iso
rename _2018 current_gdp
format current_gdp %15.0f

save "$dir\gdp.dta", replace 

insheet using "$dir\Database4.csv", clear comma names /* GDP per capita forecast. Current U.S. dollars per person Source: International Monetary Fund */
drop in 8732 
drop in 8731
keep if weosubjectcode=="NGDPDPC" 
keep iso country v48 v49 v50 v51 v52 v53 v54
destring v*, replace ignore("n/a,")
rename iso country_code_iso
local i=2018
foreach x in v48 v49 v50 v51 v52 v53 v54 {
	rename `x' pc_gdp_`i'
	local ++i
}

forvalues i=20(1)24 {
	local j=`i'-1
	replace pc_gdp_20`i'=pc_gdp_20`j' if pc_gdp_20`i'==. /*PAK last data: 2019, VEN: 2021 */
}

save "$dir\gdp_pc.dta", replace 

insheet using "$dir\Database5.csv", clear comma names /*World Bank Income Groups */
drop v3 v4
drop if Code==""
rename Code country_code_iso
gen gru=.
replace gru=1 if incomegroup=="High income"
replace gru=2 if incomegroup=="Upper middle income"
replace gru=3 if incomegroup=="Lower middle income"
replace gru=4 if incomegroup=="Low income"
lab def inc 1 "High income" 2 "Upper middle income" 3 "Lower middle income" 4 "Low income" 
lab val gru inc 
drop incomegroup 
save "$dir\group.dta", replace 

insheet using "$dir\Database6.csv", clear comma names /* Mean years of schooling. Source: UNESCO Institute of Statistics (UIS)  */
keep if natmon_ind=="MYS_1T8_AG25T99"
keep location time value
reshape wide value, i(location) j(time)

forvalues x=18(-1)14 {
	replace value2019=value20`x' if value2019==. 
}

rename value2019 year_edu
drop val*
rename location country_code_iso

save "$dir/educ", replace

insheet using "$dir\Database7.csv", clear names comma /* Mean earnings by sex and economic sector. Source: ILOSTAT */
keep if sex=="Female"
keep if economicactivity=="P. Education"
drop sourcetype sex economicactivity localcurrency  
drop if usdollars==.
sort referencearea time
bys referencearea: gen aux=_n
bys referencearea: gen aux1=_N
keep if aux==aux1
drop aux*
rename referencearea country_name 
replace country_name="Bolivia (Plurinational State of)" if country_name==	"Bolivia"
replace country_name="Cabo Verde" if country_name=="Cape Verde"
replace country_name="Côte d’Ivoire" if ppp==695
replace country_name="China  Hong Kong Special Administrative Region" if country_name=="Hong Kong, China"
replace country_name="Republic of Korea" if country_name=="Korea, Republic of"
replace country_name="Republic of Moldova" if country_name=="Moldova, Republic of"
replace country_name="United Republic of Tanzania" if country_name== "Tanzania, United Republic of"
replace country_name="United Kingdom of Great Britain and Northern Ireland" if country_name=="United Kingdom"
replace country_name="United States of America" if country_name=="United States"
replace country_name="Democratic Republic of the Congo" if substr(country_name, 1, 12)=="Congo, Democ"
replace country_name="Curaçao" if substr(country_name, 1, 4)=="Cura"
replace country_name="State of Palestine" if substr(country_name, 1, 12)=="Occupied Pal"

**assumptions
local ratio=30
local duration=1
local ecce_wages=60
local ecce_wages1=40
local share_cost=55
local months=12
gen cost=((usdollars*(`ecce_wages'/100)/(`ratio'*`duration')+ (usdollars*(`ecce_wages1'/100)/(`ratio'*`duration')))/(`share_cost'/100))*`months'
merge 1:1 country_name using "$dir/codes"
rename time time_cost_sim
keep country_code_iso cost time_cost_sim
save "$dir\costs.dta", replace 

*******************
* DATABASE CREATION
*******************
cd "$dir"

use codes, clear
merge 1:1 country_code_iso using group, nogenerate
merge 1:1 country_code_iso using gdp, nogenerate
merge 1:1 country_code_iso using gdp_pc, nogenerate
merge 1:1 country_code_iso using "$dir\participation.dta", nogenerate
merge 1:1 country_code_iso using "$dir\educ.dta", nogenerate
merge 1:1 country_code_iso using "$dir\costs.dta", nogenerate
drop if country_code==. 
merge 1:1 country_code using pop_m, nogenerate keep(match master)
merge 1:1 country_code using pop_f, nogenerate keep(match master)

forvalues i=1(1)4 {
	qui summ year_edu if gru==`i'
	replace year_edu=r(mean) if year_edu==. & gru==`i'
}

replace year_edu=round(year_edu)
levelsof subregioncode, local(levels)
foreach x of local levels {
		forvalues i=1(1)4 {
			qui summ cost if subregioncode==`x' & gru==`i'
			replace cost=r(mean) if cost==. & subregioncode==`x' & gru==`i'
		}
}

drop country year def _*

* LABELS
lab var gru "Income Group"
lab var current_gdp "GDP 2018" 
forvalues i=18(1)24 {
	lab var pc_gdp_20`i' "GDP per capita 20`i'"
}
lab var estimate "ECCE Participation rate"
lab var year_edu "Average years of education pop +25"
lab var pop_35m "Total population males 3 to 5"
lab var pop_35f "Total population females 3 to 5"
lab var cost "Annual per child costs (USD)"
save "$dir\data.dta", replace 

*********************************************************************
* 				Simulation of the cost of inaction					*
*********************************************************************
use "$dir\data.dta", clear

* Set value for parameters

local d=0.03   /*discount rate*/ 
local t=45     /*years in labor market */
local gr=0.01     /* annual growth rate of pc GDP in 2025-2070 */  
local im=0.131      /* Earnings impact of 1 SD in cognitive skills */
local im=`im'*0.556   /* Impact of ECCE on cognitive skills */
gen n=1-(estimate/100)  /* Adtional coverage to SDG */

forvalues i=2025(1)2095 {
	local j=`i'-1
	gen pc_gdp_`i'=pc_gdp_`j'*(1+`gr')
}

forvalues i=2020(1)2095 {
		gen b_`i'=(pc_gdp_`i'*`im')/((1+`d')^(`i'-2018))
}
gen ben=.

forvalues i=1(1)14 {
	local a2=2020+`i'
	local t2=`a2'+`t'-1
	egen ben_z=rowtotal(b_`a2'-b_`t2') if year_edu==`i'
	replace ben=ben_z if year_edu==`i'
	drop ben_z
}

gen cost_tot=pop_35f*cost*n+pop_35m*cost*n
gen ben_tot=ben*(pop_35m+pop_35f)*n if ben!=0

gen coi=(ben_tot-cost_tot)*100000/current_gdp
lab var coi "Cost of Inaction as % GDP"
format coi* %8.2f

*graph

forvalues i=1/4 {
	capture drop  x`i' d`i'
	kdensity coi if gru== `i' & coi>0, generate(x`i'  d`i')
}
capture drop zero
gen zero = 0
twoway rarea d1 zero x1, color("blue%50") ///
    ||  rarea d2 zero x2, color("purple%50") ///
    ||  rarea d3 zero x3, color("orange%50")  ///
    ||  rarea d4 zero x4, color("red%50") ///
        ytitle("Smoothed density") ///
        legend(ring(0) pos(2) col(1) order(1 "High" 2 "Upper middle" 3 "Lower middle" 4 "Low"))     

