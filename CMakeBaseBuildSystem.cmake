cmake_minimum_required(VERSION 3.17)
include_guard(GLOBAL)

include(utils)
include(CMakeDependentOption)
include(winDllRecursiveAnalysis)

# EXPORTED_TARGETS_LIST will contains all the list of export-targets
set_property(GLOBAL PROPERTY EXPORTED_TARGETS_LIST "")

# FIND_PACKAGES_ARGS: DIRECTORY property that contains for directories where package_add_to_dependencies (or find_package_wrapper) has been used the list of findpackages
# PKGCONFIG_FIND_PACKAGES_ARGS: DIRECTORY property that contains for directories where package_add_to_pkgconfig_dependencies (or pkg_check_modules_wrapper) has been used the list of pkg_config findpackages

# PROPERTY EXPORTED_TARGETS_${exportName}_CROSSDEPENDENCIES: contains for the exportName the required packages

# SOURCES_TO_INSTALL: property per target filled in by target_sources_wrapper with public and interface and used in installTarget to install files
# note, for INTERFACE LIBRARY SOURCES_TO_INSTALL property is not suitable, since TARGET does not accept properties, I will add GLOBAL PROPERTY ${targetName}_SOURCES_TO_INSTALL

# SOURCES_TO_INSTALL_BASEDIR: property per target filled in by target_sources_wrapper with the base folder for files to install, will be used to retrieve destination folder if not plain tree structure
# note, for INTERFACE LIBRARY SOURCES_TO_INSTALL property is not suitable, since TARGET does not accept properties, I will add GLOBAL PROPERTY  ${targetName}_SOURCES_TO_INSTALL_BASEDIR



#---------------------------------------------------------------------------------------------
macro(find_package_wrapper)
	# unfortunately this has to be a macro, because some find_package out variable needs to be known to the caller
	# in example, finding Qt will set some variable that will allow AUTOMOC to be enabled, it this is a function AUTOMOC refuse to turn on

	printCMakeUtilsDebug("[CMakeBaseBuildSystem::find_package_wrapper] ${ARGN}")
	
	find_package(${ARGN})
	package_add_to_dependencies(${ARGN})
endmacro()

