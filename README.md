# Childcare and employment in the NSCH

The analysis file is [childcare.do](childcare.do). It was run with Stata 16.1, but other versions may also work.

The log from running the analysis file is [childcare.log](childcare.log).

## Replication

To replicate, download the [NSCH data files](https://www.census.gov/programs-surveys/nsch/data/datasets.html) for years 2016-2020. Specifically, download the "\<Year\> Topical Data and Input Files > Stata Data Files" and unzip into the same directory as the repository.

## Results 

For the descriptive results (prevalence of childcare-associated employment disruption), see the CSV files starting with "jobchange" (e.g. [jobchange_pooled_by_cshcn.csv](jobchange_pooled_by_cshcn.csv)). The *P* values for the adjusted Wald tests are in [prevtest_pvals.txt](prevtest_pvals.txt). 

### Figure 1: Estimated Childcare-Related Job Change by SHCN Status and Year
The code used to produce Figure 1 is in [the do file, lines 151-324](https://github.com/caleb-easterly/childcare-nsch/blob/main/childcare.do#L151-L324). Figure 1 itself is at [prevtrends.png](prevtrends.png).

## Figure 2: Multivariate Logistic Regression
The code used to estimate the model and produce Figure 2 is in [the do file, lines 326-395](https://github.com/caleb-easterly/childcare-nsch/blob/main/childcare.do#L326-L395). See Figure 2 at [log_model_childcare.png](log_model_childcare.png). 

Estimated odds ratios are available in two files: one with 95% CIs ([logmod_est_w_ci.csv](logmod_est_w_ci.csv)) and one with *P* values ([logmod_est_w_p.csv](logmod_est_w_p.csv)).







