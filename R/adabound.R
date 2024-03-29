#' @title Adabound optimizer
#'
#' @name optim_adabound
#'
#' @author Rolf Simoes, \email{rolf.simoes@@inpe.br}
#' @author Felipe Souza, \email{lipecaso@@gmail.com}
#' @author Alber Sanchez, \email{alber.ipia@@inpe.br}
#' @author Gilberto Camara, \email{gilberto.camara@@inpe.br}
#'
#' @description
#' R implementation of the AdaBound optimizer proposed
#' by Luo et al.(2019). We used the implementation available at
#' https://github.com/jettify/pytorch-optimizer/blob/master/torch_optimizer/yogi.py.
#' Thanks to Nikolay Novik for providing the pytorch code.
#'
#' The original implementation is licensed using the Apache-2.0 software license.
#' This implementation is also licensed using Apache-2.0 license.
#'
#' AdaBound is a variant of the Adam stochastic optimizer which is
#' designed to be more robust to extreme learning rates.
#' Dynamic bounds are employed on learning rates,
#' where the lower and upper bound are initialized as zero and
#' infinity respectively, and they both smoothly converge to a
#' constant final step size. AdaBound can be regarded as an adaptive
#' method at the beginning of training, and thereafter it gradually and
#' smoothly transforms to SGD (or with momentum) as the time step increases.
#'
#' @references
#' Liangchen Luo, Yuanhao Xiong, Yan Liu, Xu Sun,
#' "Adaptive Gradient Methods with Dynamic Bound of Learning Rate",
#' International Conference on Learning Representations (ICLR), 2019.
#' https://arxiv.org/abs/1902.09843
#'
#' @param params       List of parameters to optimize.
#' @param lr           Learning rate (default: 1e-3)
#' @param betas        Coefficients computing running averages of gradient
#'                     and its square (default: (0.9, 0.999))
#' @param final_lr     Final (SGD) learning rate (default: 0.1)
#' @param gamma        Convergence speed of the bound functions
#'   (default: 1e-3)
#' @param eps          Term added to the denominator to improve numerical
#'   stability (default: 1e-8)
#' @param weight_decay Weight decay (L2 penalty) (default: 0)
#'
#' @returns
#' A torch optimizer object implementing the `step` method.
#' @examples
#' if (torch::torch_is_installed()) {

#' # function to demonstrate optimization
#' beale <- function(x, y) {
#'     log((1.5 - x + x * y)^2 + (2.25 - x - x * y^2)^2 + (2.625 - x + x * y^3)^2)
#'  }
#' # define optimizer
#' optim <- torchopt::optim_adabound
#' # define hyperparams
#' opt_hparams <- list(lr = 0.01)
#'
#' # starting point
#' x0 <- 3
#' y0 <- 3
#' # create tensor
#' x <- torch::torch_tensor(x0, requires_grad = TRUE)
#' y <- torch::torch_tensor(y0, requires_grad = TRUE)
#' # instantiate optimizer
#' optim <- do.call(optim, c(list(params = list(x, y)), opt_hparams))
#' # run optimizer
#' steps <- 400
#' x_steps <- numeric(steps)
#' y_steps <- numeric(steps)
#' for (i in seq_len(steps)) {
#'     x_steps[i] <- as.numeric(x)
#'     y_steps[i] <- as.numeric(y)
#'     optim$zero_grad()
#'     z <- beale(x, y)
#'     z$backward()
#'     optim$step()
#' }
#' print(paste0("starting value = ", beale(x0, y0)))
#' print(paste0("final value = ", beale(x_steps[steps], y_steps[steps])))
#' }
#' @export
optim_adabound <- torch::optimizer(
    "optim_adabound",
    initialize = function(params,
                          lr = 1e-3,
                          betas = c(0.9, 0.999),
                          final_lr = 0.1,
                          gamma = 1e-3,
                          eps = 1e-8,
                          weight_decay = 0) {
        if (lr <= 0.0)
            stop("Learning rate must be positive.", call. = FALSE)
        if (eps < 0.0)
            stop("eps must be non-negative.", call. = FALSE)
        if (betas[1] > 1.0 | betas[1] <= 0.0)
            stop("Invalid beta parameter.", call. = FALSE)
        if (betas[2] > 1.0 | betas[1] <= 0.0)
            stop("Invalid beta parameter.", call. = FALSE)
        if (final_lr < 0.0)
            stop("Learning rate must be positive.", call. = FALSE)
        if (gamma > 1.0 | gamma <= 0.0)
            stop("Invalid gamma parameter.", call. = FALSE)
        if (weight_decay < 0)
            stop("Invalid weight_decay value.", call. = FALSE)

        defaults = list(
            lr           = lr,
            betas        = betas,
            final_lr     = final_lr,
            gamma        = gamma,
            eps          = eps,
            weight_decay = weight_decay
        )

        self$base_lr <- lr
        super$initialize(params, defaults)
    },
    step = function(closure = NULL) {
        loop_fun <- function(group, param, g, p) {
            if (is.null(param$grad))
                next
            grad <- param$grad

            # State initialization
            if (length(state(param)) == 0) {
                state(param) <- list()
                state(param)[["step"]] <- 0
                # Exponential moving average of gradient values
                state(param)[["exp_avg"]] <- torch::torch_zeros_like(
                    param,
                    memory_format = torch::torch_preserve_format()
                )
                # Exponential moving average of squared gradient values
                state(param)[["exp_avg_sq"]] <- torch::torch_zeros_like(
                    param,
                    memory_format = torch::torch_preserve_format()
                )
            }
            exp_avg    <- state(param)[["exp_avg"]]
            exp_avg_sq <- state(param)[["exp_avg_sq"]]
            beta1      <- group[['betas']][[1]]
            beta2      <- group[['betas']][[2]]

            state(param)[["step"]] <- state(param)[["step"]] + 1

            if (group[['weight_decay']] != 0)
                grad <- grad$add(param, alpha = group[['weight_decay']])

            # Decay the first and second moment
            # running average coefficient
            exp_avg$mul_(beta1)$add_(grad, alpha = 1 - beta1)
            exp_avg_sq$mul_(beta2)$addcmul_(grad, grad, value = 1 - beta2)

            # bias correction
            bias_correction1 <- 1 - beta1^state(param)[['step']]
            bias_correction2 <- 1 - beta2^state(param)[['step']]
            step_size <- group[['lr']] *
                sqrt(bias_correction2) / bias_correction1

            # Applies bounds on actual learning rate
            # lr_scheduler cannot affect final_lr, this is a workaround to
            # apply lr decay
            final_lr <-  group[['final_lr']] * group[['lr']] / self$base_lr
            lower_bound <- final_lr *
                (1 - 1 / (group[['gamma']] * state(param)[['step']] + 1))
            upper_bound <- final_lr *
                (1 + 1 / (group[['gamma']] * state(param)[['step']]))

            # calculate denominator
            denom = exp_avg_sq$sqrt()$add_(group[['eps']])

            step_size <-  torch::torch_full_like(
                input = denom,
                fill_value = step_size)
            step_size$div_(denom)$clamp_(lower_bound, upper_bound)$mul_(exp_avg)

            param$add_(-step_size)
        }

        private$step_helper(closure, loop_fun)
    }
)
