# VcpkgHelpers.cmake
# Provides helper functions for integrating vcpkg-installed packages
# based on vcpkg.json manifest.

cmake_minimum_required(VERSION 3.19) # For string(JSON ...)

# Function to extract package names from vcpkg.json
# Sets _VCPKG_DEPENDENCIES in the PARENT_SCOPE.
function(_vcpkg_extract_dependencies)
    # In a real project, vcpkg.json is usually at the root of the source dir.
    # If this script is in a cmake/ subdirectory, CMAKE_SOURCE_DIR is the root.
    # If this script is included from a CMakeLists.txt in a subdirectory, 
    # CMAKE_CURRENT_SOURCE_DIR refers to that subdirectory.
    # For widest compatibility, assume vcpkg.json is relative to the top-level CMakeLists.txt
    set(VCPKG_JSON_PATH "${CMAKE_SOURCE_DIR}/vcpkg.json")

    # Initialize _VCPKG_DEPENDENCIES in the parent scope to an empty list (empty string)
    set(_VCPKG_DEPENDENCIES "" PARENT_SCOPE)

    if(NOT EXISTS "${VCPKG_JSON_PATH}")
        message(VERBOSE "vcpkg.json not found at ${VCPKG_JSON_PATH}. Skipping vcpkg package discovery.")
        return()
    endif()

    file(READ "${VCPKG_JSON_PATH}" VCPKG_JSON_CONTENT)
    string(JSON VCPKG_JSON_ERROR ERROR_VARIABLE VCPKG_JSON_CONTENT)

    if(NOT VCPKG_JSON_ERROR STREQUAL "NO_ERROR")
        message(WARNING "Failed to parse vcpkg.json: ${VCPKG_JSON_ERROR}")
        return()
    endif()

    string(JSON DEPENDENCIES_LIST GET "${VCPKG_JSON_CONTENT}" "dependencies")

    if(NOT DEPENDENCIES_LIST)
        message(VERBOSE "No dependencies found in vcpkg.json.")
        return()
    endif()
    
    message(VERBOSE "Raw dependencies from vcpkg.json: ${DEPENDENCIES_LIST}")

    set(extracted_package_names "") # Local variable for extraction
    list(LENGTH DEPENDENCIES_LIST num_dependencies)

    if(num_dependencies GREATER 0)
        math(EXPR last_index "${num_dependencies} - 1")
        foreach(idx RANGE ${last_index})
            string(JSON dep_item GET "${DEPENDENCIES_LIST}" ${idx})
            string(JSON dep_type TYPE "${dep_item}")

            if(dep_type STREQUAL "OBJECT")
                string(JSON pkg_name GET "${dep_item}" "name")
                list(APPEND extracted_package_names "${pkg_name}")
            elseif(dep_type STREQUAL "STRING")
                list(APPEND extracted_package_names "${dep_item}")
            else()
                message(WARNING "Unknown dependency format in vcpkg.json: ${dep_item}")
            endif()
        endforeach()
    endif()

    if(extracted_package_names)
        list(REMOVE_DUPLICATES extracted_package_names)
        set(_VCPKG_DEPENDENCIES ${extracted_package_names} PARENT_SCOPE) # Set in parent scope
        message(STATUS "vcpkg dependencies from manifest: ${extracted_package_names}")
    else()
        message(VERBOSE "No package names extracted from vcpkg.json dependencies.")
        # _VCPKG_DEPENDENCIES is already set to "" in PARENT_SCOPE initially by this function
    endif()
endfunction()

