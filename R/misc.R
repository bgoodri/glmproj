.onAttach <- function(...) {
  ver <- utils::packageVersion("glmproj")
  packageStartupMessage("This is glmproj version ", ver)
}

# from rstanarm
log_mean_exp <- function(x) {
  max_x <- max(x)
  max_x + log(sum(exp(x - max_x))) - log(length(x))
}
is.stanreg <- function(x) inherits(x, "stanreg")

# Updated version of the kfold function in the rstanarm-package

#' @export
kfold <- function (x, K = 10, save_fits = FALSE)
{
  #validate_stanreg_object(x)
  #if (!used.sampling(x))
  #  STOP_sampling_only("kfold")
  #stopifnot(!is.null(x$data), K > 1, nrow(x$data) >= K)
  d <- x$data
  N <- nrow(d)
  wts <- x[["weights"]]
  perm <- sample.int(N)
  idx <- ceiling(seq(from = 1, to = N, length.out = K + 1))
  bin <- .bincode(perm, breaks = idx, right = FALSE, include.lowest = TRUE)
  lppds <- list()
  fits <- array(list(), c(K, 2), list(NULL, c('fit','omitted')))
  for (k in 1:K) {
    message("Fitting model ", k, " out of ", K)
    omitted <- which(bin == k)
    fit_k <- update(object = x, data = d[-omitted, ], weights = if (length(wts))
      wts[-omitted]
      else NULL, refresh = 0)
    lppds[[k]] <- log_lik(fit_k, newdata = d[omitted, ])
    if(save_fits) fits[k,] <- list(fit = fit_k, omitted = omitted)
  }
  elpds <- unlist(lapply(lppds, function(x) {
    apply(x, 2, log_mean_exp)
  }))
  out <- list(elpd_kfold = sum(elpds),
              se_elpd_kfold = sqrt(N * var(elpds)),
              pointwise = cbind(elpd_kfold = elpds))
  if(save_fits) out$fits <- fits
  structure(out, class = c("kfold", "loo"), K = K)
}

# check if the fit object is suitable for variable selection
.validate_for_varsel <- function(fit) {
  if(!is.stanreg(fit))
    stop('Object is not a stanreg object')

  if(!(gsub('rstanarm::', '', fit$call[1]) %in% c("stan_glm", "stan_lm")))
    stop('Only \'stan_lm\' and \'stan_glm\' are supported.')

  families <- c('gaussian','binomial','poisson')
  if(!(family(fit)$family %in% families))
    stop(paste0('Only the following families are supported:\n',
                paste(families, collapse = ', '), '.'))

  if(NCOL(get_x(fit)) < 4)
    stop('Not enought explanatory variables for variable selection')
}

# from rstanarm
`%ORifNULL%` <- function(a, b) if (is.null(a)) b else a

# extract all important 'information' from a stanreg object for variable selection
.extract_vars <- function(fit) {
  e <- extract(fit$stanfit)
  dis_name <- switch(family(fit)$family, 'gaussian' = 'sigma', 'Gamma' = 'shape',
                     'dispersion')
  res <- list(x = unname(get_x(fit)),
              b = t(unname(cbind(drop(e$alpha), drop(e$beta)))),
              dis = unname(e[[dis_name]]) %ORifNULL% rep(1, nrow(e$beta)),
              offset = fit$offset %ORifNULL% rep(0, nobs(fit)),
              intercept = attr(fit$terms,'intercept') %ORifNULL% F)
  res$x <- res$x[, as.logical(attr(res$x, 'assign'))]
  attr(res$x, 'assign') <- NULL

  y <- unname(get_y(fit))
  if(NCOL(y) == 1) {
    res$weights <- if(length(weights(fit))) unname(weights(fit)) else rep(1, nobs(fit))
    res$y <- y
  } else {
    res$weights <- rowSums(y)
    res$y <- y[, 1] / res$weights
  }

  res
}

