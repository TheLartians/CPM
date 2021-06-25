# CPM.cmake - CMake's missing package manager
# ===========================================
# See https://github.com/cpm-cmake/CPM.cmake for usage and update instructions.
#
# MIT License
# -----------
#[[
  Copyright (c) 2021 Lars Melchior and additional contributors

  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in all
  copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
  SOFTWARE.
]]

cmake_minimum_required(VERSION 3.14 FATAL_ERROR)

set(CURRENT_CPM_VERSION 1.0.0-development-version)

if(CPM_DIRECTORY)
  if(NOT CPM_DIRECTORY STREQUAL CMAKE_CURRENT_LIST_DIR)
    if(CPM_VERSION VERSION_LESS CURRENT_CPM_VERSION)
      message(
        AUTHOR_WARNING
          "${CPM_INDENT} \
A dependency is using a more recent CPM version (${CURRENT_CPM_VERSION}) than the current project (${CPM_VERSION}). \
It is recommended to upgrade CPM to the most recent version. \
See https://github.com/cpm-cmake/CPM.cmake for more information."
      )
    endif()
    if(${CMAKE_VERSION} VERSION_LESS "3.17.0")
      include(FetchContent)
    endif()
    return()
  endif()

  get_property(
    CPM_INITIALIZED GLOBAL ""
    PROPERTY CPM_INITIALIZED
    SET
  )
  if(CPM_INITIALIZED)
    return()
  endif()
endif()

set_property(GLOBAL PROPERTY CPM_INITIALIZED true)

option(CPM_USE_LOCAL_PACKAGES "Always try to use `find_package` to get dependencies"
       $ENV{CPM_USE_LOCAL_PACKAGES}
)
option(CPM_LOCAL_PACKAGES_ONLY "Only use `find_package` to get dependencies"
       $ENV{CPM_LOCAL_PACKAGES_ONLY}
)
option(CPM_DOWNLOAD_ALL "Always download dependencies from source" $ENV{CPM_DOWNLOAD_ALL})
option(CPM_DONT_UPDATE_MODULE_PATH "Don't update the module path to allow using find_package"
       $ENV{CPM_DONT_UPDATE_MODULE_PATH}
)
option(CPM_DONT_CREATE_PACKAGE_LOCK "Don't create a package lock file in the binary path"
       $ENV{CPM_DONT_CREATE_PACKAGE_LOCK}
)
option(CPM_INCLUDE_ALL_IN_PACKAGE_LOCK
       "Add all packages added through CPM.cmake to the package lock"
       $ENV{CPM_INCLUDE_ALL_IN_PACKAGE_LOCK}
)
option(CPM_USE_NAMED_CACHE_DIRECTORIES
       "Use additional directory of package name in cache on the most nested level."
       $ENV{CPM_USE_NAMED_CACHE_DIRECTORIES}
)

set(CPM_VERSION
    ${CURRENT_CPM_VERSION}
    CACHE INTERNAL ""
)
set(CPM_DIRECTORY
    ${CMAKE_CURRENT_LIST_DIR}
    CACHE INTERNAL ""
)
set(CPM_FILE
    ${CMAKE_CURRENT_LIST_FILE}
    CACHE INTERNAL ""
)
set(CPM_PACKAGES
    ""
    CACHE INTERNAL ""
)
set(CPM_DRY_RUN
    OFF
    CACHE INTERNAL "Don't download or configure dependencies (for testing)"
)

if(DEFINED ENV{CPM_SOURCE_CACHE})
  set(CPM_SOURCE_CACHE_DEFAULT $ENV{CPM_SOURCE_CACHE})
else()
  set(CPM_SOURCE_CACHE_DEFAULT OFF)
endif()

set(CPM_SOURCE_CACHE
    ${CPM_SOURCE_CACHE_DEFAULT}
    CACHE PATH "Directory to download CPM dependencies"
)

if(NOT CPM_DONT_UPDATE_MODULE_PATH)
  set(CPM_MODULE_PATH
      "${CMAKE_BINARY_DIR}/CPM_modules"
      CACHE INTERNAL ""
  )
  # remove old modules
  file(REMOVE_RECURSE ${CPM_MODULE_PATH})
  file(MAKE_DIRECTORY ${CPM_MODULE_PATH})
  # locally added CPM modules should override global packages
  set(CMAKE_MODULE_PATH "${CPM_MODULE_PATH};${CMAKE_MODULE_PATH}")
endif()

if(NOT CPM_DONT_CREATE_PACKAGE_LOCK)
  set(CPM_PACKAGE_LOCK_FILE
      "${CMAKE_BINARY_DIR}/cpm-package-lock.cmake"
      CACHE INTERNAL ""
  )
  file(WRITE ${CPM_PACKAGE_LOCK_FILE}
       "# CPM Package Lock\n# This file should be committed to version control\n\n"
  )
endif()

include(FetchContent)