# Function to find all packages listed in _VCPKG_DEPENDENCIES (set by _vcpkg_extract_dependencies in this function's PARENT_SCOPE)
# This function will define _VCPKG_FOUND_PACKAGES and _VCPKG_FOUND_TARGETS in its PARENT_SCOPE (i.e., the CMakeLists.txt that calls this).
function(vcpkg_find_packages)
    message(STATUS "Debug VFP: vcpkg_find_packages CALLED.")

    # Call _vcpkg_extract_dependencies. It will set _VCPKG_DEPENDENCIES in this function's scope (its parent).
    _vcpkg_extract_dependencies()
    
    # Now, _VCPKG_DEPENDENCIES is available in the current scope of vcpkg_find_packages.
    if(DEFINED _VCPKG_DEPENDENCIES)
        message(STATUS "Debug VFP: _VCPKG_DEPENDENCIES in vfp scope: \'${_VCPKG_DEPENDENCIES}\' (IS DEFINED)")
    else()
        # This case should ideally not be hit if _vcpkg_extract_dependencies works correctly.
        message(WARNING "Debug VFP: _VCPKG_DEPENDENCIES in vfp scope: (IS NOT DEFINED after calling _vcpkg_extract_dependencies)")
        set(_VCPKG_DEPENDENCIES "") # Ensure it's an empty list locally if somehow not set.
    endif()

    # Initialize found packages and targets lists in the PARENT (caller of vcpkg_find_packages) scope.
    set(_VCPKG_FOUND_PACKAGES "" PARENT_SCOPE)
    set(_VCPKG_FOUND_TARGETS "" PARENT_SCOPE)

    if(NOT _VCPKG_DEPENDENCIES) # Check the version local to this function's scope (set by _vcpkg_extract_dependencies)
        message(VERBOSE "No vcpkg dependencies to find as _VCPKG_DEPENDENCIES is empty in vfp scope.")
        message(STATUS "Debug VFP: vcpkg_find_packages FINISHED (no dependencies).")
        return()
    endif()

    # Iterate using the _VCPKG_DEPENDENCIES available in the current (vfp) scope.
    foreach(PKG_NAME IN LISTS _VCPKG_DEPENDENCIES) 
        string(TOLOWER "${PKG_NAME}" lower_pkg_name)
        string(REPLACE "-" "_" pkg_name_cmake "${lower_pkg_name}")
        
        find_package(${PKG_NAME} CONFIG QUIET)
        
        if(${PKG_NAME}_FOUND)
            message(STATUS "Found vcpkg package: ${PKG_NAME}")
            list(APPEND _VCPKG_FOUND_PACKAGES ${PKG_NAME} PARENT_SCOPE) # Set in PARENT scope
            
            set(imported_target_guess1 "${PKG_NAME}::${PKG_NAME}")
            set(imported_target_guess2 "${PKG_NAME}::${pkg_name_cmake}")
            set(imported_target_guess3 "${PKG_NAME}")
            set(imported_target "") # Local variable

            if(TARGET ${imported_target_guess1})
                set(imported_target ${imported_target_guess1})
            elseif(TARGET ${imported_target_guess2})
                set(imported_target ${imported_target_guess2})
            elseif(TARGET ${imported_target_guess3})
                 set(imported_target ${imported_target_guess3})
            else()
                message(WARNING "Could not determine imported target for vcpkg package: ${PKG_NAME}. Tried ${imported_target_guess1}, ${imported_target_guess2}, and ${imported_target_guess3}. Manual linking might be required.")
            endif()
            
            if(imported_target)
                list(APPEND _VCPKG_FOUND_TARGETS ${imported_target} PARENT_SCOPE) # Set in PARENT scope
            endif()
        else()
            message(WARNING "vcpkg package not found: ${PKG_NAME}. Ensure it\'s installed via vcpkg or correctly listed in vcpkg.json.")
        endif()
    endforeach()

    # For debugging, check the value in the PARENT_SCOPE.
    # This requires a bit of a trick or relying on the fact that subsequent functions will read it.
    # The message below will show the current scope's _VCPKG_FOUND_TARGETS, which isn't what the caller sees directly.
    # However, since we used PARENT_SCOPE for list(APPEND ...), the caller's version *is* being updated.
    message(STATUS "Debug VFP: vcpkg_find_packages FINISHED. Variables _VCPKG_FOUND_PACKAGES and _VCPKG_FOUND_TARGETS set in PARENT_SCOPE.")
endfunction()