#---------------------------------------------------------------------------------------------
function(target_sources_wrapper TARGET_NAME)
	set(keywords PRIVATE PUBLIC INTERFACE PRIVATE_INSTALL)
	set(options  NO_AUTO_SOURCE_GROUP)
	
	cmake_parse_arguments(ARG "${options}" "" "${keywords}" ${ARGN})
	printCMakeUtilsDebug("[CMakeBaseBuildSystem::target_sources_wrapper] input ${ARGN}")

	# PRIVATE
	if (ARG_PRIVATE)
		printCMakeUtilsDebug("[CMakeBaseBuildSystem::target_sources_wrapper] PRIVATE ${ARG_PRIVATE}")
		# PRIVATE
		target_sources(${TARGET_NAME} PRIVATE "${ARG_PRIVATE}")
	endif()
	
	file(RELATIVE_PATH DESTINATION_FOLDER ${CMAKE_SOURCE_DIR} ${CMAKE_CURRENT_LIST_DIR})
	printCMakeUtilsDebug("[CMakeBaseBuildSystem::target_sources_wrapper] relative install path is ${DESTINATION_FOLDER}")

	# PRIVATE
	if (ARG_PRIVATE_INSTALL)
		printCMakeUtilsDebug("[CMakeBaseBuildSystem::target_sources_wrapper] PRIVATE_INSTALL ${ARG_PRIVATE_INSTALL}")
		# PRIVATE
		target_sources(${TARGET_NAME} PRIVATE "${ARG_PRIVATE_INSTALL}")

		set_property(TARGET ${TARGET_NAME} PROPERTY SOURCES_TO_INSTALL_BASEDIR ${CMAKE_CURRENT_LIST_DIR})
		
		foreach(_file ${ARG_PRIVATE_INSTALL})
			target_sources(${TARGET_NAME} PRIVATE
				$<BUILD_INTERFACE:${CMAKE_CURRENT_LIST_DIR}/${_file}>
				$<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}/${DESTINATION_FOLDER}/${_file}>
			)		
			set_property(TARGET ${TARGET_NAME} APPEND PROPERTY SOURCES_TO_INSTALL ${_file})
		endforeach()
	endif()
	
	if (ARG_PUBLIC)
	
		set_property(TARGET ${TARGET_NAME} PROPERTY SOURCES_TO_INSTALL_BASEDIR ${CMAKE_CURRENT_LIST_DIR})
		
		foreach(_file ${ARG_PUBLIC})
			target_sources(${TARGET_NAME} PUBLIC
				$<BUILD_INTERFACE:${CMAKE_CURRENT_LIST_DIR}/${_file}>
				$<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}/${DESTINATION_FOLDER}/${_file}>
			)		
			set_property(TARGET ${TARGET_NAME} APPEND PROPERTY SOURCES_TO_INSTALL ${_file})
		endforeach()
	endif()

	if (ARG_INTERFACE)
		set_property(GLOBAL PROPERTY ${TARGET_NAME}_SOURCES_TO_INSTALL_BASEDIR ${CMAKE_CURRENT_LIST_DIR})
		foreach(_file ${ARG_INTERFACE})
			target_sources(${TARGET_NAME} INTERFACE
				$<BUILD_INTERFACE:${CMAKE_CURRENT_LIST_DIR}/${_file}>
				$<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}/${DESTINATION_FOLDER}/${_file}>
			)
			# add GLOBAL property ${TARGET_NAME}_SOURCES_TO_INSTALL, target property not allowed on interfaces
			set_property(GLOBAL APPEND PROPERTY ${TARGET_NAME}_SOURCES_TO_INSTALL ${_file})
			
		endforeach()
	endif()
	
	if (NOT ARG_NO_AUTO_SOURCE_GROUP)
		source_group(Sources REGULAR_EXPRESSION "\\.c(pp)?$")
		source_group("Dependency Headers" REGULAR_EXPRESSION "\\.h(pp)?$")

		set(_target_headers ${ARG_PRIVATE} ${ARG_PRIVATE_INSTALL} ${ARG_PUBLIC} ${ARG_INTERFACE})
		list(FILTER _target_headers INCLUDE REGEX "\\.h(pp)?$")
		source_group(Headers FILES ${_target_headers})

		printCMakeUtilsDebug("[CMakeBaseBuildSystem::target_sources_wrapper] headers source group for target ${TARGET_NAME}: ${_target_headers}")
	endif()
	
endfunction()

#---------------------------------------------------------------------------------------------
function(package_add_to_dependencies)
	list(JOIN ARGN " " FIND_ARG)
	printCMakeUtilsDebug("[CMakeBaseBuildSystem::package_add_to_dependencies] add ${FIND_ARG} to directory properties")
	addToCurDirPropertyUnique(FIND_PACKAGES_ARGS ${FIND_ARG})
endfunction()

function(package_add_to_pkgconfig_dependencies)
	list(JOIN ARGN " " PKGCONFIG_FIND_ARG)
	printCMakeUtilsDebug("[CMakeBaseBuildSystem::package_add_to_pkgconfig_dependencies] add ${PKGCONFIG_FIND_ARG} to directory properties")
	addToCurDirPropertyUnique(PKGCONFIG_FIND_PACKAGES_ARGS ${PKGCONFIG_FIND_ARG})
endfunction()

#---------------------------------------------------------------------------------------------
# a target can be esported to global export, to self target or to a specific export set
# function(installAllTargets GLOBAL|SELF|exportName), default is GLOBAL
function(installAllTargets)
	printCMakeUtilsDebug("[CMakeBaseBuildSystem::installAllTargets] input arguments ${ARGN}")
	
	get_directory_property(targets BUILDSYSTEM_TARGETS)
	printCMakeUtilsDebug("[CMakeBaseBuildSystem::installAllTargets] all targets list is ${targets}")

	# check single argument passed or 0 (default GLOBAL)
	if(${ARGC} EQUAL 0)
		# default is global
		foreach(target ${targets})
			installTarget(${target} ${CMAKE_PROJECT_NAME})
		endforeach()
		
	elseif(${ARGC} EQUAL 1)
		set(options GLOBAL SELF)
		cmake_parse_arguments(INPUT "${options}" ""	"" ${ARGN} )
		if(INPUT_GLOBAL)
			foreach(target ${targets})
				installTarget(${target} ${CMAKE_PROJECT_NAME})
			endforeach()		
		elseif(INPUT_SELF)
			foreach(target ${targets})
				installTarget(${target} ${target})
			endforeach()
		else()
			set(exportName ${INPUT_UNPARSED_ARGUMENTS})
			foreach(target ${targets})
				installTarget(${target} ${exportName})
			endforeach()		
		endif()
	else()
		message(FATAL_ERROR "expected single argument")
	endif()
	printCMakeUtilsDebug("[CMakeBaseBuildSystem::installAllTargets] done!")
