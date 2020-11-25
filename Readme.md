# CMakeBaseBuildSystem
The aim of this library is to provide useful functions to standardize CMake based build projects. 
It is composed of cmake scripts and functions (*.cmake files in this folder), input files that will be configured (config/*.in) and templates (templates/CMakeLists.txt.*) as an example on how to structure a project made of libraries and executables.

## Requirements

### CMake
The (minium) required version for CMake is **3.17.0**. But, if available please install a newer version!

#### How to install on Windows
You can download installer from https://cmake.org/download. Suggested version is cmake-VERSION-win64-x64.msi and install normally

#### Linux / Ubuntu

Normally repositories (e.g., Ubuntu 18.04 offers CMake ) does not offer modern cmake version. If you already have CMake installed, uninstall it using the package manager (e.g., `sudo apt remove cmake` in Ubuntu/Debian).
Ubuntu (since 16.04) offers a alternative package manager system, `snap`, to install CMake use

```sudo snap install cmake --classic```

More info here https://snapcraft.io/install/cmake/ubuntu

Otherwise CMake can be downloaded from the official website (https://cmake.org/) and compiled from sources

### Why should I install the last version of CMake? 
Even known as "I already have CMake 3.X, are you really requiring the very last functionality of CMake?". No, probably no, but CMake developers encourage to use the very last version of this tool (see e.g., https://cliutils.gitlab.io/modern-cmake section *Why use a Modern CMake?*) and its installation is simple, probably it would have take less than reading this answer.... So please go back to section *How To install*.


## How to organize your project
We recommend to use `CMakeBaseBuildSystem ` in a folder structure similar to the following
```
+ your_workspace
|-+ cmakebasebuildsystem
|-+ yourfirstproject
  |-+ yourfirstproject_source
    |- CMakeLists.txt (main for the project)
  |-+ yourfirstproject_build
|-+ yoursecondproject
  |-+ yoursecondproject_source
    |- CMakeLists.txt (main for the project)
  |-+ yoursecondproject_build
```
You will need only a single copy of `CMakeBaseBuildSystem` shared between different projects.

Provided templates for structuring a new project look for `CMakeBaseBuildSystem` in `../../cmakebasebuildsystem` from the location of the main `CMakeLists.txt`.

These values can be changed freely in the `CMakeLists.txt` or by setting `<MAIN_PROJECT_NAME>_CMAKEBASEBUILDSYSTEM_PATH` cache variables. 

## Templates

The subfolder `templates` contains a list of samples `CMakeLists.txt` that can be used to create libraries, executables, samples and tests plus some other code templates. You can choose the more appropriate one for your case, copy in your folder and edit it.
Elements marked with `<<NAME>>` have to been susbstituted inside the templates according to your requirements.

Here there is a list of available `CMakeLists.txt` templates. Copy these templates where you need, remove the last extension, and fill in according to your needs:
* `CMakeLists.txt.main`: the main `CMakeLists.txt`, copy it in the root folder of your project.
* `CMakeLists.txt.executable`: a `CMakeLists.txt` suitable to create a folder defining an executable target.
* `CMakeLists.txt.interface`: a `CMakeLists.txt` suitable to create a folder defining an `INTERFACE` library (tipically header only library) target.
* `CMakeLists.txt.library`: a `CMakeLists.txt` suitable to create a folder defining a library (`STATIC` or `SHARED`).
* `CMakeLists.txt.samples`: a `CMakeLists.txt` suitable to create a folder containing samples. Normally this is a subfolder of a library or interface library.
* `CMakeLists.txt.tests`: a `CMakeLists.txt` suitable to create a folder containing tests. Normally this is a subfolder of a library or interface library.

Other templates:
* `example.cpp.test`: contains a sample on how to create a test with boost_test. Suitable for a tests folder.

Common substitution:
* `<<MAIN_PROJECT_NAME>>`: the name of your main project, e.g., `mySuperDuperLibrary`
* `<<DEFAULT_COMPONENT_LIST>>`: list of install targets included by default in the installed project. Refer to `CMakeLists.txt.main` and to function `createGlobalConfigFile()` in `CMakeBaseBuildSystem.cmake` for additional information.
* `<<LIBRARY_NAME>>`: name of the project name in `INTERFACE` and `STATIC` or `SHARED` libraries.
* `<<EXECUTABLE_NAME>>`: name of the project name for executable.
* `<<TARGET_NAME>>`: name of the target. In every `CMakeLists.txt` apart the main one. Note: if the project has only one target, it normally coincides with the project name, but this is not mandatory.
* `<<STATIC|SHARED>>`: in library, chose your library type
* `<<PUBLIC|PRIVATE>>`: define if compile options, linked libraries, etc are to be exported publicly or not.
* `<<...>>`: indicate a list of elements to be filled in, e.g., sources and headers for targets, linked resources, etc...
* `<<DEFAULT_VALUE>>`: allow to specify the default value for an option.
* `<<INSTALL_COMPONENT>>`: argument of `installAllTargets` (or `installTarget` for a single target) in executable, library and interface template `CMakeLists.txt`. Allow to specify in which exported target the target(s) will be exported. Names will be used by library clients as `COMPONENTS`.
* `<<SAMPLES_MAIN_NAME>>`: name for project containing samples, used in template for samples.
* `<<SAMPLE_FOLDER>>`: folder for organizing the samples
* `<<TESTS_MAIN_NAME>>`:  name for project containing tests, used in template for tests.
* `<<TEST_FOLDER>>`: folder for organizing the tests
* `<<TEST_NAME>>`: used in `example.test.cpp`, name of a single test function

## Common Defined Options

These options are defined in the main CMakeLists.txt.main
* `<<MAIN_PROJECT_NAME>>_INSTALL_DEPENDENCIES`: allow to install all cross-dependencies of projects. This is useful if your project has to be distributed as a standalone executable (or set of executables). Default value `ON` or `OFF` should be chosen depending on the expected role of your project. If your project is a library or a collection of libraries this should be `OFF` by default, you do not need to export cross dependencies, otherwise If your project is a library or a collection of libraries this should be `ON` by default.
* `<<MAIN_PROJECT_NAME>>_BUILD_SAMPLES`: allow to turn `ON` or `OFF` compilation of `samples` subfolders.
* `<<MAIN_PROJECT_NAME>>_BUILD_TESTS` : allow to turn `ON` or `OFF` compilation of `tests` subfolders.
* `BUILD_<<PROJECT_NAME>>_SAMPLES`: allow to selectively disable compilation of samples of a specific project. This is valid only if `<<MAIN_PROJECT_NAME>>_BUILD_SAMPLES` is `ON`
* `BUILD_<<PROJECT_NAME>>_TESTS`: allow to selectively disable compilation of samples of a specific project. This is valid only if `<<MAIN_PROJECT_NAME>>_BUILD_TESTS` is `ON`

## Common Behavior
Most of the following things can be personalized, here you have some default behavior description
* library in `Debug` will be produced with a `d` suffix (e.g., `myLibd.dll` in `DEBUG` and `myLib.dll` in `Release`).
*  executables will not follow the previous rule (by default), i.e., `Release` and `Debug` will have the same name.
* [windows only] a file `<<MAIN_PROJECT_NAME>>`.bat will be produced in the `build` folder. This will contains few lines that set the `PATH` environment variable and allow to start Visual Studio IDE or to open a console with the correct working environemnt.
* installation path is  by default in `include`folder in the `build` folder


## Command Line

### Configure and Generate a project
```
cd <your_project_folder>/<build_folder>
cmake ..\<source_folder>
```
or
```
cd <your_project_folder>/<build_folder>
cmake-gui ..\<source_folder>
```
then use Configure and Generate

In Windows environemnt with Microsoft Visual Studio, a bat file will be created in the <build_folder>. By default it will open Visual Studio IDE, but through command line it can open a terminal with all the paths to Dll properly setted.

#### Tips & Tricks
* Once a project has been generated it is sufficient to use `cmake .`  or `cmake-gui .` in the build folder, the source is already known
* Normally you will not need to re-run cmake, if necessary `make` command or IDE based build process will rerun cmake when necessary.

### How to compile and install from command line
#### Windows
```
cmake --build .  --config Debug 
cmake --build .  --config Release
```
```
cmake --install .  --config Debug 
cmake --install .  --config Release
```
#### Linux
TODO

## Known issues

 - `INTERFACE` libraries does not appear in Visual Studio IDE.

## Missing features & TODO
 - `Qt Plugins` are not installed. **TODO** Implement specific functions in `QtCMakeUtils.cmake` to address this issue
 - `installSpecialCMake` function copies the content of a folder to ```${CMAKE_INSTALL_LIBDIR}/cmake/${ROOT_NAME}```. The folder should contain special `cmake` files to be given to the client. Some file might be platform dependent, a mechanism to install only the required ones should be provided.

## Troubleshooting

## Markdown language
Used to write this file and supported in *bitbucket*

* Find a guide on markdown language used to write this file here https://guides.github.com/features/mastering-markdown/
* There are lots of useful tool for editing/preview Markdown. This file was produced with https://stackedit.io/ on line