# initialize arguments to their default values if they are not specified
.init_args <- function(args, vars, fam) {
  res <- list(
    ns_total = ncol(vars$b),
    rank_x = rankMatrix(vars$x),
    ns = min(args$ns %ORifNULL% 400, ncol(vars$b)),
    nc = min(args$nc %ORifNULL% 0, 100, args$ns, round(ncol(vars$b)/4)),
    n_boot = args$n_boot %ORifNULL% 1000,
    intercept = vars$intercept %ORifNULL% F,
    verbose = args$verbose %ORifNULL% F,
    cv = args$cv %ORifNULL% F,
    regul = args$regul %ORifNULL% 1e-10, #small regul as in Dupuis & Robert
    max_it = args$max_it %ORifNULL% 300,
    epsilon = args$epsilon %ORifNULL% 1e-8,
    family_kl = kl_helpers(fam)
  )
  res$clust <- res$nc > 0
  if(!is.null(args$nc) && args$nc > res$nc)
    print(paste0('Setting the number of clusters to ', res$nc, '.'))

  if(!is.null(args$ns) && args$ns > res$ns)
    print(paste0('Setting the number of samples to ', res$ns, '.'))

  res$nv <- min(ncol(vars$x) - 1 + res$intercept, args$nv, res$rank_x)
  if(!is.null(args$nv) && args$nv > res$nv)
    print(paste0(
      'Setting the max number of variables in the projection to ', res$nv, '.'))

  res
}

# perform clustering over the samples
.get_p_clust <- function(mu, dis, args, cl = NULL) {
  # calculate the means of the variables
  cl <- cl %ORifNULL% kmeans(t(mu), args$nc, iter.max = 50)
  p <- list(mu = unname(t(cl$centers)),
            dis = sapply(1:args$nc, function(cl_ind, dis, cl_assign) {
              sqrt(mean(dis[which(cl_assign == cl_ind)]^2))
            }, dis, cl$cluster),
            cluster_w = cl$size/sum(cl$size))
  list(cl = cl, p = p)
}

# function handle for the projection over samples. Gaussian case
# uses analytical solution to do the projection over samples.
.get_proj_handle <- function(family_kl) {

  # Use analytical solution for gaussian as it is a lot faster
  if(family_kl$family == 'gaussian' && family_kl$link == 'identity') {
    function(v_ind, chosen, p_full, d_train, b0, args) {
      v_inds <- c(chosen, v_ind)
      w <- sqrt(d_train$weights)
      # for forward selection, these measures are precalculated

      # check if covariance matrix is invertible if it seems possible that it might not be
      if(args$rank_x - 2  <= length(v_inds)) {
        if(rankMatrix(crossprod(w*d_train$x[,v_inds, drop = F])) < length(v_inds))
          return(list(b = NA, dis = NA, kl = Inf))
      }

      regulvec <- c((1-args$intercept)*args$regul, rep(args$regul, length(v_inds) - 1))
      regulmat <- diag(regulvec, length(regulvec), length(regulvec))
      # Solution for the gaussian case (with l2-regularization)
      p_sub <- list(b = solve(crossprod(w*d_train$x[,v_inds, drop = F]) + regulmat,
                              crossprod(w*d_train$x[, v_inds, drop = F], w*p_full$mu)))
      p_sub$dis <- sqrt(colMeans(d_train$weights*(
        p_full$mu - d_train$x[, v_inds, drop = F]%*%p_sub$b)^2) + p_full$dis^2)
      p_sub$kl <- weighted.mean(log(p_sub$dis) - log(p_full$dis) + colSums(p_sub$b^2*regulvec), p_full$cluster_w)
      p_sub
    }

  } else {
    function(v_ind, chosen, p_full, d_train, b0, args) {
      v_inds <- c(chosen, v_ind)

      # check if covariance matrix is invertible if it seems possible that it might not be
      # preferably this could be removed if NR could be guaranteed not to fail.
      if(args$rank_x - 2  <= length(v_inds)) {
        if(rankMatrix(d_train$x[, v_inds, drop =F]) < length(v_inds))
          return(list(b = NA, dis = NA, kl = Inf))
      }

      # perform the projection over samples
      res <- sapply(1:ncol(p_full$mu), function(s_ind) {
        IRLS(list(mu = p_full$mu[, s_ind, drop = F], dis = p_full$dis[s_ind]),
             list(x = d_train$x[, v_inds, drop = F], weights = d_train$weights,
                  offset = d_train$offset), b0[v_inds,], args)
      })

      # weight the results by sample weights (that are all 1 unless p_clust is used)
      p_sub <- list(kl = weighted.mean(unlist(res['kl',]), p_full$cluster_w),
                    b = do.call(cbind, res['b',]))
      if('dis' %in% rownames(res)) p_sub$dis <- unlist(res['dis',])
      p_sub
    }
  }
}

