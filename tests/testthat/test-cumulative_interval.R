# if running manually, please run the following line first:
# source("tests/testthat/setup.R")

skip_if_not(requireNamespace("stats", quietly = TRUE))

tester <- function(
  travel_matrix = get("travel_matrix", envir = parent.frame()),
  land_use_data = get("land_use_data", envir = parent.frame()),
  opportunity = "jobs",
  travel_cost = "travel_time",
  interval = c(10, 30),
  interval_increment = 1,
  summary_function = stats::median,
  group_by = "mode",
  active = TRUE
) {
  cumulative_interval(
    travel_matrix,
    land_use_data,
    opportunity,
    travel_cost,
    interval,
    interval_increment,
    summary_function,
    group_by,
    active
  )
}

test_that("raises errors due to incorrect input", {
  expect_error(tester(interval = "banana"))
  expect_error(tester(interval = 3))
  expect_error(tester(interval = c(-1, 10)))
  expect_error(tester(interval = c(11, 10)))
  expect_error(tester(interval = c(10, 10)))
  expect_error(tester(interval = c(1, Inf)))
  expect_error(tester(interval = c(1, NA)))

  expect_error(tester(interval_increment = "a"))
  expect_error(tester(interval_increment = Inf))
  expect_error(tester(interval_increment = c(1, 1)))
  expect_error(tester(interval_increment = -1))

  expect_error(tester(summary_function = "test"))
  expect_error(tester(summary_function = readRDS))
  expect_error(tester(summary_function = identity))

  expect_error(tester(opportunity = 1))
  expect_error(tester(opportunity = c("schools", "jobs")))

  expect_error(tester(travel_cost = 1))
  expect_error(tester(travel_cost = c("travel_time", "monetary_cost")))

  expect_error(tester(group_by = 1))
  expect_error(tester(group_by = NA))
  expect_error(tester(group_by = "from_id"))
  expect_error(tester(group_by = c("mode", "mode")))

  expect_error(tester(active = 1))
  expect_error(tester(active = c(TRUE, TRUE)))
  expect_error(tester(active = NA))

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
  expect_error(tester(land_use_data = land_use_data[, .(oi = id, jobs)]))
  expect_error(
    tester(
      land_use_data = land_use_data[, .(id, oi = jobs)],
      opportunity = "jobs"
    )
  )
})

test_that("throws warning if travel_matrix extra col", {
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
  result <- tester(
    as.data.frame(travel_matrix),
    land_use_data = as.data.frame(land_use_data)
  )
  expect_false(inherits(result, "data.table"))
  expect_is(result, "data.frame")
})

test_that("result has correct structure", {
  result <- tester()
  expect_true(ncol(result) == 3)
  expect_is(result$id, "character")
  expect_is(result$mode, "character")
  expect_is(result$jobs, "integer")

  result <- tester(opportunity = "schools")
  expect_true(ncol(result) == 3)
  expect_is(result$id, "character")
  expect_is(result$mode, "character")
  expect_is(result$schools, "integer")

  suppressWarnings(result <- tester(group_by = character(0)))
  expect_true(ncol(result) == 2)
  expect_is(result$id, "character")
  expect_is(result$jobs, "integer")

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
  expect_is(result$jobs, "integer")
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

test_that("active and passive accessibility is correctly calculated", {
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

  result <- tester(smaller_travel_matrix, interval = c(40, 45), group_by = "mode")
  expected_result <- data.table::data.table(
    id = rep(selected_ids, 2),
    mode = rep(c("transit", "transit2"), each = 5),
    jobs = rep(as.integer(c(82, 517, 517, 304, 0)), 2)
  )
  expect_identical(result, expected_result)

  result <- tester(
    smaller_travel_matrix,
    interval = c(40, 45),
    opportunity = "population",
    group_by = "mode",
    active = FALSE
  )
  expected_result <- data.table::data.table(
    id = rep(selected_ids, 2),
    mode = rep(c("transit", "transit2"), each = 5),
    population = rep(as.integer(c(1538, 3336, 2404, 4268, 29)), 2)
  )
  expect_identical(result, expected_result)
})

test_that("summarizes the result according to summary function", {
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

  result <- tester(
    smaller_travel_matrix,
    interval = c(40, 45),
    summary_function = min,
    group_by = "mode"
  )
  expected_result <- data.table::data.table(
    id = rep(selected_ids, 2),
    mode = rep(c("transit", "transit2"), each = 5),
    jobs = rep(as.integer(c(82, 408, 408, 109, 0)), 2)
  )
  expect_identical(result, expected_result)

  result <- tester(
    smaller_travel_matrix,
    interval = c(40, 45),
    summary_function = mean,
    group_by = "mode"
  )
  expected_result <- data.table::data.table(
    id = rep(selected_ids, 2),
    mode = rep(c("transit", "transit2"), each = 5),
    jobs = rep(as.integer(c(82, 512, 508, 304, 0)), 2)
  )
  expect_identical(result, expected_result)
})

test_that("accessibility is correctly calculated when ids are missing", {
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

  result <- tester(
    smaller_travel_matrix,
    interval = c(5, 6),
    summary_function = min,
    group_by = "mode"
  )
  expected_result <- data.table::data.table(
    id = rep(selected_ids[order(selected_ids)], each = 2),
    mode = rep(c("transit", "transit2"), 5),
    jobs = rep(as.integer(c(0, 0, 0, 0, 0)), 2)
  )
  expect_identical(result, expected_result)
})

test_that("interval_increment arg is being used", {
  # hard to "perfectly" assess if the interval_increment value is being applied
  # correctly, but the code is trivial enough to let us say that it's correctly
  # applied if the results are different when using different increments

  result_increment_1 <- tester(
    travel_matrix,
    interval_increment = 1
  )
  result_increment_3 <- tester(
    travel_matrix,
    interval_increment = 3
  )

  expect_false(identical(result_increment_1, result_increment_3))
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
  land_use_data[, opportunity := "oi"]
  result <- suppressWarnings(tester(land_use_data = land_use_data))
  expect_identical(expected_result, result)

  land_use_data[, opportunity := NULL]
})
