// ************************************************** //
// Analyze caregiver employment in 2016 - 2020 NSCH 
// 
// Programmer: Caleb Easterly
// ************************************************** // 
version 16.1
capture log close
set linesize 160
log using childcare.log, text replace nomsg

// required packages
* ssc install mat2txt

// make labeled datasets for appending
clear
forvalues yr = 2016/2020 {
	quietly do nsch_`yr'_topical
	if `yr' > 2016 { // replace stratum to match (as recommended by NSCH)
		replace stratum = "2" if stratum == "2A"
		destring stratum, replace
	}
	save nsch_`yr'_topical_labeled, replace
}

// ************************************************** //
// Read in data
// ************************************************** // 
clear 
use nsch_2020_topical_labeled
forvalues yr = 2016/2019 {
	quietly append using nsch_`yr'_topical_labeled
}

// ************************************************** //
// Set as survey data
// ************************************************** // 
// make one strata variable (per NSCH recommendation)
egen stratacross = group(fipsst stratum)
// since we're not pooling years (yet) don't need to adjust the weights
svyset hhid [pweight=fwc], strata(stratacross) 

// ************************************************** //
// Define variables
// ************************************************** // 

// redefine CSHCN to match other vars
gen cshcn_ind = sc_cshcn == 1
tabulate cshcn_ind sc_cshcn, missing
label define ci 0 "No" 1 "Yes"
label values cshcn_ind ci
svy: tabulate cshcn_ind year

// define the subpopulation we are using
// job change due to child care only asked for kids <= 5 (form T1)
gen youngchild = formtype == "T1"
// starting with 49,546 kids aged 0-5
tabulate formtype youngchild 

// jobchange variable
codebook k6q27
gen jobchange = 0
replace jobchange = 1 if k6q27 == 1
replace jobchange = . if missing(k6q27)
label define jc 0 "No" 1 "Yes"
label values jobchange jc
tabulate jobchange k6q27, missing // same number of missings

// unweighted obs by year
tabulate year if youngchild
tabulate year jobchange if youngchild, row

// weighted obs by year
svy, subpop(youngchild): tabulate year, count cellwidth(20) format(%15.2gc)
svy, subpop(youngchild): tabulate year jobchange, count cellwidth(20) format(%15.3gc) row

// *** child's age *** //
codebook sc_age_years if youngchild
svy, subpop(youngchild): tabulate sc_age_years

// *** family structure *** //

// 2016 - family
label define family_stru_lab 1 "Two parents, married" 2 "Two parents, unmarried" ///
	3 "Single parent" 4 "Other"

codebook family if youngchild
gen family_stru16 = 1 if family == 1 | family == 3 // 2 parents, married
replace family_stru16 = 2 if family == 2 | family == 4 // 2 parents, unmarried
replace family_stru16 = 3 if inrange(family, 5, 6) // 1 parent 
replace family_stru16 = 4 if inrange(family, 7, 9)
replace family_stru16 = .m if family == .m
label values family_stru16 family_stru_lab
svy, subpop(youngchild): tabulate family_stru16 if year == 2016, missing

// 2017 - 2020 - family_r
codebook family_r if youngchild
gen family_stru1720 = 1 if family_r == 1 | family_r == 3
replace family_stru1720 = 2 if family_r == 2 | family_r == 4
replace family_stru1720 = 3 if inrange(family_r, 5, 6)
replace family_stru1720 = 4 if inrange(family_r, 7, 8)
replace family_stru1720 = .m if family_r == .m
label values family_stru1720 family_stru_lab
svy, subpop(youngchild): tabulate family_stru1720 if year > 2016, missing

// combine
clonevar family_stru = family_stru16 if year == 2016
replace family_stru = family_stru1720 if year > 2016
codebook family_stru
svy, subpop(youngchild): tabulate family_stru, missing

// *** number of young kids in household *** //
codebook totage_0_5 if youngchild
// both 3 and 4 are small groups, and 2 is smaller than 1
gen totyoung = totage_0_5
recode totyoung 4 = 3
label define ty 1 "1" 2 "2" 3 "3-4"
label values totyoung ty
codebook totyoung if youngchild

