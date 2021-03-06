#     plotClimatology.R Lattice plot methods for climatological grids
#
#     Copyright (C) 2016 Santander Meteorology Group (http://www.meteo.unican.es)
#
#     This program is free software: you can redistribute it and/or modify
#     it under the terms of the GNU General Public License as published by
#     the Free Software Foundation, either version 3 of the License, or
#     (at your option) any later version.
# 
#     This program is distributed in the hope that it will be useful,
#     but WITHOUT ANY WARRANTY; without even the implied warranty of
#     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#     GNU General Public License for more details.
# 
#     You should have received a copy of the GNU General Public License
#     along with this program.  If not, see <http://www.gnu.org/licenses/>.



#' @title Lattice plot methods for climatological grids
#' @description A wrapper for the lattice (trellis) plot methods for spatial data in \code{sp::spplot}
#' @param grid Input grid
#' @param backdrop.theme Reference geographical lines to be added to the plot. See Details. 
#' @param ... Further arguments passed to \code{spplot}
#' @details The function applies the \code{\link[sp]{spplot}} method after conversion of the climatological map(s) to a
#'  \code{SpatialGridDataFrame}.
#'  
#'  \strong{Multigrids}
#'  
#'  Multigrids of climatologies can be created using \code{makeMultiGrid} 
#'  for trellis visualization of different variables, or for instance, for the comparison of
#'  raw and corrected/downscaled scenarios side to side. In case of multimember multigrids, 
#'  the function will internally compute the ensemble mean of each variable in the multigrid
#'   for representation (with a message).
#'  
#'  \strong{Backdrop theme}
#'  
#'  Current implemented options are \code{"none"} and \code{"coastline"}, which contains
#'  a simplied vector theme delineating the world coastlines. Any other themes can be introduced
#'  by the user using the \code{sp.layout} options in \code{spplot}.
#'  
#'  \strong{Controlling graphical parameters}
#'  
#'  Many different aspects of the map can be controlled passing the relevant arguments to 
#'  spplot. Fine control of graphical parameters for the trellis display can
#'  be also controlled using \code{\link{lattice}{trellis.par.set}}.
#
#' @return As spplot, \code{plotClimatology} returns a lattice plot of class \dQuote{trellis}. 
#'  If you fail to \dQuote{see} it, explicitly call \code{print(plotClimatology(...))}.
#'  
#' @importFrom abind abind
#' @importFrom sp spplot SpatialGridDataFrame GridTopology
#' @importFrom grDevices colorRampPalette
#' 
#' @export
#' 
#' @author J. Bedia
#' @seealso \code{\link{climatology}}. See \code{\link[sp]{spplot}} in package \pkg{sp} for further information on
#' plotting capabilities and options
#' @examples \donttest{
#' data(tasmax_forecast)
#' # Climatology is computed:
#' clim <- climatology(tasmax_forecast, by.member = TRUE)
#' plotClimatology(clim)
#' # Geographical lines can be added using the argument 'backdrop.theme':
#' plotClimatology(clim, backdrop.theme = "coastline")
#' 
#' # Further arguments can be passed to 'spplot'...
#' 
#' # ... a subset of members to be displayed, using 'zcol':
#' plotClimatology(clim,
#'                 backdrop.theme = "coastline",
#'                 zcol = 1:4)
#'                 
#' # ... regional focuses (e.g. the Iberian Peninsula). 
#' plotClimatology(clim,
#'                 backdrop.theme = "countries",
#'                 xlim = c(-10,5), ylim = c(35,44),
#'                 zcol = 1:4,
#'                 scales = list(draw = TRUE))
#' 
#' # Changing the default color palette and ranges:
#' plotClimatology(clim,
#'                 backdrop.theme = "coastline",
#'                 zcol = 1:4,
#'                 col.regions = cm.colors(27), at = seq(10,37,1))
#'                 
#' # For ensemble means climatology should be called with 'by.member' set to FALSE:
#' clim <- climatology(tasmax_forecast, by.member = FALSE)
#' 
#' # Adding contours to the plot is direct with argument 'contour':
#' plotClimatology(clim,
#'                 scales = list(draw = TRUE),
#'                 contour = TRUE,
#'                 main = "tasmax Predictions July Ensemble Mean")
#'                 
#'                 
#' ## Example of multigrid plotting
#' data("iberia_ncep_psl")
#' ## Winter data are split into monthly climatologies
#' monthly.clim.grids <- lapply(getSeason(iberia_ncep_psl), function(x) {
#'       climatology(subsetGrid(iberia_ncep_psl, season = x))
#' })
#' ## Skip the temporal checks, as grids correspond to different time slices
#' mg <- do.call("makeMultiGrid",
#'               c(monthly.clim.grids, skip.temporal.check = TRUE))
#'               ## We change the panel names
#' plotClimatology(mg, 
#'                 backdrop.theme = "coastline",
#'                 names.attr = c("DEC","JAN","FEB"),
#'                 main = "Mean PSL climatology 1991-2010",
#'                 scales = list(draw = TRUE))                
#' }
#' 

