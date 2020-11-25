cmake_minimum_required(VERSION 3.17)
include_guard(GLOBAL)

# option to print out messages as "STATUS" from this module
OPTION(${CMAKE_PROJECT_NAME}_CMAKEBASEBUILDSYSTEM_DEBUG OFF)
# set a global property with this file path, to use it later on as a reference for CMakeBaseBuildSystem folder
set_property(GLOBAL PROPERTY CMAKEBASEBUILDSYSTEM_PATH "${CMAKE_CURRENT_LIST_DIR}")
get_property(_tmpVal GLOBAL PROPERTY CMAKEBASEBUILDSYSTEM_PATH)

#------------------------------------------------------------------------------------------------------------------------------------		
function(printCMakeUtilsDebug msg)
	set(forced False)
	if(ARGC EQUAL 2)
		set(forced ${ARGV1})
	endif()


	if(${forced} OR ${CMAKE_PROJECT_NAME}_CMAKEBASEBUILDSYSTEM_DEBUG)
		MESSAGE(STATUS "${msg}")
	endif()
endfunction()


# print as a debug the path to CMakeBaseBuildSystem
printCMakeUtilsDebug("[utils::CMAKEBASEBUILDSYSTEM_PATH] ${_tmpVal}")




#------------------------------------------------------------------------------------------------------------------------------------		
function(addToGlobalPropertyUnique propertyName newVal)
	get_property(LIST_VALUES GLOBAL PROPERTY ${propertyName})
	if(NOT ${newVal} IN_LIST LIST_VALUES)
		set_property(GLOBAL APPEND PROPERTY ${propertyName} ${newVal})
	endif()
endfunction()

#------------------------------------------------------------------------------------------------------------------------------------		
function(addToTargetPropertyUnique targetName propertyName newVal)
	get_target_property(LIST_VALUES ${targetName} ${propertyName})
	if(NOT ${newVal} IN_LIST LIST_VALUES)
		set_property(TARGET ${targetName} APPEND PROPERTY ${propertyName} ${newVal})
	endif()
endfunction()

#------------------------------------------------------------------------------------------------------------------------------------		
function(addToCurDirPropertyUnique propertyName newVal)
	get_directory_property(LIST_VALUES ${propertyName})
	if(NOT ${newVal} IN_LIST LIST_VALUES)
		set_property(DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR} APPEND PROPERTY ${propertyName} ${newVal})
	endif()
endfunction()
