cmake_minimum_required(VERSION 3.17)
include_guard(GLOBAL)

include(utils)

if(WIN32)
	set_property(GLOBAL PROPERTY DLL_DEBUG_LIST "")
	set_property(GLOBAL PROPERTY DLL_RELEASE_LIST "")

#------------------------------------------------------------------------------------------------------------------------------------		
  # winDllRecursiveAnalysis()
  # automatically and recursively analyze target dependencies and populate DLL_DEBUG_LIST, DLL_RELEASE_LIST global properties
	function(winDllRecursiveAnalysis)
		get_directory_property(targets BUILDSYSTEM_TARGETS)
		printCMakeUtilsDebug("[winDllRecursiveAnalysis::winDllRecursiveAnalysis] targets detected are ${targets}")
		
		foreach(target ${targets})
			printCMakeUtilsDebug("[winDllRecursiveAnalysis::winDllRecursiveAnalysis] call analyzeTargetDependencies for target ${target}")
			analyzeTargetDependencies(${target})
		endforeach()
	
		# finish job for all targets, print out its dependency property
		get_property(LIST_VALUES GLOBAL PROPERTY DLL_DEBUG_LIST)
		printCMakeUtilsDebug("[winDllRecursiveAnalysis::winDllRecursiveAnalysis] complete list of dll dependencies (DEBUG): ${LIST_VALUES}")
		get_property(LIST_VALUES GLOBAL PROPERTY DLL_RELEASE_LIST)
		printCMakeUtilsDebug("[winDllRecursiveAnalysis::winDllRecursiveAnalysis] complete list of dll dependencies (RELEASE): ${LIST_VALUES}")
	
	endfunction()
		
#------------------------------------------------------------------------------------------------------------------------------------		
  # addDLLToTarget (base_target dllTarget [FORCED])
  # allow to add a DLL to the PATH and to the dependencies to install
  # if FORCED dll will be installed, otherwise DLL will only be installed if the <<PROJECT_NAME>>_INSTALL_DEPENDENCIES is True
  function(addDLLToTarget base_target dllTarget)
  	printCMakeUtilsDebug("[winDllRecursiveAnalysis::addDLLToTarget] for target ${base_target}")
    
    set(options FORCED)
    cmake_parse_arguments(INSTALL "${options}" ""	"" ${ARGN} )
    
    printCMakeUtilsDebug("[winDllRecursiveAnalysis::addDLLToTarget] for target ${base_target} INSTALL_FORCED ${INSTALL_FORCED}")
           
    # get dllTarget type
    get_target_property(target_type ${dllTarget} TYPE)
    # manage this base_target, it is a dll to be copied?
    get_target_property(target_isImported ${dllTarget} IMPORTED)

    printCMakeUtilsDebug("[winDllRecursiveAnalysis::addDLLToTarget] dll ${dllTarget}, type is ${target_type}, is imported ${target_isImported}")

    # add the dll only to the list of dependencies
    if(target_isImported AND ((${target_type} STREQUAL "MODULE_LIBRARY") OR (${target_type} STREQUAL "SHARED_LIBRARY")))
      # add dependency!
      add_dependencies(${base_target} ${dllTarget})
    
      # DEBUG
      set(DEBRELFOUND False)
      get_target_property(BIN_F_IMP_DEBUG ${dllTarget} IMPORTED_LOCATION_DEBUG) #get dll location
      if(BIN_F_IMP_DEBUG)
        addToGlobalPropertyUnique(DLL_DEBUG_LIST ${BIN_F_IMP_DEBUG})        
        set(DEBRELFOUND True)
      else()
        printCMakeUtilsDebug("[winDllRecursiveAnalysis::addDLLToTarget] dll ${dllTarget} does not have IMPORTED_LOCATION_DEBUG")
      endif()
    
      # RELEASE
      get_target_property(BIN_F_IMP_RELEASE ${dllTarget} IMPORTED_LOCATION_RELEASE) #get dll location
      if(BIN_F_IMP_RELEASE)
        addToGlobalPropertyUnique(DLL_RELEASE_LIST ${BIN_F_IMP_RELEASE})
        set(DEBRELFOUND True)
      else()
        printCMakeUtilsDebug("[winDllRecursiveAnalysis::addDLLToTarget] dll ${dllTarget} does not have IMPORTED_LOCATION_RELEASE")
      endif()
      
      printCMakeUtilsDebug("[winDllRecursiveAnalysis::addDLLToTarget] add ${dllTarget} dll libraries ${BIN_F_IMP_DEBUG} and ${BIN_F_IMP_RELEASE} to global list and as a dependancy  of ${base_target} ")			
      
      if(NOT DEBRELFOUND)
        MESSAGE(WARNING "[winDllRecursiveAnalysis::addDLLToTarget] add ${dllTarget} does not found neither DEBUG or RELEASE version, set IMPORTED_LOCATION_RELEASE and/or IMPORTED_LOCATION_DEBUG variables for ${dllTarget} target")
      endif()

      # if forced
      if(INSTALL_FORCED)
        printCMakeUtilsDebug("[winDllRecursiveAnalysis::addDLLToTarget] install forced")
        install(FILES ${BIN_F_IMP_DEBUG} DESTINATION bin CONFIGURATIONS DEBUG)	
        install(FILES ${BIN_F_IMP_RELEASE} DESTINATION bin CONFIGURATIONS RELEASE)	
      endif()

    else()
      message(FATAL_ERROR "addDLLToTarget: ${base_target} is not an IMPORTED target of SHARED_LIBRARY type (type is ${target_type}")
    endif()
    
    
	endfunction()


