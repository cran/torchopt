% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/adamw.R
\name{optim_adamw}
\alias{optim_adamw}
\title{AdamW optimizer}
\usage{
optim_adamw(
  params,
  lr = 0.01,
  betas = c(0.9, 0.999),
  eps = 1e-08,
  weight_decay = 1e-06
)
}
\arguments{
\item{params}{List of parameters to optimize.}

\item{lr}{Learning rate (default: 1e-3)}

\item{betas}{Coefficients computing running averages of gradient
and its square (default: (0.9, 0.999))}

\item{eps}{Term added to the denominator to improve numerical
stability (default: 1e-8)}

\item{weight_decay}{Weight decay (L2 penalty) (default: 1e-6)}
}
\value{
A torch optimizer object implementing the \code{step} method.
}
\description{
R implementation of the AdamW optimizer proposed
by Loshchilov & Hutter (2019). We used the pytorch implementation
developed by Collin Donahue-Oponski available at:
https://gist.github.com/colllin/0b146b154c4351f9a40f741a28bff1e3

From the abstract by the paper by Loshchilov & Hutter (2019):
L2 regularization and weight decay regularization are equivalent for standard
stochastic gradient descent (when rescaled by the learning rate),
but as we demonstrate this is not the case for adaptive gradient algorithms,
such as Adam. While common implementations of these algorithms
employ L2 regularization (often calling it “weight decay”
in what may be misleading due to the inequivalence we expose),
we propose a simple modification to recover the original formulation of
weight decay regularization by decoupling the weight decay from the optimization
steps taken w.r.t. the loss function
}
\examples{
if (torch::torch_is_installed()) {
# function to demonstrate optimization
beale <- function(x, y) {
    log((1.5 - x + x * y)^2 + (2.25 - x - x * y^2)^2 + (2.625 - x + x * y^3)^2)
 }
# define optimizer
optim <- torchopt::optim_adamw
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
Ilya Loshchilov, Frank Hutter,
"Decoupled Weight Decay Regularization",
International Conference on Learning Representations (ICLR) 2019.
https://arxiv.org/abs/1711.05101
}
\author{
Gilberto Camara, \email{gilberto.camara@inpe.br}

Rolf Simoes, \email{rolf.simoes@inpe.br}

Felipe Souza, \email{lipecaso@gmail.com}

Alber Sanchez, \email{alber.ipia@inpe.br}
}