endfunction()

# optional 
function(installTarget targetName exportName)
	include(GNUInstallDirs)
	
	if(${ARGC} EQUAL 2)
		# install include files followin folder structure
		file(RELATIVE_PATH DESTINATION_FOLDER ${CMAKE_SOURCE_DIR} ${CMAKE_CURRENT_SOURCE_DIR})
		printCMakeUtilsDebug("[CMakeBaseBuildSystem::installTarget] target relative install path default to ${DESTINATION_FOLDER}")
	elseif(${ARGC} EQUAL 3)
		set(DESTINATION_FOLDER ${ARGV2})
		printCMakeUtilsDebug("[CMakeBaseBuildSystem::installTarget] target relative install path explicit set to ${DESTINATION_FOLDER}")
	else()
		message(FATAL_ERROR "installTarget expect maximum one additional argument")
	endif()

	# check if I already know this exportName or add it to the list
	addToGlobalPropertyUnique(EXPORTED_TARGETS_LIST ${exportName})
	printCMakeUtilsDebug("[CMakeBaseBuildSystem::installTarget] targetName ${targetName} exportName ${exportName}")

	# get the target type, check if executable, shared library or STATIC_LIBRARY
	get_target_property(target_type ${targetName} TYPE)
	
	# install include files if it is a library
	if( (${target_type} STREQUAL "SHARED_LIBRARY") OR
		(${target_type} STREQUAL "STATIC_LIBRARY") OR
		(${target_type} STREQUAL "OBJECT_LIBRARY"))	
	
		get_target_property(HDRS_PUBLIC ${targetName} SOURCES_TO_INSTALL)
		get_target_property(HDRS_PUBLIC_BASEDIR ${targetName} SOURCES_TO_INSTALL_BASEDIR)
		printCMakeUtilsDebug("[CMakeBaseBuildSystem::installTarget] targetName ${targetName} headers marked as public ${HDRS_PUBLIC}, from folder ${HDRS_PUBLIC_BASEDIR}")
	
		foreach(HDR ${HDRS_PUBLIC})
			get_filename_component(SUBF ${HDR} DIRECTORY )
			printCMakeUtilsDebug("[CMakeBaseBuildSystem::installTarget] install ${HDRS_PUBLIC_BASEDIR}/${HDR} in ${CMAKE_INSTALL_INCLUDEDIR}/${DESTINATION_FOLDER}/${SUBF}")
			install(FILES ${HDRS_PUBLIC_BASEDIR}/${HDR} DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/${DESTINATION_FOLDER}/${SUBF})
		endforeach()
	elseif(${target_type} STREQUAL "INTERFACE_LIBRARY")
		get_property(HDRS_PUBLIC GLOBAL PROPERTY ${targetName}_SOURCES_TO_INSTALL)
		get_property(HDRS_PUBLIC_BASEDIR GLOBAL PROPERTY ${targetName}_SOURCES_TO_INSTALL_BASEDIR)

		foreach(HDR ${HDRS_PUBLIC})
			get_filename_component(SUBF ${HDR} DIRECTORY )
			printCMakeUtilsDebug("[CMakeBaseBuildSystem::installTarget] install ${HDRS_PUBLIC_BASEDIR}/${HDR} in ${CMAKE_INSTALL_INCLUDEDIR}/${DESTINATION_FOLDER}/${SUBF}")
			install(FILES ${HDRS_PUBLIC_BASEDIR}/${HDR} DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/${DESTINATION_FOLDER}/${SUBF})
		endforeach()
	else() 
	endif()
	
	
	# install effectively the target
	install(TARGETS ${targetName}
		EXPORT ${exportName}-targets
		RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
		LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
		ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
		INCLUDES DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
	)
  
	# and install the pdb file for debugging
	if(MSVC)
		if(${target_type} STREQUAL "SHARED_LIBRARY")
			install(FILES $<TARGET_PDB_FILE:${targetName}> DESTINATION bin OPTIONAL)	
		endif()
	endif()
	
	# cumulate the find_packages listed for  this directory in the target requirements
	get_directory_property(LIST_VALUES FIND_PACKAGES_ARGS)
	if(LIST_VALUES)
		printCMakeUtilsDebug("[CMakeBaseBuildSystem::installTarget] add cross dependencies ${LIST_VALUES} to EXPORTED_TARGETS_${exportName}_CROSSDEPENDENCIES variable")
		foreach(L ${LIST_VALUES})
			addToGlobalPropertyUnique(EXPORTED_TARGETS_${exportName}_CROSSDEPENDENCIES ${L})
		endforeach()
	endif()
	
	# cumulate the pkg_check_modules listed for  this directory in the target requirements
	get_directory_property(PKGCONFIG_LIST_VALUES PKGCONFIG_FIND_PACKAGES_ARGS)
	if(PKGCONFIG_LIST_VALUES)
		printCMakeUtilsDebug("[CMakeBaseBuildSystem::installTarget] add cross dependencies ${PKGCONFIG_LIST_VALUES} to PKGCONFIG_EXPORTED_TARGETS_${exportName}_CROSSDEPENDENCIES variable")
		foreach(L ${PKGCONFIG_LIST_VALUES})
			addToGlobalPropertyUnique(PKGCONFIG_EXPORTED_TARGETS_${exportName}_CROSSDEPENDENCIES ${L})
		endforeach()
	endif()
  
  # cumulate the add_dependencies
  get_target_property(ADD_DEP ${targetName} MANUALLY_ADDED_DEPENDENCIES)
  if(ADD_DEP)
    printCMakeUtilsDebug("[CMakeBaseBuildSystem::installTarget] ${targetName} is dependend on ${ADD_DEP} (manually added)")
    foreach(D ${ADD_DEP})
      addToGlobalPropertyUnique(EXPORTED_TARGETS_${exportName}_MANUALDEPENDENCIES ${D})
    endforeach()
  endif()