#------------------------------------------------------------------------------------------------------------------------------------		
  #analyzeTargetDependencies(target) 
  ## PRIVATE
  # internally used by winDllRecursiveAnalysis
	function(analyzeTargetDependencies base_target)
		# get the target type, check if executable, shared library or STATIC_LIBRARY
		get_target_property(target_type ${base_target} TYPE)
		printCMakeUtilsDebug("[winDllRecursiveAnalysis::analyzeTargetDependencies] for target ${base_target}, type ${target_type}")
		if(${target_type} STREQUAL "INTERFACE_LIBRARY")
			printCMakeUtilsDebug("[winDllRecursiveAnalysis::analyzeTargetDependencies] SKIP for target ${base_target}, it is an interface")
			return()
		endif()
	
	
		printCMakeUtilsDebug("[winDllRecursiveAnalysis::analyzeTargetDependencies] for target ${base_target}")

		set(targets ${base_target})
		list(LENGTH targets targets_num)

		set_target_properties(${base_target} PROPERTIES DLL_DEBUG_LIST "")
		set_target_properties(${base_target} PROPERTIES DLL_RELEASE_LIST "")

		#
		while(targets_num GREATER 0)
				
			# get the first target in the list
			list(GET targets 0 target)
			# and remove it
			list(REMOVE_AT targets 0)

			# get target type
			get_target_property(target_type ${target} TYPE)
			printCMakeUtilsDebug("[winDllRecursiveAnalysis::analyzeTargetDependencies] process target ${target}, type is ${target_type}, is imported ${target_isImported}")

			# manage this target, it is a dll to be copied?
			get_target_property(target_isImported ${target} IMPORTED)
			if(target_isImported AND ((${target_type} STREQUAL "MODULE_LIBRARY") OR (${target_type} STREQUAL "SHARED_LIBRARY")))
				
				# DEBUG
				get_target_property(BIN_F_IMP_DEBUG ${target} IMPORTED_LOCATION_DEBUG) #get dll location
				if(BIN_F_IMP_DEBUG)
					# check file exist
					if(EXISTS ${BIN_F_IMP_DEBUG})
						addToGlobalPropertyUnique(DLL_DEBUG_LIST ${BIN_F_IMP_DEBUG})
						addToTargetPropertyUnique(${base_target} DLL_DEBUG_LIST ${BIN_F_IMP_DEBUG})
					else()
						printCMakeUtilsDebug("[winDllRecursiveAnalysis::analyzeTargetDependencies] dll ${target} depends on ${BIN_F_IMP_DEBUG} but the file does not exists, skip dependancy")
					endif()
				else()
					printCMakeUtilsDebug("[winDllRecursiveAnalysis::analyzeTargetDependencies] dll ${target} does not have IMPORTED_LOCATION_DEBUG")
				endif()
			
				# RELEASE
				get_target_property(BIN_F_IMP_RELEASE ${target} IMPORTED_LOCATION_RELEASE) #get dll location
				if(BIN_F_IMP_RELEASE)
					# check file exist
					if(EXISTS ${BIN_F_IMP_RELEASE})
						addToGlobalPropertyUnique(DLL_RELEASE_LIST ${BIN_F_IMP_RELEASE})
						addToTargetPropertyUnique(${base_target} DLL_RELEASE_LIST ${BIN_F_IMP_RELEASE})
					else()
						printCMakeUtilsDebug("[winDllRecursiveAnalysis::analyzeTargetDependencies] dll ${target} depends on ${BIN_F_IMP_RELEASE} but the file does not exists, skip dependancy")
					endif()
				else()
					printCMakeUtilsDebug("[winDllRecursiveAnalysis::analyzeTargetDependencies] dll ${target} does not have IMPORTED_LOCATION_RELEASE")
				endif()
				
				printCMakeUtilsDebug("[winDllRecursiveAnalysis::analyzeTargetDependencies] add ${target} dll libraries ${BIN_F_IMP_DEBUG} and ${BIN_F_IMP_RELEASE} to global and target list")			
			endif()
			
				
			# recurse on dep libraries
			# get the target type, check if executable, shared library or STATIC_LIBRARY
			get_target_property(target_type ${target} TYPE)
			printCMakeUtilsDebug("[winDllRecursiveAnalysis::analyzeTargetDependencies] for target ${target}, type ${target_type}")
			
			if(${target_type} STREQUAL "INTERFACE_LIBRARY")
				set(link_libs "")
				printCMakeUtilsDebug("[winDllRecursiveAnalysis::analyzeTargetDependencies] ${target} cross dependencies are ${link_libs}, it is an INTERFACE")				
			else()
				set(link_libs "")
				
				get_target_property(tmp_list ${target} LINK_LIBRARIES)
				printCMakeUtilsDebug("[winDllRecursiveAnalysis::analyzeTargetDependencies] ${target} cross dependencies LINK_LIBRARIES ${tmp_list}")
				if(tmp_list)
					list(APPEND link_libs ${tmp_list})
				endif()

				get_target_property(tmp_list ${target} INTERFACE_LINK_LIBRARIES)
				printCMakeUtilsDebug("[winDllRecursiveAnalysis::analyzeTargetDependencies] ${target} cross dependencies INTERFACE_LINK_LIBRARIES ${tmp_list}")
				if(tmp_list)
					list(APPEND link_libs ${tmp_list})
				endif()

				# link dependent
				get_target_property(tmp_list ${target} IMPORTED_LINK_DEPENDENT_LIBRARIES)
				printCMakeUtilsDebug("[winDllRecursiveAnalysis::analyzeTargetDependencies] ${target} cross dependencies IMPORTED_LINK_DEPENDENT_LIBRARIES ${tmp_list}")
				if(tmp_list)
					list(APPEND link_libs ${tmp_list})
				endif()

				get_target_property(tmp_list ${target} IMPORTED_LINK_DEPENDENT_LIBRARIES_DEBUG)
				printCMakeUtilsDebug("[winDllRecursiveAnalysis::analyzeTargetDependencies] ${target} cross dependencies IMPORTED_LINK_DEPENDENT_LIBRARIES_DEBUG ${tmp_list}")
				if(tmp_list)
					list(APPEND link_libs ${tmp_list})
				endif()

				get_target_property(tmp_list ${target} IMPORTED_LINK_DEPENDENT_LIBRARIES_RELEASE)
				printCMakeUtilsDebug("[winDllRecursiveAnalysis::analyzeTargetDependencies] ${target} cross dependencies IMPORTED_LINK_DEPENDENT_LIBRARIES_RELEASE ${tmp_list}")
				if(tmp_list)
					list(APPEND link_libs ${tmp_list})
				endif()

				# link interface
				get_target_property(tmp_list ${target} IMPORTED_LINK_INTERFACE_LIBRARIES)
				printCMakeUtilsDebug("[winDllRecursiveAnalysis::analyzeTargetDependencies] ${target} cross dependencies IMPORTED_LINK_INTERFACE_LIBRARIES ${tmp_list}")
				if(tmp_list)
					list(APPEND link_libs ${tmp_list})
				endif()

				get_target_property(tmp_list ${target} IMPORTED_LINK_INTERFACE_LIBRARIES_DEBUG)
				printCMakeUtilsDebug("[winDllRecursiveAnalysis::analyzeTargetDependencies] ${target} cross dependencies IMPORTED_LINK_INTERFACE_LIBRARIES_DEBUG ${tmp_list}")
				if(tmp_list)
					list(APPEND link_libs ${tmp_list})
				endif()

				get_target_property(tmp_list ${target} IMPORTED_LINK_INTERFACE_LIBRARIES_RELEASE)
				printCMakeUtilsDebug("[winDllRecursiveAnalysis::analyzeTargetDependencies] ${target} cross dependencies IMPORTED_LINK_INTERFACE_LIBRARIES_RELEASE ${tmp_list}")
				if(tmp_list)
					list(APPEND link_libs ${tmp_list})
				endif()
				
			endif()
			
			
			if(link_libs)
				foreach(link_lib ${link_libs})
				
					if(TARGET ${link_lib})
						printCMakeUtilsDebug("[winDllRecursiveAnalysis::analyzeTargetDependencies] ${target} cross dependency ${link_lib} appended to list of dep target to process")
						list(APPEND targets ${link_lib})
					else()
						printCMakeUtilsDebug("[winDllRecursiveAnalysis::analyzeTargetDependencies] ${target} cross dependency ${link_lib} skipped (not target)")
					endif()
				endforeach()
			endif()		

			# refresh while condition variable
			list(LENGTH targets targets_num)
		endwhile()
		
		# finish job for this target, print out its dependency property
		get_target_property(LIST_VALUES ${base_target} DLL_RELEASE_LIST)
		printCMakeUtilsDebug("[winDllRecursiveAnalysis::analyzeTargetDependencies] ${base_target} complete list of dll dependencies (DEBUG): ${LIST_VALUES}")
		get_target_property(LIST_VALUES ${base_target} DLL_DEBUG_LIST)
		printCMakeUtilsDebug("[winDllRecursiveAnalysis::analyzeTargetDependencies] ${base_target} complete list of dll dependencies (RELEASE): ${LIST_VALUES}")
	endfunction()
	
