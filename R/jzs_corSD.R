jzs_corSD <-  
  function(V1,V2,
           SDmethod=c("fit.st","dnorm","splinefun","logspline"),
           alternative=c("two.sided","less","greater"),
           n.iter=10000,n.burnin=500){
    
    V1 <- (V1-mean(V1))/sd(V1)
    V2 <- (V2-mean(V2))/sd(V2)
    
    X <- V1
    Y <- V2
    
    n <- length(V1)
    r <- cor(V1,V2)
    
    #==========================================================
    # load JAGS models
    #==========================================================
    
    jagsmodelcorrelation <- 
      
      "####### Cauchy-prior on single beta #######
model
    
{
    
    for (i in 1:n)
    
{
    mu[i] <- intercept + alpha*x[i]
    y[i]   ~ dnorm(mu[i],phi)
    
}
    
    # uninformative prior on the intercept intercept, 
    # Jeffreys' prior on precision phi
    intercept ~ dnorm(0,.0001)
    phi   ~ dgamma(.0001,.0001)
    #phi   ~ dgamma(0.0000001,0.0000001) #JAGS accepts even this
    #phi   ~ dgamma(0.01,0.01)           #WinBUGS wants this
    
    # inverse-gamma prior on g:
    g       <- 1/invg 
    a.gamma <- 1/2
    b.gamma <- n/2    
    invg     ~ dgamma(a.gamma,b.gamma)
    
    
    # g-prior on beta:
    vari <- (g/phi) * invSigma 
    prec <- 1/vari
    alpha    ~ dnorm(0, prec)
}
    
    # Explanation------------------------------------------------------------------ 
    # Prior on g:
    # We know that g ~ inverse_gamma(1/2, n/2), with 1/2 the shape
    # parameter and n/2 the scale parameter.
    # It follows that 1/g ~ gamma(1/2, 2/n).
    # However, BUGS/JAGS uses the *rate parameterization* 1/theta instead of the
    # scale parametrization theta. Hence we obtain, in de BUGS/JAGS rate notation:
    # 1/g ~ dgamma(1/2, n/2)
    #------------------------------------------------------------------------------
    "
    jags.model.file1 <- tempfile(fileext=".txt")
    write(jagsmodelcorrelation,jags.model.file1)
    
    #==========================================================
    # BF FOR CORRELATION
    #==========================================================
    
    x <- X
    y <- Y
    
    invSigma <- solve(t(x)%*%x)
    
    jags.data   <- list("n", "x", "y", "invSigma")
    jags.params <- c("alpha", "g")
    jags.inits  <-  list(
      list(alpha = 0.0), #chain 1 starting value
      list(alpha = -0.3), #chain 2 starting value
      list(alpha = 0.3)) #chain 3 starting value
      
    jagsamples <- jags(data=jags.data, inits=jags.inits, jags.params, 
                       n.chains=3, n.iter=n.iter, DIC=T,
                       n.burnin=n.burnin, n.thin=1, model.file=jags.model.file1)
    
    # estimate the posterior regression coefficient and scaling factor g
    alpha <- jagsamples$BUGSoutput$sims.list$alpha[,1]
    g  <- jagsamples$BUGSoutput$sims.list$g
    
    
    #------------------------------------------------------------------
    
    if(SDmethod[1]=="fit.st"){
      
      mydt <- function(x, m, s, df) dt((x-m)/s, df)/s
      
      foo <- try({
        fit.t <- fit.st(alpha)
        nu    <- as.numeric(fit.t$par.ests[1]) #degrees of freedom
        mu    <- as.numeric(fit.t$par.ests[2]) 
        sigma <- abs(as.numeric(fit.t$par.ests[3])) # This is a hack -- with high n occasionally
        # sigma switches sign. 
      }) 
      
      if(!("try-error"%in%class(foo))){
        
        # BAYES FACTOR ALPHA
        BF <- 1/(mydt(0,mu,sigma,nu)/dcauchy(0))
        
        # save BF for one-tailed test
        # BF21 = 2*{proportion posterior samples of rho < 0}
        BF21_less <- pt((0-mu)/sigma,nu,lower.tail=TRUE)/sigma
        BF21_greater <- pt((0-mu)/sigma,nu,lower.tail=FALSE)/sigma
        
      } else {
        
        warning("fit.st did not converge, alternative optimization method was used.","\n")
        
        mydt2 <- function(pars){
          
          m <- pars[1]
          s <- abs(pars[2])  # no negative standard deviation
          df <- abs(pars[3]) # no negative degrees of freedom
          
          -2*sum(dt((alpha-m)/s, df,log=TRUE)-log(s))
        }
        
        res <- optim(c(mean(alpha),sd(alpha),20),mydt2)$par
        
        m <- res[1]
        s <- res[2]
        df <- res[3]
        
        
        # ALTERNATIVE BAYES FACTOR ALPHA
        BF <- 1/(mydt2(0,m,s,df)/dcauchy(0))
        
        # save BF for one-tailed test
        # BF21 = 2*{proportion posterior samples of alpha < 0}
        BF21_less <- pt((0-m)/s,df,lower.tail=TRUE)/s
        BF21_greater <- pt((0-m)/s,df,lower.tail=FALSE)/s
        
      }
      
      #-------------------------
      
    } else if(SDmethod[1]=="dnorm"){
      BF <- 1/(dnorm(0,mean(alpha),sd(alpha))/dcauchy(0))
      
      # save BF for one-tailed test
      # BF21 = 2*{proportion posterior samples of rho < 0}
      BF21_less <- 2*pnorm(0,lower.tail=TRUE)
      BF21_greater <- 2*pnorm(0,lower.tail=FALSE)
      
      #-------------------------
      
    } else if(SDmethod[1]=="splinefun"){
      f <- splinefun(density(alpha))
      BF <- 1/(f(0)/dcauchy(0))
      
      # save BF for one-tailed test
      # BF21 = 2*{proportion posterior samples of alpha < 0}
      propposterior_less <- sum(alpha<0)/length(alpha)
      
      # posterior proportion cannot be zero, because this renders a BF of zero
      # none of the samples of the parameter follow the restriction
      # ergo: the posterior proportion is smaller than 1/length(parameter)
      
      if(propposterior_less==0){
        propposterior_less <- 1/length(alpha)
      }
      
      propposterior_greater <- sum(alpha>0)/length(alpha)
      
      if(propposterior_greater==0){
        propposterior_greater <- 1/length(alpha)
      }
      
      BF21_less <- 2*propposterior_less
      BF21_greater <- 2*propposterior_greater
      
      #-------------------------
      
    } else if (SDmethod[1]=="logspline"){
      fit.posterior <- logspline(alpha)
      posterior.pp  <- dlogspline(0, fit.posterior) # this gives the pdf at point b2 = 0
      prior.pp      <- dcauchy(0)                   # height of prior at b2 = 0
      BF           <- prior.pp/posterior.pp
      
      # save BF for one-tailed test
      # BF21 = 2*{proportion posterior samples of alpha < 0}
      
      propposterior_less <- sum(alpha<0)/length(alpha)
      
      # posterior proportion cannot be zero, because this renders a BF of zero
      # none of the samples of the parameter follow the restriction
      # ergo: the posterior proportion is smaller than 1/length(parameter)
      
      if(propposterior_less==0){
        propposterior_less <- 1/length(alpha)
      }
      
      propposterior_greater <- sum(alpha>0)/length(alpha)
      
      if(propposterior_greater==0){
        propposterior_greater <- 1/length(alpha)
      }
      
      BF21_less <- 2*propposterior_less
      BF21_greater <- 2*propposterior_greater
    } 
    
    #--------------------------------------------------------
    
    # one-sided test?
    
    if(alternative[1]=="less"){
      # BF10 = p(D|a~cauchy(0,1))/p(D|a=0)
      BF10 <- BF
      
      # BF21 = p(D|a~cauchy-(0,1))/p(D|a~cauchy(0,1))
      # BF21 = 2*{proportion posterior samples of alpha < 0}
      BF21 <- BF21_less
      
      BF <- BF10*BF21
      
    } else if(alternative[1]=="greater"){
      # BF10 = p(D|a~cauchy(0,1))/p(D|a=0)
      BF10 <- BF
      
      # BF21 = p(D|a~cauchy+(0,1))/p(D|a~cauchy(0,1))
      # BF21 = 2*{proportion posterior samples of alpha > 0}
      BF21 <- BF21_greater
      
      BF <- BF10*BF21
      
    }
    
    #--------------------------------------------------------
    
    # convert BFs to posterior probability
    # prob cannot be exactly 1 or 0
    prob_r <- BF/(BF+1)
    
    if(prob_r == 1){
      prob_r <- prob_r - .Machine$double.eps
    }
    if(prob_r == 0){
      prob_r <- prob_r + .Machine$double.eps
    }
    
    
    #==================================================
    
    # convert posterior samples for the regression coefficient x-y to correlation
    cor_coef <- alpha*(sd(x)/sd(y))
    
    #===================================================
    
    res <- list(Correlation=mean(cor_coef),
                BayesFactor=BF,
                PosteriorProbability=prob_r,
                alpha=cor_coef,
                jagssamples=jagsamples)
    
    class(res) <- c("jzs_med","list")
    class(res$jagssamples) <- "rjags"
    
    return(res) 
    
  }