# Try to infer package name from git repository uri (path or url)
function(cpm_package_name_from_git_uri URI RESULT)
  if("${URI}" MATCHES "([^/:]+)/?.git/?$")
    set(${RESULT}
        ${CMAKE_MATCH_1}
        PARENT_SCOPE
    )
  else()
    unset(${RESULT} PARENT_SCOPE)
  endif()
endfunction()

# Try to infer package name and version from a url
function(cpm_package_name_and_ver_from_url url outName outVer)
  if(url MATCHES "[/\\?]([a-zA-Z0-9_\\.-]+)\\.(tar|tar\\.gz|tar\\.bz2|zip|ZIP)(\\?|/|$)")
    # We matched an archive
    set(filename "${CMAKE_MATCH_1}")

    if(filename MATCHES "([a-zA-Z0-9_\\.-]+)[_-]v?(([0-9]+\\.)*[0-9]+[a-zA-Z0-9]*)")
      # We matched <name>-<version> (ie foo-1.2.3)
      set(${outName}
          "${CMAKE_MATCH_1}"
          PARENT_SCOPE
      )
      set(${outVer}
          "${CMAKE_MATCH_2}"
          PARENT_SCOPE
      )
    elseif(filename MATCHES "(([0-9]+\\.)+[0-9]+[a-zA-Z0-9]*)")
      # We couldn't find a name, but we found a version
      #
      # In many cases (which we don't handle here) the url would look something like
      # `irrelevant/ACTUAL_PACKAGE_NAME/irrelevant/1.2.3.zip`. In such a case we can't possibly
      # distinguish the package name from the irrelevant bits. Moreover if we try to match the
      # package name from the filename, we'd get bogus at best.
      unset(${outName} PARENT_SCOPE)
      set(${outVer}
          "${CMAKE_MATCH_1}"
          PARENT_SCOPE
      )
    else()
      # Boldly assume that the file name is the package name.
      #
      # Yes, something like `irrelevant/ACTUAL_NAME/irrelevant/download.zip` will ruin our day, but
      # such cases should be quite rare. No popular service does this... we think.
      set(${outName}
          "${filename}"
          PARENT_SCOPE
      )
      unset(${outVer} PARENT_SCOPE)
    endif()
  else()
    # No ideas yet what to do with non-archives
    unset(${outName} PARENT_SCOPE)
    unset(${outVer} PARENT_SCOPE)
  endif()
endfunction()

# Initialize logging prefix
if(NOT CPM_INDENT)
  set(CPM_INDENT
      "CPM:"
      CACHE INTERNAL ""
  )
endif()

function(cpm_find_package NAME VERSION)
  string(REPLACE " " ";" EXTRA_ARGS "${ARGN}")
  find_package(${NAME} ${VERSION} ${EXTRA_ARGS} QUIET)
  if(${CPM_ARGS_NAME}_FOUND)
    message(STATUS "${CPM_INDENT} using local package ${CPM_ARGS_NAME}@${VERSION}")
    CPMRegisterPackage(${CPM_ARGS_NAME} "${VERSION}")
    set(CPM_PACKAGE_FOUND
        YES
        PARENT_SCOPE
    )
  else()
    set(CPM_PACKAGE_FOUND
        NO
        PARENT_SCOPE
    )
  endif()
endfunction()

# Create a custom FindXXX.cmake module for a CPM package This prevents `find_package(NAME)` from
# finding the system library
function(cpm_create_module_file Name)
  if(NOT CPM_DONT_UPDATE_MODULE_PATH)
    # erase any previous modules
    file(WRITE ${CPM_MODULE_PATH}/Find${Name}.cmake
         "include(${CPM_FILE})\n${ARGN}\nset(${Name}_FOUND TRUE)"
    )
  endif()
endfunction()

# Find a package locally or fallback to CPMAddPackage
function(CPMFindPackage)
  set(oneValueArgs NAME VERSION GIT_TAG FIND_PACKAGE_ARGUMENTS)

  cmake_parse_arguments(CPM_ARGS "" "${oneValueArgs}" "" ${ARGN})

  if(NOT DEFINED CPM_ARGS_VERSION)
    if(DEFINED CPM_ARGS_GIT_TAG)
      cpm_get_version_from_git_tag("${CPM_ARGS_GIT_TAG}" CPM_ARGS_VERSION)
    endif()
  endif()

  if(CPM_DOWNLOAD_ALL)
    CPMAddPackage(${ARGN})
    cpm_export_variables(${CPM_ARGS_NAME})
    return()
  endif()

  cpm_check_if_package_already_added(${CPM_ARGS_NAME} "${CPM_ARGS_VERSION}")
  if(CPM_PACKAGE_ALREADY_ADDED)
    cpm_export_variables(${CPM_ARGS_NAME})
    return()
  endif()

  cpm_find_package(${CPM_ARGS_NAME} "${CPM_ARGS_VERSION}" ${CPM_ARGS_FIND_PACKAGE_ARGUMENTS})

  if(NOT CPM_PACKAGE_FOUND)
    CPMAddPackage(${ARGN})
    cpm_export_variables(${CPM_ARGS_NAME})
  endif()

