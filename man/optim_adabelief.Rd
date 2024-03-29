% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/adabelief.R
\name{optim_adabelief}
\alias{optim_adabelief}
\title{Adabelief optimizer}
\usage{
optim_adabelief(
  params,
  lr = 0.001,
  betas = c(0.9, 0.999),
  eps = 1e-08,
  weight_decay = 1e-06,
  weight_decouple = TRUE,
  fixed_decay = FALSE,
  rectify = TRUE
)
}
\arguments{
\item{params}{List of parameters to optimize.}

\item{lr}{Learning rate (default: 1e-3)}

\item{betas}{Coefficients for computing running averages
of gradient and its square (default: (0.9, 0.999))}

\item{eps}{Term added to the denominator to improve numerical
stability (default: 1e-16)}

\item{weight_decay}{Weight decay (L2 penalty) (default: 0)}

\item{weight_decouple}{Use decoupled weight decay as is done in AdamW?}

\item{fixed_decay}{This is used when weight_decouple is set as True.
When fixed_decay == True, weight decay is
W_new = W_old - W_old * decay.
When fixed_decay == False, the weight decay is
W_new = W_old - W_old * decay * learning_rate.
In this case, weight decay decreases with learning rate.}

\item{rectify}{Perform the rectified update similar to RAdam?}
}
\value{
A torch optimizer object implementing the \code{step} method.
}
\description{
R implementation of the adabelief optimizer proposed
by Zhuang et al (2020). We used the pytorch implementation
developed by the authors which is available at
https://github.com/jettify/pytorch-optimizer.
Thanks to Nikolay Novik of his work on python optimizers.

The original implementation is licensed using the Apache-2.0 software license.
This implementation is also licensed using Apache-2.0 license.

From the abstract by the paper by Zhuang et al (2021):
We propose Adabelief to simultaneously achieve three goals:
fast convergence as in adaptive methods, good generalization as in SGD,
and training stability. The intuition for AdaBelief is to adapt
the stepsize according to the "belief" in the current gradient direction.
Viewing the exponential moving average of the noisy gradient
as the prediction of the gradient at the next time step,
if the observed gradient greatly deviates from the prediction,
we distrust the current observation and take a small step;
if the observed gradient is close to the prediction,
we trust it and take a large step.
}
\examples{
if (torch::torch_is_installed()) {
# function to demonstrate optimization
beale <- function(x, y) {
    log((1.5 - x + x * y)^2 + (2.25 - x - x * y^2)^2 + (2.625 - x + x * y^3)^2)
 }
# define optimizer
optim <- torchopt::optim_adabelief
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
Juntang Zhuang, Tommy Tang, Yifan Ding, Sekhar Tatikonda,
Nicha Dvornek, Xenophon Papademetris, James S. Duncan.
"Adabelief Optimizer: Adapting Stepsizes by the Belief in Observed Gradients",
34th Conference on Neural Information Processing Systems (NeurIPS 2020),
Vancouver, Canada.
https://arxiv.org/abs/2010.07468
}
\author{
Gilberto Camara, \email{gilberto.camara@inpe.br}

Rolf Simoes, \email{rolf.simoes@inpe.br}

Felipe Souza, \email{lipecaso@gmail.com}

Alber Sanchez, \email{alber.ipia@inpe.br}
}
