context("model-sample")

if (not_on_cran()) {
  set_cmdstan_path()
  stan_program <- testing_stan_file("bernoulli")
  mod <- testing_model("bernoulli")
  stan_program_fp <- testing_stan_file("bernoulli_fp")
  mod_fp <- testing_model("bernoulli_fp")

  # valid ways to supply data
  data_list <- testing_data("bernoulli")
  data_file_r <- test_path("resources", "data", "bernoulli.data.R")
  data_file_json <- test_path("resources", "data", "bernoulli.data.json")

  # these are all valid for sample()
  ok_arg_values <- list(
    data = data_list,
    output_dir = tempdir(),
    chains = 2,
    parallel_chains = 1,
    iter_warmup = 50,
    iter_sampling = 100,
    save_warmup = FALSE,
    thin = 2,
    refresh = 5,
    init = 1.5,
    seed = 12345,
    max_treedepth = 6,
    metric = "dense_e",
    step_size = 1.1,
    adapt_engaged = TRUE,
    adapt_delta = 0.7,
    save_latent_dynamics = FALSE,
    init_buffer = 20,
    term_buffer = 0,
    window = 15
  )

  # using any one of these should cause sample() to error
  bad_arg_values <- list(
    data = "NOT_A_FILE",
    output_dir = "NOT_A_DIRECTORY",
    chains = -1,
    parallel_chains = -1,
    iter_warmup = -1,
    iter_sampling = -1,
    save_warmup = "NO",
    thin = 0,
    refresh = -10,
    init = -10,
    seed = -10,
    max_treedepth = 0,
    metric = "NOT_A_METRIC",
    step_size = 0,
    adapt_engaged = "NO",
    adapt_delta = 2,
    save_latent_dynamics = "NOT_LOGICAL",
    init_buffer = "NOT_INTEGER",
    term_buffer = "NOT_INTEGER",
    window = "NOT_INTEGER"
  )

  bad_arg_values_2 <- list(
    data = matrix(1:10),
    output_dir = 1,
    chains = "NOT_A_NUMBER",
    parallel_chains = "NOT_A_NUMBER",
    init = "NOT_A_FILE",
    seed = 1:10,
    step_size = 1:10,
    metric = c("AA", "BB"),
    init_buffer = -5,
    term_buffer = -6,
    window = -7
  )

  bad_arg_values_3 <- list(
    init = rep("NOT_A_FILE", 10),
    metric = c("AA", "BB", "CC")
  )
}

test_that("code() and print() methods work", {
  skip_on_cran()

  expect_known_output(mod$print(), file = test_path("answers", "model-print-output.stan"))
  expect_known_value(mod$code(), file = test_path("answers", "model-code-output.rds"))
})

test_that("sample() method works with data list", {
  skip_on_cran()

  expect_sample_output(fit <- mod$sample(data = data_list, chains = 1), 1)
  expect_is(fit, "CmdStanMCMC")
})

test_that("sample() method works with data files", {
  skip_on_cran()

  expect_sample_output(fit_r <- mod$sample(data = data_file_r, chains = 1), 1)
  expect_is(fit_r, "CmdStanMCMC")

  expect_sample_output(fit_json <- mod$sample(data = data_file_json, chains = 1), 1)
  expect_is(fit_json, "CmdStanMCMC")
})

test_that("sample() method works with init file", {
  skip_on_cran()

  init_list <- list(theta = 0.5)
  init_file <- tempfile(
    tmpdir = cmdstan_tempdir(),
    pattern = "testing-inits-",
    fileext = ".json"
  )
  write_stan_json(init_list, file = init_file)
  expect_sample_output(mod$sample(data = data_file_r, init = init_file, chains = 1), 1)
})

test_that("sample() method runs when all arguments specified", {
  skip_on_cran()

  expect_sample_output(fit <- do.call(mod$sample, ok_arg_values), 2)
  expect_is(fit, "CmdStanMCMC")
})

test_that("sample() prints informational messages depening on show_messages", {
  skip_on_cran()
  mod_info_msg <- testing_model("info_message")
  expect_sample_output(
    expect_message(
      mod_info_msg$sample(),
      "Informational Message: The current Metropolis proposal is about to be rejected"
    )
  )
  expect_sample_output(
    expect_message(mod_info_msg$sample(show_messages = FALSE), regexp = NA)
  )
})

test_that("sample() method errors for any invalid arguments before calling cmdstan", {
  skip_on_cran()

  utils::capture.output(mod$compile())
  for (nm in names(bad_arg_values)) {
    args <- ok_arg_values
    args[[nm]] <- bad_arg_values[[nm]]
    expect_error(do.call(mod$sample, args), regexp = nm)
  }

  for (nm in names(bad_arg_values_2)) {
    args <- ok_arg_values
    args[[nm]] <- bad_arg_values_2[[nm]]
    expect_error(do.call(mod$sample, args), regexp = nm)
  }

  for (nm in names(bad_arg_values_3)) {
    args <- ok_arg_values
    args[[nm]] <- bad_arg_values_3[[nm]]
    expect_error(do.call(mod$sample, args), regexp = nm)
  }
})

test_that("sample works for warmup-only run", {
  skip_on_cran()
  expect_output(
    fit <- mod$sample(chains = 2, data = data_list, iter_sampling = 0),
    "Iteration: 1000 / 1000 [100%]  (Warmup)",
    fixed = TRUE
  )
})

test_that("sampling in parallel works", {
  skip_on_cran()
  expect_output(
    mod$sample(data = data_list, chains = 2, parallel_chains = 2),
    "Running MCMC with 2 parallel chains",
    fixed = TRUE
  )

  expect_output(
    mod$sample(data = data_list, chains = 2, parallel_chains = 2),
    "Both chains finished successfully",
    fixed = TRUE
  )
})

test_that("mc.cores option detected", {
  skip_on_cran()

  options(mc.cores = 3)
  expect_output(
    mod$sample(data = data_list, chains = 3),
    "Running MCMC with 3 parallel chains",
    fixed = TRUE
  )

  options(mc.cores = NULL)
  expect_output(
    mod$sample(data = data_list, chains = 2),
    "Running MCMC with 2 sequential chains",
    fixed = TRUE
  )
})

test_that("sample() method runs when fixed_param = TRUE", {
  skip_on_cran()
  mod_fp$compile()

  expect_sample_output(fit_1000 <- mod_fp$sample(fixed_param = TRUE, iter_sampling = 1000), 1)
  expect_is(fit_1000, "CmdStanMCMC")
  expect_equal(dim(fit_1000$draws()), c(1000,1,10))

  expect_sample_output(fit_500 <- mod_fp$sample(fixed_param = TRUE, iter_sampling = 500), 1)
  expect_equal(dim(fit_500$draws()), c(500,1,10))

  expect_sample_output(fit_500_w <- mod_fp$sample(fixed_param = TRUE, iter_sampling = 500, iter_warmup = 5000), 1)
  expect_equal(dim(fit_500_w$draws()), c(500,1,10))

  expect_equal(fit_1000$metadata()$algorithm, "fixed_param")
  expect_equal(fit_500$metadata()$algorithm, "fixed_param")
  expect_equal(fit_500_w$metadata()$algorithm, "fixed_param")
})
