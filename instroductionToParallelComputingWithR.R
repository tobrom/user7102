
#### MASTER - WORKER (Slave)


install.packages(c("foreach", "doParallel", "doRNG", 
                   "snowFT", "extraDistr", "ggplot2", 
                   "reshape2", "wpp2017"), 
                 dependencies = TRUE)

####

library(foreach)
library(doParallel)
library(doRNG)
library(snowFT)
library(extraDistr)
library(ggplot2)
library(reshape2)
library(wpp2017)

###


library(parallel)
P <- detectCores(logical = FALSE) #only counting physical cores
P


###

cl <- makeCluster(P)
typeof(cl)
length(cl)
cl[[2]]
names(cl[[2]])
stopCluster(cl)
cl[[1]] #gives error since cluster is stopped


####


cl <- makeCluster(P, type = "PSOCK") #default cluster - each worker start wit hempty environment


###

cl <- makeCluster(P)

clusterApply(cl, 1:P, fun = rnorm) # passed to all workers

#when n is larger than p!

res <- clusterApply(cl, rep(100000, 20),
                    fun = function(x) mean(rnorm(x, mean = 5)))

length(res)
head(res)
mean(unlist(res))

#another way to write

myfun <- function(r, mean = 0, sd = 1) {
  mean(rnorm(r, mean = mean, sd = sd))
}


res <- clusterApply(cl, rep(10000, 20),
                    fun = myfun, mean = 5)



####initialization of workers
##each worker corresponds to a freash session start


myrdnorm <- function(r, mean = 0, sd = 1) {
  rdnorm(r, mean = mean, sd = sd)
}


library(extraDistr)
res <- clusterApply(cl, rep(20, 20),
                    fun = myrdnorm, sd = 6)


###will cause an error -> include the library load into the function


myrdnorm2 <- function(r, mean = 0, sd = 1) {
  library(extraDistr)
  rdnorm(r, mean = mean, sd = sd)
}



res <- clusterApply(cl, rep(20, 20),
                    fun = myrdnorm, sd = 6)





##a better way is to use

clusterEvalQ(cl, library(extraDistr))


clusterEvalQ(cl, {
  library(extraDIstr)
  mean <- 10
  sd <- 5
})



###use in order to send to the workers

mean <- 20
mean <- 10


clusterExport(cl, C("mean", "sd"))



####Data partitioning

N <- 1000

ar1pars <- data.frame(
  mu = rnorm(N, 1, 0.1),
  rho = runif(N, 0.95, 0.99),
  sigma = runif(N, 0.01, 0.1)
)


##each task uses one row of the data

myar1 <- function(id, t) {
  pars <- ar1pars[id, ]
  pars$mu + pars$rho * (t - pars$mu) +
    rnorm(100, sd = pars$sigma)
}



clusterExport(cl, "ar1pars")
res <- clusterApply(cl, 1:N, fun = myar1, t = 1)


resmat <- do.call(rbind, res)
                  
dim(resmat)



###higher level functions

parApply(cl, matrix(1:2000,  nrow = 20), 1, sum)



##3previous example can be used with parApply


myar1row <- function(pars, t) {
  pars[1] + pars[2] * (t- pars[1]) +
    rnorm(100, sd = pars[3])
}


res <- parApply(cl, ar1pars, 1, myar1row, t = 1)
dim(res)



####snow package for time calculations and plot

rnmean <- function(r, mean = 0, sd = 1) {
  mean(rnorm(r, mean = mean, sd = sd))
}


N <- 30

set.seed(50)

r.seq <- sample(ceiling(exp(seq(7, 14, length = 50))), N)

head(r.seq, 10)

ctime <- snow.time(clusterApply(cl, r.seq, fun = rnmean))

plot(ctime) # not optimal

ctime <- snow.time(clusterApplyLB(cl, r.seq, fun = rnmean))

plot(ctime)

detach(package:snow) # we don´t want to take the functions from the snow package since they are 
####implemented in the parallel package


----------------------------------------------------------------------------------------
  
#library(snowFT) -> currently not working in RStudio
#Used to 
  
library(snowFT)
  
seed <- 1
res <- performParallel(P, r.seq, fun = rnmean, 
                       seed = seed, cltype = "SOCK")
tail(unlist(res))  
  
##the value with performparallel is that you only use one function for the whole process

#Dynamic resizing - change number of nodes during hte calculation period




---------------------------------------------------------------
  
#library(foreach)
#alternative looping construction

#run sequentially  
    
library(foreach)
n.seq <- sample(1:1000, 10)
res <- foreach(n = n.seq) %do% rnorm(n) #
class(res)
length(res)
length(res[[1]])
  

res <- foreach(n = n.seq, .combine = c) %do% 
  rnorm(n)
length(res)
  
  

res <- foreach(n = rep(100, 10), 
               .combine = rbind) %do% rnorm(n)
dim(res)
res <- foreach(n = rep(100, 10), 
               .combine = "+") %do% rnorm(n)
length(res)

res <- foreach(n = rep(10, 5), m = (1:5)^2, 
               .combine = rbind) %do% rnorm(n, mean = m)
res


#########Parallel backends


