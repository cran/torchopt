% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/madgrad.R
\name{optim_madgrad}
\alias{optim_madgrad}
\title{MADGRAD optimizer}
\usage{
optim_madgrad(params, lr = 0.01, momentum = 0.9, weight_decay = 0, eps = 1e-06)
}
\arguments{
\item{params}{List of parameters to optimize.}

\item{lr}{Learning rate (default: 1e-2).}

\item{momentum}{Momentum value in  the range [0,1) (default: 0.9).}

\item{weight_decay}{Weight decay, i.e. a L2 penalty (default: 0).}

\item{eps}{Term added to the denominator outside of
the root operation to improve numerical stability
(default: 1e-6).}
}
\value{
A torch optimizer object implementing the \code{step} method.
}
\description{
A Momentumized, Adaptive, Dual Averaged Gradient Method for Stochastic
Optimization (MADGRAD) is a general purpose optimizer that
can be used in place of SGD or Adam may converge faster and generalize
better. Currently GPU-only. Typically, the same learning rate schedule
that is used for SGD or Adam may be used. The overall learning rate is
not comparable to either method and should be determined by a
hyper-parameter sweep.

MADGRAD requires less weight decay than other methods, often as little as
zero. Momentum values used for SGD or Adam's beta1 should work here also.

On sparse problems both weight_decay and momentum should be set to 0.
(not yet supported in the R implementation).
}
\examples{
if (torch::torch_is_installed()) {
# function to demonstrate optimization
beale <- function(x, y) {
    log((1.5 - x + x * y)^2 + (2.25 - x - x * y^2)^2 + (2.625 - x + x * y^3)^2)
 }
# define optimizer
optim <- torchopt::optim_madgrad
# define hyperparams
opt_hparams <- list(lr = 0.01)

# starting point
x0 <- 3
y0 <- 3
# create tensor
x <- torch::torch_tensor(x0, requires_grad = TRUE)
y <- torch::torch_tensor(y0, requires_grad = TRUE)
# instantiate optimizer
optim <- do.call(optim, c(list(params = list(x, y)), opt_hparams))
# run optimizer
steps <- 400
x_steps <- numeric(steps)
y_steps <- numeric(steps)
for (i in seq_len(steps)) {
    x_steps[i] <- as.numeric(x)
    y_steps[i] <- as.numeric(y)
    optim$zero_grad()
    z <- beale(x, y)
    z$backward()
    optim$step()
}
print(paste0("starting value = ", beale(x0, y0)))
print(paste0("final value = ", beale(x_steps[steps], y_steps[steps])))
}
}
\references{
Aaron Defazio, Samy Jelassi,
"Adaptivity without Compromise: A Momentumized, Adaptive, Dual
Averaged Gradient Method for Stochastic Optimization".
https://arxiv.org/abs/2101.11075
}
\author{
Daniel Falbel, \email{dfalbel@gmail.com}
}
