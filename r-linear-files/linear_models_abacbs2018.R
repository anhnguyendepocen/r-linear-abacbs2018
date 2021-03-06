


#////////////////////////
# 1 Loading packages ----

## To install needed CRAN packages:
#
# install.packages("tidyverse")
# install.packages("multcomp")
#
## To install needed Bioconductor packages:
#
# source("https://bioconductor.org/biocLite.R")
# biocLite(c("limma", "edgeR"))
#

library(MASS)       # ginv -- coefficient estimation
library(splines)    # ns, bs -- spline curves
library(multcomp)   # glht -- linear hypotheses
library(edgeR)      # cpm, etc -- RNA-Seq normalization
library(limma)      # lmFit, etc -- fitting many models
library(tidyverse)  # working with data frames, plotting

# Much of what we will be using is built into R without loading any
# packages.



#//////////////////////////////////
# 2 Single numerical predictor ----
#
# The age (year) and height (cm) of 10 people has been measured. We want
# a model that can predict height based on age.

people <- read_csv(
    "age, height
      10,    131
      14,    147
      16,    161
       9,    136
      16,    170
      15,    160
      15,    153
      21,    187
       9,    145
      21,    195")

ggplot(people, aes(x=age, y=height)) + geom_point()

fit <- lm(height ~ 1+age, data=people)

fit

# * This is not normal addition, it's special formula notation.
# * We can "add" any number of predictors.
# * "1" denotes an intercept term. This is actually implictly included
# even if you leave it out.

lm(height ~   age, data=people)  # Implicit intercept term
lm(height ~ 0+age, data=people)  # Use 0 or -1 to omit

# Coefficients are extracted with coef:

coef(fit)

# The residual standard deviation is extracted with sigma:

sigma(fit)

# Behind the scenes a matrix of predictors has been produced from the
# formula notation ~ 1+age. We can examine it explicitly:

model.matrix(fit)

# model.matrix can be used without first calling lm.

model.matrix(~ 1+age, data=people)

# n=10 observations minus p=2 columns in the model matrix leaves 8
# residual degrees of freedom:

df.residual(fit)

# 2.1 Prediction ----
#
# predict predicts. By default it produces predictions on the original
# dataset.

predict(fit)
predict(fit, interval="confidence")

# We can also calculate predictions manually.

# Prediction for a 15-year old
x <- c(1, 15)
beta <- coef(fit)
sum(x * beta)

# Prediction for all original data
X <- model.matrix(fit)
as.vector( X %*% beta )

# predict can be used with new data.

new_people <- data_frame(age=5:25)
predict(fit, new_people)

new_predictions <- cbind(
    new_people,
    predict(fit, new_people, interval="confidence"))

ggplot() +
    geom_ribbon(aes(x=age, ymin=lwr, ymax=upr), data=new_predictions, fill="grey") +
    geom_line(aes(x=age, y=fit), data=new_predictions, color="blue") +
    geom_point(aes(x=age, y=height), data=people) +
    labs(y="height (cm)", x="age (year)",
         subtitle="Ribbon shows 95% confidence interval of the model")

# If you have ever used geom_smooth, it should now be a little less
# mysterious.

ggplot(people, aes(x=age, y=height)) + geom_smooth(method="lm") + geom_point()

# 2.2 Residuals ----
#
# The residuals are the differences between predicted and actual values.

residuals(fit)

plot(predict(fit), residuals(fit))

# Residuals should be close to normally distributed.

qqnorm(residuals(fit))
qqline(residuals(fit))

# plot(fit) produces a series of more sophisticated diagnostic plots.

plot(fit)

# 2.3 Comparing nested models ----
#
# The anova( ) function performs an F-test to compare two models. ANOVA
# means ANalysis Of VAriance, because the test compares the residual
# variances of the two models.
#
# The simpler model formula must *nest* inside the more complex model
# formula, or the test will be invalid: any model possible with the
# simpler formula must have an equivalent with the more complex formula.
# The test tells us if we have grounds to reject the simpler model
# formula.

fit_noslope <- lm(height ~ 1, data=people)
anova(fit_noslope, fit)

fit_nointercept <- lm(height ~ 0+age, data=people)
anova(fit_nointercept, fit)

# summary( ) is a quick and dirty way to compare a model to models with
# each of the terms dropped in turn.

summary(fit)

# Note that the p-values match those from the calls to anova( ).
#
# Finally, confint( ) gives confidence intervals for coefficients. If a
# coefficient had p-value 0.05 in the above tests, the confidence
# interval would just touch zero.

confint(fit)

# 2.3.1 Question ----

y <- c(5,3,2,4,1)
fit0 <- lm(y ~ 0)
fit1 <- lm(y ~ 1)
anova(fit0, fit1)

# 1. Describe the null hypothesis (fit0).
#
# 2. Describe the alternative hypothesis (fit1).
#
# 3. What have we shown with this test?
#


#///////////////////////////////
# 3 Single factor predictor ----
#
# Consider a simple experiment where two treatments are compared with a
# control group. This is called a one-way ANOVA  experiment. This is
# another usage of the term ANOVA! The F-test we just used was developed
# by Fisher in the context of this type of model.

outcomes <- read_csv(
    "group,    outcome
     control,  5.46
     control,  2.06
     control,  2.74
     control,  6.02
     a,        8.31
     a,        11.75
     a,        6.13
     a,        10.59
     b,        1.02
     b,        3.69
     b,        2.52")

outcomes$group <- factor(outcomes$group, c("control", "a", "b"))

ggplot(outcomes, aes(x=group, y=outcome)) + geom_point()

outfit <- lm(outcome ~ group, data=outcomes)
outfit

df.residual(outfit)
sigma(outfit)

# 3.1 Meanings of the coefficients ----

model.matrix(outfit)

# It's important to understand how the factor has been encoded. It's a
# bit weird, but it's a system that extends well to models with multiple
# factors. The factor is encoded as "indicator variables" for all but
# the first level in the factor ("one-hot encoding"). This means:
#
# * (Intercept) represents the average for the control group
# * groupa is the difference from the control to group "a"
# * groupb is the difference from the control to group "b"
#
# If this becomes confusing, it's possible to directly examine how
# coefficients are fitted, which is by multiplying by the "Moore-Penrose
# generalized inverse" of the model matrix.

library(MASS)
X <- model.matrix(~ group, data=outcomes)
ginv(X) %>% round(2)
ginv(X) %*% outcomes$outcome   #Confirm estimates are the same

# 3.2 F test ----
#
# An F test comparing to a null hypothesis model with just an intercept
# term tells us if there are any detectable differences between groups.

outfit_null <- lm(outcome ~ 1, data=outcomes)
anova(outfit_null, outfit)

# 3.3 Comparing pairs of levels ----
#
# What about between specific pairs of groups? summary( ) (and confint(
# )) give us two of the answers, "a" vs "control" and "b" vs "control".

summary(outfit)
confint(outfit)

# What about "b" vs "a"? For this we need a linear hypothesis test.

coef(outfit)[3] - coef(outfit)[2]

library(multcomp)

K <- rbind(c(0, -1, 1))
K %*% coef(outfit)
result <- glht(outfit, K)
summary(result)
confint(result)

# multcomp can be given multiple rows to test in K. In this case, by
# default, it does a multiple testing correction to maintain the Family-
# Wise Error Rate using a generalization of Tukey's Honestly Significant
# Differences.

# 3.4 Factor model without an intercept ----
#
# There's a further rule to learn about how R deals with factors in
# linear models. If the intercept is omitted, R produces a predictor for
# each level in the factor (rather than all but the first).

outfit2 <- lm(outcome ~ 0+group, data=outcomes)
outfit2
model.matrix(outfit2)

# This fit is equivalent to the original outfit, but the coefficients
# have different meanings.

# 3.4.1 Question ----
#
# 1. What are the meanings of the three coefficients in this alternative
# model?
#
# 2. What would be the linear hypotheses to test differences between
# each pair of groups?
#


#///////////////////////////////
# 4 Gene expression example ----
#
# Tooth growth in mouse embryos is studied using RNA-Seq. The RNA
# expression levels of several genes are examined in the cells that form
# the upper and lower first molars, in eight individual mouse embryos
# that have been dissected after different times of embryo development.
# The measurements are in terms of "Reads Per Million", essentially the
# fraction of RNA in each sample belonging to each gene, times 1
# million.
#
# (This data was extracted from ARCHS4
# (https://amp.pharm.mssm.edu/archs4/). In the Gene Expression Omnibus
# it is entry GSE76316. The sample descriptions in GEO seem to be out of
# order, but reading the associated paper and the genes they talk about
# I *think* I have the correct order of samples!)

teeth <- read_csv("data/linearModels/teeth.csv")

teeth$tooth <- factor(teeth$tooth, c("lower","upper"))
teeth$mouse <- factor(teeth$mouse)

# It will be convenient to have a quick way to examine different genes
# and different models with this data.

# A convenience to examine different model fits
more_data <- expand.grid(
    day=seq(14.3,18.2,by=0.01),
    tooth=as_factor(c("lower","upper")))

look <- function(y, fit=NULL) {
    p <- ggplot(teeth,aes(x=day,group=tooth))
    if (!is.null(fit)) {
        more_ci <- cbind(
            more_data,
            predict(fit, more_data, interval="confidence"))
        p <- p +
            geom_ribbon(data=more_ci, aes(ymin=lwr,ymax=upr),alpha=0.1) +
            geom_line(data=more_ci,aes(y=fit,color=tooth))
    }
    p + geom_point(aes(y=y,color=tooth)) +
        labs(y=deparse(substitute(y)))
}

# Try it out
look(teeth$gene_ace)

# We could treat day as a categorical variable, as in the previous
# section. However let us treat it as numerical, and see where that
# leads.

# 4.1 Transformation ----

# 4.1.1 Ace gene ----

acefit <- lm(gene_ace ~ tooth + day, data=teeth)

look(teeth$gene_ace, acefit)

# Two problems:
#
# 1. The actual data appears to be curved, our straight lines are not a
# good fit.
# 2. The predictions fall below zero, a physical impossibility.
#
# In this case, log transformation of the data will solve both these
# problems.

log2_acefit <- lm( log2(gene_ace) ~ tooth+day, data=teeth)

look(log2(teeth$gene_ace), log2_acefit)

# Various transformations of y are possible. Log transformation is
# commonly used in the context of gene expression. Square root
# transformation can also be appropriate with nicely behaved count data
# (technically, if the errors follow a Poisson distribution). This gene
# expression data is ultimately count based, but is overdispersed
# compared to the Poisson distribution so square root transformation
# isn't appropriate in this case.

# 4.1.2 Pou3f3 gene ----
#
# In the case of the Pou3f3 gene, the log transformation is even more
# important. It looks like gene expression changes at different rates in
# the upper and lower molars, that is there is a significant interaction
# between tooth and day.

pou3f3fit0 <- lm(gene_pou3f3 ~ tooth+day, data=teeth)
look(teeth$gene_pou3f3, pou3f3fit0)

pou3f3fit1 <- lm(gene_pou3f3 ~ tooth*day, data=teeth)
look(teeth$gene_pou3f3, pou3f3fit1)

anova(pou3f3fit0, pou3f3fit1)

# Examining the residuals reveals a further problem: larger expression
# values are associated with larger residuals.

look(residuals(pou3f3fit1))
plot(predict(pou3f3fit1), residuals(pou3f3fit1))
qqnorm(residuals(pou3f3fit1))
qqline(residuals(pou3f3fit1))

# Log transformation both removes the interaction and makes the
# residuals more uniform (except for one outlier).

log2_pou3f3fit0 <- lm(log2(gene_pou3f3) ~ tooth+day, data=teeth)
log2_pou3f3fit1 <- lm(log2(gene_pou3f3) ~ tooth*day, data=teeth)

anova(log2_pou3f3fit0, log2_pou3f3fit1)

look(log2(teeth$gene_pou3f3), log2_pou3f3fit0)

qqnorm(residuals(log2_pou3f3fit0))
qqline(residuals(log2_pou3f3fit0))

# 4.2 Homework - Wnt2 gene ----
#
# Look at the expression of gene Wnt2 in column gene_wnt2.
#
# 1. Try some different model formulas.
#
# 2. Justify a particular model by rejecting simpler alternatives using
# anova( ). For example, can we reject that there is no interaction
# between tooth and day?
#


#/////////////////////////////////////
# 5 Testing many genes with limma ----
#
# In this section we look at fitting the same matrix of predictors X to
# many different sets of responses y. We will use the package limma from
# Bioconductor. This is a very brief demonstration, and there is much
# more to this package. See the excellent usersguide.pdf at
# https://bioconductor.org/packages/release/bioc/html/limma.html

# 5.1 Load, normalize, log transform ----
#
# Actually in the teeth dataset, the expression level of all genes was
# measured!

counts_df <- read_csv("data/linearModels/teeth-read-counts.csv")
counts <- as.matrix(counts_df[,-1])
rownames(counts) <- counts_df[[1]]

dim(counts)
counts[1:5,]

# The column names match our teeth data frame.

teeth$sample

# A usual first step in RNA-Seq analysis is to convert read counts to
# Reads Per Million, and log2 transform the results. There are some
# subtleties here which we breeze over lightly: "TMM" normalization is
# used as a small adjustment to the total number of reads in each
# sample. A small constant is added to the counts to avoid calculating
# log2(0). The edgeR and limma manuals describe these steps in more
# detail.

library(edgeR)
library(limma)

dgelist <- calcNormFactors(DGEList(counts))

dgelist$samples

log2_cpms <- cpm(dgelist, log=TRUE, prior.count=0.25)

# There is little chance of detecting differential expression in genes
# with very low read counts. Including these genes will require a larger
# False Discovery Rate correction, and also confuses limma's Empirical
# Bayes parameter estimation. Let's only retain genes with around 5
# reads per sample or more.

keep <- rowMeans(log2_cpms) >= -3
log2_cpms_filtered <- log2_cpms[keep,]

nrow(log2_cpms)
nrow(log2_cpms_filtered)

# 5.2 Fitting a model to and testing each gene ----
#
# We use limma to fit a linear model to each gene. The same model
# formula will be used in each case. limma doesn't automatically convert
# a formula into a model matrix, so we have to do this step manually.
# Here I am using a model formula that treats the upper and lower teeth
# as following a different linear trend over time.

X <- model.matrix(~ tooth*day, data=teeth)
X

fit <- lmFit(log2_cpms_filtered, X)

class(fit)
fit$coefficients[1:5,]

# Significance testing in limma is by the use of linear hypotheses
# (which limma refers to as "contrasts"). A difference between glht and
# limma's contrasts.fit is that limma expects the contrasts in columns
# rather than rows.
#
# We will first look for genes where the slope over time is not flat,
# *averaging* the lower and upper teeth.

# Lower slope: c(0,0,1,0)
# Upper slope: c(0,0,1,1)

K <- rbind(c(0,0,1,0.5))
cfit <- contrasts.fit(fit, t(K))       #linear hypotheses in columns!
efit <- eBayes(cfit, trend=TRUE)

# The call to eBayes does Emprical Bayes squeezing of the residual
# variance for each gene (see final section). This is a bit of magic
# that allows limma to work well with small numbers of samples.

topTable(efit)

# The column adj.P.Val contains FDR adjusted p-values.

all_results <- topTable(efit, n=Inf)

significant <- all_results$adj.P.Val <= 0.05
table(significant)

ggplot(all_results, aes(x=AveExpr, y=logFC)) +
    geom_point(size=0.1, color="grey") +
    geom_point(data=all_results[significant,], size=0.1)

# 5.3 Relation to lm( ) and glht( ) ----
#
# Let's look at a specific gene.

rnf144b <- log2_cpms["Rnf144b",]
rnf144b_fit <- lm(rnf144b ~ tooth * day, data=teeth)
look(rnf144b, rnf144b_fit)

# We can use the same linear hypothesis with glht. The estimate is the
# same, but limma has gained some power by shrinking the variance toward
# the trend line, so limma's p-value is smaller.

summary( glht(rnf144b_fit, K) )

# 5.4 Confidence intervals ----
#
# Confidence Intervals should also be of interest. However note that
# these are not adjusted for multiple testing (see final section).

topTable(efit, confint=0.95)

# 5.5 F test ----
#
# limma can also test several simultaneous constraints on linear
# combinations of coefficients. Suppose we want to find *any* deviation
# from a constant expression level. We can check for this with:

K2 <- rbind(
    c(0,1,0,0),
    c(0,0,1,0),
    c(0,0,0,1))

cfit2 <- contrasts.fit(fit, t(K2))
efit2 <- eBayes(cfit2, trend=TRUE)
topTable(efit2)

# A shortcut would be to use contrasts.fit(fit, coefficients=2:4) here
# instead, or to specify a set of coefficients directly to topTable( ).
# The results would be the same.

# 5.6 Homework - construct some linear hypotheses ----
#
# Construct and use linear combinations of coefficients to find genes
# that:
#
# 1. Differ in slope between lower and upper molars.
#
# 2. Differ in expression on day 16 between the lower and upper molars.
#
# Hint: the null hypothesis for 2 can be specified as saying the
# difference in predictions between two particular samples is zero.
#
# 3. Construct a pair of linear combinations that when used together in
# an F test find genes with non-zero slope in either or both of the
# lower and upper molars.
#


#//////////////////////
# 6 Fitting curves ----
#
# Not all of the genes in our teeth data have a straight line
# relationship with time. Returning to the original data frame, let's
# look at the Smoc1 gene.

log2_smoc1fit <- lm(log2(gene_smoc1) ~ tooth + day, data=teeth)

look(log2(teeth$gene_smoc1), log2_smoc1fit)

# In this case, log transformation does not remove the curve. If you
# think this is a problem for *linear* models, you are mistaken! With a
# little *feature engineering* we can fit a quadratic curve.
# Calculations can be included in the formula if wrapped in I( ):

curved_fit <- lm(log2(gene_smoc1) ~ tooth + day + I(day^2), data=teeth)
look(log2(teeth$gene_smoc1), curved_fit)

# Another way to do this would be to add the column to the data frame:

teeth$day_squared <- teeth$day^2
curved_fit2 <- lm(log2(gene_smoc1) ~ tooth + day + day_squared, data=teeth)

# Finally, the poly( ) function can be used in a formula to fit
# polynomials of arbitrary degree. poly will encode day slightly
# differently, but produces an equivalent fit.

curved_fit3 <- lm(log2(gene_smoc1) ~ tooth + poly(day,2), data=teeth)

sigma(curved_fit)
sigma(curved_fit2)
sigma(curved_fit3)

# poly( ) can also be used to fit higher order polynomials, but these
# tend to become wobbly and extrapolate poorly. A better option may be
# to use the ns( ) or bs( ) functions in the splines package, which can
# be used to fit piecewise "B-splines". In particular ns( ) (natural
# spline) is appealing because it extrapolates beyond the ends only with
# straight lines. If the data is cyclic (for example cell cycle or
# circadian time series), sine and cosine terms can be used to fit some
# number of harmonics from a Fourier series.

library(splines)
spline_fit <- lm(log2(gene_smoc1) ~ tooth * ns(day,3), data=teeth)

look(log2(teeth$gene_smoc1), spline_fit)

# All of these approaches can also be used with limma (or edgeR or
# DESeq2).



#/////////////////////////////////////
# 7 Some further details on limma ----

# 7.1 Empirical Bayes variance squeezing ----
#
# In limma, Empirical Bayes squeezing of the residual variance acts as
# though we have some number of extra "prior" observations of the
# variance. These are also counted as extra degrees of freedom in F
# tests. The "prior" observations act to squeeze the estimated residual
# variance of each gene toward a trend line that is a function of the
# average expression level. (There is also an alternative approach that
# estimates variance at the level of individual observations rather than
# genes, called voom.)

efit <- eBayes(cfit, trend=TRUE)

efit$df.prior
efit$df.residual
efit$df.total
plotSA(efit)
points(efit$Amean, efit$s2.post^0.25, col="red", cex=0.2)

# The total effective degrees of freedom is the "prior" degrees of
# freedom plus the normal residual degrees of freedom. As can be seen in
# the plot, compared to the residual variance (black dots), this
# produces a posterior residual variance (efit$s2.post, red dots) that
# is squeezed toward the trend line.
#
# It's worthwhile checking df.prior when using limma, as a low value may
# indicate a problem with a data-set.

# 7.2 False Coverage-statement Rate corrected CIs ----
#
# We noted the CIs produced by limma were not adjusted for multiple
# testing. A False Coverage-statement Rate (FCR) corrected CI can be
# constructed corresponding to a set of genes judged significant. The
# smaller the selection of genes as a proportion of the whole, the
# greater the correction required. To ensure a False Coverage-statement
# Rate of q, we need (1-q*n_genes_selected/n_genes_total)*100%
# confidence intervals.

all_results <- topTable(efit, n=Inf)
significant <- all_results$adj.P.Val <= 0.05
prop_significant <- mean(significant)
fcr_confint <- 1 - 0.05*prop_significant

all_results <- topTable(efit, confint=fcr_confint, n=Inf)

ggplot(all_results, aes(x=AveExpr, y=logFC)) +
    geom_point(size=0.1, color="grey") +
    geom_errorbar(data=all_results[significant,], aes(ymin=CI.L, ymax=CI.R), color="red") +
    geom_point(data=all_results[significant,], size=0.1)

# The FCR corrected CIs used here have the same q, 0.05, as we used as
# the cutoff for adj.P.Val. This means they never pass through zero.
#
# I have some further thoughts on this topic, see the package
# topconfects (http://logarithmic.net/topconfects/).
