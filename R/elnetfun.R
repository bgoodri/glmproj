#
# The functions in this file are used to compute the elastic net coefficient paths
# for a GLM. The main function is glm_elnet, other functions are auxiliary ones.
# The L1-regularized projection path is computed by replacing the actual data y
# by the fit of the full model when calling glm_elnet. Uses functions glm_elnet_c
# from elnetfun.cpp.
#

pseudo_data <- function(f, y, family, offset=rep(0,length(f)), weights=rep(1.0,length(f)) ) {
    #
    # Returns locations z and weights w (inverse-variances) of the Gaussian pseudo-observations
    # based on the quadratic approximation to the loss function (negative log likelihood) at 
    # when the given fit f = eta = x*beta + beta0.
    #
	mu <- family$linkinv(f)
	dmu_df <- family$mu.eta(f)
	z <- (f - offset) + (y - mu)/dmu_df
	w <- (weights * dmu_df^2)/family$variance(mu)
	return(list(z=z,w=w))
}

loss_approx <- function(beta,f,z,w,lambda,alpha) {
	#
    # second order Taylor expansion for the penalized loss function (negative log-likelihood
	# or kl-divergence) given the pseudo-observations (locations z and weights w).
	# uses the elastic-net penalty with parameters lambda and alpha.
    #
	L <- 0.5*sum(w*(z-f)^2) + lambda*(0.5*(1-alpha)*sum(beta^2) + alpha*(sum(abs(beta))))
	return(L)
}

lambda_grid <- function(x, y, family, alpha=1.0, eps=1e-2, nlam=100) {
	#
    # Standard lambda sequence as described in Friedman et al. (2009), section 2.5.
    # The grid will have nlam values, evenly spaced in the log-space between lambda_max
    # and lambda_min. lambda_max is the smallest value for which all the regression
    # coefficients will be zero.
    #
	n <- dim(x)[1]
	obs <- pseudo_data(rep(0,n), y, family)
	
	lambda_max <- max(abs( t(x) %*% (obs$z*obs$w) )) / alpha
	lambda_min <- eps*lambda_max
	loglambda <- seq(log(lambda_min), log(lambda_max), len=nlam)
	return(rev(exp(loglambda)))
}


glm_elnet <- function(x, y, family=gaussian(), nlambda=100, lambda_min_ratio=1e-3,
                      lambda=NULL, alpha=1.0, thresh=1e-5, 
					  qa_updates_max=ifelse(family$family=='gaussian', 1, 100), 
					  pmax=dim(as.matrix(x))[2], pmax_strict=FALSE,
					  weights=NULL, offset=NULL, intercept=TRUE) {
	#
	# Fits GLM with elastic net penalty on the regression coefficients.
	# Computes the whole regularization path.
	# Does not handle any dispersion parameters.
	#
	if (is.null(lambda))
		lambda <- lambda_grid(x,y,family,alpha,nlam=nlambda,eps=lambda_min_ratio)
	
	x <- as.matrix(x)
	if (is.null(weights))
		weights <- 1.0
	if (is.null(offset))
		offset <- 0.0
	pseudo_obs <- function(f) {return(pseudo_data(f,y,family,offset=offset,weights=weights))}
	out <- glm_elnet_c(x,pseudo_obs,lambda,alpha,intercept,thresh,qa_updates_max,pmax,pmax_strict)
	return(list( beta=out[[1]], beta0=as.vector(out[[2]]), npasses=out[[3]], 
				 updates_qa=as.vector(out[[4]]), updates_as=as.vector(out[[5]]) ))
}










