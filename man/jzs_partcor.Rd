\name{jzs_partcor}
\alias{jzs_partcor}
\title{
A default Bayesian hypothesis test for partial correlation.
}
\description{
This function can be used to perform a default Bayesian hypothesis test for partial correlation, using a Jeffreys-Zellner-Siow prior set-up (Liang et al., 2008).
}
\usage{
jzs_partcor(V1, V2, control)
}
\arguments{
  \item{V1}{
a numeric vector.
}
  \item{V2}{
a numeric vector of the same length as V1.
}
  \item{control}{
a numeric vector of the same length as V1 and V2. This variable is partialled out of the correlation between V1 and V2.
}
}
\details{
See Wetzels & Wagenmakers, in press.
}
\value{
The function returns a list with the following items:
\item{BayesFactor}{
The Bayes factor for the partial correlation coefficient. A value greater than one indicates evidence in favor of correlation, a value smaller than one indicates evidence against correlation.
}
\item{PosteriorProbability}{
The posterior probability for the existence of a partial correlation between V1 and V2, controlled for the control variable.
}
}
\references{
Liang, F., Paulo, R., Molina, G., Clyde, M. A., & Berger, J. O. (2008). Mixtures of g priors for Bayesian variable selection. Journal of the American Statistical Association, 103(481), 410-423.

Nuijten, M.B., Wetzels, R., Matzke, D., Dolan, C. V., & Wagenmakers, E.-J. (in preparation). A default Bayesian hypothesis test for mediation. 

Wetzels, R. & Wagenmakers, E.-J. (in press). A default Bayesian hypothesis test for correlations and partial correlations. Psychonomic Bulletin & Review.
}
\author{
Ruud Wetzels and Michele B. Nuijten
}
%\seealso{
%\code{\link{jzs_cor}}, \code{\link{jzs_med}}
%}
\examples{
# simulate partially correlated data
X <- rnorm(50,0,1)
C <- .5*X + rnorm(50,0,1)
Y <- .3*X + .6*C + rnorm(50,0,1)

# run jzs_partcor
jzs_partcor(X,Y,C)
}