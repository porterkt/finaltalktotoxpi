args <- commandArgs(trailingOnly = TRUE)
input_file <- args[1]

#Reads input CSV
dtxsidlist <- read.csv(input_file, stringsAsFactors = FALSE)

#ChatGPT used here to debug
library(httr)
library(jsonlite)
my_key <- "ff28b69b-9007-468f-9bff-5bb27e13c051"
chemicalnamelist <- c()

#Debugging DTXSID list if needed
#dtxsidlist <- c("DTXSID7020182", "DTXSID9020112", "DTXSID9023049", "DTXSID0020232", "DTXSID3039242")

#Retrieve official chemical name for dtxsid
for (dtxsid in dtxsidlist) {
  base_url <- "https://api-ccte.epa.gov/chemical/search/equal"
  url <- paste0(base_url, "/", dtxsid)

  #Uses httr documentation thru curl
  response <- GET(url, 
                  add_headers(
                    "accept" = "application/json",
                    "x-api-key" = my_key
                  ))

  if (status_code(response) == 200) {
    data <- fromJSON(content(response, "text", encoding = "UTF-8"))
    chemical_name <- data$preferredName
    chemicalnamelist <- c(chemicalnamelist, chemical_name)
  } else {
    print(paste("Error:", status_code(response)))
  }
}

if ((length(chemicalnamelist) <= 0) || (length(chemicalnamelist) > 5)) {
  print("Error: Improper Amount of Chemicals Submitted.")
}

chem_name1 <- chemicalnamelist[1]
chem_name2 <- chemicalnamelist[2]
chem_name3 <- chemicalnamelist[3]
chem_name4 <- chemicalnamelist[4]
chem_name5 <- chemicalnamelist[5]

#Code below sourced from https://api-ccte.epa.gov/docs/chemical.html
#Downloads necessary packages
library(dplyr)
if (!library(devtools, logical.return = TRUE)) {
  install.packages("devtools")
  library(devtools)
}
if (!require("ctxR")) {
  devtools::install_github("USEPA/ctxR", force = TRUE)
  library(ctxR)
}
#Remembers API Key and stores it for all sessions
register_ctx_api_key(key = "ff28b69b-9007-468f-9bff-5bb27e13c051", write = TRUE)
my_key <- ctx_key()

#load("variables.RData")
dtxsid1 = found_dtx[0]
dtxsid2 = found_dtx[1]
dtxsid3 = found_dtx[2]
dtxsid4 = found_dtx[3]
dtxsid5 = found_dtx[4]
dtxsidlist <- c(dtxsid1, dtxsid2, dtxsid3, dtxsid4, dtxsid5)

bioactivitytoxdata1 <- get_bioactivity_details(dtxsid1)
bioactivitytoxdata2 <- get_bioactivity_details(dtxsid2)
bioactivitytoxdata3 <- get_bioactivity_details(dtxsid3)
bioactivitytoxdata4 <- get_bioactivity_details(dtxsid4)
bioactivitytoxdata5 <- get_bioactivity_details(dtxsid5)

#one column with hitc (AC50) (multiply by binary hit if needed)
if ("hitc" %in% colnames(bioactivitytoxdata1)) {
  toxpidata1 <- select(bioactivitytoxdata1, c("aeid", "hitc"))
  toxpidata1$aeid <- toxpidata1$aeid * toxpidata1$hitc
  colnames(toxpidata1) <- c("aeid", chem_name1)
}

if ("hitc" %in% colnames(bioactivitytoxdata2)) {
  toxpidata2 <- select(bioactivitytoxdata2, c("aeid", "hitc"))
  toxpidata2$aeid <- toxpidata2$aeid * toxpidata2$hitc
  colnames(toxpidata2) <- c("aeid", chem_name2)
}

if ("hitc" %in% colnames(bioactivitytoxdata3)) {
  toxpidata3 <- select(bioactivitytoxdata3, c("aeid", "hitc"))
  toxpidata3$aeid <- toxpidata3$aeid * toxpidata3$hitc
  colnames(toxpidata3) <- c("aeid", chem_name3)
}

