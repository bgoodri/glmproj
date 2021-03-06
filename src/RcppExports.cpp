// Generated by using Rcpp::compileAttributes() -> do not edit by hand
// Generator token: 10BE3573-1514-4C36-9D1C-5A225CD40393

#include <RcppArmadillo.h>
#include <Rcpp.h>

using namespace Rcpp;

// glm_elnet_c
List glm_elnet_c(arma::mat x, Function pseudo_obs, arma::vec lambda, double alpha, bool intercept, double thresh, int qa_updates_max, int pmax, bool pmax_strict, int as_updates_max);
RcppExport SEXP glmproj_glm_elnet_c(SEXP xSEXP, SEXP pseudo_obsSEXP, SEXP lambdaSEXP, SEXP alphaSEXP, SEXP interceptSEXP, SEXP threshSEXP, SEXP qa_updates_maxSEXP, SEXP pmaxSEXP, SEXP pmax_strictSEXP, SEXP as_updates_maxSEXP) {
BEGIN_RCPP
    Rcpp::RObject rcpp_result_gen;
    Rcpp::RNGScope rcpp_rngScope_gen;
    Rcpp::traits::input_parameter< arma::mat >::type x(xSEXP);
    Rcpp::traits::input_parameter< Function >::type pseudo_obs(pseudo_obsSEXP);
    Rcpp::traits::input_parameter< arma::vec >::type lambda(lambdaSEXP);
    Rcpp::traits::input_parameter< double >::type alpha(alphaSEXP);
    Rcpp::traits::input_parameter< bool >::type intercept(interceptSEXP);
    Rcpp::traits::input_parameter< double >::type thresh(threshSEXP);
    Rcpp::traits::input_parameter< int >::type qa_updates_max(qa_updates_maxSEXP);
    Rcpp::traits::input_parameter< int >::type pmax(pmaxSEXP);
    Rcpp::traits::input_parameter< bool >::type pmax_strict(pmax_strictSEXP);
    Rcpp::traits::input_parameter< int >::type as_updates_max(as_updates_maxSEXP);
    rcpp_result_gen = Rcpp::wrap(glm_elnet_c(x, pseudo_obs, lambda, alpha, intercept, thresh, qa_updates_max, pmax, pmax_strict, as_updates_max));
    return rcpp_result_gen;
END_RCPP
}
// glm_ridge_c
List glm_ridge_c(arma::mat x, Function pseudo_obs, double lambda, bool intercept, double thresh, int qa_updates_max, int ls_iter_max);
RcppExport SEXP glmproj_glm_ridge_c(SEXP xSEXP, SEXP pseudo_obsSEXP, SEXP lambdaSEXP, SEXP interceptSEXP, SEXP threshSEXP, SEXP qa_updates_maxSEXP, SEXP ls_iter_maxSEXP) {
BEGIN_RCPP
    Rcpp::RObject rcpp_result_gen;
    Rcpp::RNGScope rcpp_rngScope_gen;
    Rcpp::traits::input_parameter< arma::mat >::type x(xSEXP);
    Rcpp::traits::input_parameter< Function >::type pseudo_obs(pseudo_obsSEXP);
    Rcpp::traits::input_parameter< double >::type lambda(lambdaSEXP);
    Rcpp::traits::input_parameter< bool >::type intercept(interceptSEXP);
    Rcpp::traits::input_parameter< double >::type thresh(threshSEXP);
    Rcpp::traits::input_parameter< int >::type qa_updates_max(qa_updates_maxSEXP);
    Rcpp::traits::input_parameter< int >::type ls_iter_max(ls_iter_maxSEXP);
    rcpp_result_gen = Rcpp::wrap(glm_ridge_c(x, pseudo_obs, lambda, intercept, thresh, qa_updates_max, ls_iter_max));
    return rcpp_result_gen;
END_RCPP
}
