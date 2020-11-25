cmake_minimum_required(VERSION 3.17)
include_guard(GLOBAL)

find_package(Git QUIET)
if(NOT Git_FOUND)
  message("Git NOT found, tracking of version is not possible")
endif()

if(Git_FOUND)

	function(gitHashTrace directory out_hash)
		execute_process(COMMAND
				"${GIT_EXECUTABLE}"
				rev-parse HEAD
				WORKING_DIRECTORY
				"${directory}"
				RESULT_VARIABLE
				res
				OUTPUT_VARIABLE
				HEAD_HASH
				ERROR_QUIET
				OUTPUT_STRIP_TRAILING_WHITESPACE)
			if(NOT res EQUAL 0)
				# some error
				set(HEAD_HASH "UNKNOWN, error executing git command")
			endif()		

		set(${out_hash} "${HEAD_HASH}" PARENT_SCOPE)
	endfunction()

	function(gitLastLogTrace directory out_log)
		#log -1 --oneline
		execute_process(COMMAND
				"${GIT_EXECUTABLE}"
				log -1 --format="%cI %f"
				WORKING_DIRECTORY
				"${directory}"
				RESULT_VARIABLE
				res
				OUTPUT_VARIABLE
				OUT_LOG
				ERROR_QUIET
				OUTPUT_STRIP_TRAILING_WHITESPACE)
			if(NOT res EQUAL 0)
				# some error
				set(OUT_LOG "UNKNOWN, error executing git command")
			endif()		

		set(${out_log} "${OUT_LOG}" PARENT_SCOPE)
	endfunction()

	function(configureGitCMakeFile directory outName destination)
		get_property(CMAKEBASEBUILDSYSTEM_PATH GLOBAL PROPERTY CMAKEBASEBUILDSYSTEM_PATH)
		
		gitHashTrace(${directory} GIT_HASH_VALUE)
		gitLastLogTrace(${directory} GIT_LOG_VALUE)
		
		set(GIT_HASH_NAME "${outName}_HASH")
		set(GIT_LOG_NAME "${outName}_LOG")
		
		configure_file (
			"${CMAKEBASEBUILDSYSTEM_PATH}/config/gitVersion.cmake.in"
			"${destination}/${outName}.cmake"
		)
		
		include("${destination}/${outName}.cmake")
	endfunction()
	

else()

	function(gitHashTrace)
		message("gitHashTrace skipped, git package not found")
		set(${out_hash} "UNKNOWN, git package not found" PARENT_SCOPE)
	endfunction()
	
	function(gitLastLogTrace)
		message("gitLastLogTrace skipped, git package not found")
		set(${out_log} "UNKNOWN, git package not found" PARENT_SCOPE)
	endfunction()
	
	function(configureGitCMakeFile)
		message("configureGitCMakeFile skipped, git package not found")
	endfunction()
		
endif()