endfunction()

# checks if a package has been added before
function(cpm_check_if_package_already_added CPM_ARGS_NAME CPM_ARGS_VERSION)
  if("${CPM_ARGS_NAME}" IN_LIST CPM_PACKAGES)
    CPMGetPackageVersion(${CPM_ARGS_NAME} CPM_PACKAGE_VERSION)
    if("${CPM_PACKAGE_VERSION}" VERSION_LESS "${CPM_ARGS_VERSION}")
      message(
        WARNING
          "${CPM_INDENT} requires a newer version of ${CPM_ARGS_NAME} (${CPM_ARGS_VERSION}) than currently included (${CPM_PACKAGE_VERSION})."
      )
    endif()
    cpm_get_fetch_properties(${CPM_ARGS_NAME})
    set(${CPM_ARGS_NAME}_ADDED NO)
    set(CPM_PACKAGE_ALREADY_ADDED
        YES
        PARENT_SCOPE
    )
    cpm_export_variables(${CPM_ARGS_NAME})
  else()
    set(CPM_PACKAGE_ALREADY_ADDED
        NO
        PARENT_SCOPE
    )
  endif()
endfunction()

# Parse the argument of CPMAddPackage in case a single one was provided and convert it to a list of
# arguments which can then be parsed idiomatically. For example gh:foo/bar@1.2.3 will be converted
# to: GITHUB_REPOSITORY;foo/bar;VERSION;1.2.3
function(cpm_parse_add_package_single_arg arg outArgs)
  # Look for a scheme
  if("${arg}" MATCHES "^([a-zA-Z]+):(.+)$")
    string(TOLOWER "${CMAKE_MATCH_1}" scheme)
    set(uri "${CMAKE_MATCH_2}")

    # Check for CPM-specific schemes
    if(scheme STREQUAL "gh")
      set(out "GITHUB_REPOSITORY;${uri}")
      set(packageType "git")
    elseif(scheme STREQUAL "gl")
      set(out "GITLAB_REPOSITORY;${uri}")
      set(packageType "git")
    elseif(scheme STREQUAL "bb")
      set(out "BITBUCKET_REPOSITORY;${uri}")
      set(packageType "git")
      # A CPM-specific scheme was not found. Looks like this is a generic URL so try to determine
      # type
    elseif(arg MATCHES ".git/?(@|#|$)")
      set(out "GIT_REPOSITORY;${arg}")
      set(packageType "git")
    else()
      # Fall back to a URL
      set(out "URL;${arg}")
      set(packageType "archive")

      # We could also check for SVN since FetchContent supports it, but SVN is so rare these days.
      # We just won't bother with the additional complexity it will induce in this function. SVN is
      # done by multi-arg
    endif()
  else()
    if(arg MATCHES ".git/?(@|#|$)")
      set(out "GIT_REPOSITORY;${arg}")
      set(packageType "git")
    else()
      # Give up
      message(FATAL_ERROR "CPM: Can't determine package type of '${arg}'")
    endif()
  endif()

  # For all packages we interpret @... as version. Only replace the last occurence. Thus URIs
  # containing '@' can be used
  string(REGEX REPLACE "@([^@]+)$" ";VERSION;\\1" out "${out}")

  # Parse the rest according to package type
  if(packageType STREQUAL "git")
    # For git repos we interpret #... as a tag or branch or commit hash
    string(REGEX REPLACE "#([^#]+)$" ";GIT_TAG;\\1" out "${out}")
  elseif(packageType STREQUAL "archive")
    # For archives we interpret #... as a URL hash.
    string(REGEX REPLACE "#([^#]+)$" ";URL_HASH;\\1" out "${out}")
    # We don't try to parse the version if it's not provided explicitly. cpm_get_version_from_url
    # should do this at a later point
  else()
    # We should never get here. This is an assertion and hitting it means there's a bug in the code
    # above. A packageType was set, but not handled by this if-else.
    message(FATAL_ERROR "CPM: Unsupported package type '${packageType}' of '${arg}'")
  endif()

  set(${outArgs}
      ${out}
      PARENT_SCOPE
  )
endfunction()