if ("hitc" %in% colnames(bioactivitytoxdata4)) {
  toxpidata4 <- select(bioactivitytoxdata4, c("aeid", "hitc"))
  toxpidata4$aeid <- toxpidata4$aeid * toxpidata4$hitc
  colnames(toxpidata4) <- c("aeid", chem_name4)
}

if ("hitc" %in% colnames(bioactivitytoxdata5)) {
  toxpidata5 <- select(bioactivitytoxdata5, c("aeid", "hitc"))
  toxpidata5$aeid <- toxpidata5$aeid * toxpidata5$hitc
  colnames(toxpidata5) <- c("aeid", chem_name5)
}

library(dplyr)
library(tidyr)

#This code block fills each toxpidata set with all the aeids necessary and sets any missing data = 0
toxpidata_list <- list(toxpidata1,
                       toxpidata2, toxpidata3, toxpidata4, toxpidata5)
max_aeid <- max(sapply(toxpidata_list, function(df) max(df$aeid, na.rm = TRUE)))
full_aeid <- data.frame(aeid = 1:max_aeid)
fill_missing_aeids <- function(df) {
  chem_col <- colnames(df)[2]
  df <- full_aeid %>%
    left_join(df, by = "aeid") %>%
    replace_na(setNames(list(0), chem_col))
  return(df)
}

#Apply function to all datasets
toxpidata1 <- fill_missing_aeids(toxpidata1)
toxpidata2 <- fill_missing_aeids(toxpidata2)
toxpidata3 <- fill_missing_aeids(toxpidata3)
toxpidata4 <- fill_missing_aeids(toxpidata4)
toxpidata5 <- fill_missing_aeids(toxpidata5)

# List of ToxPi dataframes
frames <- list(toxpidata1, toxpidata2, toxpidata3, toxpidata4, toxpidata5)

#Find all unique aeid values
all_aeids <- unique(do.call(c, lapply(frames, function(frame) frame$aeid)))

#Ensure all toxpidata frames have the same aeid values
for (i in seq_along(frames)) {
  frames[[i]] <- right_join(frames[[i]], data.frame(aeid = all_aeids), by = "aeid") %>%
    mutate(across(everything(), ~ replace_na(., 0)))
  
  #Rename "chemicalname" column to avoid conflicts
  names(frames[[i]])[names(frames[[i]]) == "chem_name"] <- paste0("chem_name_", i)
}

#Merge all datasets with a loop
toxpidata <- frames[[1]]
for (i in 2:length(frames)) {
  toxpidata <- full_join(toxpidata, frames[[i]], by = "aeid", relationship = "many-to-many")
}

library(tidyverse)

#Transpose data
toxpidata_t <- toxpidata %>%
  pivot_longer(cols = -aeid, names_to = "Assays", values_to = "Value") %>%
  pivot_wider(names_from = aeid, values_from = Value, names_glue = "aeid{aeid}")

#Flatten columns
toxpidata_t_clean <- toxpidata_t %>%
  mutate(across(where(is.list), ~sapply(., function(x) mean(unlist(x), na.rm = TRUE))))

toxpidata_t_clean <- toxpidata_t %>%
  group_by(Assays) %>%
  summarise(across(where(is.list), ~mean(unlist(.), na.rm = TRUE)))

#Write to CSV
write.csv(toxpidata_t_clean, "trytoxpidata.csv", row.names = FALSE)

#Now that we have toxpidata, use toxpi to create slices and do necessary transformations
library(readr)
install.packages("toxpiR")
library(toxpiR)

