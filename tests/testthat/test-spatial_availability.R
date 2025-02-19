# if running manually, please run the following line first:
# source("tests/testthat/setup.R")

tester <- function(
  travel_matrix = get("travel_matrix", envir = parent.frame()),
  land_use_data = get("land_use_data", envir = parent.frame()),
  opportunity = "jobs",
  travel_cost = "travel_time",
  demand = "population",
  decay_function = decay_exponential(0.1),
  alpha = 1,
  group_by = "mode",
  fill_missing_ids = TRUE
) {
  spatial_availability(
    travel_matrix,
    land_use_data,
    opportunity,
    travel_cost,
    demand,
    decay_function,
    alpha,
    group_by,
    fill_missing_ids
  )
}

test_that("raises errors due to incorrect input", {
  expect_error(tester(alpha = "a"))
  expect_error(tester(alpha = -1))
  expect_error(tester(alpha = c(1, 2)))
  expect_error(tester(alpha = Inf))

  expect_error(tester(decay_function = "a"))
  expect_error(tester(decay_function = mean))
  expect_error(tester(decay_function = get))

  expect_error(tester(opportunity = 1))
  expect_error(tester(opportunity = c("schools", "jobs")))

  expect_error(tester(travel_cost = 1))
  expect_error(tester(travel_cost = c("travel_time", "monetary_cost")))

  expect_error(tester(demand = 1))
  expect_error(tester(demand = c("population", "population")))

  expect_error(tester(group_by = 1))
  expect_error(tester(group_by = NA))
  expect_error(tester(group_by = "from_id"))
  expect_error(tester(group_by = c("mode", "mode")))

  expect_error(tester(fill_missing_ids = 1))
  expect_error(tester(fill_missing_ids = c(TRUE, TRUE)))
  expect_error(tester(fill_missing_ids = NA))

  expect_error(tester(as.list(travel_matrix)))
  expect_error(tester(travel_matrix[, .(oi = from_id, to_id, travel_time)]))
  expect_error(tester(travel_matrix[, .(from_id, oi = to_id, travel_time)]))
  expect_error(
    tester(
      travel_matrix[, .(from_id, to_id, oi = travel_time)],
      travel_cost = "travel_time"
    )
  )
  expect_error(
    tester(
      travel_matrix[, .(from_id, to_id, travel_time, oi = mode)],
      group_by = "mode"
    )
  )

  expect_error(tester(as.list(land_use_data)))
  expect_error(
    tester(land_use_data = land_use_data[, .(oi = id, jobs, population)])
  )
  expect_error(
    tester(
      land_use_data = land_use_data[, .(id, oi = jobs, population)],
      opportunity = "jobs"
    )
  )
  expect_error(
    tester(
      land_use_data = land_use_data[, .(id, jobs, oi = population)],
      demand = "population"
    )
  )
})

test_that("throws warning if travel_matrix has extra col", {
  # i.e. col not listed in travel_cost and by_col
  expect_warning(tester(group_by = character(0)))
})

test_that("returns a dataframe whose class is the same as travel_matrix's", {
  result <- tester()
  expect_is(result, "data.table")
  result <- tester(land_use_data = as.data.frame(land_use_data))
  expect_is(result, "data.table")

  result <- tester(as.data.frame(travel_matrix))
  expect_false(inherits(result, "data.table"))
  expect_is(result, "data.frame")
  result <- tester(as.data.frame(travel_matrix), as.data.frame(land_use_data))
  expect_false(inherits(result, "data.table"))
  expect_is(result, "data.frame")
})

test_that("result has correct structure", {
  result <- tester()
  expect_true(ncol(result) == 3)
  expect_is(result$id, "character")
  expect_is(result$mode, "character")
  expect_is(result$jobs, "numeric")

  result <- tester(opportunity = "schools")
  expect_true(ncol(result) == 3)
  expect_is(result$id, "character")
  expect_is(result$mode, "character")
  expect_is(result$schools, "numeric")

  suppressWarnings(result <- tester(group_by = character(0)))
  expect_true(ncol(result) == 2)
  expect_is(result$id, "character")
  expect_is(result$jobs, "numeric")

  result <- tester(
    data.table::data.table(
      mode = character(),
      from_id = character(),
      to_id = character(),
      travel_time = integer()
    )
  )
  expect_true(ncol(result) == 3)
  expect_true(nrow(result) == 0)
  expect_is(result$id, "character")
  expect_is(result$mode, "character")
  expect_is(result$jobs, "numeric")
})

test_that("input data sets remain unchanged", {
  original_travel_matrix <- data.table::rbindlist(
    travel_matrix_list,
    idcol = "mode"
  )
  original_land_use_data <- readRDS(file.path(data_dir, "land_use_data.rds"))

  result <- tester()

  # subsets in other functions tests set travel_matrix index
  data.table::setindex(travel_matrix, NULL)

  expect_equal(original_travel_matrix, travel_matrix)
  expect_equal(original_land_use_data, land_use_data)
})