# Download and add a package from source
function(CPMAddPackage)
  list(LENGTH ARGN argnLength)
  if(argnLength EQUAL 1)
    cpm_parse_add_package_single_arg("${ARGN}" ARGN)

    # The shorthand syntax implies EXCLUDE_FROM_ALL
    set(ARGN "${ARGN};EXCLUDE_FROM_ALL;YES")
  endif()

  set(oneValueArgs
      NAME
      FORCE
      VERSION
      GIT_TAG
      DOWNLOAD_ONLY
      GITHUB_REPOSITORY
      GITLAB_REPOSITORY
      BITBUCKET_REPOSITORY
      GIT_REPOSITORY
      SOURCE_DIR
      DOWNLOAD_COMMAND
      FIND_PACKAGE_ARGUMENTS
      NO_CACHE
      GIT_SHALLOW
      EXCLUDE_FROM_ALL
      SOURCE_SUBDIR
  )

  set(multiValueArgs URL OPTIONS)

  cmake_parse_arguments(CPM_ARGS "" "${oneValueArgs}" "${multiValueArgs}" "${ARGN}")

  # Set default values for arguments

  if(NOT DEFINED CPM_ARGS_VERSION)
    if(DEFINED CPM_ARGS_GIT_TAG)
      cpm_get_version_from_git_tag("${CPM_ARGS_GIT_TAG}" CPM_ARGS_VERSION)
    endif()
  endif()

  if(CPM_ARGS_DOWNLOAD_ONLY)
    set(DOWNLOAD_ONLY ${CPM_ARGS_DOWNLOAD_ONLY})
  else()
    set(DOWNLOAD_ONLY NO)
  endif()

  if(DEFINED CPM_ARGS_GITHUB_REPOSITORY)
    set(CPM_ARGS_GIT_REPOSITORY "https://github.com/${CPM_ARGS_GITHUB_REPOSITORY}.git")
  elseif(DEFINED CPM_ARGS_GITLAB_REPOSITORY)
    set(CPM_ARGS_GIT_REPOSITORY "https://gitlab.com/${CPM_ARGS_GITLAB_REPOSITORY}.git")
  elseif(DEFINED CPM_ARGS_BITBUCKET_REPOSITORY)
    set(CPM_ARGS_GIT_REPOSITORY "https://bitbucket.org/${CPM_ARGS_BITBUCKET_REPOSITORY}.git")
  endif()

  if(DEFINED CPM_ARGS_GIT_REPOSITORY)
    list(APPEND CPM_ARGS_UNPARSED_ARGUMENTS GIT_REPOSITORY ${CPM_ARGS_GIT_REPOSITORY})
    if(NOT DEFINED CPM_ARGS_GIT_TAG)
      set(CPM_ARGS_GIT_TAG v${CPM_ARGS_VERSION})
    endif()

    # If a name wasn't provided, try to infer it from the git repo
    if(NOT DEFINED CPM_ARGS_NAME)
      cpm_package_name_from_git_uri(${CPM_ARGS_GIT_REPOSITORY} CPM_ARGS_NAME)
    endif()
  endif()

  set(CPM_SKIP_FETCH FALSE)

  if(DEFINED CPM_ARGS_GIT_TAG)
    list(APPEND CPM_ARGS_UNPARSED_ARGUMENTS GIT_TAG ${CPM_ARGS_GIT_TAG})
    # If GIT_SHALLOW is explicitly specified, honor the value.
    if(DEFINED CPM_ARGS_GIT_SHALLOW)
      list(APPEND CPM_ARGS_UNPARSED_ARGUMENTS GIT_SHALLOW ${CPM_ARGS_GIT_SHALLOW})
    endif()
  endif()

  if(DEFINED CPM_ARGS_URL)
    # If a name or version aren't provided, try to infer them from the URL
    list(GET CPM_ARGS_URL 0 firstUrl)
    cpm_package_name_and_ver_from_url(${firstUrl} nameFromUrl verFromUrl)
    # If we fail to obtain name and version from the first URL, we could try other URLs if any.
    # However multiple URLs are expected to be quite rare, so for now we won't bother.

    # If the caller provided their own name and version, they trump the inferred ones.
    if(NOT DEFINED CPM_ARGS_NAME)
      set(CPM_ARGS_NAME ${nameFromUrl})
    endif()
    if(NOT DEFINED CPM_ARGS_VERSION)
      set(CPM_ARGS_VERSION ${verFromUrl})
    endif()

    list(APPEND CPM_ARGS_UNPARSED_ARGUMENTS URL "${CPM_ARGS_URL}")
  endif()

  # Check for required arguments

  if(NOT DEFINED CPM_ARGS_NAME)
    message(
      FATAL_ERROR
        "CPM: 'NAME' was not provided and couldn't be automatically inferred for package added with arguments: '${ARGN}'"
    )
  endif()

  # Check if package has been added before
  cpm_check_if_package_already_added(${CPM_ARGS_NAME} "${CPM_ARGS_VERSION}")
  if(CPM_PACKAGE_ALREADY_ADDED)
    cpm_export_variables(${CPM_ARGS_NAME})
    return()
  endif()

  # Check for manual overrides
  if(NOT CPM_ARGS_FORCE AND NOT "${CPM_${CPM_ARGS_NAME}_SOURCE}" STREQUAL "")
    set(PACKAGE_SOURCE ${CPM_${CPM_ARGS_NAME}_SOURCE})
    set(CPM_${CPM_ARGS_NAME}_SOURCE "")
    CPMAddPackage(
      NAME "${CPM_ARGS_NAME}"
      SOURCE_DIR "${PACKAGE_SOURCE}"
      EXCLUDE_FROM_ALL "${CPM_ARGS_EXCLUDE_FROM_ALL}"
      OPTIONS "${CPM_ARGS_OPTIONS}"
      SOURCE_SUBDIR "${CPM_ARGS_SOURCE_SUBDIR}"
      FORCE True
    )
    cpm_export_variables(${CPM_ARGS_NAME})
    return()
  endif()

  # Check for available declaration
  if(NOT CPM_ARGS_FORCE AND NOT "${CPM_DECLARATION_${CPM_ARGS_NAME}}" STREQUAL "")
    set(declaration ${CPM_DECLARATION_${CPM_ARGS_NAME}})
    set(CPM_DECLARATION_${CPM_ARGS_NAME} "")
    CPMAddPackage(${declaration})
    cpm_export_variables(${CPM_ARGS_NAME})
    # checking again to ensure version and option compatibility
    cpm_check_if_package_already_added(${CPM_ARGS_NAME} "${CPM_ARGS_VERSION}")
    return()
  endif()

  if(CPM_USE_LOCAL_PACKAGES OR CPM_LOCAL_PACKAGES_ONLY)
    cpm_find_package(${CPM_ARGS_NAME} "${CPM_ARGS_VERSION}" ${CPM_ARGS_FIND_PACKAGE_ARGUMENTS})

    if(CPM_PACKAGE_FOUND)
      cpm_export_variables(${CPM_ARGS_NAME})
      return()
    endif()

    if(CPM_LOCAL_PACKAGES_ONLY)
      message(
        SEND_ERROR
          "CPM: ${CPM_ARGS_NAME} not found via find_package(${CPM_ARGS_NAME} ${CPM_ARGS_VERSION})"
      )
    endif()
  endif()

  CPMRegisterPackage("${CPM_ARGS_NAME}" "${CPM_ARGS_VERSION}")

  if(DEFINED CPM_ARGS_GIT_TAG)
    set(PACKAGE_INFO "${CPM_ARGS_GIT_TAG}")
  elseif(DEFINED CPM_ARGS_SOURCE_DIR)
    set(PACKAGE_INFO "${CPM_ARGS_SOURCE_DIR}")
  else()
    set(PACKAGE_INFO "${CPM_ARGS_VERSION}")
  endif()

  if(DEFINED FETCHCONTENT_BASE_DIR)
    # respect user's FETCHCONTENT_BASE_DIR if set
    set(CPM_FETCHCONTENT_BASE_DIR ${FETCHCONTENT_BASE_DIR})
  else()
    set(CPM_FETCHCONTENT_BASE_DIR ${CMAKE_BINARY_DIR}/_deps)
  endif()

  if(DEFINED CPM_ARGS_DOWNLOAD_COMMAND)
    list(APPEND CPM_ARGS_UNPARSED_ARGUMENTS DOWNLOAD_COMMAND ${CPM_ARGS_DOWNLOAD_COMMAND})
  elseif(DEFINED CPM_ARGS_SOURCE_DIR)
    list(APPEND CPM_ARGS_UNPARSED_ARGUMENTS SOURCE_DIR ${CPM_ARGS_SOURCE_DIR})
  elseif(CPM_SOURCE_CACHE AND NOT CPM_ARGS_NO_CACHE)
    string(TOLOWER ${CPM_ARGS_NAME} lower_case_name)
    set(origin_parameters ${CPM_ARGS_UNPARSED_ARGUMENTS})
    list(SORT origin_parameters)
    if(CPM_USE_NAMED_CACHE_DIRECTORIES)
      string(SHA1 origin_hash "${origin_parameters};NEW_CACHE_STRUCTURE_TAG")
      set(download_directory ${CPM_SOURCE_CACHE}/${lower_case_name}/${origin_hash}/${CPM_ARGS_NAME})
    else()
      string(SHA1 origin_hash "${origin_parameters}")
      set(download_directory ${CPM_SOURCE_CACHE}/${lower_case_name}/${origin_hash})
    endif()
    # Expand `download_directory` relative path. This is important because EXISTS doesn't work for
    # relative paths.
    get_filename_component(download_directory ${download_directory} ABSOLUTE)
    list(APPEND CPM_ARGS_UNPARSED_ARGUMENTS SOURCE_DIR ${download_directory})
    if(EXISTS ${download_directory})
      # avoid FetchContent modules to improve performance
      set(${CPM_ARGS_NAME}_BINARY_DIR ${CPM_FETCHCONTENT_BASE_DIR}/${lower_case_name}-build)
      set(${CPM_ARGS_NAME}_ADDED YES)
      set(${CPM_ARGS_NAME}_SOURCE_DIR ${download_directory})
      cpm_add_subdirectory(
        "${CPM_ARGS_NAME}" "${DOWNLOAD_ONLY}"
        "${${CPM_ARGS_NAME}_SOURCE_DIR}/${CPM_ARGS_SOURCE_SUBDIR}" "${${CPM_ARGS_NAME}_BINARY_DIR}"
        "${CPM_ARGS_EXCLUDE_FROM_ALL}" "${CPM_ARGS_OPTIONS}"
      )
      set(CPM_SKIP_FETCH TRUE)
      set(PACKAGE_INFO "${PACKAGE_INFO} at ${download_directory}")
    else()
      # Enable shallow clone when GIT_TAG is not a commit hash. Our guess may not be accurate, but
      # it should guarantee no commit hash get mis-detected.
      if(NOT DEFINED CPM_ARGS_GIT_SHALLOW)
        cpm_is_git_tag_commit_hash("${CPM_ARGS_GIT_TAG}" IS_HASH)
        if(NOT ${IS_HASH})
          list(APPEND CPM_ARGS_UNPARSED_ARGUMENTS GIT_SHALLOW TRUE)
        endif()
      endif()

      # remove timestamps so CMake will re-download the dependency
      file(REMOVE_RECURSE ${CPM_FETCHCONTENT_BASE_DIR}/${lower_case_name}-subbuild)
      set(PACKAGE_INFO "${PACKAGE_INFO} to ${download_directory}")
    endif()
  endif()

  cpm_create_module_file(${CPM_ARGS_NAME} "CPMAddPackage(${ARGN})")

  if(CPM_PACKAGE_LOCK_ENABLED)
    if((CPM_ARGS_VERSION AND NOT CPM_ARGS_SOURCE_DIR) OR CPM_INCLUDE_ALL_IN_PACKAGE_LOCK)
      cpm_add_to_package_lock(${CPM_ARGS_NAME} "${ARGN}")
    elseif(CPM_ARGS_SOURCE_DIR)
      cpm_add_comment_to_package_lock(${CPM_ARGS_NAME} "local directory")
    else()
      cpm_add_comment_to_package_lock(${CPM_ARGS_NAME} "${ARGN}")
    endif()
  endif()

  message(
    STATUS "${CPM_INDENT} adding package ${CPM_ARGS_NAME}@${CPM_ARGS_VERSION} (${PACKAGE_INFO})"
  )

  if(NOT CPM_SKIP_FETCH)
    cpm_declare_fetch(
      "${CPM_ARGS_NAME}" "${CPM_ARGS_VERSION}" "${PACKAGE_INFO}" "${CPM_ARGS_UNPARSED_ARGUMENTS}"
    )
    cpm_fetch_package("${CPM_ARGS_NAME}")
    cpm_add_subdirectory(
      "${CPM_ARGS_NAME}" "${DOWNLOAD_ONLY}"
      "${${CPM_ARGS_NAME}_SOURCE_DIR}/${CPM_ARGS_SOURCE_SUBDIR}" "${${CPM_ARGS_NAME}_BINARY_DIR}"
      "${CPM_ARGS_EXCLUDE_FROM_ALL}" "${CPM_ARGS_OPTIONS}"
    )
    cpm_get_fetch_properties("${CPM_ARGS_NAME}")
  endif()

  set(${CPM_ARGS_NAME}_ADDED YES)
  cpm_export_variables("${CPM_ARGS_NAME}")
