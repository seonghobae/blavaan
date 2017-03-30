set_stanpars <- function(TXT2, partable, nfree, dp, lv.names.x){
    ## tabs
    t1 <- paste(rep(" ", 2L), collapse="")
    t2 <- paste(rep(" ", 4L), collapse="")
    t3 <- paste(rep(" ", 6L), collapse="")
  
    eqop <- "="
    commop <- "// "
    eolop <- ";"
  
    ## parameter assignments separate from priors
    TXT3 <- paste("\n", t1, commop, "Priors", sep="")

    ## parameter numbers that need priors
    partable$freeparnums <- rep(0, length(partable$id))
    matparnums <- rep(0, length(nfree))
    parvecnum <- 0

    ## get free parameter numbers separately for each parameter type
    for(i in 1:nrow(partable)){
        miscignore <- partable$mat[i] == ""

        eqpar <- which(partable$rhs == partable$plabel[i] &
                       partable$op == "==")
        compeq <- which(partable$lhs == partable$label[i] &
                        partable$op %in% c("==", ":=") &
                        grepl("\\+|-|/|\\*|\\(|\\)|\\^", partable$rhs))
        fixed <- partable$free[i] == 0 & partable$op[i] != ":="
        if(length(eqpar) > 0 | length(compeq) > 0 | fixed |
           miscignore){
            next
        } else {
            partype <- match(partable$mat[i], names(nfree))
            matparnums[partype] <- matparnums[partype] + 1
            partable$freeparnums[i] <- matparnums[partype]
        }
    }

    for(i in 1:nrow(partable)){
        if(partable$mat[i] != "" | partable$op[i] == ":="){            
            ## to find equality constraints
            eqpar <- which(partable$rhs == partable$plabel[i] &
                           partable$op == "==")

            ## only complex equality constraints and defined parameters;
            ## rhs needs math expression
            compeq <- which(partable$lhs == partable$label[i] &
                            partable$op %in% c("==", ":=") &
                            grepl("\\+|-|/|\\*|\\(|\\)|\\^", partable$rhs))
            ## TODO check for inequality constraints here?
          
            ## start parameter assignment
            TXT2 <- paste(TXT2, "\n", t1, partable$mat[i], "[",
                          partable$row[i], ",", partable$col[i],
                          ",", partable$group[i], "] ", eqop,
                          " ", sep="")
            if(grepl("rho", partable$mat[i])) TXT2 <- paste(TXT2, "-1 + 2*", sep="")
          
            if(partable$free[i] == 0 & partable$op[i] != ":="){
                if(is.na(partable$ustart[i])){
                    ## exo
                    TXT2 <- paste(TXT2, partable$start[i], eolop,
                                  sep="")
                } else {
                    TXT2 <- paste(TXT2, partable$ustart[i], eolop,
                                  sep="")
                }
            } else if(length(eqpar) > 0){
                eqpar <- which(partable$plabel == partable$lhs[eqpar])
                if(partable$freeparnums[eqpar] == 0){
                    eqtxt <- paste(partable$mat[eqpar], "[",
                                   partable$row[eqpar], ",",
                                   partable$col[eqpar], ",",
                                   partable$group[eqpar], "]",
                                   eolop, sep="")
                } else {
                    eqtxt <- paste(partable$mat[eqpar], "free[",
                                   partable$freeparnums[eqpar],
                                   "]", eolop, sep="")
                }

                vpri <- grepl("\\[var\\]", partable$prior[eqpar])
                spri <- grepl("\\[sd\\]", partable$prior[eqpar])
                if(!vpri & (grepl("theta", partable$mat[i]) | grepl("psi", partable$mat[i]))){
                    sq <- ifelse(spri, "2", "-1")
                    TXT2 <- paste(TXT2, "pow(", eqtxt, ",", sq,
                                  ")", eolop, sep="")
                } else {
                    TXT2 <- paste(TXT2, eqtxt, sep="")
                }
            } else if(length(compeq) > 0){
                ## constraints with one parameter label on lhs
                ## FIXME? cannot handle, e.g., b1 + b2 == 2
                ## see lav_partable_constraints.R
                rhsvars <- all.vars(parse(file="",
                                          text=partable$rhs[compeq]))
                pvnum <- match(rhsvars, partable$label)

                rhstrans <- paste(partable$mat[pvnum], "free[",
                                  partable$freeparnums[pvnum], "]",
                                  sep="")

                jageq <- partable$rhs[compeq]
                for(j in 1:length(rhsvars)){
                    jageq <- gsub(rhsvars[j], rhstrans[j], jageq)
                }
                ## FIXME? no longer needed?
                ##jageq <- gsub("[", "parvec[", jageq, fixed = TRUE)

                TXT2 <- paste(TXT2, jageq, eolop, sep="")
            } else {
                ## needs a prior
                TXT3 <- paste(TXT3, "\n", t1, partable$mat[i], "free[",
                              partable$freeparnums[i], "]", sep="")
                if(partable$prior[i] == ""){
                    if(partable$mat[i] == "lvrho"){
                        partype <- grep("rho", names(dp))
                    } else if(grepl("star", partable$mat[i])){
                        pname <- paste("i", strsplit(partable$mat[i], "star")[[1]][1], sep="")
                        partype <- grep(pname, names(dp))
                    } else {
                        partype <- grep(partable$mat[i], names(dp))
                    }
                    if(length(partype) > 1) partype <- partype[1] # due to psi and ibpsi
                    partable$prior[i] <- dp[partype]
                }
                jagpri <- strsplit(partable$prior[i], "\\[")[[1]][1]
                vpri <- grepl("\\[var\\]", partable$prior[i])
                spri <- grepl("\\[sd\\]", partable$prior[i])
                if(!vpri & (grepl("theta", partable$mat[i]) | grepl("psi", partable$mat[i]))){
                    sq <- ifelse(spri, "2", "-1")
                    TXT2 <- paste(TXT2, "pow(", partable$mat[i], "free[",
                                  partable$freeparnums[i], "],", sq,
                                  ")", eolop, sep="")
                } else {
                    TXT2 <- paste(TXT2, partable$mat[i], "free[",
                                  partable$freeparnums[i],
                                  "]", eolop, sep="")
                }
                TXT3 <- paste(TXT3, " ~ ", jagpri, eolop, sep="")
            }
        }
    }

    list(TXT2 = TXT2, TXT3 = TXT3, partable = partable)
}