#------------------------------------------------------------------------------------------------------------------------------------		
  # prepareDLLInstall
	# DEBUG or RELEASE, even both (default BOTH)
	function(prepareDLLInstall)
		# check single argument passed or 0 (default GLOBAL)
		if(${ARGC} EQUAL 0)
			# default is BOTH
			get_property(DLL_RELEASE_LIST GLOBAL PROPERTY DLL_RELEASE_LIST)
			prepareDLLInstallImpl(Release ${DLL_RELEASE_LIST})
			get_property(DLL_DEBUG_LIST GLOBAL PROPERTY DLL_DEBUG_LIST)
			prepareDLLInstallImpl(Debug ${DLL_DEBUG_LIST})
		elseif((${ARGC} EQUAL 1) OR (${ARGC} EQUAL 2))
			set(options RELEASE DEBUG)
			cmake_parse_arguments(INPUT "${options}" ""	"" ${ARGN} )
			if(INPUT_RELEASE)
				get_property(DLL_RELEASE_LIST GLOBAL PROPERTY DLL_RELEASE_LIST)
				prepareDLLInstallImpl(Release ${DLL_RELEASE_LIST})			
			endif()
			if(INPUT_DEBUG)
				get_property(DLL_DEBUG_LIST GLOBAL PROPERTY DLL_DEBUG_LIST)
				prepareDLLInstallImpl(Debug ${DLL_DEBUG_LIST})			
			endif()
		else()
			MESSAGE(FATAL_ERROR "prepareDLLInstall wrong number of arguments")
		endif()
	endfunction()

