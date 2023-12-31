# Need to run 5.9-order-level-posteriors.R first
# Plot the posteriors from the taxonomic order-only
# hierarchical beta regression 

source("add_phylopic.R") # modifed from Scott's rphylopic package
subtext_col <- "grey50"

class_cols <- lu[, c("taxonomic_class", "col")]
class_cols <- class_cols[!duplicated(class_cols), ]

a_df <- plyr::join(a_df, class_cols, by = "taxonomic_class")

# get silhouette images:
or <- read.table("orders.csv", stringsAsFactors = FALSE, header = TRUE)
or <- mutate(or,
  hash = gsub("http://phylopic.org/image/([0-9a-z-]+)/", "\\1", url),
  svg_url = paste0("http://phylopic.org/assets/images/submissions/",
    hash, ".svg"),
  png_url = paste0("http://phylopic.org/assets/images/submissions/",
    hash, ".256.png"),
  scaling_factor = rep(1, nrow(or)))
or[or$taxonomic_order == "Gadiformes", "scaling_factor"] <- 0.6
or[or$taxonomic_order == "Salmoniformes", "scaling_factor"] <- 0.9
or[or$taxonomic_order == "Perciformes", "scaling_factor"] <- 0.6
or[or$taxonomic_order == "Pleuronectiformes", "scaling_factor"] <- 0.8
or[or$taxonomic_order == "Falconiformes", "scaling_factor"] <- 0.8
or[or$taxonomic_order == "Charadriiformes", "scaling_factor"] <- 0.8

# to get ordering right:
or <- plyr::join(a_df[,c("taxonomic_order", "sorted_order")], or)

# get citation details:
if(!file.exists("phylopic-metadata.rds")) {
  or_temp <- plyr::ldply(seq_len(nrow(or)), function(i) {
    temp <- rphylopic::image_get(uuid = or$hash[i], options = c("credit", "licenseURL"))
    temp <- lapply(temp, function(x) ifelse(is.null(x), "", x))
    data.frame(credit = temp$credit, licenseURL = temp$licenseURL)
  })
  saveRDS(or_temp, file = "phylopic-metadata.rds")
} else {
  or_temp <- readRDS("phylopic-metadata.rds")
}
or <- data.frame(or, or_temp)

library("xtable")
or_table <- or[ ,c("taxonomic_order", "credit", "licenseURL", "url")]
or_table$licenseURL <- paste0("\\url{", or_table$licenseURL, "}")
or_table$url <- paste0("\\url{", or_table$url, "}")
or_table$credit <- gsub("&", "and", or_table$credit)
names(or_table) <- c("Taxonomic order", "Credit", "License URL", "URL")
or_table$URL <- NULL # don't use after all

# print.xtable(xtable(or_table, caption = ""),
#   include.rownames = FALSE, file = "phylopic.tex", booktabs = TRUE,
#   sanitize.text.function = identity, only.contents = TRUE, timestamp = NULL)
#
# if(any(!file.exists(paste0("silhouettes/", or$taxonomic_order, ".png")))) {
#   for(i in 1:nrow(or)) {
#     download.file(or$png_url[i],
#       destfile = paste0("silhouettes/", or$taxonomic_order[i], ".png"))
#   }
# }

op <- vector(mode = "list", length = nrow(a_df))
for(i in seq_along(op)) {
  op[[i]]$taxonomic_order <- a_df$taxonomic_order[i]
  op[[i]]$n_pops <- a_df$n_pops[i]
  op[[i]]$order_id <- a_df$order_id[i]
  op[[i]]$class_id <- a_df$class_id[i]
  op[[i]]$taxonomic_class <- a_df$taxonomic_class[i]
  op[[i]]$col <- a_df$col[i]
  op[[i]]$img <- png::readPNG(paste0("silhouettes/", or$taxonomic_order[i], ".png"))
}

for(i in seq_along(op)) {
  op[[i]]$post <- plogis(mu_a +
      a_order[, op[[i]]$order_id] +
      a_class[, op[[i]]$class_id])
  op[[i]]$dens <- density(op[[i]]$post,
    from = quantile(op[[i]]$post, probs = 0.001)[[1]],
    to = quantile(op[[i]]$post, probs = 0.999)[[1]])
  op[[i]]$med_post <- median(op[[i]]$post)
  op[[i]]$med_dens_height <-
    op[[i]]$dens$y[max(which(op[[i]]$dens$x < op[[i]]$med_post))]
}