# Function to link found vcpkg libraries to a target
# Usage: vcpkg_link_libraries(TARGET <target_name> LINK_TYPE <PRIVATE|PUBLIC|INTERFACE>)
#        vcpkg_link_libraries(TARGET <target_name> LINK_TYPE <PRIVATE|PUBLIC|INTERFACE> PACKAGES <pkg1> <pkg2> ...)
function(vcpkg_link_libraries)
    set(options)
    set(oneValueArgs TARGET LINK_TYPE)
    set(multiValueArgs PACKAGES)
    cmake_parse_arguments(VLL "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    if(NOT VLL_TARGET)
        message(FATAL_ERROR "vcpkg_link_libraries: TARGET argument is required.")
        return()
    endif()

    if(NOT VLL_LINK_TYPE)
        message(FATAL_ERROR "vcpkg_link_libraries: LINK_TYPE argument (PRIVATE, PUBLIC, or INTERFACE) is required.")
        return()
    endif()

    if(NOT (VLL_LINK_TYPE STREQUAL "PRIVATE" OR VLL_LINK_TYPE STREQUAL "PUBLIC" OR VLL_LINK_TYPE STREQUAL "INTERFACE"))
        message(FATAL_ERROR "vcpkg_link_libraries: Invalid LINK_TYPE \'${VLL_LINK_TYPE}\'. Must be PRIVATE, PUBLIC, or INTERFACE.")
        return()
    endif()

    # These variables are expected to have been set in this function's CALLER'S scope 
    # by a previous call to vcpkg_find_packages().
    if(DEFINED _VCPKG_FOUND_TARGETS) 
        message(STATUS "Debug VLL: _VCPKG_FOUND_TARGETS in vll scope (from caller): \'${_VCPKG_FOUND_TARGETS}\' (IS DEFINED)")
    else()
        message(STATUS "Debug VLL: _VCPKG_FOUND_TARGETS in vll scope (from caller): (IS NOT DEFINED)")
    endif()

    if(NOT DEFINED _VCPKG_FOUND_TARGETS)
        message(WARNING "vcpkg_link_libraries: _VCPKG_FOUND_TARGETS is not defined in the current scope. Ensure vcpkg_find_packages() was called beforehand in this scope.")
        return() 
    endif()

    set(targets_to_link "") # Local variable for this function call
    if(VLL_PACKAGES)
        # Link only specified packages
        foreach(requested_pkg IN LISTS VLL_PACKAGES)
            # _VCPKG_FOUND_PACKAGES and _VCPKG_FOUND_TARGETS are read from the current scope 
            # (expected to be set by vcpkg_find_packages in this scope).
            list(FIND _VCPKG_FOUND_PACKAGES "${requested_pkg}" pkg_idx)
            if(pkg_idx GREATER -1)
                list(GET _VCPKG_FOUND_TARGETS ${pkg_idx} found_target)
                if(found_target)
                    list(APPEND targets_to_link ${found_target})
                else()
                    message(WARNING "vcpkg_link_libraries: Package \'${requested_pkg}\' was found by vcpkg_find_packages but its CMake target is unknown. Skipping linking.")
                endif()
            else()
                message(WARNING "vcpkg_link_libraries: Requested package \'${requested_pkg}\' was not found by vcpkg_find_packages (or not in its list). Skipping linking.")
            endif()
        endforeach()
    else()
        # Link all found packages (from current scope _VCPKG_FOUND_TARGETS)
        set(targets_to_link ${_VCPKG_FOUND_TARGETS})
    endif()

    if(targets_to_link)
        message(STATUS "Linking vcpkg libraries to target ${VLL_TARGET} (${VLL_LINK_TYPE}): ${targets_to_link}")
        target_link_libraries(${VLL_TARGET} ${VLL_LINK_TYPE} ${targets_to_link})
    else()
        message(VERBOSE "No vcpkg libraries to link for target ${VLL_TARGET} (either no dependencies or no specific packages requested/found).")
    endif()

endfunction()

message(STATUS "VcpkgHelpers.cmake loaded (v2)") 