endfunction()

# Fetch a previously declared package
macro(CPMGetPackage Name)
  if(DEFINED "CPM_DECLARATION_${Name}")
    CPMAddPackage(NAME ${Name})
  else()
    message(SEND_ERROR "Cannot retrieve package ${Name}: no declaration available")
  endif()
endmacro()

# export variables available to the caller to the parent scope expects ${CPM_ARGS_NAME} to be set
macro(cpm_export_variables name)
  set(${name}_SOURCE_DIR
      "${${name}_SOURCE_DIR}"
      PARENT_SCOPE
  )
  set(${name}_BINARY_DIR
      "${${name}_BINARY_DIR}"
      PARENT_SCOPE
  )
  set(${name}_ADDED
      "${${name}_ADDED}"
      PARENT_SCOPE
  )
endmacro()

# declares a package, so that any call to CPMAddPackage for the package name will use these
# arguments instead. Previous declarations will not be overriden.
macro(CPMDeclarePackage Name)
  if(NOT DEFINED "CPM_DECLARATION_${Name}")
    set("CPM_DECLARATION_${Name}" "${ARGN}")
  endif()
endmacro()

function(cpm_add_to_package_lock Name)
  if(NOT CPM_DONT_CREATE_PACKAGE_LOCK)
    cpm_prettify_package_arguments(PRETTY_ARGN false ${ARGN})
    file(APPEND ${CPM_PACKAGE_LOCK_FILE} "# ${Name}\nCPMDeclarePackage(${Name}\n${PRETTY_ARGN})\n")
  endif()