#DOCUMENTATION FOR Slicing Data if CSV File is Inaccessible
# f.slices <- TxpSliceList(Slice1 = TxpSlice("aeid806"),
#                          Slice2 = TxpSlice(c("aeid2364")),
#                          Slice3 = TxpSlice(c("aeid781")),
#                          Slice4 = TxpSlice(c("aeid764", "aeid788", "aeid1659", "aeid2047", "aeid2055", "aeid2068", "aeid2211", "aeid2222", "aeid2363")), 
#                          Slice5 = TxpSlice(c("aeid2365")), 
#                          Slice6 = TxpSlice(c("aeid765", "aeid789", "aeid794", "aeid804", "aeid1661", "aeid1816", "aeid2049", "aeid2053", "aeid2057", "aeid2070", "aeid2223")), 
#                          Slice7 = TxpSlice(c("aeid769", "aeid770", "aeid771", "aeid772", "aeid773", "aeid774", "aeid775", "aeid776", "aeid777", "aeid778", "aeid779", "aeid780")), 
#                          Slice8 = TxpSlice(c("aeid68", "aeid87", "aeid88", "aeid89", "aeid90", "aeid109", "aeid110", "aeid121", "aeid124", "aeid127", "aeid128", "aeid129", "aeid130")), 
#                          Slice9 = TxpSlice(c("aeid1614", "aeid1621", "aeid1630", "aeid1637", "aeid1646", "aeid1653")), 
#                          Slice10 = TxpSlice(c("aeid740", "aeid741", "aeid742", "aeid743", "aeid744", "aeid745", "aeid746", "aeid747", "aeid753", "aeid754", "aeid755", "aeid756", "aeid757", "aeid758", "aeid2386", "aeid2387", "aeid2390", "aeid2391")), 
#                          Slice11 = TxpSlice(c("aeid614", "aeid618", "aeid621", "aeid624", "aeid625", "aeid626", "aeid629", "aeid630", "aeid631", "aeid632", "aeid633", "aeid635", "aeid641", "aeid649", "aeid651", "aeid652", "aeid655", "aeid658", "aeid659", "aeid666", "aeid673", "aeid674", "aeid679", "aeid680", "aeid681", "aeid685")), 
#                          Slice12 = TxpSlice(c("aeid687", "aeid689", "aeid693", "aeid694", "aeid695", "aeid697", "aeid699", "aeid702", "aeid705")), 
#                          Slice13 = TxpSlice(c("aeid728")),
#                          Slice14 = TxpSlice(c("aeid708", "aeid709", "aeid710", "aeid711", "aeid713", "aeid714", "aeid715", "aeid716", "aeid717", "aeid718", "aeid719", "aeid720", "aeid721", "aeid722", "aeid724", "aeid725", "aeid726", "aeid727")), 
#                          Slice15 = TxpSlice(c("aeid1508", "aeid1848")),
#                          Slice16 = TxpSlice(c("aeid706", "aeid707", "aeid730", "aeid732", "aeid733", "aeid736", "aeid738")), 
#                          Slice17 = TxpSlice(c("aeid2529", "aeid2530", "aeid2540", "aeid2541")), 
#                          Slice18 = TxpSlice(c("aeid891", "aeid893", "aeid895", "aeid897", "aeid899", "aeid901", "aeid905", "aeid907", "aeid909", "aeid913", "aeid915")), 
#                          Slice19 = TxpSlice(c("aeid1831")),
#                          Slice20 = TxpSlice(c("aeid1827", "aeid1829", "aeid1833", "aeid1835", "aeid2782", "aeid2784", "aeid2785", "aeid2786", "aeid2787", "aeid2788", "aeid2789", "aeid2790", "aeid2791", "aeid2792")), 
#                          Slice21 = TxpSlice(c("aeid1372", "aeid1373", "aeid1374", "aeid1375", "aeid1376", "aeid1377", "aeid1378", "aeid1379", "aeid1380", "aeid1381", "aeid1382", "aeid1383", "aeid1384", "aeid1385", "aeid1386", "aeid1387", "aeid1388", "aeid1389", "aeid1507", "aeid1797")), 
#                          Slice22 = TxpSlice(c("aeid2454", "aeid2456", "aeid2458", "aeid2460", "aeid2462", "aeid2464", "aeid2468", "aeid2470", "aeid2472", "aeid2474", "aeid2476", "aeid2478", "aeid2480", "aeid2482")), 
#                          Slice23 = TxpSlice(c("aeid2494", "aeid2496", "aeid2498", "aeid2500", "aeid2502", "aeid2504", "aeid2506", "aeid2508", "aeid2510", "aeid2512", "aeid2514", "aeid2516", "aeid2518", "aeid2520", "aeid2522", "aeid2524", "aeid2526")), 
#                          Slice24 = TxpSlice(c("aeid319", "aeid321", "aeid329", "aeid331", "aeid333", "aeid337", "aeid343", "aeid349", "aeid355", "aeid357", "aeid361", "aeid363", "aeid365", "aeid369", "aeid375", "aeid377")), 
#                          Slice25 = TxpSlice(c("aeid3032")),
#                          Slice26 = TxpSlice(c("aeid441")),
#                          Slice27 = TxpSlice(c("aeid561")),
#                          Slice28 = TxpSlice(c("aeid421", "aeid429", "aeid435", "aeid439", "aeid443", "aeid457", "aeid463", "aeid465", "aeid473", "aeid475", "aeid477", "aeid501", "aeid503", "aeid505", "aeid513", "aeid557", "aeid571", "aeid573", "aeid575", "aeid577", "aeid579")), 
#                          Slice29 = TxpSlice(c("aeid583", "aeid585", "aeid603")), 
#                          Slice30 = TxpSlice(c("aeid521", "aeid523", "aeid525", "aeid527", "aeid547", "aeid549")), 
#                          Slice31 = TxpSlice(c("aeid411", "aeid487", "aeid489", "aeid493", "aeid495")), 
#                          Slice32 = TxpSlice(c("aeid3095", "aeid3096")),
#                          Slice33 = TxpSlice(c("aeid2366", "aeid2368")),
#                          Slice34 = TxpSlice(c("aeid767")),
#                          Slice35 = TxpSlice(c("aeid2039")),
#                          Slice36 = TxpSlice(c("aeid760", "aeid784", "aeid792", "aeid801", "aeid1109", "aeid1112", "aeid1115", "aeid1190", "aeid1194", "aeid1197", "aeid1199", "aeid1203", "aeid1316", "aeid1320", "aeid1324", "aeid1328", "aeid1341", "aeid1345", "aeid1845", "aeid2042", "aeid2045", "aeid2064", "aeid2114", "aeid2122", "aeid2126", "aeid2216")), 
#                          Slice37 = TxpSlice(c("aeid1130", "aeid1201", "aeid2217", "aeid2371", "aeid2375")), 
#                          Slice38 = TxpSlice(c("aeid1110", "aeid1113", "aeid1317", "aeid1321", "aeid1325", "aeid1329", "aeid1342", "aeid1346", "aeid2065")), 
#                          Slice39 = TxpSlice(c("aeid2046")), 
#                          Slice40 = TxpSlice(c("aeid1127")), 
#                          Slice41 = TxpSlice(c("aeid1846")), 
#                          Slice42 = TxpSlice(c("aeid2040", "aeid2043")), 
#                          Slice43 = TxpSlice(c("aeid2372", "aeid2376")), 
#                          Slice44 = TxpSlice(c("aeid761", "aeid762", "aeid785", "aeid786", "aeid793", "aeid802", "aeid1131", "aeid1132", "aeid2115", "aeid2119", "aeid2123", "aeid2127", "aeid2218", "aeid2219")), 
#                          Slice45 = TxpSlice(c("aeid2061")), 
#                          Slice46 = TxpSlice(c("aeid739", "aeid750", "aeid751")), 
#                          Slice47 = TxpSlice(c("aeid63", "aeid64", "aeid65", "aeid66", "aeid67", "aeid69", "aeid72", "aeid73", "aeid74", "aeid76", "aeid77", "aeid78", "aeid79", "aeid80", "aeid82", "aeid83", "aeid84", "aeid86", "aeid91", "aeid92", "aeid93", "aeid94", "aeid95", "aeid96", "aeid97", "aeid98", "aeid99", "aeid100", "aeid105", "aeid106", "aeid107", "aeid108", "aeid111", "aeid114")), 
#                          Slice48 = TxpSlice(c("aeid2067")), 
#                          Slice49 = TxpSlice(c("aeid112")), 
#                          Slice50 = TxpSlice(c("aeid70", "aeid71", "aeid75", "aeid81", "aeid85", "aeid101", "aeid102", "aeid103", "aeid104", "aeid113", "aeid115", "aeid116", "aeid117", "aeid118", "aeid119", "aeid120", "aeid122", "aeid123", "aeid125", "aeid126", "aeid131", "aeid132", "aeid133", "aeid134", "aeid135", "aeid136", "aeid137", "aeid138", "aeid139", "aeid140", "aeid141", "aeid142", "aeid143", "aeid144", "aeid803", "aeid2484", "aeid2486")), 
#                          Slice51 = TxpSlice(c("aeid936")), 
#                          Slice52 = TxpSlice(c("aeid932")), 
#                          Slice53 = TxpSlice(c("aeid952")), 
#                          Slice54 = TxpSlice(c("aeid1038")), 
#                          Slice55 = TxpSlice(c("aeid938", "aeid940", "aeid942", "aeid944", "aeid946", "aeid954", "aeid956", "aeid958", "aeid960", "aeid1010")), 
#                          Slice56 = TxpSlice(c("aeid962", "aeid964", "aeid966", "aeid968", "aeid970", "aeid972", "aeid974", "aeid976", "aeid978", "aeid980", "aeid982", "aeid984", "aeid986", "aeid988", "aeid1615", "aeid1616", "aeid1617", "aeid1618", "aeid1619", "aeid1620", "aeid1631", "aeid1632", "aeid1633", "aeid1634", "aeid1635", "aeid1636", "aeid1647", "aeid1648", "aeid1649", "aeid1650", "aeid1651", "aeid1652")), 
#                          Slice57 = TxpSlice(c("aeid1044")), 
#                          Slice58 = TxpSlice(c("aeid1000", "aeid1046", "aeid1098")), 
#                          Slice59 = TxpSlice(c("aeid990", "aeid994", "aeid1006", "aeid1008", "aeid1032", "aeid1036", "aeid1048", "aeid1064", "aeid1066", "aeid1068", "aeid1074", "aeid1086", "aeid1100", "aeid1106")), 
#                          Slice60 = TxpSlice(c("aeid1054", "aeid1056")), 
#                          Slice61 = TxpSlice(c("aeid1052")), 
#                          Slice62 = TxpSlice(c("aeid992", "aeid1030", "aeid1040", "aeid1090", "aeid1092", "aeid1094")), 
#                          Slice63 = TxpSlice(c("aeid1050")), 
#                          Slice64 = TxpSlice(c("aeid930", "aeid1072")), 
#                          Slice65 = TxpSlice(c("aeid1016", "aeid1018")), 
#                          Slice66 = TxpSlice(c("aeid926", "aeid1002", "aeid1034", "aeid1623", "aeid1639", "aeid1655")), 
#                          Slice67 = TxpSlice(c("aeid996")), 
#                          Slice68 = TxpSlice(c("aeid1058")), 
#                          Slice69 = TxpSlice(c("aeid1012", "aeid1014")), 
#                          Slice70 = TxpSlice(c("aeid928")), 
#                          Slice71 = TxpSlice(c("aeid1004", "aeid1070", "aeid1080")), 
#                          Slice72 = TxpSlice(c("aeid934", "aeid1076", "aeid1078")), 
#                          Slice73 = TxpSlice(c("aeid948", "aeid950", "aeid1060", "aeid1062")), 
#                          Slice74 = TxpSlice(c("aeid1096")), 
#                          Slice75 = TxpSlice(c("aeid1026", "aeid1028", "aeid1088", "aeid1102", "aeid1104", "aeid1622", "aeid1625", "aeid1626", "aeid1638", "aeid1641", "aeid1642", "aeid1654", "aeid1657", "aeid1658")), 
#                          Slice76 = TxpSlice(c("aeid916", "aeid918", "aeid920", "aeid922", "aeid924", "aeid998", "aeid1042", "aeid1082", "aeid1084", "aeid1611", "aeid1612", "aeid1613", "aeid1624", "aeid1627", "aeid1628", "aeid1629", "aeid1640", "aeid1643", "aeid1644", "aeid1645", "aeid1656")), 
#                          Slice77 = TxpSlice(c("aeid796", "aeid798")), 
#                          Slice78 = TxpSlice(c("aeid8", "aeid10", "aeid12", "aeid16", "aeid28", "aeid30", "aeid32", "aeid36", "aeid48", "aeid50", "aeid52", "aeid56", "aeid1854")), 
#                          Slice79 = TxpSlice(c("aeid4", "aeid14", "aeid22", "aeid24", "aeid34", "aeid42", "aeid44", "aeid54", "aeid62")), 
#                          Slice80 = TxpSlice(c("aeid18", "aeid20", "aeid38", "aeid40", "aeid58", "aeid60")), 
#                          Slice81 = TxpSlice(c("aeid2", "aeid1855", "aeid1856")), 
#                          Slice82 = TxpSlice(c("aeid224", "aeid234", "aeid236", "aeid258", "aeid260", "aeid280", "aeid298", "aeid306")), 
#                          Slice83 = TxpSlice(c("aeid226", "aeid254", "aeid270", "aeid292", "aeid318")), 
#                          Slice84 = TxpSlice(c("aeid212", "aeid216", "aeid218", "aeid220", "aeid230", "aeid232", "aeid240", "aeid242", "aeid244", "aeid246", "aeid250", "aeid262", "aeid264", "aeid266", "aeid278", "aeid282", "aeid284", "aeid286", "aeid288", "aeid294", "aeid296", "aeid300", "aeid302", "aeid304", "aeid308", "aeid310", "aeid312")), 
#                          Slice85 = TxpSlice(c("aeid228", "aeid290")),
#                          Slice86 = TxpSlice(c("aeid272")),
#                          Slice87 = TxpSlice(c("aeid238")), 
#                          Slice88 = TxpSlice(c("aeid214")), 
#                          Slice89 = TxpSlice(c("aeid248", "aeid268", "aeid276")), 
#                          Slice90 = TxpSlice(c("aeid256", "aeid274")), 
#                          Slice91 = TxpSlice(c("aeid2038")), 
#                          Slice92 = TxpSlice(c("aeid759", "aeid783", "aeid791", "aeid1108", "aeid1111", "aeid1114", "aeid1189", "aeid1193", "aeid1198", "aeid1202", "aeid1315", "aeid1319", "aeid1323", "aeid1327", "aeid1340", "aeid1344", "aeid2041", "aeid2044", "aeid2063", "aeid2113", "aeid2121", "aeid2125", "aeid2214", "aeid2215")), 
#                          Slice93 = TxpSlice(c("aeid800", "aeid1129", "aeid1200", "aeid2370", "aeid2374")), 
#                          Slice94 = TxpSlice(c("aeid6", "aeid26", "aeid46", "aeid222", "aeid252", "aeid314", "aeid316", "aeid763", "aeid766", "aeid768", "aeid782", "aeid787", "aeid790", "aeid795", "aeid799", "aeid805", "aeid807", "aeid1128", "aeid1133", "aeid1136", "aeid1185", "aeid1186", "aeid1318", "aeid1322", "aeid1326", "aeid1330", "aeid1331", "aeid1343", "aeid1347", "aeid1509", "aeid1660", "aeid1662", "aeid1664", "aeid1817", "aeid1825", "aeid1826", "aeid1847", "aeid1850", "aeid1852", "aeid1857", "aeid2048", "aeid2050", "aeid2054", "aeid2059", "aeid2060", "aeid2062", "aeid2066", "aeid2072", "aeid2074", "aeid2075")), 
#                          Slice95 = TxpSlice(c("aeid2077", "aeid2078", "aeid2080", "aeid2082", "aeid2084", "aeid2086", "aeid2088", "aeid2089", "aeid2116", "aeid2120", "aeid2124", "aeid2128", "aeid2212", "aeid2220", "aeid2221", "aeid2224", "aeid2225", "aeid2297", "aeid2298", "aeid2299", "aeid2300", "aeid2301", "aeid2302", "aeid2303", "aeid2304", "aeid2305", "aeid2306", "aeid2307", "aeid2308", "aeid2362", "aeid2367", "aeid2369", "aeid2373", "aeid2377", "aeid2450", "aeid2451", "aeid2452", "aeid2793", "aeid2797")), 
#                          Slice96 = TxpSlice(c("aeid1134", "aeid2130", "aeid2131")), 
#                          Slice97 = TxpSlice(c("aeid2485", "aeid2487")))