endfunction()

#---------------------------------------------------------------------------------------------
# add this function at the end of the main cmake, additional parameter set default list of components used with a findPackage(...), use ALL, NONE or a custom list
function(createGlobalConfigFile ROOT_NAME)
	include(GNUInstallDirs)
	include(CMakePackageConfigHelpers)
	
	# prepare list of components that will be added if no components specified in find_package

	if(${ARGC} EQUAL 1)
		get_property(LIST_VALUES GLOBAL PROPERTY EXPORTED_TARGETS_LIST)
		set(DEFAULT_COMPONENTS_LIST ${LIST_VALUES})
			printCMakeUtilsDebug("[CMakeBaseBuildSystem::createGlobalConfigFile] DEFAULT_COMPONENTS_LIST (Default:ALL) ${DEFAULT_COMPONENTS_LIST}")
	else()
		set(options ALL NONE)
		cmake_parse_arguments(INPUT "${options}" ""	"" ${ARGN} )
		if(INPUT_ALL)
			get_property(LIST_VALUES GLOBAL PROPERTY EXPORTED_TARGETS_LIST)
			set(DEFAULT_COMPONENTS_LIST ${LIST_VALUES})
			printCMakeUtilsDebug("[CMakeBaseBuildSystem::createGlobalConfigFile] DEFAULT_COMPONENTS_LIST (ALL) ${DEFAULT_COMPONENTS_LIST}")
		elseif(INPUT_NONE)
			set(DEFAULT_COMPONENTS_LIST "")
			printCMakeUtilsDebug("[CMakeBaseBuildSystem::createGlobalConfigFile] DEFAULT_COMPONENTS_LIST (NONE) ${DEFAULT_COMPONENTS_LIST}")
		else()
			set(DEFAULT_COMPONENTS_LIST ${INPUT_UNPARSED_ARGUMENTS})
			printCMakeUtilsDebug("[CMakeBaseBuildSystem::createGlobalConfigFile] DEFAULT_COMPONENTS_LIST (custom) ${DEFAULT_COMPONENTS_LIST}")
		endif()
	endif()
	

	set(INSTALL_CONFIGDIR ${CMAKE_INSTALL_LIBDIR}/cmake/${ROOT_NAME})

	#Export the targets to a script per target 
	installExportedTargetFiles(${ROOT_NAME} ${INSTALL_CONFIGDIR})

	# create a global config file that allow to manage components
	set(CODE_FOR_DEPENDENCIES "")
	set(POST_CODE_FOR_DEPENDENCIES "")


	get_property(EXPORTED_TARGETS_LIST GLOBAL PROPERTY EXPORTED_TARGETS_LIST)
	foreach(exportName ${EXPORTED_TARGETS_LIST})	

		# open if 
		set(CODE_FOR_DEPENDENCIES "${CODE_FOR_DEPENDENCIES} if(\"${exportName}\" IN_LIST ${ROOT_NAME}_FIND_COMPONENTS)\n")
    set(POST_CODE_FOR_DEPENDENCIES "${POST_CODE_FOR_DEPENDENCIES} if(TARGET ${ROOT_NAME}::${exportName})\n")
		
		# find package dependencies
		get_property(EXPORTED_TARGETS_${exportName}_CROSSDEPENDENCIES GLOBAL PROPERTY EXPORTED_TARGETS_${exportName}_CROSSDEPENDENCIES)
		printCMakeUtilsDebug("[CMakeBaseBuildSystem::createGlobalConfigFile] EXPORTED_TARGETS_${exportName}_CROSSDEPENDENCIES ${EXPORTED_TARGETS_${exportName}_CROSSDEPENDENCIES}")

		foreach(FIND_ARGS ${EXPORTED_TARGETS_${exportName}_CROSSDEPENDENCIES})
			set(CODE_FOR_DEPENDENCIES "${CODE_FOR_DEPENDENCIES}   MESSAGE(DEBUG \"looking for dependencies ${FIND_ARGS}\")\n")
			set(CODE_FOR_DEPENDENCIES "${CODE_FOR_DEPENDENCIES}   find_package(${FIND_ARGS})\n")
			# seems that using macro find_dependency may broke something...
		endforeach()

		# pkg_check_modules dependencies
		get_property(PKGCONFIG_EXPORTED_TARGETS_${exportName}_CROSSDEPENDENCIES GLOBAL PROPERTY PKGCONFIG_EXPORTED_TARGETS_${exportName}_CROSSDEPENDENCIES)
		printCMakeUtilsDebug("[CMakeBaseBuildSystem::createGlobalConfigFile] PKGCONFIG_EXPORTED_TARGETS_${exportName}_CROSSDEPENDENCIES ${PKGCONFIG_EXPORTED_TARGETS_${exportName}_CROSSDEPENDENCIES}")

		list(LENGTH PKGCONFIG_EXPORTED_TARGETS_${exportName}_CROSSDEPENDENCIES PKGCONFIG_DEP_LIST_LEN)

		if(PKGCONFIG_DEP_LIST_LEN GREATER 0)
			set(CODE_FOR_DEPENDENCIES "${CODE_FOR_DEPENDENCIES}\n   find_package(PkgConfig REQUIRED)\n")
		endif()

		foreach(PKGCONFIG_ARGS ${PKGCONFIG_EXPORTED_TARGETS_${exportName}_CROSSDEPENDENCIES})
			set(CODE_FOR_DEPENDENCIES "${CODE_FOR_DEPENDENCIES}   MESSAGE(DEBUG \"looking for dependencies ${PKGCONFIG_ARGS}\")\n")
			set(CODE_FOR_DEPENDENCIES "${CODE_FOR_DEPENDENCIES}   pkg_check_modules(${PKGCONFIG_ARGS})\n")
			# seems that using macro find_dependency may broke something...
		endforeach()
    
    # manual dependencies, added at the end
		get_property(EXPORTED_TARGETS_${exportName}_MANUALDEPENDENCIES GLOBAL PROPERTY EXPORTED_TARGETS_${exportName}_MANUALDEPENDENCIES)
		printCMakeUtilsDebug("[CMakeBaseBuildSystem::createGlobalConfigFile] EXPORTED_TARGETS_${exportName}_MANUALDEPENDENCIES ${EXPORTED_TARGETS_${exportName}_MANUALDEPENDENCIES}")
			

		# check if there are manual cross dep and add them
		list(LENGTH EXPORTED_TARGETS_${exportName}_MANUALDEPENDENCIES MANUAL_DEP_LIST_LEN)

		if(MANUAL_DEP_LIST_LEN GREATER 0)
			foreach(FIND_ARGS ${EXPORTED_TARGETS_${exportName}_MANUALDEPENDENCIES})
				set(POST_CODE_FOR_DEPENDENCIES "${POST_CODE_FOR_DEPENDENCIES}     MESSAGE(DEBUG \"add manual dependencies ${FIND_ARGS}\")\n")
				set(POST_CODE_FOR_DEPENDENCIES "${POST_CODE_FOR_DEPENDENCIES}     set_property(TARGET ${ROOT_NAME}::${exportName} PROPERTY IMPORTED_LINK_DEPENDENT_LIBRARIES_DEBUG ${FIND_ARGS} APPEND)\n")
				set(POST_CODE_FOR_DEPENDENCIES "${POST_CODE_FOR_DEPENDENCIES}     set_property(TARGET ${ROOT_NAME}::${exportName} PROPERTY IMPORTED_LINK_DEPENDENT_LIBRARIES_RELEASE ${FIND_ARGS} APPEND)\n")        
			endforeach()
		else()
			set(POST_CODE_FOR_DEPENDENCIES "${POST_CODE_FOR_DEPENDENCIES}   # no manual dep specified\n\n")    
		endif()
    
    # done, close target
		set(CODE_FOR_DEPENDENCIES "${CODE_FOR_DEPENDENCIES}\n endif()\n\n")
    set(POST_CODE_FOR_DEPENDENCIES "${POST_CODE_FOR_DEPENDENCIES} endif()\n")
    

	endforeach()
		
	get_property(CMAKEBASEBUILDSYSTEM_PATH GLOBAL PROPERTY CMAKEBASEBUILDSYSTEM_PATH)
	configure_package_config_file(${CMAKEBASEBUILDSYSTEM_PATH}/config/templateConfig.cmake.in
		${CMAKE_CURRENT_BINARY_DIR}/${ROOT_NAME}Config.cmake
		INSTALL_DESTINATION ${INSTALL_CONFIGDIR}
	)

	#Create a ConfigVersion.cmake file
	write_basic_package_version_file(
		${CMAKE_CURRENT_BINARY_DIR}/${ROOT_NAME}ConfigVersion.cmake
		VERSION ${PROJECT_VERSION}
		COMPATIBILITY AnyNewerVersion
	)

	#Install the config and configversion 
	install(FILES
		${CMAKE_CURRENT_BINARY_DIR}/${ROOT_NAME}Config.cmake
		${CMAKE_CURRENT_BINARY_DIR}/${ROOT_NAME}ConfigVersion.cmake
		DESTINATION ${INSTALL_CONFIGDIR}
	)

