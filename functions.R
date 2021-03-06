load.pkgs <- function(pkgs.list){
  req.pkgs <- unlist(pkgs.list)
  invisible(lapply(req.pkgs, require, 
                   quietly = TRUE, 
                   warn.conflicts = FALSE, 
                   character.only = TRUE))
}

makeFormula <- function(X, y){
  y <- data.frame(y)
  X <- data.frame(X)
  as.formula(paste(names(y), paste(names(X), collapse = '+'), sep = '~'))
}

getFaced <- function(faceMat, n.faces = as.matrix(1:1), 
                     facet.ncol = floor(sqrt(length(n.faces)))) {
  if (is.vector(faceMat)) {
    faceMat <- as.matrix(faceMat)
  }
  face.dim <- sqrt(nrow(faceMat))
  faceGrid <- expand.grid(x = face.dim:1, y = face.dim:1)
  faceGrid <- data.frame(faceGrid, Face = faceMat[, n.faces])
  faceStack <- melt(faceGrid, c('x', 'y'))
  
  plt <- ggplot(faceStack, aes_string('y', 'x', fill = 'value')) + 
    geom_tile() + 
    facet_wrap(~variable, ncol = facet.ncol) +
    scale_fill_continuous(low = 'black', high = 'white') +
    theme_bw() + theme(axis.title = element_blank(),
                       axis.text = element_text(size = 6),
                       legend.position = 'none')
  print(plt)
}

getScored <- function(scoreMat, ncomp, which = c(1,2), attr.df = NULL, 
                      col.var = NULL, shape.var = NULL){
  require(data.table)
  if (!is.null(attr.df)) {
    scores.dt <- data.table(scoreMat[,], attr.df)
  } else {
    scores.dt <- data.table(scoreMat[,])
  } 
  pc.n <- names(scores.dt[, which, with = F])
  ggplot(scores.dt, aes_string(pc.n[1], pc.n[2])) + 
    geom_point(aes_string(color = col.var, shape = shape.var)) +
    theme_bw() +
    theme(legend.title = element_blank(),
          legend.position = 'top') +
    geom_vline(xintercept = 0, col = 'blue', linetype = 2) +
    geom_hline(yintercept = 0, col = 'blue', linetype = 2)
}

getGrided <- function(gp.lst, ncol = floor(sqrt(length(gp.lst)))){
  gp.lst$ncol <- ncol
  do.call(gridExtra::grid.arrange, gp.lst)
}

getClassified <- function(fitted.value, original.value, 
                          rule = function(x){ifelse(x < 0, -1, 1)}){
  classified.value = rule(fitted.value)
  confusion.matrix = table(classified.value, original.value)
  errors <- confusion.matrix[row(confusion.matrix) != col(confusion.matrix)]
  error.rate = sum(errors) / sum(confusion.matrix)
  dimnames(confusion.matrix) <- list(Classified = c('Male', 'Female'), 
                                     Original = c('Male', 'Female'))
  
  class.plt <- ggplot(as.data.frame(confusion.matrix), 
                      aes(Original, y = Freq, fill = Classified)) + 
    geom_bar(stat = 'identity', size = 0.5) + 
    theme_bw() + theme(legend.position = 'top',
                       axis.title.y = element_blank()) + 
    coord_flip() + 
    labs(y = 'Frequency')
  
  return(invisible(list(classified.value = classified.value,
                        confusion.matrix = confusion.matrix,
                        conf.plot = class.plt,
                        error.rate = error.rate)))
}

plotRMSEP <- function(rmsep.obj, h.just = -.2){
  df <- adply(rmsep.obj$val, 3)[-1, ]
  df[, 1] <- as.numeric(df[, 1]) - 1
  names(df) <- c('Comp', 'CV', 'adjCV')
  
  df.stk <- melt(df, 1, variable.name = 'CV', value.name = 'RMSEP')
  df.stk.min <- ddply(df.stk, .(CV), dplyr::filter, RMSEP == min(RMSEP))
  
  ### Generating Plot
  plt <- ggplot(df.stk, aes(Comp, RMSEP, group = CV, color = CV)) + 
    geom_line(aes(linetype = CV)) + theme_bw() +
    theme(axis.text.x = element_blank(),
          axis.ticks.x = element_blank(),
          legend.position = 'top',
          legend.title = element_blank()) +
    labs(x = 'Principal Components') +
    geom_vline(data = df.stk.min, aes(xintercept = Comp), 
               color = 'blue', linetype = 2) + 
    annotate(geom = 'text', x = df.stk.min$Comp, 
             y = unlist(daply(df.stk, .(CV), summarize, median(RMSEP))), 
             label = paste(df.stk.min$CV, ':', 
                           round(df.stk.min$RMSEP, 2)), 
             hjust = h.just, vjust = c(-3.5,-1.5), 
             size = 3) +
    annotate('text', mean(df.stk.min$Comp), max(df.stk$RMSEP), 
             label = paste('Min Comp:', df.stk.min$Comp[1]), 
             size = 4, hjust = h.just + 0.5)
  return(plt)
}