/// *** respondent's sex *** ///
codebook a1_sex
svy, subpop(youngchild): tabulate a1_sex

// *** highest education among household adults *** //
codebook higrade_tvis if youngchild // more detailed than higrade
label define hsimp 1 "Less than High School" 2 "High School" 3 "Some college" 4 "College deg. or higher"
label values higrade_tvis hsimp
svy, subpop(youngchild): tabulate higrade_tvis

// *** race *** //
codebook sc_race_r if youngchild

// combine asian and pacific islander
gen race_cat = sc_race_r
recode race_cat 5 = 4 // recode native hawaiian/PI to AA 

// recode "american indian" to "some other race" (because both small groups) 
recode race_cat 3 = 6 
label define rc 1 "White" 2 "Black" 4 "AA/PI" 6 "Other" 7 "2+ Races"
label values race_cat rc
table race_cat sc_race_r if youngchild
svy, subpop(youngchild): tabulate race_cat, missing

// *** ethnicity *** // 
codebook sc_hispanic_r if youngchild
label define hisp 1 "Yes" 2 "No"
label values sc_hispanic_r hisp
svy, subpop(youngchild): tabulate sc_hispanic_r 


// ************************************************** //
// Job Change Due to Child Care - Overall by Year 
// ************* ************************************* // 
svy, subpop(youngchild): proportion jobchange, over(year) percent cformat(%3.1f)
// https://www.statalist.org/forums/forum/general-stata-discussion/general/1618810-saving-95-ci-values-after-proportion-using-parmest-or-estout
eststo Overall
mat ll = r(table)["ll", 1...]
mat ul = r(table)["ul", 1...]
mat bb = r(table)["b", 1...]
estadd matrix ll=ll: Overall
estadd matrix ul=ul: Overall
estadd matrix bb=bb: Overall
esttab Overall using jobchange_overall_year.csv, ///
	cells("bb(fmt(1)) ll(fmt(1)) ul(fmt(1))") wide ci plain nomtitles noobs replace

// ratio of 2020 to 2019
display _b[1.jobchange@2020.year] / _b[1.jobchange@2019.year]

// difference
display _b[1.jobchange@2020.year] - _b[1.jobchange@2019.year]

// test
test 1.jobchange@2020.year = 1.jobchange@2019.year 
scalar overall_19v20 = r(p)  

// ************************************************** //
// Job Change Due to Child Care - By SHCN by Year
// ************************************************** // 
svy, subpop(youngchild): proportion jobchange, over(year cshcn_ind) percent cformat(%3.1f)
estimates store CSHCN

mat ll = r(table)["ll", 1...]
mat ul = r(table)["ul", 1...]
mat bb = r(table)["b", 1...]
estadd matrix ll=ll: CSHCN
estadd matrix ul=ul: CSHCN
estadd matrix bb=bb: CSHCN
esttab CSHCN using jobchange_by_cshcn_year.csv, ///
	cells("bb(fmt(1)) ll(fmt(1)) ul(fmt(1))") wide ci plain nomtitles noobs replace

// tests

// 2020 vs. 2019 for CSHCN
test 1.jobchange@2020.year#1.cshcn_ind = 1.jobchange@2019.year#1.cshcn_ind
scalar cshcn_19v20 = r(p)

// 2020 vs. 2019 for non-CSHCN
test 1.jobchange@2020.year#0.cshcn_ind = 1.jobchange@2019.year#0.cshcn_ind 
scalar ncshcn_19v20 = r(p)