endfunction()

function(cpm_add_comment_to_package_lock Name)
  if(NOT CPM_DONT_CREATE_PACKAGE_LOCK)
    cpm_prettify_package_arguments(PRETTY_ARGN true ${ARGN})
    file(APPEND ${CPM_PACKAGE_LOCK_FILE}
         "# ${Name} (unversioned)\n# CPMDeclarePackage(${Name}\n${PRETTY_ARGN}#)\n"
    )
  endif()
endfunction()

# includes the package lock file if it exists and creates a target `cpm-write-package-lock` to
# update it
macro(CPMUsePackageLock file)
  if(NOT CPM_DONT_CREATE_PACKAGE_LOCK)
    get_filename_component(CPM_ABSOLUTE_PACKAGE_LOCK_PATH ${file} ABSOLUTE)
    if(EXISTS ${CPM_ABSOLUTE_PACKAGE_LOCK_PATH})
      include(${CPM_ABSOLUTE_PACKAGE_LOCK_PATH})
    endif()
    if(NOT TARGET cpm-update-package-lock)
      add_custom_target(
        cpm-update-package-lock COMMAND ${CMAKE_COMMAND} -E copy ${CPM_PACKAGE_LOCK_FILE}
                                        ${CPM_ABSOLUTE_PACKAGE_LOCK_PATH}
      )
    endif()
    set(CPM_PACKAGE_LOCK_ENABLED true)
  endif()
