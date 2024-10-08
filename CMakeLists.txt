# bgfx.cmake - bgfx building in cmake
# Written in 2017 by Joshua Brookover <joshua.al.brookover@gmail.com>

# To the extent possible under law, the author(s) have dedicated all copyright
# and related and neighboring rights to this software to the public domain
# worldwide. This software is distributed without any warranty.

# You should have received a copy of the CC0 Public Domain Dedication along with
# this software. If not, see <http://creativecommons.org/publicdomain/zero/1.0/>.

cmake_minimum_required( VERSION 3.0 )
project( bgfx )

set_property( GLOBAL PROPERTY USE_FOLDERS ON )
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# __cplusplus value is not in sync with language version used. MVSC needs this flag to update it accordingly
# https://gitlab.kitware.com/cmake/cmake/-/issues/18837
if (MSVC)
    add_compile_options(/Zc:__cplusplus)

    # https://devblogs.microsoft.com/cppblog/announcing-full-support-for-a-c-c-conformant-preprocessor-in-msvc/
    add_compile_options(/Zc:preprocessor)
endif()

if( APPLE AND NOT IOS )
	set( CMAKE_CXX_FLAGS "-ObjC++" )
endif()

if (MSVC AND (MSVC_VERSION GREATER_EQUAL 1914))
    add_compile_options("/Zc:__cplusplus")
endif()

option( BGFX_BUILD_TOOLS                "Build bgfx tools."                             ON  )
option( BGFX_BUILD_TOOLS_SHADER         "Build bgfx shader tools."                      ON  )
option( BGFX_BUILD_TOOLS_GEOMETRY       "Build bgfx geometry tools."                    ON  )
option( BGFX_BUILD_TOOLS_TEXTURE        "Build bgfx texture tools."                     ON  )
option( BGFX_BUILD_EXAMPLES             "Build bgfx examples."                          ON  )
option( BGFX_INSTALL                    "Create installation target."                   OFF  )
option( BGFX_INSTALL_EXAMPLES           "Install examples and their runtimes."          OFF )
option( BGFX_CUSTOM_TARGETS             "Include convenience custom targets."           ON  )
option( BGFX_AMALGAMATED                "Amalgamated bgfx build for faster compilation" OFF )
option( BX_AMALGAMATED                  "Amalgamated bx build for faster compilation"   OFF )
option( BGFX_CONFIG_MULTITHREADED       "Build bgfx with multithreaded configuration"   ON )
option( BGFX_CONFIG_RENDERER_WEBGPU     "Enables the webgpu renderer"                   OFF )
option( BX_CONFIG_DEBUG                 "Log debug messages (default: on in debug)"     OFF )

set( BGFX_OPENGL_VERSION   ""       CACHE STRING "Specify minimum opengl version" )
set( BGFX_OPENGLES_VERSION ""       CACHE STRING "Specify minimum OpenGL ES version" )
set( BGFX_LIBRARY_TYPE     "STATIC" CACHE STRING "Linking type for library" )

set( BGFX_CONFIG_DEFAULT_MAX_ENCODERS             "" CACHE STRING "Specify default maximum encoder count (multithreaded only)" )
set( BGFX_CONFIG_MAX_DRAW_CALLS                   "" CACHE STRING "Specify maximum draw calls" )
set( BGFX_CONFIG_MAX_VIEWS                        "" CACHE STRING "Specify maximum view count (should be a power of two)" )
set( BGFX_CONFIG_MAX_FRAME_BUFFERS                "" CACHE STRING "Specify maximum frame buffers" )
set( BGFX_CONFIG_MAX_VERTEX_LAYOUTS               "" CACHE STRING "Specify maximum vertex layouts" )
set( BGFX_CONFIG_MAX_VERTEX_BUFFERS               "" CACHE STRING "Specify maximum vertex buffer count" )
set( BGFX_CONFIG_MAX_DYNAMIC_VERTEX_BUFFERS       "" CACHE STRING "Specify maximum dynamic vertex buffer count" )
set( BGFX_CONFIG_MAX_INDEX_BUFFERS                "" CACHE STRING "Specify maximum index buffer count" )
set( BGFX_CONFIG_MAX_DYNAMIC_INDEX_BUFFERS        "" CACHE STRING "Specify maximum dynamic index buffer count" )
set( BGFX_CONFIG_MAX_TEXTURES                     "" CACHE STRING "Specify maximum texture count" )
set( BGFX_CONFIG_MAX_TEXTURE_SAMPLERS             "" CACHE STRING "Specify maximum texture samplers" )
set( BGFX_CONFIG_MAX_SHADERS                      "" CACHE STRING "Specify shader count" )
set( BGFX_CONFIG_SORT_KEY_NUM_BITS_PROGRAM        "" CACHE STRING "Specify maximum program count as 2^(program bits)" )