endfunction()

#---------------------------------------------------------------------------------------------
function(installSpecialCMake DIR_PATH)
	include(GNUInstallDirs)

	
	set(INSTALL_CONFIGDIR ${CMAKE_INSTALL_LIBDIR}/cmake/${ROOT_NAME})
	
	install(DIRECTORY ${DIR_PATH}
		DESTINATION ${INSTALL_CONFIGDIR}
		#PATTERN "${DIR_PATH}" EXCLUDE 
	)
endfunction()

#---------------------------------------------------------------------------------------------
function(prepareVersionFile ROOT_NAME)
  include(GNUInstallDirs)
	get_property(CMAKEBASEBUILDSYSTEM_PATH GLOBAL PROPERTY CMAKEBASEBUILDSYSTEM_PATH)
	
	set(COMPANY_NAME "CMakeBaseBuildSystem" PARENT_SCOPE)
	set(COMPANY_DOMAIN "CMakeBaseBuildSystem" PARENT_SCOPE)
	set(APPLICATION_NAME ${ROOT_NAME} PARENT_SCOPE)
  
  if(NOT VERSION_BUILD)
    set(VERSION_BUILD "0" CACHE STRING "version build postfix")
  endif()

	configure_file (
		"${CMAKEBASEBUILDSYSTEM_PATH}/config/Version.h.in"
		"${CMAKE_CURRENT_BINARY_DIR}/${ROOT_NAME}/${ROOT_NAME}Version.h"
	)

	configure_file (
		"${CMAKEBASEBUILDSYSTEM_PATH}/config/Version.cpp.in"
		"${CMAKE_CURRENT_BINARY_DIR}/${ROOT_NAME}/${ROOT_NAME}Version.cpp"
	)

	configure_file (
		"${CMAKEBASEBUILDSYSTEM_PATH}/config/Version.rc.in"
		"${CMAKE_CURRENT_BINARY_DIR}/${ROOT_NAME}/${ROOT_NAME}Version.rc"
	)
	
	# define an interface target that everybody will "link" to have the current path in include
	add_library(${ROOT_NAME}Version STATIC )
	
	target_sources(${ROOT_NAME}Version 
		PUBLIC 
			$<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/${ROOT_NAME}/${ROOT_NAME}Version.h>
			$<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}/${ROOT_NAME}/${ROOT_NAME}Version.h>
		PRIVATE
			${CMAKE_CURRENT_BINARY_DIR}/${ROOT_NAME}/${ROOT_NAME}Version.cpp
			
			$<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/${ROOT_NAME}/${ROOT_NAME}Version.rc>
			$<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}/${ROOT_NAME}/${ROOT_NAME}Version.rc>			
	)
	
	# add target property SOURCES_TO_INSTALL, will be used by install target
	set_property(TARGET ${ROOT_NAME}Version  APPEND PROPERTY SOURCES_TO_INSTALL ${ROOT_NAME}Version.h ${ROOT_NAME}Version.rc)
	set_property(TARGET ${ROOT_NAME}Version  APPEND PROPERTY SOURCES_TO_INSTALL_BASEDIR ${CMAKE_CURRENT_BINARY_DIR}/${ROOT_NAME})
	
	
	#Add an alias so that library can be used inside the build tree, e.g. when testing
	add_library(${ROOT_NAME}::${ROOT_NAME}Version ALIAS ${ROOT_NAME}Version)
	
	#And add the current dir as target include directory, every target will link this library
	# and so they will inherit the main include path
	target_include_directories(${ROOT_NAME}Version 
		INTERFACE
			$<INSTALL_INTERFACE:>
			$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
		INTERFACE
			$<INSTALL_INTERFACE:>
			$<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}>
	)


	installTarget(${ROOT_NAME}Version ${ROOT_NAME} ${ROOT_NAME})
		
