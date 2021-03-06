# - Try to locate glib3
# This module defines:
#
#  GLIB_INCLUDE_DIRS
#  GLIB_LIBRARIES
#  GLIB_FOUND
#  GLIB_DEFINITIONS
#

FIND_PACKAGE(PkgConfig)

PKG_CHECK_MODULES(PC_GLIB REQUIRED glib-2.0)

SET(GLIB_INCLUDE_DIRS ${PC_GLIB_INCLUDE_DIRS})

FOREACH(LIB ${PC_GLIB_LIBRARIES})
	FIND_LIBRARY(FOUND${LIB} HINTS ${PC_GLIB_LIBRARY_DIRS} NAMES ${LIB})
	LIST(APPEND GLIB_LIBRARIES ${FOUND${LIB}})
ENDFOREACH(LIB)

IF(GLIB_INCLUDE_DIRS AND GLIB_LIBRARIES)
	SET(GLIB_FOUND TRUE)
ENDIF(GLIB_INCLUDE_DIRS AND GLIB_LIBRARIES)

IF(GLIB_FOUND)
	IF(NOT GLIB_FIND_QUIETLY)
		MESSAGE(STATUS "Found GLIB: -I${GLIB_INCLUDE_DIRS}, ${GLIB_LIBRARIES}")
	ENDIF(NOT GLIB_FIND_QUIETLY)
ELSE(GLIB_FOUND)
	IF(GLIB_FIND_REQUIRED)
		MESSAGE(FATAL_ERROR "Could not find GLIB")
	ENDIF(GLIB_FIND_REQUIRED)
ENDIF(GLIB_FOUND)

MARK_AS_ADVANCED(GLIB_INCLUDE_DIRS GLIB_LIBRARIES GLIB_FOUND)