// For 2020, CSHCN vs. non-CSHCN
// ratio
display _b[1.jobchange@2020.year#1.cshcn_ind] / _b[1.jobchange@2020.year#0.cshcn_ind]
// difference
display _b[1.jobchange@2020.year#1.cshcn_ind] - _b[1.jobchange@2020.year#0.cshcn_ind]
// test
test 1.jobchange@2020.year#1.cshcn_ind = 1.jobchange@2020.year#0.cshcn_ind
scalar cshcn_v_ncshcn_20 = r(p)

// ************************************************************ //
// Job Change Due to Child Care - Overall, By 2020 vs. 2016-19
// ************************************************************ // 
gen is2020 = year == 2020
tabulate is2020 year, missing

// adjust FWC for pooling 2016-19 and svyset again
gen fwc2 = fwc
replace fwc2 = fwc2/4 if year < 2020
svyset, clear
svyset hhid [pweight=fwc2], strata(stratacross)

// make sure totals make sense - (they are good, about the same)
svy, subpop(youngchild): tabulate is2020 jobchange, count cellwidth(20) format(%15.3gc) row

// job change overall
svy, subpop(youngchild): prop jobchange, over(is2020) percent cformat(%3.1f)
eststo Pooled
mat ll = r(table)["ll", 1...]
mat ul = r(table)["ul", 1...]
mat bb = r(table)["b", 1...]
estadd matrix ll=ll: Pooled
estadd matrix ul=ul: Pooled
estadd matrix bb=bb: Pooled

esttab Pooled using jobchange_pooled_overall.csv, ///
	cells("bb(fmt(1)) ll(fmt(1)) ul(fmt(1))") wide ci plain nomtitles noobs replace

// save for plotting
global overall1619 = _b[1.jobchange@0.is2020] * 100
display $overall1619

global overall1619_label_val = $overall1619 * 1.03 // position the label
global overall1619_lab : display %2.1f $overall1619 // write the label

// ratio of 2020 to 2016-19
display _b[1.jobchange@1.is2020] / _b[1.jobchange@0.is2020]

// difference 
display _b[1.jobchange@1.is2020] - _b[1.jobchange@0.is2020]

// test
test 1.jobchange@1.is2020 = 1.jobchange@0.is2020
scalar overall_1619p_v20 = r(p)

// *********************************************************** //
// Job Change Due to Child Care - By SHCN, By 2020 vs. 2016-19
// *********************************************************** //
svy, subpop(youngchild): prop jobchange, over(is2020 cshcn_ind) percent cformat(%3.1f)
eststo PooledSHCN
mat ll = r(table)["ll", 1...]
mat ul = r(table)["ul", 1...]
mat bb = r(table)["b", 1...]
estadd matrix ll=ll: PooledSHCN
estadd matrix ul=ul: PooledSHCN
estadd matrix bb=bb: PooledSHCN

esttab PooledSHCN using jobchange_pooled_by_cshcn.csv, ///
	cells("bb(fmt(1)) ll(fmt(1)) ul(fmt(1))") wide ci plain nomtitles noobs replace

// cshcn
global cshcn1619 = _b[1.jobchange@0.is2020#1.cshcn_ind] * 100
display $cshcn1619
global cshcn1619_lab : display %2.1f $cshcn1619 // for labeling

// non cshcn 
global noncshcn1619 = _b[1.jobchange@0.is2020#0.cshcn_ind] * 100
display $noncshcn1619

global noncshcn1619_label_val = $noncshcn1619 * 0.97 // position label
global noncshcn1619_lab : display %2.1f $noncshcn1619 // for labeling

// tests
test 1.jobchange@1.is2020#1.cshcn_ind = 1.jobchange@0.is2020#1.cshcn_ind
scalar cshcn_1619Pv20 = r(p)

test 1.jobchange@1.is2020#0.cshcn_ind = 1.jobchange@0.is2020#0.cshcn_ind
scalar ncshcn_1619Pv20 = r(p)

// ******************************************** //
// collect test results 
// ******************************************** //
matrix P = (scalar(overall_19v20)     \ ///
			scalar(cshcn_19v20)       \ ///
			scalar(ncshcn_19v20)      \ ///
			scalar(cshcn_v_ncshcn_20) \ ///
			scalar(overall_1619p_v20) \ ///
			scalar(cshcn_1619Pv20)    \ ///
			scalar(ncshcn_1619Pv20))
matrix rownames P = "Overall, 2019 v. 2020" ///
	"CSHCN, 2019 v. 2020" ///
	"NCSHCN, 2019 v. 2020" ///
	"CSHCH v. NCSHCN, 2020" ///
	"Overall, 2016-19 (Pooled) v. 2020" ///
	"CSHCN, 2016-19 (Pooled) v. 2020" ///
	"NCSHCN, 2016-19 (Pooled) v. 2020"
matrix colnames P = "Pval"
matlist P, format(%5.4f) twidth(50)
mat2txt, matrix(P) saving(prevtest_pvals.txt) format(%5.4f) replace

// ******************************************** //
// display 
// ******************************************** //
// colors from https://davidmathlogic.com/colorblind/
global cshcn_col = "136 34 85"
global overall_col = "68 170 153"
global noncshcn_col = "51 34 136"

coefplot (CSHCN, keep(1.jobchange@*.year#1.cshcn_ind) ///
		rename(1.jobchange@2016.year#1.cshcn_ind = "2016" ///
		   1.jobchange@2017.year#1.cshcn_ind = "2017" ///
		   1.jobchange@2018.year#1.cshcn_ind = "2018" ///
		   1.jobchange@2019.year#1.cshcn_ind = "2019" ///
		   1.jobchange@2020.year#1.cshcn_ind = "2020") ///
		lcolor("$cshcn_col") mcolor("$cshcn_col") ///
		ciopts(lcolor("$cshcn_col")) lpattern(l) label("CSHCN") ///
		ci((ll ul)) b(bb)) ///
	(Overall, keep(1.jobchange@*.year) ///
		rename(1.jobchange@2016.year = "2016" ///
		   1.jobchange@2017.year = "2017" ///
		   1.jobchange@2018.year = "2018" ///
		   1.jobchange@2019.year = "2019" ///
		   1.jobchange@2020.year = "2020") ///
		lcolor("$overall_col") mcolor("$overall_col") offset(0.05) ///
		ciopts(lcolor("$overall_col")) lpattern(l) label("Overall") ///
		ci((ll ul)) b(bb)) ///
	(CSHCN, keep(1.jobchange@*.year#0.cshcn_ind) ///
		rename(1.jobchange@2016.year#0.cshcn_ind = "2016" ///
		   1.jobchange@2017.year#0.cshcn_ind = "2017" ///
		   1.jobchange@2018.year#0.cshcn_ind = "2018" ///
		   1.jobchange@2019.year#0.cshcn_ind = "2019" ///
		   1.jobchange@2020.year#0.cshcn_ind = "2020") ///
		lcolor("$noncshcn_col") mcolor("$noncshcn_col") offset(-0.05) ///
		ciopts(lcolor("$noncshcn_col")) label("non-CSHCN") lpattern(l) ///
		ci((ll ul)) b(bb)), ///
	yaxis(1 2) ///
	vertical recast(connected) scheme(s1color) nooffset ///
	xtitle(Year) ytitle("Childcare-Related" "Employment Disruption (%)", axis(2)) connect(l) ///
	msize(medsmall) ///
	ylabel(0 5 10 15 20 25 30, ///
		grid axis(2) angle(0) labsize(small)) ///
	ylabel($cshcn1619 "$cshcn1619_lab%" ///
		   $overall1619_label_val "$overall1619_lab%" ///
		   $noncshcn1619_label_val "$noncshcn1619_lab%", ///
		axis(1) format(%3.2g) angle(0) labsize(small) noticks) ///
	yline($cshcn1619, lcolor($cshcn_col) lwidth(0.2) lpattern(-) axis(2)) ///
	yline($overall1619, lcolor($overall_col) lwidth(0.2) lpattern(-) axis(2)) ///
	yline($noncshcn1619, lcolor($noncshcn_col) lwidth(0.2) lpattern(-) axis(2)) ///
	legend(row(1)) yscale(titlegap(6pt) axis(2)) xscale(titlegap(6pt)) ///
	xsize(6) ysize(4)
graph export prevtrends.pdf, replace

// ************************************************** //
// Job Change Due to Child Care - Adjusted
// ************************************************** // 
// set back to unpooled weights
svyset, clear
svyset hhid [pweight=fwc], strata(stratacross) 

// year dummies to keep the right levels in the regression 
gen year20 = year == 2020
gen year16 = year == 2016
gen year17 = year == 2017
gen year18 = year == 2018
// use 2019 as the reference (not a real value and not really estimated)
// see logistic model below
gen year19placeholder = 0  

// Income: Use imputed estimates following instructions from NSCH
gen fpl_i0=. // need to have a variable that's all missing
save nsch_all_labeled, replace // need to save
mi import wide, imputed(fpl_i0=fpl_i1-fpl_i6)
mi passive: generate povcat_i = 1
mi passive: replace povcat_i = 2 if fpl_i0 >= 100 & fpl_i0 < 200
mi passive: replace povcat_i = 3 if fpl_i0 >= 200 & fpl_i0 < 400
mi passive: replace povcat_i = 4 if fpl_i0 >= 400
label define povcat_label 1 "<100% FPL" 2 "100-199% FPL" 3 "200-399% FPL" 4 "400%+ FPL"
label values povcat_i povcat_label
mi est: svy, subpop(youngchild): proportion povcat_i

// Estimate model

mi est, allbaselevels or post: svy, subpop(youngchild): logistic jobchange /// 
	i.year16 i.year17 i.year18 i.year19placeholder i.year20 ///
	b0.cshcn_ind b0.cshcn_ind#i.year20 ///
	b5.sc_age_years i.race_cat b2.sc_hispanic_r /// 
	i.family_stru b2.a1_sex b4.higrade_tvis b1.totyoung b4.povcat_i
eststo reg
esttab reg using logmod_est_w_ci.csv, b(%4.3f) ci wide eform plain nomtitles replace
esttab reg using logmod_est_w_p.csv, b(%4.3f) p wide eform plain nomtitles replace

coefplot reg, omitted base eform /// all base labels, omitted (year19), and eform for ORs 
	keep(1.year16 1.year17 1.year18 0.year19 1.year20 ///
		 1.cshcn_ind 1.cshcn_ind#1.year20 ///
		 *.sc_age_years *.race_cat *.sc_hispanic_r ///
		 *.family_stru *.totyoung *.a1_sex *.higrade_tvis *.povcat_i) ///
	coeflabels(1.year16 = "2016" 1.year17 = "2017" 1.year18 = "2018" ///
		0.year19placeholder = "2019" 1.year20 = "2020" ///
		1.cshcn_ind = "CSHCN" ///
		1.cshcn_ind#1.year20 = "CSHCN x 2020 Interaction", labsize(small)) ///
	headings(1.cshcn_ind = "{bf}CSHCN Status" ///
		0.sc_age_years = "{bf}Age (years)" ///
		1.race_cat = "{bf}Race" ///
		1.sc_hispanic_r = "{bf} Hispanic/Latino" ///
		1.a1_sex = "{bf} Respondent Sex" ///
		1.totyoung = "{bf} # of Children Aged 0-5" ///
		1.higrade_tvis = "{bf}Education (Household)" ///
		1.family_stru = "{bf}Family Structure" ///
		1.povcat_i = "{bf} Family Income", labsize(small) offset(-.1)) ///
	groups(1.year16 1.year17 1.year18 1.year20 = "{it}Year" ///
		1.cshcn_ind 0.sc_age_years 1.race_cat 2.sc_hispanic_r = "{it}Child Variables" ///
		1.a1_sex 3.totyoung 1.higrade_tvis 1.family_stru 4.povcat_i = "{it}Caregiver/Household Variables", ///
		gap(3)) ///
	msize(medsmall) mlabcolor(none) ///
	mlabel(cond(@pval<0.01, "**", cond(@pval<0.05, "*", ""))) ///
	addplot(scatter @at @ul, ms(i) mlabel(@mlbl) mlabcolor(black) mlabpos(3)) ///
	scheme(s2color) drop(_cons) xline(1, lpattern(l) lwidth(0.1)) ///
	xtitle(" " "Odds Ratio") ///
	ysize(8) xsize(5) scale(0.9) ///
	xlabel(-0(0.5)3, grid glwidth(0.2) glcolor(dknavy) glpattern(.)) ///
	grid(none) graphregion(color(white))
graph export log_model_childcare.pdf, replace

log close