set_property( CACHE BGFX_LIBRARY_TYPE PROPERTY STRINGS STATIC SHARED )

if( BGFX_LIBRARY_TYPE MATCHES "SHARED" )
    set(CMAKE_POSITION_INDEPENDENT_CODE ON)
endif()

if( NOT BX_DIR )
	set( BX_DIR "${CMAKE_CURRENT_SOURCE_DIR}/bx" CACHE STRING "Location of bx." )
elseif( NOT IS_ABSOLUTE "${BX_DIR}")
	get_filename_component(BX_DIR "${BX_DIR}" REALPATH BASE_DIR "${CMAKE_CURRENT_SOURCE_DIR}")
endif()
if( NOT BIMG_DIR )
	set( BIMG_DIR "${CMAKE_CURRENT_SOURCE_DIR}/bimg" CACHE STRING "Location of bimg." )
elseif( NOT IS_ABSOLUTE "${BIMG_DIR}")
	get_filename_component(BIMG_DIR "${BIMG_DIR}" REALPATH BASE_DIR "${CMAKE_CURRENT_SOURCE_DIR}")
endif()
if( NOT BGFX_DIR )
	set( BGFX_DIR "${CMAKE_CURRENT_SOURCE_DIR}/bgfx" CACHE STRING "Location of bgfx." )
elseif( NOT IS_ABSOLUTE "${BGFX_DIR}")
	get_filename_component(BGFX_DIR "${BGFX_DIR}" REALPATH BASE_DIR "${CMAKE_CURRENT_SOURCE_DIR}")
endif()

# sets project version from api ver / git rev
include( ${CMAKE_CURRENT_SOURCE_DIR}/cmake/version.cmake )

include( ${CMAKE_CURRENT_SOURCE_DIR}/cmake/shared.cmake )
include( ${CMAKE_CURRENT_SOURCE_DIR}/cmake/bx.cmake )
include( ${CMAKE_CURRENT_SOURCE_DIR}/cmake/bimg.cmake )
include( ${CMAKE_CURRENT_SOURCE_DIR}/cmake/bgfx.cmake )

if( BGFX_BUILD_TOOLS )
	include( ${CMAKE_CURRENT_SOURCE_DIR}/cmake/tools.cmake )
endif()

if( BGFX_BUILD_TOOLS OR BGFX_BUILD_EXAMPLES )
	include( ${CMAKE_CURRENT_SOURCE_DIR}/cmake/examples.cmake )
endif()