#------------------------------------------------------------------------------------------------------------------------------------		
  ## PRIVATE
	function(prepareDLLInstallImpl CONF)
		foreach(L ${ARGN})
			install(FILES ${L} DESTINATION bin CONFIGURATIONS ${CONF})	
		endforeach()
	endfunction()
	
#------------------------------------------------------------------------------------------------------------------------------------			
  ## PRIVATE
	function(getDirectoriesList outVar)
		set(out "")
		foreach(i ${ARGN})
			get_filename_component(o "${i}" DIRECTORY)
			list(APPEND out ${o})
		endforeach()
		SET(${outVar} ${out} PARENT_SCOPE)
	endfunction()
	
#------------------------------------------------------------------------------------------------------------------------------------			
	function(prepareBatFile)
		# prepare release path
		get_property(DLL_RELEASE_LIST GLOBAL PROPERTY DLL_RELEASE_LIST)
		getDirectoriesList(RELEASE_DLL_PATHS ${DLL_RELEASE_LIST})
		list(REMOVE_DUPLICATES RELEASE_DLL_PATHS)

		# prepare debug path
		get_property(DLL_DEBUG_LIST GLOBAL PROPERTY DLL_DEBUG_LIST)
		getDirectoriesList(DEBUG_DLL_PATHS ${DLL_DEBUG_LIST})
		list(REMOVE_DUPLICATES DEBUG_DLL_PATHS)
		
		# prepare ALL_DLL_PATHS, joining both
		set(ALL_DLL_PATHS_C ${DLL_RELEASE_LIST})
		list (APPEND ALL_DLL_PATHS_C ${DLL_DEBUG_LIST})
		getDirectoriesList(ALL_DLL_PATHS ${ALL_DLL_PATHS_C})
		list(REMOVE_DUPLICATES ALL_DLL_PATHS)
		
		# check if qt plugin folder is required
		find_package(Qt5 COMPONENTS Core CONFIG QUIET)		
		if(Qt5_FOUND)
			get_target_property(BIN_F Qt5::Core LOCATION) #get dll location
			get_filename_component(QT_BIN_DIR "${BIN_F}" DIRECTORY)
			get_filename_component(QT_PLUGIN_PATH "${QT_BIN_DIR}/../plugins" REALPATH)
		endif()
		
		# CMAKE_CXX_COMPILER
		if(MSVC)
			if(MSVC_VERSION EQUAL 1900) # 2015
				if(CMAKE_CL_64)
					get_filename_component(VS_IDE_PATH "${CMAKE_CXX_COMPILER}/../../../../Common7/IDE/devenv.com" REALPATH)			
				else()
					get_filename_component(VS_IDE_PATH "${CMAKE_CXX_COMPILER}/../../../Common7/IDE/devenv.com" REALPATH)	
				endif()		
			elseif((MSVC_VERSION GREATER_EQUAL 1910) AND (MSVC_VERSION LESS_EQUAL 1929)) # 2017 to 2019
				get_filename_component(VS_IDE_PATH "${CMAKE_CXX_COMPILER}/../../../../../../../../Common7/IDE/devenv.com" REALPATH)
			endif()
		endif()
		
		# configure the bat file 
		get_property(CMAKEBASEBUILDSYSTEM_PATH GLOBAL PROPERTY CMAKEBASEBUILDSYSTEM_PATH)		
		configure_file(${CMAKEBASEBUILDSYSTEM_PATH}/config/launch.bat.in
			${CMAKE_BINARY_DIR}/${CMAKE_PROJECT_NAME}.bat
		)
		
	endfunction()
else()
  function(winDllRecursiveAnalysis)
  endfunction()

  function(addDLLToTarget)
  endfunction()

  function(analyzeTargetDependencies)
  endfunction()

  function(prepareDLLInstall)
  endfunction()

  function(prepareDLLInstallImpl)
  endfunction()

  function(prepareBatFile)	
  endfunction()
		
endif()