getDB <- function(score.df, grid.size, da.fit, n.comp){
  gs <- grid.size
  da.fit <- update(da.fit, data = model.frame(da.fit)[, c(1, n.comp + 1)])
  mmpc <- ldply(c(min, max), function(x) 
    apply(score.df[, n.comp, with = F], 2, x))
  rownames(mmpc) <- c('min', 'max')
  
  gsamp <- llply(seq_along(n.comp), function(x){
    seq(mmpc["min", names(score.df[, n.comp, with = F])[x]], 
        mmpc["max", names(score.df[, n.comp, with = F])[x]], 
        length.out = gs)
  })
  names(gsamp) <- names(score.df[, n.comp, with = F])
  gdf <- do.call(expand.grid, gsamp)
  yhat <- as.numeric(as.character(predict(da.fit, gdf)$class))
  qda.db <- data.frame(gdf, z = yhat)
  return(qda.db)
}

## From Hadley Wickham (github)
grid_arrange_shared_legend <- function(..., ncol = 1) {
  plots <- list(...)
  g <- ggplotGrob(plots[[1]] + theme(legend.position = "top"))$grobs
  legend <- g[[which(sapply(g, function(x) x$name) == "guide-box")]]
  lheight <- sum(legend$height)
  plt.lst <- lapply(plots, function(x) x + theme(legend.position = "none"))
  plt.lst$ncol <- ncol
  grid.arrange(
    legend,
    do.call(arrangeGrob, plt.lst),
    ncol = 1,
    heights = unit.c(lheight, unit(1, "npc") - lheight))
}


colorScorePlot <- function(Comps, Groups) {
  Comps <- unlist(Comps); Groups <- as.character(Groups)
  if (Groups == 'Gender')
    qdb <- getDB(pca.scr.df, grid.size = 25, 
                 da.fit = qda.fit.gender, n.comp = Comps)
  if (Groups == 'Shoulder')
    qdb <- getDB(pca.scr.df, grid.size = 25, 
                 da.fit = qda.fit.shoulder, n.comp = Comps)
  plt <- getScored(scores(pc.a), ncomp = 1:3, 
                   which = Comps, 
                   attr.df = attr.df, 
                   col.var = Groups) 
  plt <- plt + geom_contour(data = qdb, 
                            aes_string(paste('PC', Comps, sep = ''), 
                                       z = 'z'), 
                            bins = 1)
}

plot.basis <- function(basis.obj, n = 1000){
  require(ggplot2); require(reshape2)
  get.bounds <- attr(basis.obj, 'Boundary.knots')
  x.seq <- seq(get.bounds[1], get.bounds[2], length.out = n)
  pred.bs <- predict(basis.obj, newx = x.seq)
  dt <- data.table(x = x.seq, bs = pred.bs)
  dt.stk <- melt(dt, 1, value.name = 'y', variable.name = 'BasisFun')
  plt <- ggplot(dt.stk, aes(x, y, group = BasisFun, color = BasisFun)) + 
    geom_line() + theme_bw() +
    scale_color_discrete(guide = FALSE) +
    theme(axis.title = element_blank())
  return(plt)
}

plot.basisfd <- function(fd.basis.obj, n = 1000){
  require(ggplot2); require(reshape2)
  get.bounds <- fd.basis.obj$rangeval
  x.seq <- seq(get.bounds[1], get.bounds[2], length.out = n)
  # browser()
  pred.bs <- predict(fd.basis.obj, newdata = x.seq)
  dt <- data.table(x = x.seq, bs = pred.bs)
  dt.stk <- melt(dt, 1, value.name = 'y', variable.name = 'BasisFun')
  plt <- ggplot(dt.stk, aes(x, y, group = BasisFun, color = BasisFun)) + 
    geom_line() + theme_bw() +
    scale_color_discrete(guide = FALSE) +
    theme(axis.title = element_blank())
  return(plt)
}