x <- rexp(2e6, 0.01)
x <- x[x > 2]
prior_p10 <- length(x[x < 10])/length(x)

pdf("order-posteriors-covariates.pdf", width = 3.1, height = 5.65)
layout(mat =c(rep(1, 9), rep(2, 4)))
par(mar = c(4.1,2,1.4,0), oma = c(0.2, 5.9, 0, 0.8),
  tck = -0.04, mgp = c(2, 0.5, 0), col.axis = "grey25", col = "grey25")
par(cex = 0.8)

#############################
# the order-level intercepts:
par(tck = -0.02)

xlim <- c(-.025, 0.29)
plot(1, 1, xlim = xlim, ylim = c(1, length(op)), type = "n",
  ylab = "", xlab = "", axes = FALSE, xaxs = "i")
abline(v = prior_p10, lty = 2, col = "grey40", lwd = 0.6)
scaling_factor <- 63
for(i in seq_along(op)) {
  polygon(c(op[[i]]$dens$x, rev(op[[i]]$dens$x)),
    i + c(op[[i]]$dens$y/scaling_factor, -rev(op[[i]]$dens$y/scaling_factor)),
    border = "grey50", lwd = 0.5, col = "white")
  polygon(c(op[[i]]$dens$x, rev(op[[i]]$dens$x)),
    i + c(op[[i]]$dens$y/scaling_factor, -rev(op[[i]]$dens$y/scaling_factor)),
    border = "grey50", lwd = 1, col = paste0(op[[i]]$col, "90"))
  segments(
    op[[i]]$med_post,
    i - op[[i]]$med_dens_height/scaling_factor,
    op[[i]]$med_post,
    i + op[[i]]$med_dens_height/scaling_factor,
    col = "grey50", lwd = 1)
  par(xpd = NA)
  add_phylopic(op[[i]]$img, alpha = 1, x = 0.004, y = i,
    ysize = 0.9 * or$scaling_factor[i], xy_ratio = 35, color = "grey45")
  par(xpd = FALSE)
}

axis(2, at = seq_along(op),
  labels = as.character(unlist(lapply(op, function(x) x$taxonomic_order))),
  las = 1, lwd = 0, line = -0.6)
axis(1, at = seq(0, 0.3, 0.1), mgp = c(2, 0.3, 0))
mtext("Probability of black swans", side = 1, line = 1.8, cex = 0.8)
mtext(quote(Pr(nu<10)), side = 1, line = 3, cex = 0.8, col = subtext_col)
mtext("A", side = 3, line = 0, cex = 1.2, adj = -0.6, font = 2)

################
# the main coefficients:
m <- readRDS("beta-stan-samples.rds") # or reload this

means <- plyr::laply(extract(m), mean)[1:5]
ord <- order(means)

coefs <- c(expression(Productivity~(lambda)), expression(Density~dep.~(b)),
  expression(Process~noise~log(sigma)),
  expression(log(Time~steps)), expression(log(Lifespan)))

plot(1, 1, xlim = c(-1, 1), ylim = c(0.5, 5.5), main = "", axes = FALSE, yaxs = "i",
  type = "n", yaxs = "i", yaxt = "n", xlab = "", ylab = "")
scaling_factor <- 8

abline(v = 0, lty = 2, col = "grey60")
j <- 0
for(i in ord) {
  j <- j + 1
  em <- extract(m)[[i]]
  x <- density(em,
    from = quantile(em, probs = 0.0001),
    to = quantile(em, probs = 0.9999))

  x_med <- median(em)
  x_med_dens_height <- x$y[max(which(x$x < x_med))]

  polygon(c(x$x, rev(x$x)),
    j + c(x$y/scaling_factor, -rev(x$y/scaling_factor)),
    border = "grey50", lwd = 1, col = "grey90")
  segments(
    x_med,
    j - x_med_dens_height/scaling_factor,
    x_med,
    j + x_med_dens_height/scaling_factor,
    col = "grey50", lwd = 1)
}
axis(1, mgp = c(2, 0.3, 0), tck = -0.045)
axis(2, at = 1:5, labels = coefs[ord], las = 1, lwd = 0, line = -0.6)

mtext("Coefficient value", side = 1, line = 1.55,
  cex = 0.8, outer = FALSE)
mtext("(per 2 SDs of predictor)", side = 1, line = 2.6,
  cex = 0.8, outer = FALSE, col = subtext_col)
mtext("B", side = 3, line = 0.5, cex = 1.2, adj = -0.6, font = 2)


dev.off()
