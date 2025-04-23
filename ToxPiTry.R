install.packages("toxpiR")

library(toxpiR)

# txp_example_input <- data.frame(
#                     chemical_name = c("chem1", "chem2", "chem3", "chem4", "chem5"),
#                     metric = c(1:5),
#                     stringsAsFactors = FALSE
#                 )
data(txp_example_input, package = "toxpiR")
head(txp_example_input)