endfunction()

function(prepareVersionFileInterface ROOT_NAME)
  include(GNUInstallDirs)
	get_property(CMAKEBASEBUILDSYSTEM_PATH GLOBAL PROPERTY CMAKEBASEBUILDSYSTEM_PATH)

	configure_file (
		"${CMAKEBASEBUILDSYSTEM_PATH}/config/VersionInterface.h.in"
		"${CMAKE_CURRENT_BINARY_DIR}/${ROOT_NAME}/${ROOT_NAME}Version.h"
	)
	
	# define an interface target that everybody will "link" to have the current path in include
	add_library(${ROOT_NAME}Version INTERFACE )
	
	target_sources(${ROOT_NAME}Version 
		INTERFACE
			$<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/${ROOT_NAME}/${ROOT_NAME}Version.h>
			$<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}/${ROOT_NAME}/${ROOT_NAME}Version.h>
	)
  
  # TODO: try to convince VisualStudio to show files... so far not working :-(
  # add_custom_target(${ROOT_NAME}Version SOURCES <<...>>)
  
	
	# add target property SOURCES_TO_INSTALL, will be used by install target
  set_property(GLOBAL PROPERTY ${ROOT_NAME}Version_SOURCES_TO_INSTALL_BASEDIR ${CMAKE_CURRENT_BINARY_DIR}/${ROOT_NAME})
  set_property(GLOBAL APPEND PROPERTY ${ROOT_NAME}Version_SOURCES_TO_INSTALL ${ROOT_NAME}Version.h)
	
	#Add an alias so that library can be used inside the build tree, e.g. when testing
	add_library(${ROOT_NAME}::${ROOT_NAME}Version ALIAS ${ROOT_NAME}Version)
	
	#And add the current dir as target include directory, every target will link this library
	# and so they will inherit the main include path
	target_include_directories(${ROOT_NAME}Version 
		INTERFACE
			$<INSTALL_INTERFACE:>
			$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
		INTERFACE
			$<INSTALL_INTERFACE:>
			$<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}>
	)


	installTarget(${ROOT_NAME}Version ${ROOT_NAME} ${ROOT_NAME})
		
