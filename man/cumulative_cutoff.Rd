% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/cumulative_cutoff.R
\name{cumulative_cutoff}
\alias{cumulative_cutoff}
\title{Cumulative access based on a travel cost cutoff}
\usage{
cumulative_cutoff(
  travel_matrix,
  land_use_data,
  opportunity,
  travel_cost,
  cutoff,
  group_by = character(0),
  active = TRUE,
  fill_missing_ids = TRUE
)
}
\arguments{
\item{travel_matrix}{A data frame. The travel matrix describing the costs
(i.e. travel time, distance, monetary cost, etc.) between the origins and
destinations in the study area. Must contain the columns \code{from_id}, \code{to_id}
and any others specified in \code{travel_cost_col}.}

\item{land_use_data}{A data frame. The distribution of opportunities within
the study area cells. Must contain the columns \code{id} and any others
specified in \code{opportunity_col}.}

\item{opportunity}{A string. The name of the column in \code{land_use_data}
with the number of opportunities/resources/services to be considered when
calculating accessibility levels.}

\item{travel_cost}{A string. The name of the column in \code{travel_matrix}
with the travel cost between origins and destinations. Defaults to
\code{"travel_time"}.}

\item{cutoff}{A \code{numeric} vector. The travel cost cutoffs to consider when
calculating accessibility levels. If more than one value is provided, the
output includes an extra column specifying the cutoff that the
accessibility levels refer to.}

\item{group_by}{A \code{character} vector. When not \code{character(0)} (the default),
indicates the \code{travel_matrix} columns that should be used to group the
accessibility estimates by. For example, if \code{travel_matrix} includes a
departure time column, that specifies the departure time of each entry in
the data frame, passing \code{"departure_time"} to this parameter results in
accessibility estimates grouped by origin and by departure time.}

\item{active}{A logical. Whether to calculate active accessibility (the
of opportunities that can be reached from a given origin, the default) or
passive accessibility (by how many people each destination can be reached).}

\item{fill_missing_ids}{A \code{logical}. Calculating cumulative accessibility may
result in missing ids if the they cannot reach any of the destinations
within the specified travel cost cutoff. For example, using a travel time
cutoff of 20 minutes, when estimating the accessibility of origin \code{A} that
can only reach destinations with more than 40 minutes results in id \code{A}
not being included in the output. When \code{TRUE} (the default), the function
identifies which origins would be left out and fills their respective
accessibility values with 0, which incurs in a performance penalty.}
}
\value{
A data frame containing the accessibility estimates for each
origin/destination (depending if \code{active} is \code{TRUE} or \code{FALSE}) in the
travel matrix.
}
\description{
Calculates the number of opportunities accessible under a given specified
travel cost cutoff.

This function is generic over any kind of numeric travel cost,
such as distance, time and money.
}
\examples{
data_dir <- system.file("extdata", package = "accessibility")
travel_matrix <- readRDS(file.path(data_dir, "travel_matrix.rds"))
land_use_data <- readRDS(file.path(data_dir, "land_use_data.rds"))

# active accessibility: number of schools accessible from each origin
df <- cumulative_cutoff(
  travel_matrix = travel_matrix,
  land_use_data = land_use_data,
  cutoff = 30,
  opportunity = "schools",
  travel_cost = "travel_time"
)
head(df)

df <- cumulative_cutoff(
  travel_matrix = travel_matrix,
  land_use_data = land_use_data,
  cutoff = c(30, 60),
  opportunity = "schools",
  travel_cost = "travel_time"
)
head(df)

# passive accessibility: number of people that can reach each destination
df <- cumulative_cutoff(
  travel_matrix = travel_matrix,
  land_use_data = land_use_data,
  cutoff = 30,
  opportunity = "population",
  travel_cost = "travel_time",
  active = FALSE
)
head(df)

}
\seealso{
Other cumulative access: 
\code{\link{cumulative_interval}()}
}
\concept{cumulative access}
