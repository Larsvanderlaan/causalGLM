
#' spglm
#' Semiparametric generalized linear models for causal inference
#' Supports flexible semiparametric conditional average treatment effect (CATE), conditional odds ratio (OR), and conditional relative risk (RR) estimation
#' Highly Adaptive Lasso (HAL) (see \code{\link[hal9001]{fit_hal}}), a flexible and adaptive spline regression estimator, is recommended for medium-small to large sample sizes.
#' @param formula A R formula object specifying the parametric form of CATE, OR, or RR (depending on method).
#' @param data A data.frame or matrix containing the numeric values corresponding with the nodes \code{W}, \code{A} and \code{Y}.
#' Or a \code{spglm} fit object in which case previous ML fits are reused in computation.
#' Note, only pass in a previous fit object for the same estimand and for subformulas. (See vignette)
#' @param W A character vector of covariates contained in \code{data}
#' @param A A character name for the treatment assignment variable contained in \code{data}
#' @param Y A character name for the outcome variable contained in \code{data} (outcome can be continuous, nonnegative or binary depending on method)
#' @param learning_method Machine-learning method to use. This is overrided if argument \code{sl3_Learner} is provided. Options are:
#' "SuperLearner: A stacked ensemble of all of the below that utilizes cross-validation to adaptivelly choose the best learner.
#' "HAL": Adaptive robust automatic machine-learning using the Highly Adaptive Lasso \code{hal9001}. See arguments\code{HAL_args_Y0W}.
#' "glm": Fit nuisances with parametric model.
#' "glmnet": Learn using lasso with glmnet.
#' "gam": Learn using generalized additive models with mgcv.
#' "mars": Multivariate adaptive regression splines with \code{earth}.
#' "ranger": Robust random-forests with the package \code{Ranger}
#' "xgboost": Learn using a default cross-validation tuned xgboost library with max_depths 3 to 7.
#' Note speed can vary significantly depending on learner choice!
#' @param estimand Estimand/parameter to estimate. Choices are:
#' `CATE`: Estimate conditional average treatment effect with \code{\link[tmle3]{Param_spCATE}} assuming it satisfies parametric model \code{formula}.
#' `OR`: Estimate conditional odds ratio with \code{\link[tmle3]{Param_spOR}} assuming it satisfies parametric model \code{formula}.
#' `RR`: Estimate conditional relative risk with \code{\link[tmle3]{Param_spRR}} assuming it satisfies parametric model \code{formula}.
#' @param append_interaction_matrix Default: TRUE. This argument is passed to \code{Lrnr_glm_semiparametric}.
#' This is a boolean for whether to estimate the conditional mean/regression of Y by combining observations with A=0,A=1 (`TRUE`),
#' or to first E[Y|A=0,W] nonparametrically with \code{sl3_Learner_Y} or \code{learning_method} and then learning the parametric component with offsetted parametric regression (`FALSE`).
#' If `TRUE` the design matrix passed to the regression algorithm/learner for `Y` is `cbind(W,A*V)` where `V  = model.matrix(formula, as.data.frame(W))` is the design matrix specified by the argument \code{formula}.
#' Therefore, it may not be necessary to use learners that model (treatment) interactions when this argument is TRUE.
#' The resulting estimators are projected onto the semiparametric model, ensuring compatibility with the statistical model assumptions.
#' In high dimensions, pool_A_when_training = FALSE may be preferred to prevent dilution of the treatment interactions in the fitting.
#' @param cross_fit Whether to cross-fit the initial estimator. This is always set to FALSE if argument \code{sl3_Learner} is provided.
#' learning_method = `SuperLearner` is always cross-fitted (default).
#'  learning_method = `xgboost` and `ranger` are always cross-fitted regardless of the value of \code{cross_fit}
#'  All other learning_methods are only cross-fitted if `cross_fit=TRUE`.
#'  Note, it is not necessary to cross-fit glm, glmnet, gam or mars as long as the dimension of W is not too high.
#'  In smaller samples and lower dimensions, it may fact hurt to cross-fit.
#' @param sl3_Learner_A A \code{sl3} Learner object to use to estimate nuisance function P(A=1|W) with machine-learning.
#' Note, \code{cross_fit} is automatically set to FALSE if this argument is provided.
#' If you wish to cross-fit the learner \code{sl3_Learner} then do: sl3_Learner <- Lrnr_cv$new(sl3_Learner).
#' Cross-fitting is recommended for all tree-based algorithms like random-forests and gradient-boosting.
#' @param sl3_Learner_Y A \code{sl3} Learner object to use to estimate nuisance functions [Y|A=1,W] and E[Y|A=0,W] (depending on method) with machine-learning.
#' Note, \code{cross_fit} is automatically set to FALSE if this argument is provided.
#' Keep in mind the value of the argument \code{pool_A_when_training}. If FALSE  then E[Y|A=0,W] is estimated by itself.
#' Therefore, it may not be needed to add interactions, since treatment interactions are automatic by stratification.
#' If TRUE, the design matrix passed to the pooled learner contains A*V where V is the design matrix obtained from \code{formula}.
#' For some learners, it may also be unnecessary to include interactions in this case.
#' #' If you wish to cross-fit the learner \code{sl3_Learner} then do: sl3_Learner <- Lrnr_cv$new(sl3_Learner).
#' Cross-fitting is recommended for all tree-based algorithms like random-forests and gradient-boosting.
#' @param wrap_in_Lrnr_glm_sp Mostly for internal use (should be TRUE usually). Whether \code{sl3_Learner_Y} should be wrapped in a \code{Lrnr_glm_semiparametric} object.
#' @param HAL_args_Y0W A list of parameters for the semiparametric Highly Adaptive Lasso estimator for E[Y|A=0,W].
#' Possible parameters are:
#' 1. `smoothness_orders`: Smoothness order for HAL estimator of E[Y|A=0,W] (see \code{\link[hal9001]{fit_hal}})
#' smoothness_order_Y0W = 1 is piece-wise linear. smoothness_order_Y0W = 0 is piece-wise constant.
#' 2. `max_degree`: Max interaction degree for HAL estimator of E[Y|A=0,W] (see \code{\link[hal9001]{fit_hal}})
#' 3. `num_knots`: A vector of the number of knots by interaction degree for HAL estimator of E[Y|A=0,W] (see \code{\link[hal9001]{fit_hal}}). Used to generate spline basis functions.
#' @param HAL_fit_control See the argument `fit_control` of (see \code{\link[hal9001]{fit_hal}}).
#' @param sl3_Learner_var_Y A \code{sl3}-Learner for the conditional variance of `Y`. Only used if `estimand = "CATE"` and by default is estimated using Poisson-link LASSO regression with `Lrnr_glmnet`.
#' If conditional variance is constant, set `sl3_Learner_var_Y = Lrnr_mean$new()`.
#' @param delta_epsilon Step size of iterative targeted maximum likelihood estimator. `delta_epsilon = 1 ` leads to large step sizes and fast convergence. `delta_epsilon = 0.005` leads to slower convergence but possibly better performance.
#' Useful to set to a large value in high dimensions.
#' @param ... Not used
#' @export
spglm <- function(formula, data, W, A, Y, estimand = c("CATE", "OR", "RR"), learning_method = c("HAL", "SuperLearner", "glm", "glmnet", "gam", "mars", "ranger", "xgboost"), append_interaction_matrix = TRUE, cross_fit = FALSE, sl3_Learner_A = NULL, sl3_Learner_Y = NULL, wrap_in_Lrnr_glm_sp = TRUE, HAL_args_Y0W = list(smoothness_orders = 1, max_degree = 1, num_knots = c(10, 5, 1)), HAL_fit_control = list(parallel = F), sl3_Learner_var_Y = Lrnr_glmnet$new(family = "poisson"), delta_epsilon = 0.1, verbose = FALSE, warn = TRUE, ...) {
  weights <- NULL
  if (inherits(data, "spglm")) {
    formula_orig <- data$args$formula
    term_orig <- terms(formula_orig, data = data$args$data)
    term <- terms(formula, data = data$args$data)
    all_terms_orig <- attr(term_orig, "term.labels")
    all_terms <- attr(term, "term.labels")
    check1 <- all(all_terms %in% all_terms_orig)
    check2 <- attr(term_orig, "intercept") == attr(term, "intercept")
    if (!(check1 && check2)) {
      if (warn) {
        warning("Terms of new formula could not be confirmed as subsets of original formula. Make sure this formula is truly a subformula or else the results may be unreliable..")
      }
    }
    if (data$estimand != estimand) {
      stop("Reusing fit is not possible for different estimands.")
    }
    args <- data$args
    args$formula <- formula

    tmle3_input <- data$tmle3_input
    likelihood <- data$tmle3_fit$likelihood$initial_likelihood
    data <- tmle3_input$data
    node_list <- tmle3_input$node_list
    delta_epsilon <- tmle3_input$delta_epsilon
    learner_list <- NULL
    tmle_spec_sp <- tmle3_Spec_spCausalGLM$new(formula = formula, estimand = estimand, append_interaction_matrix = NULL, wrap_in_Lrnr_glm_sp = FALSE, binary_outcome = F, delta_epsilon = delta_epsilon, verbose = verbose, likelihood_override = likelihood)
  } else {
    check_arguments(formula, data, W, A, Y)
    if (length(unique(data[[A]])) > 2) {
      stop("`spglm` does not support categorical or continuous treatments. Use `npglm` and `contglm` instead.")
    }
    args <- list(formula = formula, data = data, W = W, A = A, Y = Y)
    estimand <- match.arg(estimand)
    learning_method <- match.arg(learning_method)
    data <- as.data.table(data)
    if (all(data[[Y]] %in% c(0, 1)) && estimand == "CATE") {
      append_interaction_matrix <- FALSE
      binary_outcome <- TRUE
    } else {
      binary_outcome <- FALSE
    }
    if (!is.null(weights)) {
      data$weights <- weights
    } else {
      data$weights <- 1
    }



    superlearner_default <- make_learner(Pipeline, Lrnr_cv$new(Stack$new(
      Lrnr_glmnet$new(), Lrnr_glm$new(), Lrnr_gam$new(), Lrnr_earth$new(),
      Lrnr_ranger$new(), Lrnr_xgboost$new(verbose = 0, max_depth = 3), Lrnr_xgboost$new(verbose = 0, max_depth = 4), Lrnr_xgboost$new(verbose = 0, max_depth = 5)
    ), full_fit = T), Lrnr_cv_selector$new(loss_squared_error))
    superlearner_RR <- make_learner(Pipeline, Lrnr_cv$new(list(
      Lrnr_glmnet$new(family = "poisson"), Lrnr_glm$new(family = poisson()), Lrnr_gam$new(family = poisson()),
      Lrnr_xgboost$new(verbose = 0, max_depth = 3, objective = "count:poisson"), Lrnr_xgboost$new(verbose = 0, max_depth = 4, objective = "count:poisson"), Lrnr_xgboost$new(verbose = 0, max_depth = 5, objective = "count:poisson")
    ), full_fit = TRUE), Lrnr_cv_selector$new(loss_squared_error))

    learner_list_A <- list(
      HAL = Lrnr_hal9001$new(max_degree = 2, smoothness_orders = 1, num_knots = c(10, 3)), SuperLearner = superlearner_default, glmnet = Lrnr_glmnet$new(), glm = Lrnr_glm$new(), gam = Lrnr_gam$new(), mars = Lrnr_earth$new(),
      ranger = Lrnr_cv$new(Lrnr_ranger$new(), full_fit = TRUE), xgboost = make_learner(Pipeline, Lrnr_cv$new(Stack$new(Lrnr_xgboost$new(verbose = 0, max_depth = 3, eval_metric = "logloss"), Lrnr_xgboost$new(verbose = 0, max_depth = 4, eval_metric = "logloss"), Lrnr_xgboost$new(verbose = 0, max_depth = 5, eval_metric = "logloss")), full_fit = TRUE), Lrnr_cv_selector$new(loss_loglik_binomial))
    )

    learner_list_Y0W <- list(
      SuperLearner = superlearner_default, glmnet = Lrnr_glmnet$new(), glm = Lrnr_glm$new(), gam = Lrnr_gam$new(), mars = Lrnr_earth$new(),
      ranger = Lrnr_cv$new(Lrnr_ranger$new(), full_fit = TRUE), xgboost = make_learner(Pipeline, Lrnr_cv$new(Stack$new(Lrnr_xgboost$new(verbose = 0, max_depth = 3), Lrnr_xgboost$new(verbose = 0, max_depth = 4), Lrnr_xgboost$new(verbose = 0, max_depth = 5)), full_fit = TRUE), Lrnr_cv_selector$new(loss_squared_error))
    )

    learner_list_Y0W_RR <- list(
      SuperLearner = superlearner_RR, glmnet = Lrnr_glmnet$new(family = "poisson"), glm = Lrnr_glm$new(family = poisson()), gam = Lrnr_gam$new(family = poisson()),
      xgboost = make_learner(Pipeline, Lrnr_cv$new(Stack$new(Lrnr_xgboost$new(verbose = 0, max_depth = 3, objective = "count:poisson", eval_metric = "error"), Lrnr_xgboost$new(verbose = 0, max_depth = 4, objective = "count:poisson", eval_metric = "error"), Lrnr_xgboost$new(verbose = 0, max_depth = 5, objective = "count:poisson", eval_metric = "error")), full_fit = TRUE), Lrnr_cv_selector$new(loss_squared_error))
    )


    if (is.null(sl3_Learner_A)) {
      sl3_Learner_A <- learner_list_A[[learning_method]]
      if (learning_method %in% c("glm", "glmnet", "mars") && cross_fit) {
        sl3_Learner_A <- Lrnr_cv$new(sl3_Learner_A)
      }
    }
    if (is.null(sl3_Learner_Y)) {
      if (learning_method == "HAL") {
        wrap_in_Lrnr_glm_sp <- FALSE
        sl3_Learner_Y <- Lrnr_hal9001_semiparametric$new(
          formula = formula, family = family_list[[estimand]],
          interaction_variable = A,
          smoothness_orders = HAL_args_Y0W$smoothness_orders,
          max_degree = HAL_args_Y0W$max_degree,
          num_knots = HAL_args_Y0W$num_knots, fit_control = HAL_fit_control
        )
      } else if (estimand == "RR") {
        sl3_Learner_Y <- learner_list_Y0W_RR[[learning_method]]
      } else {
        sl3_Learner_Y <- learner_list_Y0W[[learning_method]]
      }
      if (learning_method %in% c("glm", "glmnet", "mars") && cross_fit) {
        sl3_Learner_Y <- Lrnr_cv$new(sl3_Learner_Y)
      }
    }

    tmle_spec_sp <- tmle3_Spec_spCausalGLM$new(formula = formula, estimand = estimand, append_interaction_matrix = append_interaction_matrix, wrap_in_Lrnr_glm_sp = wrap_in_Lrnr_glm_sp, binary_outcome = F, delta_epsilon = delta_epsilon, verbose = verbose)
    learner_list <- list(A = sl3_Learner_A, Y = sl3_Learner_Y)
    if (estimand == "CATE") {
      learner_list$var_Y <- sl3_Learner_var_Y
    }
    node_list <- list(W = W, A = A, Y = Y)
    tmle3_input <- list(tmle_spec_sp = tmle_spec_sp, data = data, node_list = node_list, learner_list = learner_list, append_interaction_matrix = append_interaction_matrix, binary_outcome = binary_outcome, delta_epsilon = delta_epsilon)
  }

  tmle3_fit <- suppressMessages(suppressWarnings(tmle3(tmle_spec_sp, data, node_list, learner_list)))



  coefs <- tmle3_fit$summary
  coefs <- coefs[, -3]
  if (estimand %in% c("CATE", "CATT", "TSM")) {
    coefs <- coefs[, 1:6]
  } else {
    cur_names <- colnames(coefs)
    cur_names <- gsub("transformed", "exp", cur_names)
    colnames(coefs) <- cur_names
  }
  n <- nrow(data)
  Zscore <- abs(coefs$tmle_est / coefs$se)
  pvalue <- signif(2 * (1 - pnorm(Zscore)), 5)
  coefs$Z_score <- Zscore
  coefs$p_value <- pvalue

  tmp <- coefs$param
  if (estimand %in% c("OR", "RR")) {
    formula_fit <- paste0("log ", coefs$type[1], "(W) = ", paste0(signif(coefs$tmle_est, 3), " * ", tmp, collapse = " + "))
  } else {
    formula_fit <- paste0(coefs$type[1], "(W) = ", paste0(signif(coefs$tmle_est, 3), " * ", tmp, collapse = " + "))
  }

  output <- list(estimand = estimand, formula_fit = formula_fit, coefs = coefs, tmle3_fit = tmle3_fit, tmle3_input = tmle3_input, args = args)
  class(output) <- c("spglm", "causalglm")
  return(output)
}