endfunction()

#---------------------------------------------------------------------------------------------
function(addSampleFolder)
	# add samples folder
	if(EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/samples)
		CMAKE_DEPENDENT_OPTION(BUILD_${PROJECT_NAME}_SAMPLES "Build Samples of ${target_name} project" ON ${CMAKE_PROJECT_NAME}_BUILD_SAMPLES OFF)		
		if(BUILD_${PROJECT_NAME}_SAMPLES)
			add_subdirectory(samples)
		endif()
	endif()
endfunction()

#---------------------------------------------------------------------------------------------
function(addTestsFolder)
	# add test folder
	if(EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/tests)
		CMAKE_DEPENDENT_OPTION(BUILD_${PROJECT_NAME}_TESTS "Build Tests of ${target_name} project" ON ${CMAKE_PROJECT_NAME}_BUILD_TESTS OFF)		
		if(BUILD_${PROJECT_NAME}_TESTS)
			add_subdirectory(tests)
		endif()
	endif()
endfunction()

#---------------------------------------------------------------------------------------------

# if your cmake is standard, add this at the end!
# Optionally, pass the NO_AUTO_VS_FOLDERS argument if you don't want to wrap each target within
# a folder with the name of the target in Visual Studio. This leaves you the freedom to organize
# folders in Visual Studio the way you like.
function(commonEndProjectCMake top_project)

	set(options  NO_AUTO_VS_FOLDERS)
	cmake_parse_arguments(ARG "${options}" "" "" ${ARGN})
	
	addSampleFolder()
	addTestsFolder()

	if(PROJECT_VERSION)
		set(toSetVersion ${PROJECT_VERSION})
		set(toSetVersionMajor ${PROJECT_VERSION_MAJOR})
		set(toSetVersionMinor ${PROJECT_VERSION_MINOR})
	elseif(CMAKE_PROJECT_VERSION)
		set(toSetVersion ${CMAKE_PROJECT_VERSION})
		set(toSetVersionMajor ${CMAKE_PROJECT_VERSION_MAJOR})
		set(toSetVersionMinor ${CMAKE_PROJECT_VERSION_MINOR})
	else()
		message(FATAL_ERROR "Please set project version")
	endif()

	get_directory_property(targets BUILDSYSTEM_TARGETS)
	printCMakeUtilsDebug("[CMakeBaseBuildSystem::commonEndProjectCMake] all targets list is ${targets}")
	printCMakeUtilsDebug("[CMakeBaseBuildSystem::commonEndProjectCMake] setting version to ${toSetVersion}")

	foreach(target_name ${targets})

		if(${ARGC} EQUAL 2)
			set(SOURCE_FOLDER ${ARGV1})
		else()
			set(SOURCE_FOLDER ${target_name})
		endif()

		#------------------------------------------------------------------------------------------
		#Set self target include directories to project root
		# get the target type, check if executable, shared library or STATIC_LIBRARY
		get_target_property(target_type ${target_name} TYPE)
		if(TARGET ${top_project}Version)
			if (NOT ${target_type} STREQUAL "INTERFACE_LIBRARY")
				target_link_libraries(${target_name} PUBLIC ${top_project}Version)
			else()
				target_link_libraries(${target_name} INTERFACE ${top_project}Version)
			endif()
		endif()
    
    if (NOT ${target_type} STREQUAL "INTERFACE_LIBRARY")
    	set_target_properties(${target_name} PROPERTIES
        VERSION ${toSetVersion}
        SOVERSION "${toSetVersionMajor}.${toSetVersionMinor}.0"
      )
    endif()


		# specific windows compiler properties (folder)
		if (NOT ARG_NO_AUTO_VS_FOLDERS AND WIN32 AND (NOT ${target_type} STREQUAL "INTERFACE_LIBRARY"))
			set_target_properties(${target_name} PROPERTIES FOLDER ${SOURCE_FOLDER})
		endif()
		
		#Add here unix specific commands for targets
		#if (UNIX)
		#endif()


	endforeach()

	#------------------------------------------------------------------------------------------
	# append dependencies 
	winDllRecursiveAnalysis()
endfunction()

#---------------------------------------------------------------------------------------------
# this is used internally
function(installExportedTargetFiles NAMESPACE INSTALL_CONFIGDIR)
	get_property(LIST_VALUES GLOBAL PROPERTY EXPORTED_TARGETS_LIST)
		
	foreach(name ${LIST_VALUES})
		install(EXPORT ${name}-targets
		FILE
			${name}Targets.cmake
		NAMESPACE
			${NAMESPACE}::
		DESTINATION
			${INSTALL_CONFIGDIR}/targets
		)
	endforeach()
endfunction()