#ToxPiR Model and Results Generated
# final.trans <- TxpTransFuncList(f1 = function(x) -1 * log10(x) + 6, f2 = function(x) -1 * log10(x) + 6, f3 = function(x) -1 * log10(x) + 6, f4 = function(x) -1 * log10(x) + 6, f5 = function(x) -1 * log10(x) + 6, f6 = function(x) -1 * log10(x) + 6, f7 = function(x) -1 * log10(x) + 6, f8 = function(x) -1 * log10(x) + 6, f9 = function(x) -1 * log10(x) + 6, f10 = function(x) -1 * log10(x) + 6, f11 = function(x) -1 * log10(x) + 6, f12 = function(x) -1 * log10(x) + 6, f13 = function(x) -1 * log10(x) + 6, f14 = function(x) -1 * log10(x) + 6, f15 = function(x) -1 * log10(x) + 6, f16 = function(x) -1 * log10(x) + 6, f17 = function(x) -1 * log10(x) + 6, f18 = function(x) -1 * log10(x) + 6, f19 = function(x) -1 * log10(x) + 6, f20 = function(x) -1 * log10(x) + 6, f21 = function(x) -1 * log10(x) + 6, f22 = function(x) -1 * log10(x) + 6, f23 = function(x) -1 * log10(x) + 6, f24 = function(x) -1 * log10(x) + 6, f25 = function(x) -1 * log10(x) + 6, f26 = function(x) -1 * log10(x) + 6, f27 = function(x) -1 * log10(x) + 6, f28 = function(x) -1 * log10(x) + 6, f29 = function(x) -1 * log10(x) + 6, f30 = function(x) -1 * log10(x) + 6, f31 = function(x) -1 * log10(x) + 6, f32 = function(x) -1 * log10(x) + 6, f33 = function(x) -1 * log10(x) + 6, f34 = function(x) -1 * log10(x) + 6, f35 = function(x) -1 * log10(x) + 6, f36 = function(x) -1 * log10(x) + 6, f37 = function(x) -1 * log10(x) + 6, f38 = function(x) -1 * log10(x) + 6, f39 = function(x) -1 * log10(x) + 6, f40 = function(x) -1 * log10(x) + 6, f41 = function(x) -1 * log10(x) + 6, f42 = function(x) -1 * log10(x) + 6, f43 = function(x) -1 * log10(x) + 6, f44 = function(x) -1 * log10(x) + 6, f45 = function(x) -1 * log10(x) + 6, f46 = function(x) -1 * log10(x) + 6, f47 = function(x) -1 * log10(x) + 6, f48 = function(x) -1 * log10(x) + 6, f49 = function(x) -1 * log10(x) + 6, f50 = function(x) -1 * log10(x) + 6, f51 = function(x) -1 * log10(x) + 6, f52 = function(x) -1 * log10(x) + 6, f53 = function(x) -1 * log10(x) + 6, f54 = function(x) -1 * log10(x) + 6, f55 = function(x) -1 * log10(x) + 6, f56 = function(x) -1 * log10(x) + 6, f57 = function(x) -1 * log10(x) + 6, f58 = function(x) -1 * log10(x) + 6, f59 = function(x) -1 * log10(x) + 6, f60 = function(x) -1 * log10(x) + 6, f61 = function(x) -1 * log10(x) + 6, f62 = function(x) -1 * log10(x) + 6, f63 = function(x) -1 * log10(x) + 6, f64 = function(x) -1 * log10(x) + 6, f65 = function(x) -1 * log10(x) + 6, f66 = function(x) -1 * log10(x) + 6, f67 = function(x) -1 * log10(x) + 6, f68 = function(x) -1 * log10(x) + 6, f69 = function(x) -1 * log10(x) + 6, f70 = function(x) -1 * log10(x) + 6, f71 = function(x) -1 * log10(x) + 6, f72 = function(x) -1 * log10(x) + 6, f73 = function(x) -1 * log10(x) + 6, f74 = function(x) -1 * log10(x) + 6, f75 = function(x) -1 * log10(x) + 6, f76 = function(x) -1 * log10(x) + 6, f77 = function(x) -1 * log10(x) + 6, f78 = function(x) -1 * log10(x) + 6, f79 = function(x) -1 * log10(x) + 6, f80 = function(x) -1 * log10(x) + 6, f81 = function(x) -1 * log10(x) + 6, f82 = function(x) -1 * log10(x) + 6, f83 = function(x) -1 * log10(x) + 6, f84 = function(x) -1 * log10(x) + 6, f85 = function(x) -1 * log10(x) + 6, f86 = function(x) -1 * log10(x) + 6, f87 = function(x) -1 * log10(x) + 6, f88 = function(x) -1 * log10(x) + 6, f89 = function(x) -1 * log10(x) + 6, f90 = function(x) -1 * log10(x) + 6, f91 = function(x) -1 * log10(x) + 6, f92 = function(x) -1 * log10(x) + 6, f93 = function(x) -1 * log10(x) + 6, f94 = function(x) -1 * log10(x) + 6, f95 = function(x) -1 * log10(x) + 6, f96 = function(x) -1 * log10(x) + 6, f97 = function(x) -1 * log10(x) + 6)
# f.model <- TxpModel(txpSlices = f.slices,
#                     txpTransFuncs = final.trans)