library(doParallel)
cl <- makeCluster(3)
registerDoParallel(cl)
res <- foreach(n = rep(10, 5), m = (1:5)^2, 
               .combine = rbind) %dopar% rnorm(n, mean = m)


getDoParWorkers()
getDoParName()



mean <- 20
sd <- 10
myrdnorm <- function(r) 
  rdnorm(r, mean = mean, sd = sd)

res <- foreach(r = rep(1000, 100), .combine = c, 
               .packages = "extraDistr") %dopar% myrdnorm(r)
hist(res)








###number not reproducible by default

set.seed(1)
foreach(n = rep(2, 5), .combine=rbind) %dopar% 
  rnorm(n)


set.seed(1)
foreach(n = rep(2, 5), .combine=rbind) %dopar% 
  rnorm(n)


####in order to have reproduciblity you use
library(doRNG)

set.seed(1)
res1 <- foreach(n = rep(2, 5), 
                .combine=rbind) %dorng% rnorm(n)



set.seed(1)
res2 <- foreach(n = rep(2, 5), 
                .combine=rbind) %dorng% rnorm(n)
identical(res1, res2)


#foreach - vs parallelApply (kind of the )
#parellel backend --> foreach

----------------------------------------------------------
  
#Benchmarking the parallel methods
  
  
dat <- subset(iris, Species != "setosa")

bootstrap <- function(x = NULL) {
  ind <- sample(nrow(dat), 100, replace = TRUE)
  res <- glm(Species ~ ., data = dat[ind,], 
             family = binomial)
  coefficients(res)
}


bootstrap()
bootstrap()  
  
  
  


# using the parallel package
run.parallel <- function(nodes, trials = 100, 
                         seed = 1) {
  cl <- makeCluster(nodes)
  # Export the dat object to workers
  clusterExport(cl, "dat")
  clusterSetRNGStream(cl, seed)
  res <- clusterApply(cl, 1:trials, 
                      fun = bootstrap)
  stopCluster(cl)
  # convert to a matrix
  do.call(rbind, res)
}

# load-balanced version of run.parallel
run.parallelLB <- function(nodes, trials = 100, 
                           seed = 1) {
  cl <- makeCluster(nodes)
  clusterExport(cl, "dat")
  clusterSetRNGStream(cl, seed)
  res <- clusterApplyLB(cl, 1:trials, 
                        fun = bootstrap)
  stopCluster(cl)
  do.call(rbind, res)
}

# using snowFT
run.snowFT <- function(nodes, trials = 100, 
                       seed = 1) {
  res <- performParallel(nodes, 1:trials, 
                         bootstrap, export = "dat", seed = seed)
  do.call(rbind, res)
}


# using foreach
run.foreach <- function(nodes, trials = 100, 
                        seed = 1) {
  cl <- makeCluster(nodes)
  registerDoParallel(cl)
  registerDoRNG(seed)
  res <- foreach(i = 1:trials, .combine = rbind, 
                 .export = c("dat", "bootstrap")) %dopar% 
    bootstrap()
  stopCluster(cl)
  res[,]
}

##same results independently of number of nodes
  
run.snowFT(3, 10)
run.snowFT(4, 10)

run.foreach(5, 10)
run.foreach(10, 10)
  
  
###but not for this

run.parallel(3, 10)
run.parallel(4, 10)


###compare

  
runtime <- function(trials, 
                    nodes = 1:detectCores(), seed = 1, 
                    methods = c("parallel", "parallelLB", 
                                "snowFT", "foreach")) {
  
  tmm <- matrix(NA, nrow = length(nodes), 
                ncol = length(methods),
                dimnames=list(NULL, methods))
  tm <- data.frame(nodes=nodes, tmm)
  
  for(i in 1:nrow(tm)) {
    # sequential run at the end
    if (tm$nodes[i] == 1) next
    # iterate over methods
    for(method in methods) {
      t <- system.time(
        do.call(paste0("run.", method), 
                list(nodes=tm$nodes[i], 
                     trials=trials, seed=seed))
      )
      tm[i, method] <- t["elapsed"]
    }
    print(tm[i,])
  }
  # add time of a sequential run
  if (1 %in% nodes) {
    tm[1, methods] <- system.time(
      run.snowFT(0, trials, seed)
    )["elapsed"]
    # add column with a linear speedup
    tm <- cbind(tm, 
                "linear speedup" = tm[1, "parallel"]/
                  tm$nodes)
  }
  tm
}  
  
  

## for plot 

library(ggplot2)
library(reshape2)
show.runtime <- function(t) {
  tl <- melt(t, id.vars = "nodes", 
             variable.name = "method")
  g <- ggplot(tl, aes(x = nodes, y = value, 
                      color = method)) + 
    geom_line() + ylab("time") +
    scale_x_continuous(
      breaks = sort(unique(tl$nodes)))
  print(g)
}




t <- runtime(50, 1:4)
show.runtime(t)


###fast calculations are better to run sequentially


t <- runtime(1000, c(1,2,4,6))
show.runtime(t)


library(snow)
st <- snow.time(run.parallelLB(6, 1000))
plot(st)

####here we see that most of the time is spent in the master setting up the cluster and communication due to the short calculations
####benchmarking IMPORTANT!




  





