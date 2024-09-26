function (data, xreg = "cumcases", IP = 2, nsim = 10, regtype = "gaussian", 
    sigmamax = 3, userYhat = numeric(), alpha = NULL, sbar = NULL, 
    family = "gaussian", link = "identity", method = "deterministic", 
    inits.fit = FALSE, epidemics = "cont", pred = "forward", 
    threshold = 1, seasonality = "standard", add.noise.sd = 0, 
    mul.noise.sd = 0, printon = F, fit = NULL, fittype = NULL) 
{
    if ((nsim%%1 == 0) == F) {
        nsim <- round(nsim)
    }
    datacheck <- c("time", "cases", "pop", "births")
    if (sum(datacheck %in% names(data)) < length(datacheck)) {
        stop("data frame must contain \"time\", \"cases\", \"pop\", and \"births\" columns")
    }
    na.casescheck <- sum(is.na(data$cases))
    if (na.casescheck > 0) {
        stop("there cannot be any NAs in the cases vector -- please correct")
    }
    na.birthscheck <- sum(is.na(data$births))
    if (na.casescheck > 0) {
        stop("there cannot be any NAs in the births vector -- please correct")
    }
    xregcheck <- c("cumcases", "cumbirths")
    if (xreg %in% xregcheck == F) {
        stop("xreg must be either \"cumcases\" or \"cumbirths\"")
    }
    regtypecheck <- c("gaussian", "lm", "spline", "lowess", "loess", 
        "user")
    if (regtype %in% regtypecheck == F) {
        stop("regtype must be one of 'gaussian','lm','spline','lowess','loess','user'")
    }
    if (length(sbar) == 1) {
        if (sbar > 1 || sbar < 0) {
            stop("sbar must be a percentage of the population, i.e. between zero and one.")
        }
    }
    linkcheck <- c("log", "identity")
    if (link %in% linkcheck == F) {
        stop("link must be either 'log' or 'identity'")
    }
    seasonalitycheck <- c("standard", "schoolterm", "none")
    if (seasonality %in% seasonalitycheck == F) {
        stop("seasonality must be either 'standard' or 'schoolterm' or 'none'")
    }
    methodcheck <- c("deterministic", "negbin", "pois")
    if (method %in% methodcheck == F) {
        stop("method must be one of 'deterministic','negbin','pois'")
    }
    epidemicscheck <- c("cont", "break")
    if (epidemics %in% epidemicscheck == F) {
        stop("epidemics must be either 'cont' or 'break'")
    }
    predcheck <- c("forward", "step-ahead")
    if (pred %in% predcheck == F) {
        stop("pred must be either 'forward' or 'step-ahead'")
    }
    if (length(fittype) == 1) {
        warning("Argument fittype is deprecated;\n            if fixing alpha or sbar (or both!) set alpha =, and/or sbar = in the function.\n            For now defaulting to alpha = 0.97, sbar = 0.05. Will be removed soon.")
        if (fittype == "less") {
            sbar = 0.05
            alpha = 0.97
        }
        if (fittype == "fixalpha") 
            alpha = 0.97
    }
    if (length(fit) == 1) {
        stop("Argument fit is deprecated; the only fit option here is using a glm.\n         Please use mcmctsir for an mcmc version of the tsir model.")
    }
    input.alpha <- alpha
    input.sbar <- sbar
    nzeros <- length(which(data$cases == 0))
    ltot <- length(data$cases)
    if (nzeros > 0.3 * ltot && epidemics == "cont") {
        print(sprintf("time series is %.0f%% zeros, consider using break method", 
            100 * nzeros/ltot))
    }
    cumbirths <- cumsum(data$births)
    cumcases <- cumsum(data$cases)
    if (xreg == "cumcases") {
        X <- cumcases
        Y <- cumbirths
    }
    if (xreg == "cumbirths") {
        X <- cumbirths
        Y <- cumcases
    }
    x <- seq(X[1], X[length(X)], length = length(X))
    y <- approxfun(X, Y)(x)
    y[1] <- y[2] - (y[3] - y[2])
    if (regtype == "lm") {
        Yhat <- predict(lm(Y ~ X))
    }
    if (regtype == "lowess") {
        Yhat <- lowess(X, Y, f = 2/3, iter = 1)$y
    }
    if (regtype == "loess") {
        Yhat <- predict(loess(y ~ x, se = T, family = "gaussian", 
            degree = 1, model = T), X)
    }
    if (regtype == "spline") {
        Yhat <- predict(smooth.spline(x, y, df = 2.5), X)$y
    }
    if (regtype == "gaussian") {
        sigvec <- seq(sigmamax, 0, -0.1)
        for (it in 1:length(sigvec)) {
            if (printon == T) {
                print(sprintf("gaussian regression attempt number %d", 
                  it))
            }
            Yhat <- predict(gausspr(x, y, variance.model = T, 
                fit = T, tol = 1e-07, var = 0.01, kernel = "rbfdot", 
                kpar = list(sigma = sigvec[it])), X)
            if (sigvec[it] <= min(sigvec)) {
                print("gaussian regressian failed -- switching to loess regression")
                Yhat <- predict(loess(y ~ x, se = T, family = "gaussian", 
                  degree = 1, model = T), X)
            }
            if (xreg == "cumcases") {
                Z <- residual.cases(Yhat, Y)
                rho <- derivative(X, Yhat)
                if (length(which(rho <= 1)) == 0) {
                  (break)()
                }
            }
            if (xreg == "cumbirths") {
                rho <- derivative(X, Yhat)
                Z <- residual.births(rho, Yhat, Y)
                if (length(which(rho >= 1)) == 0 && length(which(rho < 
                  0)) == 0) {
                  (break)()
                }
            }
        }
    }
    if (regtype == "user") {
        Yhat <- userYhat
        if (length(Yhat) == 0) {
            stop("Yhat returns numeric(0) -- make sure to input a userYhat under regtype=user")
        }
    }
    rho <- derivative(X, Yhat)
    if (xreg == "cumcases") {
        Z <- residual.cases(Yhat, Y)
    }
    if (xreg == "cumbirths") {
        Z <- residual.births(rho, Yhat, Y)
    }
    if (xreg == "cumcases") {
        adj.rho <- rho
    }
    if (xreg == "cumbirths") {
        adj.rho <- 1/rho
    }
    if (regtype == "lm") {
        adj.rho <- signif(adj.rho, 3)
    }
    if (any(1/adj.rho < 0.01)) {
        warning("Reporting rate has fallen below 1% -- try lowering the value of sigmamax (default is 3) if you are using\n            regtype=\"gaussian\"")
    }
    if (length(which(adj.rho < 1)) > 1) {
        warning("Reporting exceeds 100% -- use different regression")
    }
    Iadjusted <- data$cases * adj.rho
    datacopy <- data
    if (seasonality == "standard") {
        period <- rep(1:(52/IP), round(nrow(data) + 1))[1:(nrow(data) - 
            1)]
        if (IP == 1) {
            period <- rep(1:(52/2), each = 2, round(nrow(data) + 
                1))[1:(nrow(data) - 1)]
        }
    }
    if (seasonality == "schoolterm") {
        term <- rep(1, 26)
        term[c(1, 8, 15, 16, 17, 18, 19, 23, 26)] <- 2
        iterm <- round(approx(term, n = 52/IP)$y)
        period <- rep(iterm, round(nrow(data) + 1))[1:(nrow(data) - 
            1)]
    }
    if (seasonality == "none") {
        period <- rep(1, nrow(data) - 1)
        period[nrow(data) - 1] <- 2
    }
    Inew <- tail(Iadjusted, -1) + 1
    lIminus <- log(head(Iadjusted, -1) + 1)
    Zminus <- head(Z, -1)
    pop <- data$pop
    minSmean <- max(0.01 * pop, -(min(Z) - 1))
    Smean <- seq(minSmean, 0.4 * mean(pop), length = 250)
    loglik <- rep(NA, length(Smean))
    if (link == "identity") {
        Inew <- log(Inew)
    }
    if (family %in% c("poisson", "quasipoisson")) {
        Inew <- round(Inew)
    }
    if (length(input.alpha) == 0 && length(input.sbar) == 0) {
        for (i in 1:length(Smean)) {
            lSminus <- log(Smean[i] + Zminus)
            glmfit <- glm(Inew ~ -1 + as.factor(period) + (lIminus) + 
                offset(lSminus), family = eval(parse(text = family))(link = link))
            loglik[i] <- glmfit$deviance
        }
        sbar <- Smean[which.min(loglik)]
        lSminus <- log(sbar + Zminus)
        glmfit <- glm(Inew ~ -1 + as.factor(period) + (lIminus) + 
            offset(lSminus), family = eval(parse(text = family))(link = link))
        beta <- exp(head(coef(glmfit), -1))
        alpha <- tail(coef(glmfit), 1)
    }
    if (length(input.alpha) == 1 && length(input.sbar) == 0) {
        for (i in 1:length(Smean)) {
            lSminus <- log(Smean[i] + Zminus)
            glmfit <- glm(Inew ~ -1 + as.factor(period) + offset(alpha * 
                lIminus) + offset(lSminus), family = eval(parse(text = family))(link = link))
            loglik[i] <- glmfit$deviance
        }
        sbar <- Smean[which.min(loglik)]
        lSminus <- log(sbar + Zminus)
        glmfit <- glm(Inew ~ -1 + as.factor(period) + offset(alpha * 
            lIminus) + offset(lSminus), family = eval(parse(text = family))(link = link))
        beta <- exp(coef(glmfit))
    }
    if (length(input.alpha) == 0 && length(input.sbar) == 1) {
        sbar <- sbar * mean(pop)
        lSminus <- log(sbar + Zminus)
        glmfit <- glm(Inew ~ -1 + as.factor(period) + (lIminus) + 
            offset(lSminus), family = eval(parse(text = family))(link = link))
        beta <- exp(head(coef(glmfit), -1))
        alpha <- tail(coef(glmfit), 1)
    }
    if (length(input.alpha) == 1 && length(input.sbar) == 1) {
        sbar <- sbar * mean(pop)
        lSminus <- log(sbar + Zminus)
        glmfit <- glm(Inew ~ -1 + as.factor(period) + offset(alpha * 
            lIminus) + offset(lSminus), family = eval(parse(text = family))(link = link))
        beta <- exp(coef(glmfit))
    }
    if (seasonality == "none") {
        beta[2] <- beta[1]
        beta <- mean(beta)
        period <- rep(1, nrow(data) - 1)
    }
    confinterval <- suppressMessages(confint(glmfit))
    continterval <- confinterval[1:length(unique(period)), ]
    betalow <- exp(confinterval[, 1])
    betahigh <- exp(confinterval[, 2])
    glmAIC <- AIC(glmfit)
    contact <- as.data.frame(cbind(time = seq(1, length(beta[period]), 
        1), betalow[period], beta[period], betahigh[period]), 
        row.names = F)
    names(contact) <- c("time", "betalow", "beta", "betahigh")
    contact <- head(contact, 52/IP)
    S <- rep(0, length(data$cases))
    I <- rep(0, length(data$cases))
    nsample <- 30
    inits.grid <- expand.grid(S0 = seq(0.01 * mean(pop), 0.1 * 
        mean(pop), length = nsample), I0 = seq(0.01 * 0.001 * 
        mean(pop), 1 * 0.001 * mean(pop), length = nsample))
    if (inits.fit == TRUE) {
        inits.res <- rep(NA, nsample * nsample)
        for (it in 1:nrow(inits.grid)) {
            S0 <- inits.grid[it, 1]
            I0 <- inits.grid[it, 2]
            S[1] <- S0
            I[1] <- I0
            for (t in 2:(nrow(data))) {
                lambda <- min(S[t - 1], unname(beta[period[t - 
                  1]] * S[t - 1] * (I[t - 1])^alpha))
                if (is.nan(lambda) == T) {
                  lambda <- 0
                }
                I[t] <- lambda
                if (epidemics == "cont") {
                  I[t] <- I[t]
                }
                if (epidemics == "break") {
                  t0s <- epitimes(data, threshold)$start
                  if (t %in% t0s) {
                    I[t] <- adj.rho[t] * data$cases[t]
                  }
                }
                S[t] <- max(S[t - 1] + data$births[t - 1] - I[t], 
                  0)
            }
            inits.res[it] <- sum((I - data$cases * adj.rho)^2)
        }
        inits <- inits.grid[which.min(inits.res), ]
        inits.grid$S0 <- inits.grid$S0/mean(pop)
        inits.grid$I0 <- inits.grid$I0/mean(pop)
        inits.grid$log10LS <- log10(inits.res)
        S_start <- inits[[1]]
        I_start <- inits[[2]]
    }
    else {
        S_start <- sbar + Z[1]
        I_start <- adj.rho[1] * datacopy$cases[1]
    }
    IC <- c(S_start, I_start)
    if (any(IC < 0)) {
        warning("One (or both) initial condition is zero, try fixing or increasing sbar")
    }
    print(c(alpha = unname(signif(alpha, 2)), `mean beta` = unname(signif(mean(beta), 
        3)), `mean rho` = unname(signif(mean(1/adj.rho), 3)), 
        `mean sus` = unname(signif(sbar, 3)), `prop. init. sus.` = unname(signif(S_start/mean(pop), 
            3)), `prop. init. inf.` = unname(signif(I_start/mean(pop), 
            3))))
    nsim <- nsim
    res <- matrix(0, length(data$cases), nsim)
    Sres <- matrix(0, length(data$cases), nsim)
    for (ct in 1:nsim) {
        S <- rep(0, length(data$cases))
        I <- rep(0, length(data$cases))
        S[1] <- S_start
        I[1] <- I_start
        for (t in 2:(nrow(data))) {
            if (pred == "step-ahead") {
                lambda <- min(S[t - 1], unname(beta[period[t - 
                  1]] * S[t - 1] * (adj.rho[t - 1] * data$cases[t - 
                  1])^alpha))
            }
            if (pred == "forward") {
                I <- I
                lambda <- min(S[t - 1], unname(beta[period[t - 
                  1]] * S[t - 1] * (I[t - 1])^alpha))
            }
            if (is.nan(lambda) == T) {
                lambda <- 0
            }
            if (method == "deterministic") {
                I[t] <- lambda * rnorm(n = 1, mean = 1, sd = mul.noise.sd)
                if (I[t] < 0 && lambda >= 0) {
                  warning("infected overflow  -- reduce multiplicative noise sd")
                }
            }
            if (method == "negbin") {
                I[t] <- rnbinom(n = 1, mu = lambda, size = I[t - 
                  1] + 1e-10)
            }
            if (method == "pois") {
                I[t] <- rpois(n = 1, lambda = lambda)
            }
            if (epidemics == "cont") {
                I[t] <- I[t]
            }
            if (epidemics == "break") {
                t0s <- epitimes(data, threshold)$start
                if (t %in% t0s) {
                  I[t] <- adj.rho[t] * data$cases[t]
                }
            }
            S[t] <- max(S[t - 1] + data$births[t - 1] - I[t] + 
                rnorm(n = 1, mean = 0, sd = add.noise.sd), 0)
            if (S[t] < 0 && (S[t - 1] + data$births[t - 1] - 
                I[t]) > 0) {
                warning("susceptible overflow  -- reduce additive noise sd")
            }
        }
        res[, ct] <- I/adj.rho
        Sres[, ct] <- S
    }
    res[is.nan(res)] <- 0
    res[res < 1] <- 0
    res <- as.data.frame(res)
    Sres <- as.data.frame(Sres)
    res$mean <- rowMeans(res, na.rm = T)
    res$sd <- apply(res, 1, function(row) sd(row[-1], na.rm = T))
    res$time <- data$time
    Sres$mean <- rowMeans(Sres, na.rm = T)
    Sres$sd <- apply(Sres, 1, function(row) sd(row[-1], na.rm = T))
    Sres$time <- data$time
    res$cases <- data$cases
    obs <- res$cases
    pred <- res$mean
    fit <- lm(pred ~ obs)
    rsquared <- signif(summary(fit)$adj.r.squared, 2)
    return(list(X = X, Y = Y, Yhat = Yhat, contact = contact, 
        period = period, glmfit = glmfit, AIC = glmAIC, beta = head(beta[period], 
            52/IP), rho = adj.rho, pop = pop, Z = Z, sbar = sbar, 
        alpha = alpha, res = res, simS = Sres, loglik = loglik, 
        Smean = Smean, nsim = nsim, rsquared = rsquared, inits.fit = inits.fit, 
        time = data$time, inits.grid = inits.grid, inits = IC))
}
