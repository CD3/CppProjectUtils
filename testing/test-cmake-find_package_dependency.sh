#! /bin/bash

function component_cmakelists()
{
NAME=$1
shift
cat << EOF
cmake_minimum_required(VERSION 3.9)
project(${NAME} VERSION 1.0)
add_library(${NAME} main.cpp)
add_library(${NAME}::${NAME} ALIAS ${NAME})
target_include_directories( ${NAME} PUBLIC
  $<BUILD_INTERFACE:\${CMAKE_CURRENT_SOURCE_DIR}/include>
  $<INSTALL_INTERFACE:${NAME}/include>)
install( TARGETS ${NAME} EXPORT ${NAME}Targets
  LIBRARY DESTINATION ${NAME}/lib
  ARCHIVE DESTINATION ${NAME}/lib
  RUNTIME DESTINATION ${NAME}/bin
  INCLUDES DESTINATION ${NAME}/include)
install(DIRECTORY include/
        DESTINATION ${NAME}/include/)
install(EXPORT ${NAME}Targets
  FILE ${NAME}Targets.cmake
  NAMESPACE ${NAME}::
  DESTINATION ${NAME}/cmake)
file(WRITE \${CMAKE_CURRENT_BINARY_DIR}/${NAME}Config.cmake
"include(CMakeFindDependencyMacro)
include(\\\${CMAKE_CURRENT_LIST_DIR}/${NAME}Targets.cmake)
"
  )
include(CMakePackageConfigHelpers)
write_basic_package_version_file(\${CMAKE_CURRENT_BINARY_DIR}/${NAME}ConfigVersion.cmake
  VERSION \${${NAME}_VERSION}
  COMPATIBILITY SameMajorVersion)
install(FILES
  \${CMAKE_CURRENT_BINARY_DIR}/${NAME}Config.cmake
  \${CMAKE_CURRENT_BINARY_DIR}/${NAME}ConfigVersion.cmake
  DESTINATION ${NAME}/cmake)
EOF
}

function component_main()
{
NAME=$1
shift
MSG=$1
shift
cat << EOF 
#include <string>
namespace ${NAME} {
std::string info()
{
  return "${MSG}";
}
}
EOF
}

function component_header()
{
NAME=$1
shift
cat << EOF 
namespace ${NAME} {
#include<string>
std::string info();
}
EOF
}

function component_make()
{
  CURR_DIR=$PWD

  NAME=$1
  shift

  [ -d ${NAME} ] && rm ${NAME} -r

  mkdir ${NAME}
  cd ${NAME}
  mkdir include
  component_cmakelists ${NAME}               > CMakeLists.txt
  component_main   ${NAME} "${NAME}:UNKNOWN" > main.cpp
  component_header ${NAME}                   > include/${NAME}_main.h

  cd $CURR_DIR
}

function component_install()
{
  CURR_DIR=$PWD

  NAME=$1
  shift
  LOC=$1
  shift

  component_make ${NAME}
  component_main ${NAME} "${NAME}:${LOC}" > ${NAME}/main.cpp

  cd ${NAME}
  mkdir build
  cd build
  cmake .. -DCMAKE_INSTALL_PREFIX=${LOC}
  make
  make install

  cd $CURR_DIR
}

function component_copy_to()
{
  CURR_DIR=$PWD

  NAME=$1
  shift
  LOC=$1
  shift

  [ -d ${LOC} ] || mkdir ${LOC}
  component_make ${NAME}
  component_main ${NAME} "${NAME}:${LOC}:uninstalled" > ${NAME}/main.cpp
  cp -r ${NAME} ${LOC}


  cd $CURR_DIR
}


function client_build() {

  CURR_DIR=$PWD

  NAME=$1
  shift
  CMAKE_OPTS=$1
  shift

  [ -d ${NAME} ] || mkdir ${NAME}

  cd ${NAME}

  cat << EOF > CMakeLists.txt
  cmake_minimum_required(VERSION 3.9)

  include( ${TOPDIR}/../../cmake/Modules/macro-find_project_dependency.cmake )
  #include( macro-find_project_dependency )

  project(${NAME})

  add_executable(${NAME} main.cpp)
EOF

  echo "#include<iostream>" > main.cpp
  for COMP in "${@}"
  do
    echo "#include<${COMP}_main.h>" >> main.cpp
  done
  echo "int main(int argc, char *argv[])" >> main.cpp
  echo "{" >> main.cpp
  for COMP in "${@}"
  do
    echo "std::cout << ${COMP}::info() << std::endl;" >> main.cpp
  done
  echo "return 0;" >> main.cpp
  echo "}" >> main.cpp



  for COMP in "${@}"
  do
    cat << EOF >> CMakeLists.txt
    find_project_dependency( ${COMP}
                             PATHS \${CMAKE_CURRENT_SOURCE_DIR}/install \$ENV{INSTALLS}
                             OVERRIDE_PATHS \${CMAKE_CURRENT_SOURCE_DIR}/overrides
                             SUBDIRECTORY_PATHS \${CMAKE_CURRENT_SOURCE_DIR}/externals \$ENV{EXTERNALS} )
    target_link_libraries( ${NAME} PUBLIC ${COMP}::${COMP} )
EOF

done

  mkdir build
  cd build
  cmake .. ${CMAKE_OPTS}
  make
  
  cd $CURR_DIR
}




set -e

TOPDIR=$(readlink -f $0.d)
rm ${TOPDIR} -rf
mkdir ${TOPDIR}

cd ${TOPDIR}

export INSTALLS="${TOPDIR}/install;${TOPDIR}/install2"

component_install comp1 ${TOPDIR}/install

component_install comp2 ${TOPDIR}/install
component_install comp2 ${TOPDIR}/client/install

component_install comp3 ${TOPDIR}/install
component_install comp3 ${TOPDIR}/client/install
component_install comp3 ${HOME}/tmp/install

component_copy_to comp4 ${TOPDIR}/client/externals

component_install comp5 ${TOPDIR}/install
component_copy_to comp5 ${TOPDIR}/client/externals

component_install comp6 ${TOPDIR}/install
component_copy_to comp6 ${TOPDIR}/client/overrides

component_install comp7 ${TOPDIR}/install2

client_build client "-Dcomp3_DIR=${HOME}/tmp/install/comp3/cmake" comp1 comp2 comp3 comp4 comp5 comp6 comp7

./client/build/client > tmp.txt

cat << EOF | diff tmp.txt - | tee output.diff
comp1:${TOPDIR}/install
comp2:${TOPDIR}/client/install
comp3:${HOME}/tmp/install
comp4:${TOPDIR}/client/externals:uninstalled
comp5:${TOPDIR}/install
comp6:${TOPDIR}/client/overrides:uninstalled
comp7:${TOPDIR}/install2
EOF
if [ "$?" -eq 0 ]
then
  echo "Everything looks good"
  exit 0
else
  echo "ERROR: output did NOT match expected."
  exit 1
fi




exit 0