test_that("fill_missing_ids arg works correctly", {
  small_travel_matrix <- travel_matrix[
    from_id %in% c("89a88cdb57bffff", "89a88cdb597ffff")
  ]
  small_travel_matrix <- small_travel_matrix[
    !(from_id == "89a88cdb57bffff" & mode == "transit2")
  ]

  result <- tester(small_travel_matrix, fill_missing_ids = TRUE)
  result[, jobs := as.integer(jobs)]
  data.table::setkey(result, NULL)
  expect_identical(
    result,
    data.table::data.table(
      id = rep(c("89a88cdb57bffff", "89a88cdb597ffff"), each = 2),
      mode = rep(c("transit", "transit2"), times = 2),
      jobs = c(271899L, 0L, 224153L, 496053L)
    )
  )

  result <- tester(small_travel_matrix, fill_missing_ids = FALSE)
  result[, jobs := as.integer(jobs)]
  expect_identical(
    result,
    data.table::data.table(
      id = c("89a88cdb57bffff", "89a88cdb597ffff", "89a88cdb597ffff"),
      mode = c("transit", "transit", "transit2"),
      jobs = c(271899L, 224153L, 496053L)
    )
  )
})

test_that("accepts custom decay function", {
  selected_ids <- c(
    "89a88cdb57bffff",
    "89a88cdb597ffff",
    "89a88cdb5b3ffff",
    "89a88cdb5cfffff",
    "89a88cd909bffff"
  )
  smaller_travel_matrix <- travel_matrix[
    from_id %in% selected_ids & to_id %in% selected_ids
  ]

  custom_function <- function(travel_cost) rep(1L, length(travel_cost))

  result <- tester(smaller_travel_matrix, decay_function = custom_function)
  result[, jobs := round(jobs, digits = 0)]
  expect_identical(
    result,
    data.table::data.table(
      id = rep(selected_ids, 2),
      mode = rep(c("transit", "transit2"), each = 5),
      jobs = rep(c(74, 90, 204, 228, 4))
    )
  )
})

test_that("works even if travel_matrix and land_use has specific colnames", {
  expected_result <- tester()

  travel_matrix[, opportunity := "oi"]
  result <- suppressWarnings(tester(travel_matrix))
  expect_identical(expected_result, result)

  travel_matrix[, opportunity := NULL]
  travel_matrix[, travel_cost := "oi"]
  result <- suppressWarnings(tester(travel_matrix))
  expect_identical(expected_result, result)

  travel_matrix[, travel_cost := NULL]
  travel_matrix[, groups := "oi"]
  result <- suppressWarnings(tester(travel_matrix))
  expect_identical(expected_result, result)

  travel_matrix[, groups := NULL]
  travel_matrix[, demand := "oi"]
  result <- suppressWarnings(tester(travel_matrix))
  expect_identical(expected_result, result)

  travel_matrix[, demand := NULL]
  land_use_data[, opportunity := "oi"]
  result <- suppressWarnings(tester(land_use_data = land_use_data))
  expect_identical(expected_result, result)

  land_use_data[, opportunity := NULL]
  land_use_data[, demand := "oi"]
  result <- suppressWarnings(tester(land_use_data = land_use_data))
  expect_identical(expected_result, result)

  land_use_data[, demand := NULL]
})

test_that("calculates spatial availability correctly", {
  # data used in Soukhov et al. (2023), slightly modified

  paper_travel_matrix <- data.table::data.table(
    from_id = rep(c("A", "B", "C"), each = 3),
    to_id = as.character(rep(1:3, 3)),
    travel_time = c(15, 30, 100, 30, 15, 100, 100, 100, 15)
  )
  paper_land_use_data <- data.table::data.table(
    id = c("A", "B", "C", "1", "2", "3"),
    population = c(50000, 150000, 10000, 0, 0, 0),
    jobs = c(0, 0, 0, 100000, 100000, 10000)
  )

  result <- tester(
    paper_travel_matrix,
    paper_land_use_data,
    group_by = character(0)
  )
  result[, jobs := round(jobs, digits = 0)]

  expect_identical(
    result,
    data.table::data.table(
      id = c("A", "B", "C"),
      jobs = c(66833, 133203, 9963)
    )
  )
})

test_that("results are grouped by decay_function_arg when needed", {
  small_travel_matrix <- travel_matrix[
    from_id %in% c("89a88cdb57bffff", "89a88cdb597ffff") &
      mode != "transit2"
  ]

  result <- tester(
    small_travel_matrix,
    decay_function = decay_exponential(c(0.5, 0.6))
  )
  result[, jobs := round(jobs, 1)]

  expect_identical(
    result,
    data.table::data.table(
      id = rep(c("89a88cdb57bffff", "89a88cdb597ffff"), times = 2),
      mode = rep("transit", 4),
      decay_function_arg = rep(c(0.5, 0.6), each = 2),
      jobs = c(367025.8, 129027.2, 372144.5, 123908.5)
    )
  )
})