endmacro()

# registers a package that has been added to CPM
function(CPMRegisterPackage PACKAGE VERSION)
  list(APPEND CPM_PACKAGES ${PACKAGE})
  set(CPM_PACKAGES
      ${CPM_PACKAGES}
      CACHE INTERNAL ""
  )
  set("CPM_PACKAGE_${PACKAGE}_VERSION"
      ${VERSION}
      CACHE INTERNAL ""
  )
endfunction()

# retrieve the current version of the package to ${OUTPUT}
function(CPMGetPackageVersion PACKAGE OUTPUT)
  set(${OUTPUT}
      "${CPM_PACKAGE_${PACKAGE}_VERSION}"
      PARENT_SCOPE
  )
endfunction()

# declares a package in FetchContent_Declare
function(cpm_declare_fetch PACKAGE VERSION INFO)
  if(${CPM_DRY_RUN})
    message(STATUS "${CPM_INDENT} package not declared (dry run)")
    return()
  endif()

  FetchContent_Declare(${PACKAGE} ${ARGN})
endfunction()

# returns properties for a package previously defined by cpm_declare_fetch
function(cpm_get_fetch_properties PACKAGE)
  if(${CPM_DRY_RUN})
    return()
  endif()
  FetchContent_GetProperties(${PACKAGE})
  string(TOLOWER ${PACKAGE} lpackage)
  set(${PACKAGE}_SOURCE_DIR
      "${${lpackage}_SOURCE_DIR}"
      PARENT_SCOPE
  )
  set(${PACKAGE}_BINARY_DIR
      "${${lpackage}_BINARY_DIR}"
      PARENT_SCOPE
  )
endfunction()

# adds a package as a subdirectory if viable, according to provided options
function(
  cpm_add_subdirectory
  PACKAGE
  DOWNLOAD_ONLY
  SOURCE_DIR
  BINARY_DIR
  EXCLUDE
  OPTIONS
)
  if(NOT DOWNLOAD_ONLY AND EXISTS ${SOURCE_DIR}/CMakeLists.txt)
    if(EXCLUDE)
      set(addSubdirectoryExtraArgs EXCLUDE_FROM_ALL)
    else()
      set(addSubdirectoryExtraArgs "")
    endif()
    if(OPTIONS)
      # the policy allows us to change options without caching
      cmake_policy(SET CMP0077 NEW)
      set(CMAKE_POLICY_DEFAULT_CMP0077 NEW)

      foreach(OPTION ${OPTIONS})
        cpm_parse_option(${OPTION})
        set(${OPTION_KEY} ${OPTION_VALUE})
      endforeach()
    endif()
    set(CPM_OLD_INDENT "${CPM_INDENT}")
    set(CPM_INDENT "${CPM_INDENT} ${PACKAGE}:")
    add_subdirectory(${SOURCE_DIR} ${BINARY_DIR} ${addSubdirectoryExtraArgs})
    set(CPM_INDENT "${CPM_OLD_INDENT}")
  endif()
endfunction()

# downloads a previously declared package via FetchContent and exports the variables
# `${PACKAGE}_SOURCE_DIR` and `${PACKAGE}_BINARY_DIR` to the parent scope
function(cpm_fetch_package PACKAGE)
  if(${CPM_DRY_RUN})
    message(STATUS "${CPM_INDENT} package ${PACKAGE} not fetched (dry run)")
    return()
  endif()

  FetchContent_GetProperties(${PACKAGE})

  if(NOT ${lower_case_name}_POPULATED)
    FetchContent_Populate(${PACKAGE})
  endif()

  string(TOLOWER "${PACKAGE}" lower_case_name)
  set(${PACKAGE}_SOURCE_DIR
      ${${lower_case_name}_SOURCE_DIR}
      PARENT_SCOPE
  )
  set(${PACKAGE}_BINARY_DIR
      ${${lower_case_name}_BINARY_DIR}
      PARENT_SCOPE
  )