if( BGFX_INSTALL )
	include(GNUInstallDirs)

	# install bx
	install( TARGETS bx
		EXPORT bgfx-config
		ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR} )
	install( DIRECTORY ${BX_DIR}/include DESTINATION . )

	# Configuration
	set(version_config "${generated_dir}/${PROJECT_NAME}ConfigVersion.cmake")
	set(project_config "${generated_dir}/${PROJECT_NAME}Config.cmake")
	set(TARGETS_EXPORT_NAME "${PROJECT_NAME}Targets")
	set(namespace "${PROJECT_NAME}::")

	# Include module with fuction 'write_basic_package_version_file'
	include(CMakePackageConfigHelpers)

	# Configure '<PROJECT-NAME>ConfigVersion.cmake'
	# Use:
	#   * PROJECT_VERSION
	if(${CMAKE_VERSION} VERSION_LESS "3.11.0")
		set(BGFX_COMPATIBILITY SameMajorVersion)
	else()
		set(BGFX_COMPATIBILITY SameMinorVersion)
	endif()
	write_basic_package_version_file(
		"${version_config}"
		VERSION ${PROJECT_VERSION}
		COMPATIBILITY ${BGFX_COMPATIBILITY}
	)

	# Configure '<PROJECT-NAME>Config.cmake'
	# Use variables:
	#   * TARGETS_EXPORT_NAME
	#   * PROJECT_NAME
	configure_package_config_file(
		"${CMAKE_CURRENT_SOURCE_DIR}/cmake/Config.cmake.in"
		"${project_config}"
		INSTALL_DESTINATION "${config_install_dir}"
	)

	install(FILES ${BGFX_DIR}/LICENSE DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/licences/${PROJECT_NAME})

	# install bgfx
	install( TARGETS bgfx
			 EXPORT "${TARGETS_EXPORT_NAME}"
			 LIBRARY DESTINATION "${CMAKE_INSTALL_LIBDIR}"
			 ARCHIVE DESTINATION "${CMAKE_INSTALL_LIBDIR}"
			 RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}"
			 INCLUDES DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}"
	)
	if( NOT BGFX_LIBRARY_TYPE MATCHES "SHARED" )
		install( TARGETS bimg bx astc-encoder edtaa3 etc1 etc2 iqa squish nvtt pvrtc tinyexr
				 EXPORT "${TARGETS_EXPORT_NAME}"
				 LIBRARY DESTINATION "${CMAKE_INSTALL_LIBDIR}"
				 ARCHIVE DESTINATION "${CMAKE_INSTALL_LIBDIR}"
				 RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}"
				 INCLUDES DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}"
		)
	endif()
    if (BGFX_CONFIG_RENDERER_WEBGPU)
		install( TARGETS webgpu
				 EXPORT "${TARGETS_EXPORT_NAME}"
				 LIBRARY DESTINATION "${CMAKE_INSTALL_LIBDIR}"
				 ARCHIVE DESTINATION "${CMAKE_INSTALL_LIBDIR}"
				 RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}"
				 INCLUDES DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}"
		)
    endif()

	# install export
	install(
		EXPORT bgfx-config
		NAMESPACE bgfx::
		DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/bgfx)

	# install tools
	install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/cmake/bgfxToolUtils.cmake
		DESTINATION "${config_install_dir}")
	if( BGFX_BUILD_TOOLS )
		if (BGFX_BUILD_TOOLS_SHADER)
			install( TARGETS shaderc
				EXPORT "${TARGETS_EXPORT_NAME}"
				DESTINATION "${CMAKE_INSTALL_BINDIR}" )
		endif()
		if (BGFX_BUILD_TOOLS_GEOMETRY)
			install( TARGETS geometryc
				EXPORT "${TARGETS_EXPORT_NAME}"
				DESTINATION "${CMAKE_INSTALL_BINDIR}" )
			install( TARGETS geometryv
				EXPORT "${TARGETS_EXPORT_NAME}"
				DESTINATION "${CMAKE_INSTALL_BINDIR}" )
		endif()
		if (BGFX_BUILD_TOOLS_TEXTURE)
			install( TARGETS texturec
				EXPORT "${TARGETS_EXPORT_NAME}"
				DESTINATION "${CMAKE_INSTALL_BINDIR}" )
			install( TARGETS texturev
				EXPORT "${TARGETS_EXPORT_NAME}"
				DESTINATION "${CMAKE_INSTALL_BINDIR}" )
		endif()
	endif()

	# install examples
	if( BGFX_BUILD_EXAMPLES AND BGFX_INSTALL_EXAMPLES )
		install( DIRECTORY ${BGFX_DIR}/examples/runtime/ DESTINATION examples )
		foreach( EXAMPLE ${BGFX_EXAMPLES} )
			install( TARGETS example-${EXAMPLE} DESTINATION examples )
		endforeach()
	endif()
endif()