# calculate everything that needs to be saved from the submodel
.summary_stats <- function(d_test, chosen, p, args) {
  mu_temp <- args$family_kl$linkinv(d_test$x[,chosen]%*%p$b + d_test$offset)
  if(is.null(p$dis)) {
    dis_temp <- NA
  } else {
    dis_temp <- matrix(rep(p$dis, each = length(d_test$y)), ncol = NCOL(mu_temp))
  }

  list(mu = rowMeans(mu_temp),
       lppd = apply(args$family_kl$ll_fun(
         mu_temp, dis_temp, d_test$y, d_test$weights), 1, log_mean_exp))
}

# get bootstrapped 95%-intervals for the estimates
.bootstrap_stats <- function(mu_all, lppd_all, nv, d_test, family_kl, b_weights, data) {

  # calculate the bootstrap samples
  res_boot <- mapply(function(mu, lppd, nv, d_test, family_kl, b_weights) {
    c(.bootstrap_helper(mu, lppd, d_test, family_kl, b_weights), nv = nv)
  }, mu_all, lppd_all, nv, MoreArgs = list(d_test, family_kl, b_weights), SIMPLIFY = F)

  # get the quantiles from the bootstrap samples
  res_quantiles <- lapply(res_boot, function(res_boot, res_full, data) {
    mapply(function(size, name, stat, boot_stat, stat_full, boot_stat_full, nv, data) {
      qs <- quantile(boot_stat, c(0.025, 0.975))
      qs_delta <- quantile(boot_stat - boot_stat_full, c(0.025, 0.975))
      data.frame(data = data, size = size, delta = c(F, T),
                 summary = rep(name, 2), value = c(stat, stat - stat_full),
                 lq = c(qs[1], qs_delta[1]), uq = c(qs[2], qs_delta[2]))
    }, res_boot$nv, names(res_boot$stats), res_boot$stats, res_boot$boot_stats,
    res_full$stats, res_full$boot_stats, MoreArgs = list(nv, data), SIMPLIFY = F)
  }, res_boot[[length(res_boot)]], data)

  # rbind the elements into one data.frame
  do.call(rbind, c(unlist(res_quantiles, recursive = F), make.row.names = F))
}

.bootstrap_helper <- function(mu, lppd, d_test, family_kl, b_weights) {

  y <- d_test$y
  weights <- d_test$weights
  n <- length(y)
  arr <- rbind(mlpd = lppd, mse = (y-mu)^2)
  # stats are the actual values, boot_stats are the bootstrap samples
  stats <- as.list(rowMeans(arr))
  boot_stats <- lapply(seq_len(length(stats)),
                       function(ind, tc) tc[ind, ], tcrossprod(arr, b_weights))
  names(boot_stats) <- names(stats)

  # McFadden's pseudo r2
  lppd_null <- -2*family_kl$dev.resids(y, sum(weights * y)/sum(weights), weights)
  stats$r2 <- 1 - sum(lppd)/sum(lppd_null)
  boot_stats$r2 <- drop(1 - (b_weights%*%lppd)/(b_weights%*%lppd_null))

  if(family_kl$family == 'binomial') {
    stats$pctcorr <- mean(round(weights*mu) == weights*y)
    boot_stats$pctcorr <- drop(b_weights%*%(round(weights*mu) == weights*y))
  }

  list(stats = stats, boot_stats = boot_stats)
}

.gen_bootstrap_ws <- function(n_obs, n_boot) {
  b_weights <- matrix(rexp(n_obs * n_boot, 1), ncol = n_obs)
  b_weights/rowSums(b_weights)
}