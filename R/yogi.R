#' @title Yogi optimizer
#'
#' @name optim_yogi
#'
#' @author Gilberto Camara, \email{gilberto.camara@@inpe.br}
#' @author Rolf Simoes, \email{rolf.simoes@@inpe.br}
#' @author Felipe Souza, \email{lipecaso@@gmail.com}
#' @author Alber Sanchez, \email{alber.ipia@@inpe.br}
#'
#' @description
#' R implementation of the Yogi optimizer proposed
#' by Zaheer et al.(2019). We used the implementation available at
#' https://github.com/jettify/pytorch-optimizer/blob/master/torch_optimizer/yogi.py.
#' Thanks to Nikolay Novik for providing the pytorch code.
#'
#' The original implementation is licensed using the Apache-2.0 software license.
#' This implementation is also licensed using Apache-2.0 license.
#'
#' From the abstract by the paper by Zaheer et al.(2019):
#' Adaptive gradient methods that rely on scaling gradients
#' down by the square root of exponential moving averages
#' of past squared gradients, such RMSProp, Adam, Adadelta have
#' found wide application in optimizing the nonconvex problems
#' that arise in deep learning. However, it has been recently
#' demonstrated that such methods can fail to converge even
#' in simple convex optimization settings.
#' Yogi is a new adaptive optimization algorithm,
#' which controls the increase in effective learning rate,
#' leading to even better performance with similar theoretical
#' guarantees on convergence. Extensive experiments show that
#' Yogi with very little hyperparameter tuning outperforms
#' methods such as Adam in several challenging machine learning tasks.
#'
#'
#' @references
#' Manzil Zaheer, Sashank Reddi, Devendra Sachan, Satyen Kale, Sanjiv Kumar,
#' "Adaptive Methods for Nonconvex Optimization",
#' Advances in Neural Information Processing Systems 31 (NeurIPS 2018).
#' https://papers.nips.cc/paper/8186-adaptive-methods-for-nonconvex-optimization
#'
#' @param params         List of parameters to optimize.
#' @param lr             Learning rate (default: 1e-3)
#' @param betas          Coefficients computing running averages of gradient
#'                       and its square (default: (0.9, 0.999))
#' @param eps            Term added to the denominator to improve numerical
#'   stability (default: 1e-8)
#' @param initial_accumulator  Initial values for first and
#'   second moments.
#' @param weight_decay   Weight decay (L2 penalty) (default: 0)
#'
#' @returns
#' A torch optimizer object implementing the `step` method.
#'
#' @examples
#' if (torch::torch_is_installed()) {

#' # function to demonstrate optimization
#' beale <- function(x, y) {
#'     log((1.5 - x + x * y)^2 + (2.25 - x - x * y^2)^2 + (2.625 - x + x * y^3)^2)
#'  }
#' # define optimizer
#' optim <- torchopt::optim_yogi
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
optim_yogi <- torch::optimizer(
    "optim_yogi",
    initialize = function(params,
                          lr = 0.01,
                          betas = c(0.9, 0.999),
                          eps = 0.001,
                          initial_accumulator = 1e-6,
                          weight_decay = 0) {
        if (lr <= 0.0)
            stop("Learning rate must be positive.", call. = FALSE)
        if (eps < 0.0)
            stop("eps must be non-negative.", call. = FALSE)
        if (betas[1] > 1.0 | betas[1] <= 0.0)
            stop("Invalid beta parameter.", call. = FALSE)
        if (betas[2] > 1.0 | betas[1] <= 0.0)
            stop("Invalid beta parameter.", call. = FALSE)
        if (weight_decay < 0)
            stop("Invalid weight_decay value.", call. = FALSE)

        defaults = list(
            lr                  = lr,
            betas               = betas,
            eps                 = eps,
            weight_decay        = weight_decay,
            initial_accumulator = initial_accumulator
        )
        super$initialize(params, defaults)
    },
    step = function(closure = NULL) {
        loop_fun <- function(group, param, g, p) {
            if (is.null(param$grad))
                next
            grad <- param$grad

            # get value of initial accumulator
            init_acc <- group[["initial_accumulator"]]

            # State initialization
            if (length(state(param)) == 0) {
                state(param) <- list()
                state(param)[["step"]] <- 0
                # Exponential moving average of gradient values
                state(param)[["exp_avg"]] <- torch::nn_init_constant_(
                    torch::torch_empty_like(
                        param,
                        memory_format = torch::torch_preserve_format()
                    ),
                    init_acc
                )
                # Exponential moving average of squared gradient values
                state(param)[["exp_avg_sq"]] <- torch::nn_init_constant_(
                    torch::torch_empty_like(
                        param,
                        memory_format = torch::torch_preserve_format()
                    ),
                    init_acc
                )
            }
            # Define variables for optimization function
            exp_avg      <- state(param)[["exp_avg"]]
            exp_avg_sq   <- state(param)[["exp_avg_sq"]]
            beta1        <- group[['betas']][[1]]
            beta2        <- group[['betas']][[2]]
            weight_decay <- group[['weight_decay']]
            eps          <- group[["eps"]]
            lr           <- group[['lr']]

            # take one step
            state(param)[["step"]] <- state(param)[["step"]] + 1
            # bias correction
            bias_correction1 <- 1 - beta1^state(param)[['step']]
            bias_correction2 <- 1 - beta2^state(param)[['step']]

            # L2 correction
            if (weight_decay != 0)
                grad <- grad$add(p, alpha = weight_decay)

            # Decay the first moment
            exp_avg$mul_(beta1)$add_(grad, alpha = 1 - beta1)
            # Decay the second moment
            grad_squared <- grad$mul(grad)
            exp_avg_sq$addcmul_(
                torch::torch_sign(exp_avg_sq - grad_squared),
                grad_squared,
                value = -(1 - beta2)
            )

            # calculate denominator
            denom = (exp_avg_sq$sqrt() / sqrt(bias_correction2))$add_(eps)

            # calculate step size
            step_size <- lr / bias_correction1
            # go to next step
            param$addcdiv_(exp_avg, denom, value = -step_size)
        }

        private$step_helper(closure, loop_fun)
    }
)