# f.results <- txpCalculateScores(model = f.model,
#                                 input = as.data.frame(toxpidata_t_clean),
#                                 id.var = "Assays")
# txpScores(f.results)
# txpSliceScores(f.results)
# rbind(f.results, txpSliceScores)

#Read in structure to get ToxpiGUI heading properly
slicemaker <- read.csv("/Users/porterkt/finaltalktotoxpi/structured_output.csv")

#Set all na values to 0
slicemaker[is.na(slicemaker)] <- 0

#Make sure that dataframe is the proper length
toxpidata_t_clean <- toxpidata_t_clean[,1:3098]

#Make column names equivalent
names(slicemaker) <- names(toxpidata_t_clean)

#Row bind the GUI structure and the data
fullgui <- rbind(slicemaker, toxpidata_t_clean)

#Replaces the 98th row with the metric names to finalize GUI format
fullgui[ , 99:ncol(fullgui)] <- rbind(fullgui[1, ], fullgui[2:nrow(fullgui), ])

#Delete the first row
fullgui <- fullgui[-1, ]

#Store all column names as a vector
column_names_vector <- colnames(fullgui)

#Insert the column names vector below the last "Slice" row (Row 97)
fullgui <- rbind(fullgui[1:97, ], column_names_vector, fullgui[98:nrow(fullgui), ])

#Get rid of column names
colnames(fullgui) <- NULL

#Set NAs to empty
fullgui[is.na(fullgui)] <- ""

#Get ride of id variable Assays
fullgui[98,1] <- ""

output_file <- paste(fullgui, collapse = ",")
print(output_file)
