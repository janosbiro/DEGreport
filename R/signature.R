.get_counts <- function(c, slot){
    if (class(c) == "bcbioRNASeq")
        return(counts(c, "rlog"))
    if (class(c) == "DESeqDataSet")
        return(counts(c, normalized = TRUE))
    if (class(c) %in% c("SummarizedExperiment", "RangedSummarizedExperiment"))
        return(assays(c)[[slot]])
    if (class(c) == "data.frame")
        return(c)
    if (class(c) == "matrix")
        return(as.data.frame(c))
    stop("class ", class(c), " no supported.")
}

.get_meta <- function(c){
    if (class(c) %in% c("bcbioRNASeq", "DESeqDataSet",
                        "SummarizedExperiment", "RangedSummarizedExperiment"))
        return(data.frame(colData(c), stringsAsFactors = FALSE))
    return(NULL)
}

#' Plot gene signature for each group and signature
#' 
#' Given a list of genes beloging to a different classes, like
#' markers, plot for each group, the expression values for all the samples.
#' 
#' @param counts expression data. It accepts bcbioRNASeq, DESeqDataSet and
#'   SummarizedExperiment. As well, data.frame or matrix is supported, but
#'   it requires metadata in that case.
#' @param signature data.frame with two columns: a) genes that match
#'   row.names of counts, b) label to classify the gene inside a group.
#'   Normally, cell tissue name.
#' @param group character in metadata used to split data into different
#'   groups.
#' @param metadata data frame with sample information. Rownames
#'   should match \code{ma} column names
#'   row number should be the same length than p-values vector.
#' @param slot slotName in the case of SummarizedExperiment objects.
#' @param scale Whether to scale or not the expression.
#' @return ggplot plot.
#' @examples
#' data(humanGender)
#' data(geneInfo)
#' degSignature(humanGender, geneInfo, group = "group")
#' @export
degSignature <- function(counts, signature,
                         group = NULL, metadata = NULL,
                         slot = 1, scale = FALSE){
    c <- .get_counts(counts, slot)
    if (scale)
        c <- t(scale(t(c)))
    meta <- .get_meta(counts)
    if (is.null(meta))
        meta <- metadata
    stopifnot(group %in% colnames(meta))

    names(signature) <- c("gene", "signature")
    common <- intersect(row.names(c), signature[["gene"]])
    c[common, ] %>%  as.data.frame() %>% rownames_to_column("id") %>% 
        melt() %>%  data.frame(., stringsAsFactors = FALSE) %>% 
        set_colnames(c("gene", "sample", "expression")) %>% 
        mutate_if(is.factor, as.character) %>% 
        left_join(meta %>% rownames_to_column("degsample") %>% 
                      mutate_if(is.factor, as.character),
                  by = c("sample" = "degsample")) %>%
        left_join(signature %>% 
                      mutate_if(is.factor, as.character), by = "gene") %>% 
        group_by(!!sym(group), signature, sample) %>% 
        summarise(median = median(expression)) %>% 
        ungroup %>% 
        ggplot(aes_string(x = group, y = "median", color = "signature")) +
        geom_boxplot() +
        geom_jitter() +
        facet_wrap(~signature)
}