plotClimatology <- function(grid, backdrop.theme = "none", ...) {
      if (is.null(attr(grid[["Data"]], "climatology:fun"))) {
            stop("The input grid is not a climatology: Use function 'climatology' first")
      }
      arg.list <- list(...)
      bt <- match.arg(backdrop.theme, choices = c("none", "coastline", "countries"))
      dimNames <- downscaleR:::getDim(grid)
      ## Multigrids are treated as realizations, previously aggregated by members if present
      is.multigrid <- "var" %in% dimNames
      if (is.multigrid) {
            if ("member" %in% dimNames) {
                  mem.ind <- grep("member", dimNames)
                  n.mem <- downscaleR:::getShape(grid, "member")
                  if (n.mem > 1) message("NOTE: The multimember mean will be displayed for each variable in the multigrid")
                  grid <- suppressMessages(aggregateGrid(grid, aggr.mem = list(FUN = "mean", na.rm = TRUE)))
                  dimNames <- downscaleR:::getDim(grid)
            }
            attr(grid[["Data"]], "dimensions") <- gsub("var", "member", dimNames)      
      }
      grid <- redim(grid, drop = FALSE)
      dimNames <- downscaleR:::getDim(grid)
      mem.ind <- grep("member", dimNames)
      n.mem <- downscaleR:::getShape(grid, "member")
      co <- expand.grid(grid$xyCoords$y, grid$xyCoords$x)[2:1]
      le <- nrow(co)
      aux <- vapply(1:n.mem, FUN.VALUE = numeric(le), FUN = function(x) {
            z <- asub(grid[["Data"]], idx = x, dims = mem.ind, drop = TRUE)
            z <- unname(abind(z, along = -1L))
            attr(z, "dimensions") <- c("time", "lat", "lon")
            array3Dto2Dmat(z)
      })
      # Data reordering to match SpatialGrid coordinates
      aux <- aux[order(-co[,2], co[,1]), ] 
      aux <- data.frame(aux)
      # Panel names 
      if (is.multigrid) {
            vname <- attr(grid$Variable, "longname")
            if (!is.null(grid$Variable$level)) {
                  auxstr <- paste(vname, grid$Variable$level, sep = "@")
                  vname <- gsub("@NA", "", auxstr)
            }
            vname <- gsub("\\s", "_", vname)
            vname <- make.names(vname, unique = TRUE)
      } else {
            vname <- paste0("Member_", 1:n.mem)
      }
      names(aux) <- vname
      # Defining grid topology -----------------
      aux.grid <- getGrid(grid)
      cellcentre.offset <- vapply(aux.grid, FUN = "[", 1L, FUN.VALUE = numeric(1L))
      cellsize <- vapply(c("resX", "resY"), FUN.VALUE = numeric(1L), FUN = function(x) attr(aux.grid, which = x))
      aux.grid <- getCoordinates(grid)
      cells.dim <- vapply(aux.grid, FUN.VALUE = integer(1L), FUN = "length")
      grd <- sp::GridTopology(cellcentre.offset, cellsize, cells.dim)
      df <- sp::SpatialGridDataFrame(grd, aux)
      ## Backdrop theme ---------------------
      if (bt != "none") {
            uri <- switch(bt,
                          "coastline" = system.file("coastline.rda", package = "downscaleR"),
                          "countries" = system.file("countries.rda", package = "downscaleR"))
            load(uri)      
            if (is.null(arg.list[["sp.layout"]])) {
                  arg.list[["sp.layout"]] <- list(l1)
            } else {
                  arg.list[["sp.layout"]][[length(arg.list[["sp.layout"]]) + 1]] <- l1
            } 
      }
      ## Default colorbar --------------
      if (is.null(arg.list[["col.regions"]])) {
            jet.colors <- colorRampPalette(c("#00007F", "blue", "#007FFF", "cyan",
                                             "#7FFF7F", "yellow", "#FF7F00", "red", "#7F0000"))
            arg.list[["col.regions"]] <- jet.colors(101)
      }
      ## Other args --------
      arg.list[["obj"]] <- df
      arg.list[["asp"]] <- 1
      do.call("spplot", arg.list)
}      


