include(CheckFunctionExists)

# First check whether the system has kqueue built-in. Prefer that over everything else.
check_function_exists(kqueue HAVE_SYSTEM_KQUEUE)

if ( NOT HAVE_SYSTEM_KQUEUE )

  # If the user passed in a path for libkqueue, see if we can find a copy of it there.
  # If they didn't pass one, build our local copy of it.
  if ( LIBKQUEUE_ROOT_DIR )

    set(static_ext "${CMAKE_STATIC_LIBRARY_SUFFIX}")

    find_path(LIBKQUEUE_ROOT_DIR
      NAMES "include/sys/event.h")

    find_library(LIBKQUEUE_LIBRARIES
      NAMES libkqueue.a
      HINTS ${LIBKQUEUE_ROOT_DIR}/lib)

    find_path(LIBKQUEUE_INCLUDE_DIRS
      NAMES "sys/event.h"
      HINTS ${LIBKQUEUE_ROOT_DIR}/include/kqueue)

    include(FindPackageHandleStandardArgs)
    find_package_handle_standard_args(LIBKQUEUE DEFAULT_MSG
      LIBKQUEUE_LIBRARIES
      LIBKQUEUE_INCLUDE_DIRS
      )

    mark_as_advanced(
      LIBKQUEUE_ROOT_DIR
      LIBKQUEUE_LIBRARIES
      LIBKQUEUE_INCLUDE_DIRS
      )

    set(zeekdeps ${zeekdeps} ${LIBKQUEUE_LIBRARIES})
    include_directories(BEFORE ${LIBKQUEUE_INCLUDE_DIRS})
    set(LIBKQUEUE_FOUND true)

  else()

    include(ExternalProject)
    set(kqueue_src     "${CMAKE_CURRENT_SOURCE_DIR}/src/3rdparty/libkqueue")
    set(kqueue_ep      "${CMAKE_CURRENT_BINARY_DIR}/libkqueue-ep")
    set(kqueue_build   "${CMAKE_CURRENT_BINARY_DIR}/libkqueue-build")
    set(kqueue_dir     "${kqueue_src}")
    set(kqueue_install "${CMAKE_INSTALL_PREFIX}")
    set(static_ext "${CMAKE_STATIC_LIBRARY_SUFFIX}")

    if ( ${CMAKE_VERSION} VERSION_LESS "3.2.0" )
      # Build byproducts is just required by the Ninja generator
      # though it's not available before CMake 3.2 ...
      if ( ${CMAKE_GENERATOR} STREQUAL Ninja )
	message(FATAL_ERROR "Ninja generator requires CMake >= 3.2")
      endif ()

      set(build_byproducts_arg)
    else ()
      set(build_byproducts_arg BUILD_BYPRODUCTS ${kqueue_build}/libkqueue${static_ext})
    endif ()

    message("${build_byproducts_arg}")

    ExternalProject_Add(project_kqueue
      PREFIX            "${kqueue_ep}"
      BINARY_DIR        "${kqueue_build}"
      DOWNLOAD_COMMAND  ""
      CONFIGURE_COMMAND ""
      BUILD_COMMAND     ""
      INSTALL_COMMAND   ""
      ${build_byproducts_arg}
      )

    if ( ${CMAKE_VERSION} VERSION_LESS "3.4.0" )
      set(use_terminal_arg)
    else ()
      set(use_terminal_arg USES_TERMINAL 1)
    endif ()

    ExternalProject_Add_Step(project_kqueue project_kqueue_build_step
      COMMAND ${CMAKE_MAKE_PROGRAM}
      COMMENT "Building libkqueue"
      WORKING_DIRECTORY ${kqueue_build}
      ALWAYS 1
      ${use_terminal_arg}
      )

    install(CODE "execute_process(
    COMMAND ${CMAKE_MAKE_PROGRAM} install
    WORKING_DIRECTORY ${kqueue_build}
    )"
      )

    if ( CMAKE_TOOLCHAIN_FILE )
      set(toolchain_arg -DCMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE})
    else ()
      set(toolchain_arg)
    endif ()

    if ( CMAKE_C_COMPILER_LAUNCHER )
      set(cmake_c_compiler_launcher_arg
        -DCMAKE_C_COMPILER_LAUNCHER:path=${CMAKE_C_COMPILER_LAUNCHER})
    else ()
      set(cmake_c_compiler_launcher_arg)
    endif ()

    if ( CMAKE_CXX_COMPILER_LAUNCHER )
      set(cmake_cxx_compiler_launcher_arg
        -DCMAKE_CXX_COMPILER_LAUNCHER:path=${CMAKE_CXX_COMPILER_LAUNCHER})
    else ()
      set(cmake_cxx_compiler_launcher_arg)
    endif ()

    execute_process(
      COMMAND
      ${CMAKE_COMMAND}
      -G${CMAKE_GENERATOR}
      ${toolchain_arg}
      ${cmake_c_compiler_launcher_arg}
      ${cmake_cxx_compiler_launcher_arg}
      -DCMAKE_BUILD_TYPE:string=${CMAKE_BUILD_TYPE}
      -DCMAKE_INSTALL_PREFIX:path=${kqueue_install}
      -DCMAKE_INSTALL_LIBDIR:path=lib
      -DSTATIC_KQUEUE=yes
      ${kqueue_src}
      WORKING_DIRECTORY ${kqueue_build}
      RESULT_VARIABLE kqueue_cmake_result
      ERROR_VARIABLE KQUEUE_CMAKE_OUTPUT
      OUTPUT_VARIABLE KQUEUE_CMAKE_OUTPUT
      ERROR_STRIP_TRAILING_WHITESPACE
      OUTPUT_STRIP_TRAILING_WHITESPACE
      )

    message("\n********** Begin libkqueue External Project CMake Output ************")
    message("\n${KQUEUE_CMAKE_OUTPUT}")
    message("\n*********** End libkqueue External Project CMake Output *************")
    message("\n")

    if (kqueue_cmake_result)
      message(FATAL_ERROR "libkqueue CMake configuration failed")
    endif ()

    add_library(libkqueue_a STATIC IMPORTED)
    set_property(TARGET libkqueue_a PROPERTY IMPORTED_LOCATION
      ${kqueue_build}/libkqueue${static_ext})
    add_dependencies(libkqueue_a project_kqueue)

    set(LIBKQUEUE_FOUND true)
    set(LIBKQUEUE_LIBRARIES libkqueue_a CACHE STRING "libkqueue libs" FORCE)
    set(LIBKQUEUE_INCLUDE_DIRS "${kqueue_src}/include" CACHE STRING "libkqueue includes" FORCE)

    include_directories(BEFORE ${LIBKQUEUE_INCLUDE_DIRS})
    set(zeekdeps ${zeekdeps} ${LIBKQUEUE_LIBRARIES})

  endif()
endif()

if ( NOT HAVE_SYSTEM_KQUEUE AND NOT LIBKQUEUE_FOUND )
  message(FATAL_ERROR "Failed to find either a working version of kqueue.")
endif()

set(USE_KQUEUE_BACKEND true)
