library(nanoparquet)
library(broom)
library(MASS)
library(dplyr)

# --- Clean data
df_modeling <- read_parquet('../data/final/analytical_table.parquet')

df_cd <- df_modeling %>%
  group_by(borocd) %>%
  summarise(
    n_reports_311 = sum(n_reports_311),
    n_repairs_dot = sum(n_repairs_dot),
    total_population = first(total_population),
    road_miles = first(road_miles),
    median_household_income = first(median_household_income) / 10000,
    rental_vacancy_rate = first(rental_vacancy_rate),
    pct_renters = first(pct_renters),
    pct_with_college_degree = first(pct_with_college_degree),
    pct_foreign_born = first(pct_foreign_born)
  )

df_cd_std <- df_cd %>%
  mutate(across(
    c(median_household_income, pct_renters, pct_foreign_born),
    ~ as.numeric(scale(.))  # mean-center, divide by SD
  ))

# --- Construct models
m_311 <- glm.nb(
  n_reports_311 ~
    log(total_population) +
    median_household_income +
    pct_foreign_born +
    pct_renters +
    offset(log(road_miles)),
  data = df_cd_std
)
m_dot <- glm.nb(
  n_repairs_dot ~
    log(total_population) +
    median_household_income +
    pct_foreign_born +
    pct_renters +
    offset(log(road_miles)),
  data = df_cd_std
)

df_cd_std$predicted_311 <- predict(m_311, type = "response")
df_cd_std$predicted_dot <- predict(m_dot, type = "response")
df_cd_std$resid_311 <- residuals(m_311, type = "pearson")
df_cd_std$resid_dot <- residuals(m_dot, type = "pearson")
df_cd_std$gap <- df_cd_std$resid_311 - df_cd_std$resid_dot
df_cd_std$is_outlier <- abs(df_cd_std$gap) > quantile(abs(df_cd_std$gap), 0.9)

# --- Function for parametric bootstrap
parametric_bootstrap <- function(data, m311, mdot, n_boot = 2000) {
  n_cd <- nrow(data)
  boot_gaps <- matrix(NA, nrow = n_boot, ncol = n_cd)
  
  # Get fitted means and thetas from the original models
  mu_311 <- fitted(m311)
  mu_dot <- fitted(mdot)
  theta_311 <- m311$theta
  theta_dot <- mdot$theta
  
  for (b in 1:n_boot) {
    # Simulate new outcome data from negative binomial with fitted means
    sim_311 <- rnbinom(n_cd, mu = mu_311, size = theta_311)
    sim_dot <- rnbinom(n_cd, mu = mu_dot, size = theta_dot)
    
    # Refit both models on simulated outcomes
    sim_data <- data
    sim_data$n_reports_311 <- sim_311
    sim_data$n_repairs_dot <- sim_dot
    
    m311_b <- tryCatch(
      glm.nb(n_reports_311 ~ log(total_population) + median_household_income +
               pct_foreign_born + pct_renters + offset(log(road_miles)),
             data = sim_data),
      error = function(e) NULL
    )
    mdot_b <- tryCatch(
      glm.nb(n_repairs_dot ~ log(total_population) + median_household_income +
               pct_foreign_born + pct_renters + offset(log(road_miles)),
             data = sim_data),
      error = function(e) NULL
    )
    
    if (is.null(m311_b) || is.null(mdot_b)) next
    
    pred_311 <- predict(m311_b, newdata = sim_data, type = "response")
    pred_dot <- predict(mdot_b, newdata = sim_data, type = "response")
    
    resid_311 <- (sim_data$n_reports_311 - pred_311) / sqrt(pred_311 + pred_311^2 / m311_b$theta)
    resid_dot <- (sim_data$n_repairs_dot - pred_dot) / sqrt(pred_dot + pred_dot^2 / mdot_b$theta)
    
    boot_gaps[b, ] <- resid_311 - resid_dot
  }
  
  boot_gaps
}

# --- Calculate p-values from parametric-bootstrapped CIs of gaps
observed_gap <- df_cd_std$gap
# Run parametric bootstrap to get null distribution per CD
null_gaps <- parametric_bootstrap(df_cd_std, m_311, m_dot, n_boot = 2000)
# For each CD, compute the p-value: what fraction of null gaps are 
#    more extreme than observed?
p_values <- sapply(1:ncol(null_gaps), function(i) {
  mean(abs(null_gaps[, i]) >= abs(observed_gap[i]))
})
# Adjust for multiple testing (59 tests)
p_adjusted <- p.adjust(p_values, method = "BH")
significant <- p_adjusted < 0.05
# Print the number of significant p-values
print(paste('Number Significant: ', sum(significant)))

# --- Write model results to file
write.csv(broom::tidy(m_311, conf.int = TRUE), 'data/final/coefficients_311.csv')
write.csv(broom::tidy(m_dot, conf.int = TRUE), 'data/final/coefficients_dot.csv')
write.csv(df_cd_std, 'data/final/model_preds_resids.csv')