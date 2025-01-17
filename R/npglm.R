


#' npglm
#' Nonparametric robust generalized linear models for interpretable causal inference.
#' Supports flexible working-model-based estimation of the  conditional average treatment effect (CATE and CATT), treatment-specific mean (TSM), conditional odds ratio (OR), and conditional relative risk (RR),
#' ... where a user-specified working parametric model for the estimand is viewed as an approximation of the true estimand and nonparametrically correct inference is given for these approximations.
#' The estimates and inference obtained by `npglm` are robust and nonparametrically correct, which comes at a small cost in confidence interval width relative to `spglm`.
#' Highly Adaptive Lasso (HAL) (see \code{\link[hal9001]{fit_hal}}), a flexible and adaptive spline regression estimator, is recommended for medium-small to large sample sizes.
#' @param formula A R formula object specifying the parametric form of CATE, OR, or RR (depending on method).
#' @param data A data.frame or matrix containing the numeric values corresponding with the nodes \code{W}, \code{A} and \code{Y}.
#' Can also be a \code{npglm} fit/output object in which case machine-learning fits are reused (see vignette).
#' @param W A character vector of covariates contained in \code{data}
#' @param A A character name for the treatment assignment variable contained in \code{data}
#' @param Y A character name for the outcome variable contained in \code{data} (outcome can be continuous, nonnegative or binary depending on method)
#' @param learning_method Machine-learning method to use. This is overrided if argument \code{sl3_Learner} is provided. Options are:
#' "SuperLearner": A stacked ensemble of all of the below that utilizes cross-validation to adaptivelly choose the best learner.
#' "HAL": Adaptive robust automatic machine-learning using the Highly Adaptive Lasso \code{hal9001}
#' "glm": Fit nuisances with parametric model.
#' "glmnet": Learn using lasso with glmnet.
#' "gam": Learn using generalized additive models with mgcv.
#' "mars": Multivariate adaptive regression splines with \code{earth}.
#' "ranger": Robust random-forests with the package \code{Ranger}
#' "xgboost": Learn using a default cross-validation tuned xgboost library with max_depths 3 to 7.
#' Note speed can vary  depending on learner choice!
#' @param estimand Estimand/parameter to estimate. Choices are:
#' `CATE`: Estimate the best parametric approximation of the conditional average treatment effect with \code{\link[tmle3]{Param_npCATE}} using the parametric model \code{formula}.
#' Specifically, this estimand is the least-squares projection of the true CATE onto the parametric working model.
#' `CATT`: Estimate the best parametric approximation of the conditional average treatment effect among the treated with \code{\link[tmle3]{Param_npCATE}} using the parametric model \code{formula}.
#' Specifically, this estimand is the least-squares projection of the true CATE onto the parametric working model using only the observations with `A=1` (among the treated).
#' `TSM`: Estimate the best parametric approximation of the conditional treatment-specific mean `E[Y|A=a,W]` for `a` in \code{levels_A}.
#' Specifically, this estimand is the least-squares projection of the true TSM onto the parametric working model.
#' `OR`: Estimate the best parametric approximation of the conditional odds ratio with \code{\link[tmle3]{Param_npOR}} using the parametric model \code{formula}.
#' Specifically, this estimand is the log-likelihood projection of the true conditional odds ratio onto the partially-linear logistic regression model with the true `E[Y|A=0,W]` used as offset.
#' `RR`: Projection of the true conditional relative risk onto a exponential working-model using log-linear/poisson regression.
#' @param treatment_level A value/level of \code{A} that represents the treatment arm value. By default, the maximum level.
#' The estimands are defined relative to \code{treatment_level} and \code{control_level}.
#' This is mainly useful when \code{A} is categorical.
#' @param control_level A value/level of \code{A} that represents the control arm value. By default, the maximum level.
#' The estimands are defined relative to \code{treatment_level} and \code{control_level}.
#' This is mainly useful when \code{A} is categorical.
#' @param cross_fit Whether to cross-fit the initial estimator. This is always set to FALSE if argument \code{sl3_Learner_A} and/or \code{sl3_Learner_Y} is provided.
#' learning_method = `SuperLearner` is always cross-fitted (default).
#'  learning_method = `xgboost` and `ranger` are always cross-fitted regardless of the value of \code{cross_fit}
#'  All other learning_methods are only cross-fitted if `cross_fit=TRUE`.
#'  Note, it is not necessary to cross-fit glm, glmnet, gam or mars as long as the dimension of W is not too high.
#'  In smaller samples and lower dimensions, it may in fact hurt to cross-fit.
#' @param sl3_Learner_A A \code{sl3} Learner object to use to estimate nuisance function P(A=1|W) with machine-learning.
#' Note, \code{cross_fit} is automatically set to FALSE if this argument is provided.
#' If you wish to cross-fit the learner \code{sl3_Learner_A} then do: sl3_Learner_A <- Lrnr_cv$new(sl3_Learner_A).
#' Cross-fitting is recommended for all tree-based algorithms like random-forests and gradient-boosting.
#' @param sl3_Learner_Y A \code{sl3} Learner object to use to nonparametrically [Y|A,W] with machine-learning.
#' Note, \code{cross_fit} is automatically set to FALSE if this argument is provided.
#' Cross-fitting is recommended for all tree-based algorithms like random-forests and gradient-boosting.
#' @param formula_Y Only used if `learning_method %in% c("glm", "earth", "glmnet")`. A R \code{formula} object that specifies the design matrix to be passed to the Learner specified by learning_method: "glm", "earth", "glmnet".
#' By default, `formula_Y = . + A*.` so that additive learners still model treatment interactions.
#' @param formula_HAL_Y A HAL formula string to be passed to \code{\link[hal9001]{fit_hal}}). See the `formula` argument of \code{\link[hal9001]{fit_hal}}) for syntax and example use.
#' @param HAL_args_Y A list of parameters for the semiparametric Highly Adaptive Lasso estimator for E[Y|A,W].
#' Should contain the parameters:
#' 1. `smoothness_orders`: Smoothness order for HAL estimator of E[Y|A,W] (see \code{\link[hal9001]{fit_hal}})
#' smoothness_order_Y0W = 1 is piece-wise linear. smoothness_order_Y0W = 0 is piece-wise constant.
#' 2. `max_degree`: Max interaction degree for HAL estimator of E[Y|A,W] (see \code{\link[hal9001]{fit_hal}})
#' 3. `num_knots`: A vector of the number of knots by interaction degree for HAL estimator of E[Y|A=0,W] (see \code{\link[hal9001]{fit_hal}}). Used to generate spline basis functions.
#' @param HAL_fit_control See the argument `fit_control` of (see \code{\link[hal9001]{fit_hal}}).
#' @param delta_epsilon Step size of iterative targeted maximum likelihood estimator. `delta_epsilon = 1 ` leads to large step sizes and fast convergence. `delta_epsilon = 0.01` leads to slower convergence but possibly better performance.
#' Useful to set to a large value in high dimensions.
#' @param verbose Passed to \code{tmle3} routines. Prints additional information if TRUE.
#' @param ... Not used
#'
#'
#' @export
npglm <- function(formula, data, W, A, Y, estimand = c("CATE", "CATT", "TSM", "OR", "RR"), learning_method = c("HAL", "SuperLearner", "glm", "glmnet", "gam", "mars", "ranger", "xgboost"), treatment_level = max(data[[A]]), control_level = min(data[[A]]), cross_fit = FALSE, sl3_Learner_A = NULL, sl3_Learner_Y = NULL, formula_Y = ~ .^2, formula_HAL_Y = NULL, HAL_args_Y = list(smoothness_orders = 1, max_degree = 2, num_knots = c(15, 10, 1)), HAL_fit_control = list(parallel = F), delta_epsilon = 0.025, verbose = FALSE, ...) {
  if (inherits(data, "npglm") || inherits(data, "msmglm")) {
    if (verbose) {
      print("Reusing previous fit...")
    }
    old_output <- data
    data <- old_output$arg$data
    args <- old_output$args
    A <- old_output$args$A
    args$formula <- formula
    tmle3_input <- old_output$tmle3_input

    if (estimand == "TSM") {
      treatment_level <- union(treatment_level, control_level)
      levels_A <- treatment_level
    }
    tmle3_fit <- refit_glm(old_output, formula, estimand = estimand, treatment_level = treatment_level, control_level = control_level, verbose = verbose)
  } else {
    if (is.null(formula_HAL_Y)) {
      formula_HAL_Y <- paste0("~ . + h(.,", A, ")")
    }
    if (length(unique(data[[A]])) > 2) {
      formula_HAL_Y <- paste0("~ . + h(.,.)")
    }
    check_arguments(formula, data, W, A, Y)
    args <- list(formula = formula, data = data, W = W, A = A, Y = Y)


    weights <- NULL

    estimand <- match.arg(estimand)
    learning_method <- match.arg(learning_method)

    if (!is.null(weights)) {
      data$weights <- weights
    } else {
      data$weights <- 1
    }

    superlearner_default <- make_learner(Pipeline, Lrnr_cv$new(Stack$new(
      Lrnr_glmnet$new(), Lrnr_glm$new(), Lrnr_gam$new(), Lrnr_earth$new(),
      Lrnr_ranger$new(), Lrnr_xgboost$new(verbose = 0, max_depth = 3), Lrnr_xgboost$new(verbose = 0, max_depth = 4), Lrnr_xgboost$new(verbose = 0, max_depth = 5)
    ), full_fit = T), Lrnr_cv_selector$new(loss_squared_error))

    learner_list_A <- list(
      HAL = Lrnr_hal9001$new(max_degree = 2, smoothness_orders = 1, num_knots = c(10, 3)), SuperLearner = superlearner_default, glmnet = Lrnr_glmnet$new(), glm = Lrnr_glm$new(), gam = Lrnr_gam$new(), mars = Lrnr_earth$new(),
      ranger = Lrnr_cv$new(Lrnr_ranger$new(), full_fit = TRUE), xgboost = make_learner(Pipeline, Lrnr_cv$new(Stack$new(Lrnr_xgboost$new(verbose = 0, max_depth = 3, eval_metric = "logloss"), Lrnr_xgboost$new(verbose = 0, max_depth = 4, eval_metric = "logloss"), Lrnr_xgboost$new(verbose = 0, max_depth = 5, eval_metric = "logloss")), full_fit = TRUE), Lrnr_cv_selector$new(loss_loglik_binomial))
    )

    if (is.null(sl3_Learner_A)) {
      sl3_Learner_A <- learner_list_A[[learning_method]]
      if (learning_method %in% c("glm", "glmnet", "mars") && cross_fit) {
        sl3_Learner_A <- Lrnr_cv$new(sl3_Learner_A, full_fit = TRUE)
      }
    }
    binary <- all(Y %in% c(0, 1))
    if (is.null(sl3_Learner_Y)) {
      if (learning_method == "HAL") {
        wrap_in_Lrnr_glm_sp <- FALSE
        # Allow for formula_HAL
        sl3_Learner_Y <- Lrnr_hal9001$new(
          formula_HAL = formula_HAL_Y, family = family_list[[estimand]],
          smoothness_orders = HAL_args_Y$smoothness_orders,
          max_degree = HAL_args_Y$max_degree,
          num_knots = HAL_args_Y$num_knots, fit_control = HAL_fit_control
        )
      } else if (estimand == "RR" && !binary) {
        superlearner_RR <- make_learner(Pipeline, Lrnr_cv$new(list(
          Lrnr_glmnet$new(family = "poisson", formula = formula_Y), Lrnr_glm$new(family = poisson(), formula = formula_Y), Lrnr_gam$new(family = poisson()),
          Lrnr_xgboost$new(verbose = 0, max_depth = 3, objective = "count:poisson"), Lrnr_xgboost$new(verbose = 0, max_depth = 4, objective = "count:poisson"), Lrnr_xgboost$new(verbose = 0, max_depth = 5, objective = "count:poisson")
        ), full_fit = TRUE), Lrnr_cv_selector$new(loss_squared_error))

        learner_list_Y0W_RR <- list(
          SuperLearner = superlearner_RR, glmnet = Lrnr_glmnet$new(formula = formula_Y, family = "poisson"), glm = Lrnr_glm$new(formula = formula_Y, family = poisson()), gam = Lrnr_gam$new(family = poisson()),
          xgboost = make_learner(Pipeline, Lrnr_cv$new(Stack$new(Lrnr_xgboost$new(verbose = 0, max_depth = 3, objective = "count:poisson", eval_metric = "error"), Lrnr_xgboost$new(verbose = 0, max_depth = 4, objective = "count:poisson", eval_metric = "error"), Lrnr_xgboost$new(verbose = 0, max_depth = 5, objective = "count:poisson", eval_metric = "error")), full_fit = TRUE), Lrnr_cv_selector$new(loss_squared_error))
        )
        sl3_Learner_Y <- learner_list_Y0W_RR[[learning_method]]
      } else {
        superlearner_default <- make_learner(Pipeline, Lrnr_cv$new(list(
          Lrnr_glmnet$new(formula = formula_Y), Lrnr_glm$new(formula = formula_Y), Lrnr_gam$new(), Lrnr_earth$new(formula = formula_Y),
          Lrnr_ranger$new(), Lrnr_xgboost$new(verbose = 0, max_depth = 3), Lrnr_xgboost$new(verbose = 0, max_depth = 4), Lrnr_xgboost$new(verbose = 0, verbose = 0, max_depth = 5)
        ), full_fit = TRUE), Lrnr_cv_selector$new(loss_squared_error))
        learner_list_Y <- list(
          SuperLearner = superlearner_default, glmnet = Lrnr_glmnet$new(formula = formula_Y), glm = Lrnr_glm$new(formula = formula_Y), gam = Lrnr_gam$new(), mars = Lrnr_earth$new(formula = formula_Y),
          ranger = Lrnr_cv$new(Lrnr_ranger$new(), full_fit = TRUE), xgboost = make_learner(Pipeline, Lrnr_cv$new(Stack$new(Lrnr_xgboost$new(verbose = 0, verbose = 0, max_depth = 3), Lrnr_xgboost$new(verbose = 0, verbose = 0, max_depth = 4), Lrnr_xgboost$new(verbose = 0, max_depth = 5)), full_fit = TRUE), Lrnr_cv_selector$new(loss_squared_error))
        )
        sl3_Learner_Y <- learner_list_Y[[learning_method]]
      }
      if (learning_method %in% c("glm", "glmnet", "mars") && cross_fit) {
        sl3_Learner_Y <- Lrnr_cv$new(sl3_Learner_Y, full_fit = TRUE)
      }
    }
    if (length(unique(data[[A]])) > 2) {
      sl3_Learner_A <- Lrnr_pooled_hazards$new(sl3_Learner_A)
    }
    if (estimand == "TSM") {
      treatment_level <- union(treatment_level, control_level)
      levels_A <- treatment_level
    } else {
      levels_A <- NULL
    }

    tmle_spec_np <- tmle3_Spec_npCausalGLM$new(formula = formula, estimand = estimand, delta_epsilon = delta_epsilon, verbose = verbose, treatment_level = treatment_level, control_level = control_level)
    learner_list <- list(A = sl3_Learner_A, Y = sl3_Learner_Y)
    node_list <- list(W = W, A = A, Y = Y)

    tmle3_input <- list(tmle_spec_np = tmle_spec_np, data = data, node_list = node_list, learner_list = learner_list, delta_epsilon = delta_epsilon, levels_A = levels_A, treatment_level = treatment_level, control_level = control_level)
    tmle3_fit <- suppressMessages(suppressWarnings(tmle3(tmle_spec_np, data, node_list, learner_list)))
  }
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
  Zscore <- abs( coefs$tmle_est / coefs$se)
  pvalue <- signif(2 * (1 - pnorm(Zscore)), 5)
  coefs$Z_score <- Zscore
  coefs$p_value <- pvalue

  if (estimand == "TSM") {
    anum <- length(levels_A)

    numform <- nrow(coefs) / anum

    coefs_list <- split(coefs, rep(1:anum, each = numform))

    output_list <- list()
    for (i in 1:anum) {
      coefs <- coefs_list[[i]]

      tmp <- coefs$param
      formula_fit <- paste0(coefs$type[1], "(W) = ", paste0(signif(coefs$tmle_est, 3), " * ", tmp, collapse = " + "))

      output <- list(estimand = estimand, formula_fit = formula_fit, coefs = coefs, tmle3_fit = tmle3_fit, tmle3_input = tmle3_input, args = args)
      class(output) <- c("npglm", "causalglm")
      output_list[[gsub(":.*", "", tmp[1])]] <- output
    }
    output_list$estimand <- "TSM"
    output_list$levels_A <- levels_A
    return(output_list)
  }

  tmp <- coefs$param
  if (estimand %in% c("OR", "RR")) {
    formula_fit <- paste0("log ", coefs$type[1], "(W) = ", paste0(signif(coefs$tmle_est, 3), " * ", tmp, collapse = " + "))
  } else {
    formula_fit <- paste0(coefs$type[1], "(W) = ", paste0(signif(coefs$tmle_est, 3), " * ", tmp, collapse = " + "))
  }

  output <- list(estimand = estimand, formula_fit = formula_fit, coefs = coefs, tmle3_fit = tmle3_fit, tmle3_input = tmle3_input, args = args)
  class(output) <- c("npglm", "causalglm")
  return(output)
}