endfunction()

# splits a package option
function(cpm_parse_option OPTION)
  string(REGEX MATCH "^[^ ]+" OPTION_KEY ${OPTION})
  string(LENGTH ${OPTION} OPTION_LENGTH)
  string(LENGTH ${OPTION_KEY} OPTION_KEY_LENGTH)
  if(OPTION_KEY_LENGTH STREQUAL OPTION_LENGTH)
    # no value for key provided, assume user wants to set option to "ON"
    set(OPTION_VALUE "ON")
  else()
    math(EXPR OPTION_KEY_LENGTH "${OPTION_KEY_LENGTH}+1")
    string(SUBSTRING ${OPTION} "${OPTION_KEY_LENGTH}" "-1" OPTION_VALUE)
  endif()
  set(OPTION_KEY
      "${OPTION_KEY}"
      PARENT_SCOPE
  )
  set(OPTION_VALUE
      "${OPTION_VALUE}"
      PARENT_SCOPE
  )
endfunction()

# guesses the package version from a git tag
function(cpm_get_version_from_git_tag GIT_TAG RESULT)
  string(LENGTH ${GIT_TAG} length)
  if(length EQUAL 40)
    # GIT_TAG is probably a git hash
    set(${RESULT}
        0
        PARENT_SCOPE
    )
  else()
    string(REGEX MATCH "v?([0123456789.]*).*" _ ${GIT_TAG})
    set(${RESULT}
        ${CMAKE_MATCH_1}
        PARENT_SCOPE
    )
  endif()
endfunction()

# guesses if the git tag is a commit hash or an actual tag or a branch nane.
function(cpm_is_git_tag_commit_hash GIT_TAG RESULT)
  string(LENGTH "${GIT_TAG}" length)
  # full hash has 40 characters, and short hash has at least 7 characters.
  if(length LESS 7 OR length GREATER 40)
    set(${RESULT}
        0
        PARENT_SCOPE
    )
  else()
    if(${GIT_TAG} MATCHES "^[a-fA-F0-9]+$")
      set(${RESULT}
          1
          PARENT_SCOPE
      )
    else()
      set(${RESULT}
          0
          PARENT_SCOPE
      )
    endif()
  endif()
endfunction()

function(cpm_prettify_package_arguments OUT_VAR IS_IN_COMMENT)
  set(oneValueArgs
      NAME
      FORCE
      VERSION
      GIT_TAG
      DOWNLOAD_ONLY
      GITHUB_REPOSITORY
      GITLAB_REPOSITORY
      GIT_REPOSITORY
      SOURCE_DIR
      DOWNLOAD_COMMAND
      FIND_PACKAGE_ARGUMENTS
      NO_CACHE
      GIT_SHALLOW
  )
  set(multiValueArgs OPTIONS)
  cmake_parse_arguments(CPM_ARGS "" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

  foreach(oneArgName ${oneValueArgs})
    if(DEFINED CPM_ARGS_${oneArgName})
      if(${IS_IN_COMMENT})
        string(APPEND PRETTY_OUT_VAR "#")
      endif()
      if(${oneArgName} STREQUAL "SOURCE_DIR")
        string(REPLACE ${CMAKE_SOURCE_DIR} "\${CMAKE_SOURCE_DIR}" CPM_ARGS_${oneArgName}
                       ${CPM_ARGS_${oneArgName}}
        )
      endif()
      string(APPEND PRETTY_OUT_VAR "  ${oneArgName} ${CPM_ARGS_${oneArgName}}\n")
    endif()
  endforeach()
  foreach(multiArgName ${multiValueArgs})
    if(DEFINED CPM_ARGS_${multiArgName})
      if(${IS_IN_COMMENT})
        string(APPEND PRETTY_OUT_VAR "#")
      endif()
      string(APPEND PRETTY_OUT_VAR "  ${multiArgName}\n")
      foreach(singleOption ${CPM_ARGS_${multiArgName}})
        if(${IS_IN_COMMENT})
          string(APPEND PRETTY_OUT_VAR "#")
        endif()
        string(APPEND PRETTY_OUT_VAR "    \"${singleOption}\"\n")
      endforeach()
    endif()
  endforeach()

  if(NOT "${CPM_ARGS_UNPARSED_ARGUMENTS}" STREQUAL "")
    if(${IS_IN_COMMENT})
      string(APPEND PRETTY_OUT_VAR "#")
    endif()
    string(APPEND PRETTY_OUT_VAR " ")
    foreach(CPM_ARGS_UNPARSED_ARGUMENT ${CPM_ARGS_UNPARSED_ARGUMENTS})
      string(APPEND PRETTY_OUT_VAR " ${CPM_ARGS_UNPARSED_ARGUMENT}")
    endforeach()
    string(APPEND PRETTY_OUT_VAR "\n")
  endif()

  set(${OUT_VAR}
      ${PRETTY_OUT_VAR}
      PARENT_SCOPE
  )

endfunction()
